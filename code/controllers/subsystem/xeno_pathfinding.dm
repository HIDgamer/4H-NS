/**
 * Owns the native pathfinder's persistent full-map walkability grid
 * (tools/rust/xeno_pathfind - see code/__DEFINES/__xeno_pathfind.dm for the
 * FFI wrappers). Bulk-loads every z-level's turf walkability once at round
 * start, then keeps the native grid in sync through a batched delta pipeline
 * fed by the two places tile passability actually changes at runtime:
 * ChangeTurf() (walls built/destroyed, resin placed/melted - the single
 * canonical funnel for all turf type changes, hooked at its tail) and door
 * density flips (door.dm's finish_open()/close()/Destroy()).
 *
 * Everything degrades gracefully: if the native library is missing or too
 * old for the persistent entry points, `available` stays FALSE and the AI
 * keeps using the bounded local-grid solver exactly as before.
 */
SUBSYSTEM_DEF(xeno_pathfinding)
	name = "Xeno Pathfinding"
	wait = 5 SECONDS
	init_order = SS_INIT_XENO_PATHFINDING
	priority = SS_PRIORITY_XENO_PATHFINDING

	/// TRUE once every z-level loaded into the native grid successfully - the AI only routes globally while this holds.
	var/available = FALSE
	/// Pending "z,x,y,c" delta strings, flushed to the native side each fire() or the moment the batch grows past XENO_PATHFIND_DELTA_FLUSH_AT.
	var/list/pending_deltas = list()
	/// fire() counter driving the periodic threat decay (see Rust-side xeno_pathfind_decay()).
	var/decay_counter = 0

/datum/controller/subsystem/xeno_pathfinding/Initialize()
	// The DLL outlives world reboots (the Dream Daemon process doesn't
	// restart between rounds) - wipe last round's grid/threat before
	// rebuilding for this one.
	rust_xeno_pathfind_clear()

	var/loaded_count = 0
	for(var/z in 1 to world.maxz)
		if(load_z_level(z))
			loaded_count++
		else
			log_debug("SSxeno_pathfinding: failed to load z-level [z] into the native grid.")
	// Partial availability is fine - a route on an unloaded z just returns
	// "" and that mob falls back to the bounded local solver; demanding every
	// z-level meant one oddball level silently disabled routing everywhere.
	available = loaded_count > 0 && __xeno_pathfind_persistent_available
	if(!available)
		log_debug("SSxeno_pathfinding: native grid unavailable ([loaded_count]/[world.maxz] z-levels loaded, persistent_available=[__xeno_pathfind_persistent_available]) - AI falls back to bounded local pathfinding.")

	// Threat layer: every xeno death marks its tile (radius-2 falloff,
	// native side) as costly to route through, decaying via fire() below -
	// approach routes bend around marine kill zones, so flanking emerges
	// from the cost function with no per-caste code at all.
	RegisterSignal(SSdcs, COMSIG_GLOB_XENO_DEATH, PROC_REF(on_xeno_death))
	return SS_INIT_SUCCESS

/datum/controller/subsystem/xeno_pathfinding/proc/on_xeno_death(datum/source, mob/living/carbon/xenomorph/dead_xeno, gibbed)
	SIGNAL_HANDLER
	if(!available)
		return
	var/turf/death_turf = get_turf(dead_xeno)
	if(!death_turf)
		return
	rust_xeno_pathfind_threat("[death_turf.z],[death_turf.x],[death_turf.y],[AI_THREAT_DEATH_AMOUNT]")

/// Packs one z-level's turf walkability row-major from (1,1) and bulk-loads it into the native grid. Returns whether the native side accepted it.
/datum/controller/subsystem/xeno_pathfinding/proc/load_z_level(z)
	var/list/cells = list()
	for(var/y in 1 to world.maxy)
		for(var/x in 1 to world.maxx)
			var/turf/scanned = locate(x, y, z)
			cells += turf_cell_code(scanned)
		CHECK_TICK
	return rust_xeno_pathfind_init_z("[z],[world.maxx],[world.maxy]", cells.Join("")) == "ok"

/**
 * The native cell code for a turf's current state: '1' dense turf (wall),
 * '2' walkable turf with a dense door on it, '3' walkable turf with some
 * other dense breakable structure (window, girder - priced far above a door
 * so routes only smash through glass as a last resort, never as a shortcut),
 * '0' open. Directional (ON_BORDER) structures like flipped tables and most
 * barricades are ignored - they only block from one side, which a
 * full-tile cost can't represent; the per-step obstacle handling deals with
 * them on contact instead.
 */
/datum/controller/subsystem/xeno_pathfinding/proc/turf_cell_code(turf/scanned)
	if(!scanned || scanned.density)
		return "1"
	var/has_obstacle = FALSE
	for(var/obj/structure/blocker in scanned)
		if(!blocker.density || (blocker.flags_atom & ON_BORDER))
			continue
		if(istype(blocker, /obj/structure/machinery/door))
			return "2"
		if(blocker.climbable)
			continue // Tables/racks - vaulted over, not smashed; near-free for movement.
		has_obstacle = TRUE
	return has_obstacle ? "3" : "0"

/**
 * Re-reads one turf's walkability and queues the delta for the native grid.
 * Called from ChangeTurf()'s tail (every turf type change funnels through
 * it) and from door.dm's density-flip sites. Cheap enough to call
 * redundantly - a delta that doesn't actually change the cell is harmless
 * on the native side.
 *
 * turf_cell_code() can return "3" (a breakable obstacle - window/girder),
 * matching the Rust side's own CELL_OBSTACLE code - the mapping below must
 * produce it too, or a window/girder placed or revealed mid-round (e.g. a
 * wall demolished down to a girder) syncs into the native grid as a
 * zero-cost open tile instead of the intended higher STEP_COST_OBSTACLE,
 * degrading route quality without erroring.
 */
/datum/controller/subsystem/xeno_pathfinding/proc/push_delta(turf/changed)
	if(!available || !changed)
		return
	var/code_char = turf_cell_code(changed)
	var/code = (code_char == "1") ? 1 : ((code_char == "2") ? 2 : ((code_char == "3") ? 3 : 0))
	pending_deltas += "[changed.z],[changed.x],[changed.y],[code]"
	if(length(pending_deltas) >= XENO_PATHFIND_DELTA_FLUSH_AT)
		flush_deltas()

/datum/controller/subsystem/xeno_pathfinding/proc/flush_deltas()
	if(!length(pending_deltas))
		return
	rust_xeno_pathfind_update(pending_deltas.Join(";"))
	pending_deltas = list()

/datum/controller/subsystem/xeno_pathfinding/fire(resumed = FALSE)
	if(!available)
		return
	flush_deltas()
	decay_counter++
	if(decay_counter >= XENO_PATHFIND_DECAY_EVERY_FIRES)
		decay_counter = 0
		rust_xeno_pathfind_decay()
