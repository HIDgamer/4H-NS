//! Native A* grid pathfinder for NPC Xenomorph AI movement.
//!
//! This is a standalone extension (not a fork of rust-g) exposed via the same
//! `call_ext()`-compatible C ABI convention rust-g uses: fixed-arity functions
//! taking `*const c_char` string arguments and returning a `*const c_char`
//! string, valid until the next call on the same thread.
//!
//! Two solvers live here:
//! - `xeno_pathfind` (original): BYOND supplies a bounded local grid
//!   (blocked/open per tile) around the chase area per call. Kept unchanged
//!   as the fallback for hosts running DM code newer than their DLL.
//! - `xeno_pathfind_route` (persistent): BYOND bulk-loads each z-level's
//!   walkability once at round start (`xeno_pathfind_init_z`), then pushes
//!   only deltas as turfs/doors change (`xeno_pathfind_update`). Routes are
//!   solved against this retained full-map grid - true long-range routing
//!   around whole buildings, plus a decaying "threat" cost layer
//!   (`xeno_pathfind_threat`/`xeno_pathfind_decay`) that bends paths away
//!   from tiles where hive members recently died.

use std::cell::RefCell;
use std::cmp::Ordering;
use std::collections::{BinaryHeap, HashMap};
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::sync::{LazyLock, Mutex};

thread_local! {
    static RETURN_STRING: RefCell<CString> = RefCell::new(CString::default());
}

/// Leaks the string into a thread-local CString and returns a pointer valid
/// until this thread's next call into this library - the standard rust-g
/// return-string pattern, since BYOND copies the string immediately.
fn return_to_byond(s: String) -> *const c_char {
    RETURN_STRING.with(|cell| {
        let cstring = CString::new(s).unwrap_or_default();
        let ptr = cstring.as_ptr();
        *cell.borrow_mut() = cstring;
        ptr
    })
}

/// # Safety
/// `ptr` must be either null or a valid pointer to a null-terminated C string,
/// which is exactly what BYOND's call_ext() passes for string arguments.
unsafe fn parse_arg<'a>(ptr: *const c_char) -> &'a str {
    if ptr.is_null() {
        return "";
    }
    CStr::from_ptr(ptr).to_str().unwrap_or("")
}

/// # Safety
/// `argv` must be either null or a valid pointer to `argc` C string pointers -
/// exactly what BYOND's call_ext() passes (its external-function ABI is
/// `char* func(int argc, char** argv)`, NOT one C parameter per DM argument;
/// declaring individual `*const c_char` parameters makes the function
/// dereference argc as a pointer and crash with a "native exception").
unsafe fn parse_args<'a>(argc: c_int, argv: *const *const c_char) -> Vec<&'a str> {
    if argv.is_null() || argc <= 0 {
        return Vec::new();
    }
    (0..argc as usize).map(|i| parse_arg(*argv.add(i))).collect()
}

/// Shared FFI shell: decodes BYOND's (argc, argv), enforces the expected
/// argument count, and catches any panic (a panic unwinding across an
/// `extern "C"` boundary aborts the whole Dream Daemon process - contained
/// here it just becomes an empty "unavailable" result instead).
fn byond_call(
    argc: c_int,
    argv: *const *const c_char,
    want: usize,
    body: impl Fn(&[&str]) -> String,
) -> *const c_char {
    let args = unsafe { parse_args(argc, argv) };
    if args.len() < want {
        return return_to_byond(String::new());
    }
    let out = catch_unwind(AssertUnwindSafe(|| body(&args))).unwrap_or_default();
    return_to_byond(out)
}

#[derive(Copy, Clone, Eq, PartialEq)]
struct OpenNode {
    priority: i32,
    x: i32,
    y: i32,
}

// BinaryHeap is a max-heap; reverse priority ordering to get a min-heap.
impl Ord for OpenNode {
    fn cmp(&self, other: &Self) -> Ordering {
        other.priority.cmp(&self.priority)
    }
}

