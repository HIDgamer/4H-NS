// __xeno_pathfind.dm - DM bindings for the xeno_pathfind native extension
// (tools/rust/xeno_pathfind/). Not a fork of rust-g - a separate library
// using the same call_ext()-compatible C ABI convention (see __rust_g.dm for
// the reference pattern this mirrors). See
// code/modules/mob/living/carbon/xenomorph/ai/xeno_ai_movement.dm for the
// BYOND-side grid-building and fallback-to-step_towards() logic that calls
// into this - the AI must work correctly even if this library is entirely
// absent from a given host.

#ifndef XENO_PATHFIND_LIB
/var/__xeno_pathfind_lib

/proc/__detect_xeno_pathfind_lib()
	if(world.system_type == UNIX)
		if(fexists("./libxeno_pathfind.so"))
			return __xeno_pathfind_lib = "./libxeno_pathfind.so"
		return __xeno_pathfind_lib = "libxeno_pathfind.so"
	else
		return __xeno_pathfind_lib = "xeno_pathfind"

#define XENO_PATHFIND_LIB (__xeno_pathfind_lib || __detect_xeno_pathfind_lib())
#endif

#if DM_VERSION >= 515
#define XENO_PATHFIND_CALL call_ext
#else
#define XENO_PATHFIND_CALL call
#endif

// Plain globals rather than GLOBAL_VAR_INIT()/GLOB - this file is included
// before code/__DEFINES/_globals.dm in colonialmarines.dme (same position as
// __rust_g.dm, which does the same thing), so that machinery isn't defined
// yet at this point in the build.

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
		. = XENO_PATHFIND_CALL(XENO_PATHFIND_LIB, "xeno_pathfind")(grid_desc, blocked_map)
		// The doc comment above promises callers always get a string back -
		// a non-text result (e.g. null) is just as much a "this isn't
		// actually working" signal as a thrown exception.
		if(!istext(.))
			. = ""
		__xeno_pathfind_available = TRUE
	catch
		. = ""
		__xeno_pathfind_available = FALSE
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
			. = XENO_PATHFIND_CALL(XENO_PATHFIND_LIB, func_name)(arg1)
		else
			. = XENO_PATHFIND_CALL(XENO_PATHFIND_LIB, func_name)(arg1, arg2)
		if(!istext(.))
			. = ""
		__xeno_pathfind_persistent_available = TRUE
	catch
		. = ""
		__xeno_pathfind_persistent_available = FALSE
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
