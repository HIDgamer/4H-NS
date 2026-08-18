// __xeno_pathfind.dm - DM bindings for the xeno pathfinding native
// functions. These are exports of rust-g itself (tools/rust/rust-g/src/
// xeno_pathfind.rs, feature "xeno_pathfind") - a second, separately loaded
// library (tools/rust/xeno_pathfind/, the original home of this module)
// reproducibly failed call_ext() with "undefined symbol" in production
// despite being architecture/symbol/dependency-correct, while the same style
// of call against rust-g's own functions succeeded every time in the same
// process - so these functions were merged into rust-g's own build rather
// than continuing to chase why a second library wouldn't load. Calls route
// through __rust_g.dm's RUST_G/RUSTG_CALL, the same proven detection every
// other rust-g function on this codebase uses.
//
// See code/modules/mob/living/carbon/xenomorph/ai/xeno_ai_movement.dm for
// the BYOND-side grid-building and fallback-to-step_towards() logic that
// calls into this - the AI must work correctly even if this rust-g build
// predates these exports (an older DLL/so without them fails the first call
// below and degrades to the bounded local solver, same as if native
// pathfinding were absent entirely).

/// Set once the first call either succeeds or fails, so a missing library is only probed once instead of retried every AI tick.
/var/__xeno_pathfind_checked = FALSE
/// Whether the native library is actually present and callable on this host.
/var/__xeno_pathfind_available = FALSE

/**
 * Calls the native A* solver. grid_desc is
 * "width,height,start_x,start_y,end_x,end_y" (grid-local coordinates);
 * blocked_map is a width*height-length string of '0'/'1' characters,
 * row-major. Returns a ';'-separated list of "x,y" grid-local coordinates
 * from start to end inclusive, or an empty string if no path exists, the
 * input was malformed, or the native library isn't present on this host.
 *
 * Always safe to call - never throws. Callers must treat an empty result as
 * "fall back to the existing step_towards()-based movement", since that's
 * also the answer for a genuinely missing library, not just "no path."
 */
/proc/rust_xeno_pathfind(grid_desc, blocked_map)
	// A bad caller (null/empty args) must not get conflated with "library
	// missing/broken" - returning here, before the one-shot check below is
	// ever consulted or written, keeps a caller bug from permanently
	// blacklisting a perfectly good library for the rest of the round.
	if(!grid_desc || !blocked_map)
		return ""
	if(__xeno_pathfind_checked && !__xeno_pathfind_available)
		return ""
	. = ""
	try
		. = RUSTG_CALL(RUST_G, "xeno_pathfind")(grid_desc, blocked_map)
		// The doc comment above promises callers always get a string back -
		// a non-text result (e.g. null) is just as much a "this isn't
		// actually working" signal as a thrown exception.
		if(!istext(.))
			. = ""
		__xeno_pathfind_available = TRUE
	catch(var/exception/error)
		// "Native grid unavailable" used to be the whole story in the log -
		// the actual DM exception (wrong architecture, missing symbol, lib
		// not found at this working directory, ABI mismatch) was thrown away
		// right here. Logged once, on the very first failure only - this proc
		// is only ever reached before __xeno_pathfind_checked latches, so
		// there's no risk of spamming this every AI tick for the rest of the
		// round.
		. = ""
		__xeno_pathfind_available = FALSE
		log_debug("SSxeno_pathfinding: rust_xeno_pathfind() native call failed - [error]")
	__xeno_pathfind_checked = TRUE

// ---------------------------------------------------------------------------
// Persistent full-map grid entry points (see SSxeno_pathfinding,
// code/controllers/subsystem/xeno_pathfinding.dm, which owns the round-start
// bulk load and the turf/door delta pipeline). Same hardening discipline as
// rust_xeno_pathfind() above: never throws, "" always means "treat the
// native path as unavailable and fall back." A host running an older DLL
// without these exports fails the first call, flips the persistent
// availability flag below, and degrades to the bounded local solver.
// ---------------------------------------------------------------------------

/// Set once the first persistent-grid call either succeeds or fails - separate from __xeno_pathfind_available since an older DLL can support the bounded solver but not these.
/var/__xeno_pathfind_persistent_checked = FALSE
/// Whether the persistent-grid entry points are present and callable on this host.
/var/__xeno_pathfind_persistent_available = FALSE

/// Shared call/harden/blacklist tail for every persistent-grid entry point.
/proc/__xeno_pathfind_persistent_call(func_name, arg1, arg2)
	if(__xeno_pathfind_persistent_checked && !__xeno_pathfind_persistent_available)
		return ""
	. = ""
	try
		if(isnull(arg2))
			. = RUSTG_CALL(RUST_G, func_name)(arg1)
		else
			. = RUSTG_CALL(RUST_G, func_name)(arg1, arg2)
		if(!istext(.))
			. = ""
		__xeno_pathfind_persistent_available = TRUE
	catch(var/exception/error)
		// Same reasoning as rust_xeno_pathfind()'s catch above - this is the
		// one that was actually silently failing in production (missing
		// libxeno_pathfind.so on a Linux host), and "failed to load z-level
		// N" with no further detail was the entire diagnostic trail left
		// behind. Logged once per round (first call only, before
		// __xeno_pathfind_persistent_checked latches).
		. = ""
		__xeno_pathfind_persistent_available = FALSE
		log_debug("SSxeno_pathfinding: native call to [func_name] failed - [error]")
	__xeno_pathfind_persistent_checked = TRUE

/// Bulk-loads one z-level's walkability. z_desc is "z,width,height"; packed_cells is width*height chars of '0' open / '1' blocked / '2' closed door, row-major from tile (1,1). Returns "ok" or "".
/proc/rust_xeno_pathfind_init_z(z_desc, packed_cells)
	if(!z_desc || !packed_cells)
		return ""
	return __xeno_pathfind_persistent_call("xeno_pathfind_init_z", z_desc, packed_cells)

/// Applies batched cell deltas: ';'-separated "z,x,y,c" entries (c: 0 open / 1 blocked / 2 door / 3 breakable obstacle). Unknown z / malformed entries are skipped individually.
/proc/rust_xeno_pathfind_update(deltas)
	if(!deltas)
		return ""
	return __xeno_pathfind_persistent_call("xeno_pathfind_update", deltas)

/// Solves a full-map route. route_desc is "z,sx,sy,ex,ey" (world 1-based coords). Returns ';'-separated "x,y" world coords start-to-end inclusive, or "" (no route / z unloaded / library unavailable - callers always fall back).
/proc/rust_xeno_pathfind_route(route_desc)
	if(!route_desc)
		return ""
	return __xeno_pathfind_persistent_call("xeno_pathfind_route", route_desc)

/// Adds decaying threat cost at "z,x,y,amount" with radius-2 falloff - routes bend away from hot cells until xeno_pathfind_decay() cools them.
/proc/rust_xeno_pathfind_threat(threat_desc)
	if(!threat_desc)
		return ""
	return __xeno_pathfind_persistent_call("xeno_pathfind_threat", threat_desc)

/// Halves every threat value on every loaded z-level - called periodically so kill zones cool off.
/proc/rust_xeno_pathfind_decay()
	return __xeno_pathfind_persistent_call("xeno_pathfind_decay", "")

/// Wipes all retained native-side state (round restart).
/proc/rust_xeno_pathfind_clear()
	return __xeno_pathfind_persistent_call("xeno_pathfind_clear", "")