impl PartialOrd for OpenNode {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

/// Manhattan distance heuristic - movement is 4-directional only (see
/// DIRECTIONS), so there's no diagonal cost component to approximate.
fn heuristic(x1: i32, y1: i32, x2: i32, y2: i32) -> i32 {
    let dx = (x1 - x2).abs();
    let dy = (y1 - y2).abs();
    10 * (dx + dy)
}

/// Cardinal moves only - deliberately no diagonals. Diagonal steps produced
/// the "conga line" effect when several xenos converged on the same target
/// (their near-identical diagonal shortcuts all funneled through the same
/// handful of corner tiles) and looked unnatural for a creature that isn't
/// actually cutting corners. Cardinal-only paths are longer in the open but
/// match BYOND's own cardinal movement more predictably.
const DIRECTIONS: [(i32, i32, i32); 4] = [(1, 0, 10), (-1, 0, 10), (0, 1, 10), (0, -1, 10)];

/// A* over a bounded width x height grid. `blocked[y*width+x]` is true if
/// that tile can't be entered. Returns the path from start to end inclusive,
/// or None if unreachable. Cardinal movement only (see DIRECTIONS) - no
/// diagonal steps, so there's nothing to reject for corner-cutting.
pub fn find_path(
    width: i32,
    height: i32,
    start: (i32, i32),
    end: (i32, i32),
    blocked: &[bool],
) -> Option<Vec<(i32, i32)>> {
    if width <= 0 || height <= 0 {
        return None;
    }
    let idx = |x: i32, y: i32| -> usize { (y * width + x) as usize };
    let in_bounds = |x: i32, y: i32| -> bool { x >= 0 && y >= 0 && x < width && y < height };

    if !in_bounds(start.0, start.1) || !in_bounds(end.0, end.1) {
        return None;
    }
    if blocked.len() != (width * height) as usize {
        return None;
    }
    if blocked[idx(end.0, end.1)] {
        return None;
    }
    if start == end {
        return Some(vec![start]);
    }

    let cell_count = (width * height) as usize;
    let mut g_score = vec![i32::MAX; cell_count];
    let mut came_from = vec![-1i32; cell_count];
    let mut closed = vec![false; cell_count];

    g_score[idx(start.0, start.1)] = 0;

    let mut open = BinaryHeap::new();
    open.push(OpenNode {
        priority: heuristic(start.0, start.1, end.0, end.1),
        x: start.0,
        y: start.1,
    });

    // Bounds worst-case cost - this is meant for bounded local chase-area
    // pathing (the caller passes a small grid), not full-map routing.
    let max_iterations = cell_count.saturating_mul(4);
    let mut iterations = 0usize;

    while let Some(current) = open.pop() {
        iterations += 1;
        if iterations > max_iterations {
            return None;
        }

        let cur_idx = idx(current.x, current.y);
        if closed[cur_idx] {
            continue;
        }
        if current.x == end.0 && current.y == end.1 {
            let mut path = Vec::new();
            let mut trace = cur_idx as i32;
            while trace != -1 {
                let tx = trace % width;
                let ty = trace / width;
                path.push((tx, ty));
                trace = came_from[trace as usize];
            }
            path.reverse();
            return Some(path);
        }
        closed[cur_idx] = true;

        for (dx, dy, step_cost) in DIRECTIONS.iter() {
            let nx = current.x + dx;
            let ny = current.y + dy;
            if !in_bounds(nx, ny) {
                continue;
            }
            let n_idx = idx(nx, ny);
            if closed[n_idx] || blocked[n_idx] {
                continue;
            }
            let tentative = g_score[cur_idx].saturating_add(*step_cost);
            if tentative < g_score[n_idx] {
                g_score[n_idx] = tentative;
                came_from[n_idx] = cur_idx as i32;
                let priority = tentative + heuristic(nx, ny, end.0, end.1);
                open.push(OpenNode {
                    priority,
                    x: nx,
                    y: ny,
                });
            }
        }
    }

    None
}

/// FFI entry point. `grid_desc` is "width,height,start_x,start_y,end_x,end_y"
/// (grid-local coordinates, 0-indexed). `blocked_map` is a width*height
/// length string of '0'/'1' characters, row-major. Returns a ';'-separated
/// list of "x,y" grid-local coordinates from start to end inclusive, or an
/// empty string if no path exists or the input was malformed.
///
#[no_mangle]
pub extern "C" fn xeno_pathfind(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 2, |args| pathfind_impl(args[0], args[1]))
}

fn pathfind_impl(desc: &str, blocked_str: &str) -> String {
    let parts: Vec<i32> = desc
        .split(',')
        .filter_map(|s| s.trim().parse::<i32>().ok())
        .collect();
    if parts.len() != 6 {
        return String::new();
    }
    let (width, height, sx, sy, ex, ey) = (
        parts[0], parts[1], parts[2], parts[3], parts[4], parts[5],
    );

    if width <= 0 || height <= 0 || (width as i64 * height as i64) as usize != blocked_str.len() {
        return String::new();
    }

    let blocked: Vec<bool> = blocked_str.bytes().map(|b| b == b'1').collect();

    match find_path(width, height, (sx, sy), (ex, ey), &blocked) {
        Some(path) => {
            let encoded: Vec<String> = path.iter().map(|(x, y)| format!("{},{}", x, y)).collect();
            encoded.join(";")
        }
        None => String::new(),
    }
}

// ---------------------------------------------------------------------------
// Persistent full-map grid
// ---------------------------------------------------------------------------

/// Cell walkability codes as sent by BYOND in init/update payloads.
const CELL_OPEN: u8 = b'0';
const CELL_BLOCKED: u8 = b'1';
const CELL_DOOR: u8 = b'2';
const CELL_OBSTACLE: u8 = b'3';

/// Base step cost of entering an open tile (matches the original solver's 10).
const STEP_COST_OPEN: i32 = 10;
/// Step cost of entering a closed-door tile - passable, so a door is always a
/// viable route the AI will open/smash on arrival, but expensive enough that
/// an actually-open corridor of similar length wins.
const STEP_COST_DOOR: i32 = 80;
/// Step cost of a tile holding a dense breakable structure (window, girder) -
/// passable in the same force-on-arrival sense as a door, but priced well
/// above one: without this, a window tile read as OPEN (windows are objects,
/// not turfs) and routes preferred smashing through glass over using the
/// actual door a few tiles away.
const STEP_COST_OBSTACLE: i32 = 200;

/// One z-level's retained state. `base[(y-1)*width + (x-1)]` holds the cell
/// code for world tile (x, y) - BYOND turf coordinates are 1-based.
struct ZGrid {
    width: i32,
    height: i32,
    base: Vec<u8>,
    threat: Vec<u16>,
}

impl ZGrid {
    fn idx(&self, x: i32, y: i32) -> Option<usize> {
        if x < 1 || y < 1 || x > self.width || y > self.height {
            return None;
        }
        Some(((y - 1) * self.width + (x - 1)) as usize)
    }

    /// Extra cost of stepping onto (x, y); None if impassable/out of bounds.
    fn step_cost(&self, x: i32, y: i32) -> Option<i32> {
        let i = self.idx(x, y)?;
        let base = match self.base[i] {
            CELL_OPEN => STEP_COST_OPEN,
            CELL_DOOR => STEP_COST_DOOR,
            CELL_OBSTACLE => STEP_COST_OBSTACLE,
            _ => return None,
        };
        Some(base + self.threat[i] as i32)
    }
}

static MAP: LazyLock<Mutex<HashMap<i32, ZGrid>>> = LazyLock::new(|| Mutex::new(HashMap::new()));

/// Locks the retained map, recovering from a poisoned mutex (a prior panic
/// while holding the lock) instead of propagating a panic on every later
/// call - the grid data is plain-old-data, safe to keep using.
fn map_lock() -> std::sync::MutexGuard<'static, HashMap<i32, ZGrid>> {
    MAP.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Weighted A* over one retained z-grid, world (1-based) coordinates in and
/// out. Same cardinal-only movement and iteration cap discipline as
/// `find_path` - threat/door costs only ever raise a step's cost above the
/// heuristic's 10-per-tile assumption, so Manhattan stays admissible.
fn route_on_grid(grid: &ZGrid, start: (i32, i32), end: (i32, i32)) -> Option<Vec<(i32, i32)>> {
    let start_idx = grid.idx(start.0, start.1)?;
    grid.idx(end.0, end.1)?;
    grid.step_cost(end.0, end.1)?;
    if start == end {
        return Some(vec![start]);
    }

    let cell_count = (grid.width * grid.height) as usize;
    let mut g_score = vec![i32::MAX; cell_count];
    let mut came_from = vec![-1i32; cell_count];
    let mut closed = vec![false; cell_count];

    g_score[start_idx] = 0;

    let mut open = BinaryHeap::new();
    open.push(OpenNode {
        priority: heuristic(start.0, start.1, end.0, end.1),
        x: start.0,
        y: start.1,
    });

    let max_iterations = cell_count.saturating_mul(4);
    let mut iterations = 0usize;

    while let Some(current) = open.pop() {
        iterations += 1;
        if iterations > max_iterations {
            return None;
        }

        let cur_idx = grid.idx(current.x, current.y)?;
        if closed[cur_idx] {
            continue;
        }
        if current.x == end.0 && current.y == end.1 {
            let mut path = Vec::new();
            let mut trace = cur_idx as i32;
            while trace != -1 {
                let tx = trace % grid.width + 1;
                let ty = trace / grid.width + 1;
                path.push((tx, ty));
                trace = came_from[trace as usize];
            }
            path.reverse();
            return Some(path);
        }
        closed[cur_idx] = true;

        for (dx, dy, _) in DIRECTIONS.iter() {
            let nx = current.x + dx;
            let ny = current.y + dy;
            let Some(n_idx) = grid.idx(nx, ny) else {
                continue;
            };
            if closed[n_idx] {
                continue;
            }
            let Some(step_cost) = grid.step_cost(nx, ny) else {
                continue;
            };
            let tentative = g_score[cur_idx].saturating_add(step_cost);
            if tentative < g_score[n_idx] {
                g_score[n_idx] = tentative;
                came_from[n_idx] = cur_idx as i32;
                open.push(OpenNode {
                    priority: tentative + heuristic(nx, ny, end.0, end.1),
                    x: nx,
                    y: ny,
                });
            }
        }
    }

    None
}

fn parse_ints(s: &str) -> Vec<i32> {
    s.split(',')
        .filter_map(|p| p.trim().parse::<i32>().ok())
        .collect()
}

/// Bulk-loads one z-level's walkability. `z_desc` is "z,width,height";
/// `packed_cells` is width*height chars of '0' (open) / '1' (blocked) /
/// '2' (closed door), row-major from world tile (1,1). Returns "ok" on
/// success, "" on malformed input.
#[no_mangle]
pub extern "C" fn xeno_pathfind_init_z(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 2, |args| init_z_impl(args[0], args[1]))
}

fn init_z_impl(desc: &str, cells: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 3 {
        return String::new();
    }
    let (z, width, height) = (parts[0], parts[1], parts[2]);
    if width <= 0 || height <= 0 || (width as i64 * height as i64) as usize != cells.len() {
        return String::new();
    }
    if cells
        .bytes()
        .any(|b| b != CELL_OPEN && b != CELL_BLOCKED && b != CELL_DOOR && b != CELL_OBSTACLE)
    {
        return String::new();
    }

    let cell_count = (width * height) as usize;
    let grid = ZGrid {
        width,
        height,
        base: cells.as_bytes().to_vec(),
        threat: vec![0; cell_count],
    };
    map_lock().insert(z, grid);
    "ok".to_string()
}

/// Applies batched cell deltas: "z,x,y,c" entries separated by ';', where c
/// is a cell code (0/1/2). Unknown z or out-of-bounds entries are skipped
/// (the delta pipeline must never poison the whole batch). Returns "ok".
#[no_mangle]
pub extern "C" fn xeno_pathfind_update(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 1, |args| update_impl(args[0]))
}

fn update_impl(payload: &str) -> String {
    let mut map = map_lock();
    for entry in payload.split(';') {
        let parts = parse_ints(entry);
        if parts.len() != 4 {
            continue;
        }
        let (z, x, y, code) = (parts[0], parts[1], parts[2], parts[3]);
        let code = match code {
            0 => CELL_OPEN,
            1 => CELL_BLOCKED,
            2 => CELL_DOOR,
            3 => CELL_OBSTACLE,
            _ => continue,
        };
        let Some(grid) = map.get_mut(&z) else {
            continue;
        };
        if let Some(i) = grid.idx(x, y) {
            grid.base[i] = code;
        }
    }
    "ok".to_string()
}

/// Solves a route on the retained grid. `route_desc` is "z,sx,sy,ex,ey"
/// (world 1-based coordinates). Returns a ';'-separated "x,y" path from
/// start to end inclusive, or "" if the z isn't loaded, input is malformed,
/// or no route exists.
#[no_mangle]
pub extern "C" fn xeno_pathfind_route(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 1, |args| route_impl(args[0]))
}

fn route_impl(desc: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 5 {
        return String::new();
    }
    let (z, sx, sy, ex, ey) = (parts[0], parts[1], parts[2], parts[3], parts[4]);

    let map = map_lock();
    let Some(grid) = map.get(&z) else {
        return String::new();
    };
    match route_on_grid(grid, (sx, sy), (ex, ey)) {
        Some(path) => {
            let encoded: Vec<String> = path.iter().map(|(x, y)| format!("{},{}", x, y)).collect();
            encoded.join(";")
        }
        None => String::new(),
    }
}

/// Adds threat at "z,x,y,amount" with linear falloff over a Chebyshev
/// radius of 2 (amount, then 1/2, then 1/3 of it). Saturating - repeated
/// deaths stack up to u16::MAX. Returns "ok" ("" on malformed input).
#[no_mangle]
pub extern "C" fn xeno_pathfind_threat(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 1, |args| threat_impl(args[0]))
}

fn threat_impl(desc: &str) -> String {
    let parts = parse_ints(desc);
    if parts.len() != 4 {
        return String::new();
    }
    let (z, x, y, amount) = (parts[0], parts[1], parts[2], parts[3].max(0) as u16);

    let mut map = map_lock();
    let Some(grid) = map.get_mut(&z) else {
        return String::new();
    };
    for dy in -2i32..=2 {
        for dx in -2i32..=2 {
            let dist = dx.abs().max(dy.abs()) as u16;
            let add = amount / (dist + 1);
            if add == 0 {
                continue;
            }
            if let Some(i) = grid.idx(x + dx, y + dy) {
                grid.threat[i] = grid.threat[i].saturating_add(add);
            }
        }
    }
    "ok".to_string()
}

/// Halves every threat value on every loaded z-level - called periodically
/// by BYOND so kill zones cool off over a couple of minutes. Returns "ok".
#[no_mangle]
pub extern "C" fn xeno_pathfind_decay(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 0, |_| {
        let mut map = map_lock();
        for grid in map.values_mut() {
            for t in grid.threat.iter_mut() {
                *t /= 2;
            }
        }
        "ok".to_string()
    })
}

/// Wipes all retained state (round restart). Returns "ok".
#[no_mangle]
pub extern "C" fn xeno_pathfind_clear(argc: c_int, argv: *const *const c_char) -> *const c_char {
    byond_call(argc, argv, 0, |_| {
        map_lock().clear();
        "ok".to_string()
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grid(width: i32, height: i32, blocked_coords: &[(i32, i32)]) -> Vec<bool> {
        let mut g = vec![false; (width * height) as usize];
        for (x, y) in blocked_coords {
            g[(y * width + x) as usize] = true;
        }
        g
    }

    #[test]
    fn straight_line_open_grid() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 0), &b).expect("path should exist");
        assert_eq!(path.first(), Some(&(0, 0)));
        assert_eq!(path.last(), Some(&(5, 0)));
        // Open straight line should be exactly 6 tiles (start + 5 steps), no zigzag.
        assert_eq!(path.len(), 6);
    }

    #[test]
    fn no_diagonal_steps_in_returned_path() {
        let b = grid(10, 10, &[]);
        let path = find_path(10, 10, (0, 0), (5, 5), &b).expect("path should exist");
        // Cardinal-only movement: a (5,5) offset takes 10 steps (11 tiles
        // including start), never a 5-step diagonal shortcut. Every
        // consecutive pair of tiles must differ in exactly one axis.
        assert_eq!(path.len(), 11);
        for pair in path.windows(2) {
            let (x1, y1) = pair[0];
            let (x2, y2) = pair[1];
            let dx = (x2 - x1).abs();
            let dy = (y2 - y1).abs();
            assert!(
                (dx == 1 && dy == 0) || (dx == 0 && dy == 1),
                "found a non-cardinal step: {:?} -> {:?}",
                pair[0],
                pair[1]
            );
        }
    }

    #[test]
    fn routes_around_a_wall_with_a_gap() {
        // Vertical wall at x=5 spanning y=0..8, with a gap at y=9.
        let mut blocked_coords = vec![];
        for y in 0..9 {
            blocked_coords.push((5, y));
        }
        let b = grid(10, 10, &blocked_coords);
        let path = find_path(10, 10, (0, 0), (9, 0), &b).expect("path should exist through the gap");
        // Must pass through the only gap in the wall.
        assert!(path.contains(&(5, 9)));
    }

    #[test]
    fn unreachable_target_returns_none() {
        // Fully enclose the target at (5,5) with a ring of blocked tiles.
        let mut blocked_coords = vec![];
        for x in 4..=6 {
            for y in 4..=6 {
                if !(x == 5 && y == 5) {
                    blocked_coords.push((x, y));
                }
            }
        }
        let b = grid(10, 10, &blocked_coords);
        assert!(find_path(10, 10, (0, 0), (5, 5), &b).is_none());
    }

    #[test]
    fn blocked_start_or_end_out_of_bounds_is_handled_gracefully() {
        let b = grid(5, 5, &[]);
        assert!(find_path(5, 5, (-1, 0), (2, 2), &b).is_none());
        assert!(find_path(5, 5, (0, 0), (10, 10), &b).is_none());
    }

    /// Invokes an entry point exactly the way BYOND's call_ext() does:
    /// (argc, argv) with argv pointing at an array of C string pointers.
    fn byond(
        f: extern "C" fn(c_int, *const *const c_char) -> *const c_char,
        args: &[&str],
    ) -> String {
        let cstrings: Vec<CString> = args.iter().map(|s| CString::new(*s).unwrap()).collect();
        let ptrs: Vec<*const c_char> = cstrings.iter().map(|c| c.as_ptr()).collect();
        let result_ptr = f(ptrs.len() as c_int, ptrs.as_ptr());
        unsafe { CStr::from_ptr(result_ptr) }
            .to_str()
            .unwrap()
            .to_string()
    }

    #[test]
    fn ffi_roundtrip_produces_expected_path_string() {
        let blocked = "0".repeat(25);
        let result = byond(xeno_pathfind, &["5,5,0,0,4,0", &blocked]);
        assert_eq!(result, "0,0;1,0;2,0;3,0;4,0");
    }

    #[test]
    fn ffi_malformed_input_returns_empty_string_not_a_crash() {
        assert_eq!(byond(xeno_pathfind, &["not,a,valid,grid", ""]), "");
        // Missing/null arguments must also be handled, not crash.
        assert_eq!(byond(xeno_pathfind, &["5,5,0,0,4,0"]), "");
        let result_ptr = xeno_pathfind(0, std::ptr::null());
        assert_eq!(unsafe { CStr::from_ptr(result_ptr) }.to_str().unwrap(), "");
    }

    // ------------------------------------------------------------------
    // Persistent grid tests. Each test uses its own z value - the MAP
    // static is shared across the parallel test threads.
    // ------------------------------------------------------------------

    fn call1(f: extern "C" fn(c_int, *const *const c_char) -> *const c_char, arg: &str) -> String {
        byond(f, &[arg])
    }

    fn call2(
        f: extern "C" fn(c_int, *const *const c_char) -> *const c_char,
        a: &str,
        b: &str,
    ) -> String {
        byond(f, &[a, b])
    }

    /// Builds a width x height all-open packed string with the given cells
    /// (1-based world coords) overridden to the given code char.
    fn packed(width: i32, height: i32, overrides: &[(i32, i32, u8)]) -> String {
        let mut cells = vec![b'0'; (width * height) as usize];
        for (x, y, code) in overrides {
            cells[((y - 1) * width + (x - 1)) as usize] = *code;
        }
        String::from_utf8(cells).unwrap()
    }

    #[test]
    fn persistent_init_and_route_roundtrip() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "101,10,10", &packed(10, 10, &[])),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "101,1,1,5,1");
        assert_eq!(path, "1,1;2,1;3,1;4,1;5,1");
    }

    #[test]
    fn persistent_update_reroutes_around_new_wall() {
        // Vertical wall at x=5 spanning y=1..9 on a 10x10 grid, gap at y=10.
        let overrides: Vec<(i32, i32, u8)> = (1..10).map(|y| (5, y, b'1')).collect();
        assert_eq!(
            call2(xeno_pathfind_init_z, "102,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "102,1,1,10,1");
        assert!(path.contains("5,10"), "route should use the only gap: {path}");
        // Close the gap - now unreachable.
        assert_eq!(call1(xeno_pathfind_update, "102,5,10,1"), "ok");
        assert_eq!(call1(xeno_pathfind_route, "102,1,1,10,1"), "");
        // Reopen a different cell in the wall - reachable again through it.
        assert_eq!(call1(xeno_pathfind_update, "102,5,5,0"), "ok");
        let path = call1(xeno_pathfind_route, "102,1,1,10,1");
        assert!(path.contains("5,5"), "route should use the reopened cell: {path}");
    }

    #[test]
    fn persistent_door_costs_prefer_open_route_but_pass_when_only_option() {
        // Wall at x=5 with a door at y=1 and an open gap at y=3: from (4,1)
        // to (6,1) the door is 2 steps, the gap detour is 6 - door cost 80
        // vs open cost 10 makes the longer open route cheaper (2*80=160 vs
        // 6*10=60... door route = door tile 80 + open 10 = 90 vs detour 60).
        let mut overrides: Vec<(i32, i32, u8)> = (1..=10).map(|y| (5, y, b'1')).collect();
        overrides[0] = (5, 1, b'2'); // door at y=1
        overrides[2] = (5, 3, b'0'); // open gap at y=3
        assert_eq!(
            call2(xeno_pathfind_init_z, "103,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "103,4,1,6,1");
        assert!(path.contains("5,3"), "open gap should beat the door: {path}");
        assert!(!path.contains("5,1"), "door tile should be avoided: {path}");
        // Close the gap - the door becomes the only way through.
        assert_eq!(call1(xeno_pathfind_update, "103,5,3,1"), "ok");
        let path = call1(xeno_pathfind_route, "103,4,1,6,1");
        assert!(path.contains("5,1"), "door should be used when only option: {path}");
    }

    #[test]
    fn persistent_door_preferred_over_window_obstacle() {
        // Wall at x=5 with a window ('3') directly on the straight line at
        // y=1 and a door ('2') at y=3: the longer route through the door must
        // win - smashing through glass is a last resort, not a shortcut.
        let mut overrides: Vec<(i32, i32, u8)> = (1..=10).map(|y| (5, y, b'1')).collect();
        overrides[0] = (5, 1, b'3'); // window on the straight line
        overrides[2] = (5, 3, b'2'); // door two tiles south
        assert_eq!(
            call2(xeno_pathfind_init_z, "106,10,10", &packed(10, 10, &overrides)),
            "ok"
        );
        let path = call1(xeno_pathfind_route, "106,4,1,6,1");
        assert!(path.contains("5,3"), "door should beat the window: {path}");
        assert!(!path.contains("5,1;"), "window tile should be avoided: {path}");
    }

    #[test]
    fn persistent_threat_bends_route_and_decays() {
        assert_eq!(
            call2(xeno_pathfind_init_z, "104,11,11", &packed(11, 11, &[])),
            "ok"
        );
        // Heavy threat on the straight line's midpoint.
        assert_eq!(call1(xeno_pathfind_threat, "104,6,1,200"), "ok");
        let path = call1(xeno_pathfind_route, "104,1,1,11,1");
        assert!(
            !path.contains(";6,1;"),
            "route should detour around the threat epicenter: {path}"
        );
        // Decay enough times and the straight line wins again.
        for _ in 0..12 {
            assert_eq!(call1(xeno_pathfind_decay, ""), "ok");
        }
        let path = call1(xeno_pathfind_route, "104,1,1,11,1");
        assert!(
            path.contains(";6,1;"),
            "decayed threat should no longer bend the route: {path}"
        );
    }

    #[test]
    fn persistent_malformed_and_unknown_z_return_empty() {
        assert_eq!(call2(xeno_pathfind_init_z, "bad,desc", "000"), "");
        assert_eq!(call2(xeno_pathfind_init_z, "105,3,3", "not-nine!"), "");
        assert_eq!(call1(xeno_pathfind_route, "9999,1,1,2,2"), "");
        assert_eq!(call1(xeno_pathfind_route, "garbage"), "");
        assert_eq!(call1(xeno_pathfind_threat, "9999,1,1,50"), "");
        // Updates against unknown z / malformed entries are skipped, not errors.
        assert_eq!(call1(xeno_pathfind_update, "9999,1,1,1;garbage;;"), "ok");
    }
}
