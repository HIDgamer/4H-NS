/**
 * Movement for xeno_ai_controller. Route-native: every flow goes through
 * travel_to(), which consumes real A* routes - whole-map when
 * SSxeno_pathfinding's persistent native grid is loaded, a bounded local
 * grid otherwise - and only degrades to greedy stepping plus a one-tile
 * sidestep on a host with no native library at all. Obstacle-forcing (claw
 * open the door/wall a route legitimately runs through) lives in the same
 * primitive, gated by TRAVEL_FLAG_FORCE_OBSTACLES.
 */
/**
 * The unified route-first navigation primitive every AI movement flow goes
 * through: consume the A* route (whole-map when the persistent grid loaded,
 * bounded local otherwise), fall to a direct cardinal step, then - only with
 * TRAVEL_FLAG_FORCE_OBSTACLES - claw through whatever's blocking (doors
 * preferred over walls, the existing commit chain), climb what's climbable,
 * and finally take a one-tile sidestep. The sidestep survives the greedy-era
 * retirement deliberately: mobs aren't modeled in the route grid, so a
 * sister or marine standing in a planned corridor tile blocks the route step
 * and one sidestep un-sticks it. Returns TRUE when any progress was made
 * this tick (moved, climbed, or hit a blocking obstacle).
 */
/datum/xeno_ai_controller/proc/travel_to(atom/goal, travel_flags = TRAVEL_FLAG_FORCE_OBSTACLES)
	if(!pilot || !goal)
		return FALSE

	// A goal already close is stepped at directly - routing to a moving
	// nearby goal (a pack buddy, a shifting target) plans to where it WAS,
	// walks the stale route the wrong way, replans, turns around - which is
	// exactly the "walking back and forth" pacing. At this range a plain
	// cardinal step can't meaningfully be wrong.
	if(get_dist(pilot, goal) <= AI_TRAVEL_DIRECT_RANGE)
		if(cardinal_step_towards(goal, travel_flags & TRAVEL_FLAG_AVOID_MOBS))
			return TRUE
	else if(advance_along_path(goal))
		return TRUE
	if(cardinal_step_towards(goal, travel_flags & TRAVEL_FLAG_AVOID_MOBS))
		return TRUE

	var/obj/structure/climbable_obstacle = get_climbable_obstacle(goal)
	if(climbable_obstacle)
		if((travel_flags & TRAVEL_FLAG_FORCE_OBSTACLES) && should_smash_instead_of_climb(climbable_obstacle))
			attack_blocking_obstacle(climbable_obstacle)
			return TRUE
		if((travel_flags & TRAVEL_FLAG_COVER_CHECK) && current_target && is_direct_approach_too_risky(climbable_obstacle, current_target) && retreat_to_cover(current_target))
			return TRUE
		// "Is climbing a table worth it or not" - do_climb() costs a real
		// ~2-second do_after(), stalling this controller's tick() the whole
		// time; open ground immediately beside the obstacle is a free
		// alternative navigate_around() (below) will actually take, so it's
		// only worth vaulting when there's nowhere cheaper to step instead.
		if(!has_open_detour(get_dir(pilot, goal)) && attempt_climb_obstacle(climbable_obstacle))
			return TRUE

	if(travel_flags & TRAVEL_FLAG_FORCE_OBSTACLES)
		var/atom/blocking_obstacle = get_blocking_obstacle(goal)
		if(blocking_obstacle)
			if((travel_flags & TRAVEL_FLAG_COVER_CHECK) && current_target && is_direct_approach_too_risky(blocking_obstacle, current_target) && retreat_to_cover(current_target))
				return TRUE
			attack_blocking_obstacle(blocking_obstacle)
			return TRUE

	return navigate_around(goal)

/datum/xeno_ai_controller/proc/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target() // Target actually died/became invalid - nothing to go investigate.
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(check_pack_staging())
		return

	var/atom/movable/approach_goal = current_target
	if(count_engaged_allies(current_target))
		var/turf/flank_turf = get_or_pick_flank_turf(current_target)
		if(flank_turf)
			approach_goal = flank_turf

	if(check_movement_progress(approach_goal))
		return

	if(travel_to(approach_goal, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_COVER_CHECK))
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= get_pathfind_giveup_attempts())
		drop_target(TRUE) // Couldn't force through - go investigate where it was last seen instead of forgetting it outright.

/**
 * Coordinated pack assault: a pilot that reaches staging range of her target
 * while pack sisters are still inbound briefly holds instead of trickling in
 * alone, then everyone commits together - marines face synchronized rushes
 * from multiple directions (each committer heads for her own existing flank
 * position) instead of a killable one-at-a-time stream. Returns TRUE while
 * holding (process_movement() takes no movement action that tick).
 *
 * Never passive: the hold is hard-capped at AI_XENO_STAGE_MAX_WAIT, breaks
 * instantly on taking any damage, and is skipped outright when the target is
 * already fighting a sister (pile in - never watch her die), when nobody
 * else is coming (solo behavior is exactly the old behavior), and for
 * Facehuggers (a pouncing ambusher gains nothing from standing in the open).
 */
/datum/xeno_ai_controller/proc/check_pack_staging()
	if(!pilot || !current_target)
		return FALSE
	var/dist_to_target = get_dist(pilot, current_target)
	if(dist_to_target > AI_XENO_STAGE_RANGE || dist_to_target <= 1)
		staged_until = 0
		return FALSE
	if(pilot.caste_type == XENO_CASTE_FACEHUGGER)
		return FALSE

	var/list/pack = get_pack_assault_status()

	if(staged_until)
		if(world.time >= staged_until || pilot.health < stage_start_health || pack["engaged"] || pack["in_range"] || !pack["inbound"])
			// Wait cap hit, taking fire, a sister's already fighting/arrived,
			// or nobody's actually coming any more - rush now.
			staged_until = 0
			next_stage_time = world.time + AI_XENO_STAGE_COOLDOWN
			return FALSE
		pilot.setDir(get_dir(pilot, current_target))
		return TRUE

	if(world.time < next_stage_time)
		return FALSE
	// Only worth starting a hold when sisters are inbound but none is in
	// position or fighting yet - anything else means go immediately. The
	// arrival-order asymmetry resolves itself: the first arrival stages, the
	// second sees a sister already in range and goes straight in, which
	// releases the first's hold the same tick via the in_range commit above.
	if(!pack["inbound"] || pack["in_range"] || pack["engaged"])
		return FALSE
	staged_until = world.time + AI_XENO_STAGE_MAX_WAIT
	stage_start_health = pilot.health
	pilot.setDir(get_dir(pilot, current_target))
	return TRUE

/// Other same-hive AI xenos hunting the same target, split by how close they are to joining the fight - see check_pack_staging().
/datum/xeno_ai_controller/proc/get_pack_assault_status()
	var/inbound = 0
	var/in_range = 0
	var/engaged = 0
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/ally_controller = ally.ai_controller
		if(!ally_controller || ally_controller.current_target != current_target)
			continue
		if(ally_controller.ai_state == AI_STATE_ATTACKING)
			engaged++
		else if(ally_controller.ai_state == AI_STATE_APPROACHING)
			if(get_dist(ally, current_target) <= AI_XENO_STAGE_RANGE)
				in_range++
			else
				inbound++
	return list("inbound" = inbound, "in_range" = in_range, "engaged" = engaged)

/**
 * blocked_attempts resets on every successful branch of process_movement(),
 * including a successful smash-attack against an obstacle - so a pilot that
 * can always find something to hit (a wall segment, a door) never actually
 * reaches blocked_attempts's own giveup, even while making zero real ground
 * toward approach_goal (e.g. chasing a target around a whole building with
 * no direct route). This tracks actual distance instead: sampled every
 * AI_XENO_STUCK_CHECK_INTERVAL, counts consecutive samples with no
 * improvement, and gives up on the target once that streak reaches
 * AI_XENO_STUCK_GIVEUP_TICKS - should_flee() is already re-checked every
 * tick at the top of tick() itself, so a stuck pilot that's also hurt enough
 * to flee already does so on its own before this ever needs to run.
 */
/datum/xeno_ai_controller/proc/check_movement_progress(atom/approach_goal)
	if(!pilot || !approach_goal)
		return FALSE
	if(world.time < last_progress_check_time + AI_XENO_STUCK_CHECK_INTERVAL)
		return FALSE

	var/current_distance = get_dist(pilot, approach_goal)
	last_progress_check_time = world.time
	if(isnull(last_progress_distance) || current_distance < last_progress_distance)
		no_progress_ticks = 0
	else
		no_progress_ticks++
	last_progress_distance = current_distance

	if(no_progress_ticks < AI_XENO_STUCK_GIVEUP_TICKS)
		return FALSE

	no_progress_ticks = 0
	drop_target(TRUE) // Truly stuck - go investigate the last-seen location / return to patrol instead of continuing to bash the same obstacle forever.
	return TRUE

/**
 * Shared continuous-kiting movement decision for every ranged caste
 * (Spitter/Boiler/Sentinel/Queen) - "approach, spit, and die in place" /
 * "spitter and all other ranged variants are really bad and die instantly."
 * The bug was the old binary min/preferred band each of them duplicated:
 * hold completely still anywhere inside the "preferred" distance, only
 * retreat once the target was already almost on top of her
 * (AI_XENO_RANGED_MIN_DISTANCE). A marine walking straight at her crossed
 * that whole multi-tile band completely unopposed - she just stood there
 * spitting - and by the time the emergency-floor retreat finally triggered,
 * one more step already closed it to melee. Now retreats the moment the
 * target is closer than preferred (not just inside a tight emergency
 * floor), holds only at/near the ideal ring, and advances only when
 * meaningfully farther - real continuous kiting instead of a static hold.
 * Prefers falling back toward a nearby defensible corner/wall
 * (find_defensible_turf()) over open ground when one's actually closer.
 * Sets ai_state directly (ATTACKING once holding in band) so callers are
 * just this one call from their own process_movement() override.
 */
/datum/xeno_ai_controller/proc/maintain_kiting_distance(atom/target, preferred_distance, seek_cover = FALSE)
	if(!pilot || !target)
		return
	var/dist = get_dist(pilot, target)

	if(dist < preferred_distance)
		// No obstacle-forcing while backing up - retreating through a wall
		// is never the move; route around or take the reactive back-step.
		var/turf/defensible = seek_cover ? (get_or_pick_cover_turf(target) || find_defensible_turf()) : find_defensible_turf()
		if(defensible && get_dist(pilot, defensible) > 0 && travel_to(defensible, 0))
			return
		var/away_dir = get_dir(target, pilot)
		if(!ai_step(away_dir))
			navigate_around(target)
		return

	if(dist <= preferred_distance + 1)
		// "Smaller T1/T2 ranged are light and small enough to kite and dodge
		// while aiming and firing accurately" - a caste that opts in (see
		// process_attack()'s own alternating fire/move ticks) takes one dodge
		// step toward cover instead of freezing in the open, then still holds
		// the band and fires next tick either way - never actually stands
		// still, but never skips a shot for it either.
		if(seek_cover)
			attempt_seek_cover_step(target)
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(travel_to(target, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_COVER_CHECK))
		blocked_attempts = 0
		return

	blocked_attempts++
	if(blocked_attempts >= 2)
		drop_target(TRUE)

/**
 * "I want better pathfinding as it's still too much, varied by the caste's
 * size/tier T1 vs T2 vs T3." Three knobs scaled by pilot.tier instead of one
 * flat setting for every caste regardless of size: a disposable, numerous
 * Tier 1 gives up on a blocked target sooner and gets a smaller local
 * pathfinding grid (not worth the compute or the exposure time for a caste
 * that's cheap to lose), while a Tier 2/3 - fewer of them, each one a much
 * bigger investment - gets a wider grid budget, worth spending more to
 * actually solve a real detour instead of falling back to the greedy walk
 * early.
 */
/datum/xeno_ai_controller/proc/get_pathfind_cell_budget()
	if(!pilot)
		return XENO_PATHFIND_MAX_CELLS
	if(pilot.tier >= 3)
		return XENO_PATHFIND_MAX_CELLS * 2
	if(pilot.tier == 2)
		return round(XENO_PATHFIND_MAX_CELLS * 1.5)
	return XENO_PATHFIND_MAX_CELLS

/// See get_pathfind_cell_budget()'s doc comment - same tier scaling applied to how many consecutive blocked ticks the chase path tolerates before giving up on the target entirely.
/datum/xeno_ai_controller/proc/get_pathfind_giveup_attempts()
	if(!pilot)
		return 2
	if(pilot.tier >= 3)
		return 4
	if(pilot.tier == 2)
		return 3
	return 2

/**
 * Plain turf-density line check between pilot and target, reusing the
 * existing get_line() helper rather than a real raycast library - good
 * enough to tell "clean shot" from "there's a wall in the way" for ranged
 * castes (see ranged.dm's process_attack()) without adding a new dependency.
 * Ignores the two endpoint tiles themselves (the pilot's and target's own
 * turf) since a dense structure the target happens to be standing against
 * shouldn't block a shot at the target on that same tile.
 *
 * physical_path = TRUE also counts climbable obstacles (tables, some
 * fences/barricades) as blocking - "charge/pounce/lunge stuck on terrain...
 * still a problem with tables, fences, barricades." A ranged shot can fly
 * over a table just fine, which is why climbable structures are normally
 * exempted here, but a charge/pounce is a physical dash, not a projectile -
 * it collides with furniture the same way footstep movement climbing over
 * it doesn't happen mid-dash. Callers doing a physical gap-closer (crusher/
 * ravager charge, runner/lurker pounce) pass this TRUE; ranged spit/shot
 * callers leave it FALSE.
 */
/datum/xeno_ai_controller/proc/has_line_of_sight(atom/target, physical_path = FALSE)
	if(!pilot || !target)
		return FALSE
	var/turf/pilot_turf = get_turf(pilot)
	var/turf/target_turf = get_turf(target)
	if(!pilot_turf || !target_turf || pilot_turf.z != target_turf.z)
		return FALSE
	for(var/turf/line_turf in get_line(pilot_turf, target_turf))
		if(line_turf == pilot_turf || line_turf == target_turf)
			continue
		if(line_turf.density)
			return FALSE
		for(var/obj/structure/blocker in line_turf)
			if(blocker.density && (physical_path || !blocker.climbable))
				return FALSE
	return TRUE

/// Same-hive AI xenos already actively approaching/attacking this exact target - see get_flanking_position()/process_movement()'s flanking check.
/datum/xeno_ai_controller/proc/count_engaged_allies(atom/movable/target)
	if(!pilot)
		return 0
	var/count = 0
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.ai_xeno_list)
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		var/datum/xeno_ai_controller/ally_controller = ally.ai_controller
		if(!ally_controller || ally_controller.current_target != target)
			continue
		if(ally_controller.ai_state != AI_STATE_APPROACHING && ally_controller.ai_state != AI_STATE_ATTACKING)
			continue
		count++
	return count

/**
 * "Flanking logic to flank humans" - once at least one same-hive ally is
 * already closing on/fighting the same target, a fresh approacher heads for
 * an unoccupied side of it instead of the same tile everyone else is
 * beelining for, so a group actually surrounds a marine from different
 * angles rather than stacking into a single-file queue on one side. Returns
 * null (meaning "just approach the target directly, same as before") if
 * every side is already taken or blocked - flanking only matters when there's
 * actually a free side left to take.
 */
/datum/xeno_ai_controller/proc/get_flanking_position(atom/movable/target)
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return null

	var/list/free_sides = list()
	var/list/taken_sides = list()
	for(var/dir_option in list(NORTH, SOUTH, EAST, WEST))
		var/turf/side_turf = get_step(target_turf, dir_option)
		if(!side_turf || side_turf.density)
			continue
		var/occupied = FALSE
		for(var/mob/living/carbon/xenomorph/ally in side_turf)
			if(ally != pilot && ally.hivenumber == pilot.hivenumber && ally.stat != DEAD)
				occupied = TRUE
				break
		if(occupied)
			taken_sides += side_turf
		else
			free_sides += side_turf

	if(!length(free_sides))
		return null

	// Prefer whichever free side sits farthest from the already-taken ones -
	// the opposite/most different angle, not just the nearest empty tile
	// (which is often right next to a clustered ally anyway).
	if(!length(taken_sides))
		return free_sides[1]

	var/turf/best
	var/best_score = -1
	for(var/turf/candidate in free_sides)
		var/score = 0
		for(var/turf/taken in taken_sides)
			score += get_dist(candidate, taken)
		if(score > best_score)
			best_score = score
			best = candidate
	return best

/// Same "commit for a while instead of re-deriving every tick" wrapper as get_or_pick_cover_turf() above, applied to get_flanking_position() - recomputing which side of the target is "free" fresh every tick as allies shift position mid-fight could flip the chosen side by more than a route replan tolerates, reading as reversing direction mid-approach.
/datum/xeno_ai_controller/proc/get_or_pick_flank_turf(atom/movable/target)
	if(!pilot || !target)
		return null
	if(committed_flank_turf && world.time < committed_flank_until && !committed_flank_turf.density)
		return committed_flank_turf
	committed_flank_turf = get_flanking_position(target)
	committed_flank_until = world.time + AI_XENO_COVER_COMMIT_DURATION
	return committed_flank_turf

/**
 * Consumes one step of a cached native-pathfinder route toward goal,
 * (re)computing it first if needed. Returns FALSE - meaning "fall through to
 * the old greedy behavior for this tick" - if the native library isn't
 * available, no path exists, the goal is out of local-grid range, or the
 * planned next tile turned out to be blocked when we actually tried to move
 * (something wandered into the way, a door shut) - in that last case the
 * stale plan is dropped and a fresh one gets computed next tick.
 *
 * The cached plan is reused as long as the goal hasn't moved far from where
 * it was computed for (PATH_GOAL_REPLAN_TOLERANCE), not just whenever it
 * isn't in the exact same tile - a live target shifts by a tile almost every
 * heartbeat, and replanning from scratch every single tick near a corner let
 * minor start/goal differences flip the solver's tie-breaking back and
 * forth, which is what the reported "walks in a triangle near walls" turned
 * out to be: a fresh plan every tick, not a bad plan.
 */
/datum/xeno_ai_controller/proc/advance_along_path(atom/goal)
	if(!pilot || !goal)
		return FALSE

	var/turf/goal_turf = get_turf(goal)
	if(!goal_turf)
		return FALSE

	var/goal_unchanged = path_goal && get_dist(path_goal, goal_turf) <= PATH_GOAL_REPLAN_TOLERANCE
	// A live route toward a goal that merely drifted keeps being consumed
	// while inside the replan throttle window - without this, a moving
	// target more than PATH_GOAL_REPLAN_TOLERANCE from path_goal forces a
	// whole-map native solve every single tick, per mob. Only while the
	// drift stays small, though: consuming a route toward somewhere the goal
	// has substantially LEFT walks visibly the wrong way and reads as pacing.
	if(length(path_queue) && !goal_unchanged && world.time < next_replan_time && path_goal && get_dist(path_goal, goal_turf) <= PATH_GOAL_REPLAN_TOLERANCE * 2)
		goal_unchanged = TRUE
	if(!path_queue || !length(path_queue) || !goal_unchanged)
		// A prior failure against essentially the same goal waits out a short
		// cooldown before trying again, instead of re-running the full
		// grid-build + native solver call every single tick indefinitely -
		// exactly what happens chasing a target across an open LZ/Thunderdome
		// pad, where the bounding box blows the cell budget every time.
		if(path_failed && goal_unchanged && world.time < next_path_attempt)
			return FALSE
		// The persistent full-map grid (SSxeno_pathfinding) is tried first
		// when available - it's both cheaper per replan (no per-call grid
		// serialization at all) and sees the whole z-level, so a detour
		// around an entire building is a real computed route rather than
		// invisible past the bounded box. The bounded local solve stays as
		// the fallback for hosts whose DLL predates the persistent grid.
		path_queue = compute_path_global(goal_turf) || compute_path(goal_turf)
		path_goal = goal_turf
		if(!path_queue || !length(path_queue))
			path_failed = TRUE
			next_path_attempt = world.time + PATH_RETRY_COOLDOWN
			return FALSE
		path_failed = FALSE
		next_replan_time = world.time + PATH_REPLAN_MIN_INTERVAL

	var/turf/pilot_turf = get_turf(pilot)
	if(pilot_turf == path_queue[1])
		path_queue.Cut(1, 2)
		if(!length(path_queue))
			return FALSE

	var/turf/next_step = path_queue[1]
	if(!cardinal_step_towards(next_step))
		path_queue = null // Plan is stale - let this tick fall back to greedy/obstacle handling, replan next tick.
		return FALSE

	if(get_turf(pilot) == next_step)
		path_queue.Cut(1, 2)
	return TRUE

/**
 * Full-map route against SSxeno_pathfinding's persistent native grid - the
 * primary planner whenever that subsystem loaded successfully. The grid
 * already models walls (impassable), closed doors (passable at a cost, so a
 * route through one is taken when it's genuinely the best opening and the
 * existing arrival-time obstacle-forcing opens/smashes it), and the decaying
 * threat layer (routes bend away from tiles where hive members recently
 * died - flanking emerges from the cost function, no per-caste code).
 * Returns null (fall through to the bounded local solver, then the greedy
 * chain) when unavailable or no route exists.
 */
/datum/xeno_ai_controller/proc/compute_path_global(turf/goal_turf)
	if(!SSxeno_pathfinding?.available)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || !goal_turf || pilot_turf.z != goal_turf.z)
		return null

	var/result = rust_xeno_pathfind_route("[pilot_turf.z],[pilot_turf.x],[pilot_turf.y],[goal_turf.x],[goal_turf.y]")
	if(!result || !length(result))
		return null

	var/list/waypoints = list()
	for(var/pair in splittext(result, ";"))
		var/list/point = splittext(pair, ",")
		if(length(point) != 2)
			continue
		var/turf/waypoint = locate(text2num(point[1]), text2num(point[2]), pilot_turf.z)
		if(waypoint)
			waypoints += waypoint

	if(length(waypoints) && waypoints[1] == pilot_turf)
		waypoints.Cut(1, 2)
	if(!length(waypoints))
		return null
	return waypoints

/**
 * Builds a bounded local grid around the pilot and goal (only turf density
 * counts as "blocked" - doors/windows/tables are left for the existing
 * per-step obstacle-forcing and native climb-over handling, not modeled in
 * the grid) and asks the native solver for a route. Returns null (meaning
 * "no plan, use the old behavior") if the library isn't present, the hop is
 * too large for local grid pathing, or no path exists - long-range chases
 * are already handled fine by the greedy approach, this is specifically for
 * routing around nearby walls/dead-ends. Fallback for hosts whose native
 * library predates the persistent full-map grid (see compute_path_global()).
 *
 * Grows the search margin around the direct pilot-goal bounding box as far
 * as the remaining cell budget (get_pathfind_cell_budget()) allows, capped
 * at AI_PATHFIND_MAX_MARGIN, rather than a small flat margin - a real
 * door/entrance is rarely within just a couple tiles of the straight line
 * between two points in a room-and-corridor layout, so a wider margin is
 * what actually makes a detour through a door a few tiles off the direct
 * line visible to the solver.
 */
/datum/xeno_ai_controller/proc/compute_path(turf/goal_turf)
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || !goal_turf || pilot_turf.z != goal_turf.z)
		return null

	var/base_width = abs(pilot_turf.x - goal_turf.x) + 1
	var/base_height = abs(pilot_turf.y - goal_turf.y) + 1
	var/budget = get_pathfind_cell_budget()
	var/margin = AI_PATHFIND_MIN_MARGIN
	while(margin < AI_PATHFIND_MAX_MARGIN && (base_width + 2 * (margin + 1)) * (base_height + 2 * (margin + 1)) <= budget)
		margin++

	var/min_x = max(min(pilot_turf.x, goal_turf.x) - margin, 1)
	var/min_y = max(min(pilot_turf.y, goal_turf.y) - margin, 1)
	var/max_x = min(max(pilot_turf.x, goal_turf.x) + margin, world.maxx)
	var/max_y = min(max(pilot_turf.y, goal_turf.y) + margin, world.maxy)

	var/width = max_x - min_x + 1
	var/height = max_y - min_y + 1
	if(width <= 0 || height <= 0 || width * height > get_pathfind_cell_budget())
		return null

	var/list/blocked = list()
	for(var/y in min_y to max_y)
		for(var/x in min_x to max_x)
			var/turf/T = locate(x, y, pilot_turf.z)
			var/tile_blocked = (T && T.density)
			// Fire is walkable, not a wall - so it isn't blocked outright, but
			// it's treated as blocked for routing purposes so the solver
			// prefers a route around it. Never blocks the pilot's own tile or
			// the goal's tile - if either end is already on fire, the pilot
			// still needs a route in/out of it.
			if(!tile_blocked && T && T != pilot_turf && T != goal_turf && (locate(/obj/flamer_fire) in T))
				tile_blocked = TRUE
			blocked += tile_blocked ? "1" : "0"

	var/grid_desc = "[width],[height],[pilot_turf.x - min_x],[pilot_turf.y - min_y],[goal_turf.x - min_x],[goal_turf.y - min_y]"
	var/blocked_map = blocked.Join("")

	var/result = rust_xeno_pathfind(grid_desc, blocked_map)
	if(!result || !length(result))
		return null

	var/list/waypoints = list()
	for(var/pair in splittext(result, ";"))
		var/list/point = splittext(pair, ",")
		if(length(point) != 2)
			continue
		var/turf/T = locate(text2num(point[1]) + min_x, text2num(point[2]) + min_y, pilot_turf.z)
		if(T)
			waypoints += T

	if(length(waypoints) && waypoints[1] == pilot_turf)
		waypoints.Cut(1, 2)

	return waypoints

/**
 * Single-tile sidestep around one obstacle. Not real pathfinding - if this
 * fails too the caller gives up on the target. Prefers whichever side
 * worked last time before trying the other - target_dir shifts by a notch
 * almost every tick a mob is near a corner, and always re-deriving "left or
 * right" fresh from it made the pilot flip-flop between both sides of the
 * corner instead of committing to going around one way, which is what the
 * reported "walks in a triangle near walls" turned out to be for hosts
 * without the native pathfinder available (or wherever it falls through to
 * this greedy tail).
 */
/**
 * Single choke point every AI-driven step() call in this whole controller
 * goes through - "AI pathfinding is now too fast, need to nerf it so they
 * move exactly at the same speed a normal player controlled mob would."
 * Raw BYOND step() has no pacing of its own; a real player's movement rate
 * is throttled by /client/Move()'s own next_movement var (mob_movement.dm),
 * which only exists on a client and never applies to a clientless AI mob
 * calling step() directly - nothing was gating AI movement speed at all.
 * Recomputes and enforces the pilot's own movement_delay() (the same speed
 * a player of this caste would actually move at) before allowing another
 * step, independent of how often tick() itself runs.
 */
/datum/xeno_ai_controller/proc/ai_step(direction)
	if(!pilot || world.time < next_step_time)
		return FALSE
	. = step(pilot, direction)
	if(.)
		next_step_time = world.time + pilot.movement_delay()

/// Same as ai_step() but treats a destination turf already holding another living mob as blocked - see turf_occupied_by_other_mob()'s doc comment. Used by wander()'s own free-heading steps, which don't go through cardinal_step_towards()'s avoid_mobs param.
/datum/xeno_ai_controller/proc/ai_step_avoiding_mobs(direction)
	if(!pilot)
		return FALSE
	if(turf_occupied_by_other_mob(get_step(pilot, direction)))
		return FALSE
	return ai_step(direction)

/**
 * goal defaults to current_target so every existing chase-path call site is
 * unaffected - passed explicitly by return_to_anchor() (xeno_ai_controller.dm),
 * which has no current_target at all (drop_target() cleared it on entering
 * AI_STATE_RETURNING) and would otherwise have this bail out immediately
 * every time it's called while fleeing. Only ever reached after both
 * advance_along_path() (real A*) and a direct cardinal step have already
 * failed this tick - a real route is always preferred; this is what's left
 * once one genuinely isn't available (native library missing/broken, or the
 * goal is outside both the persistent grid's loaded z-levels and the bounded
 * local grid's budget).
 *
 * A bare one-tile sidestep here reads as "walking back and forth" against
 * anything wider than a single tile - it re-aims at the goal fresh every
 * tick, so the very next tick's cardinal_step_towards() just walks straight
 * back into the same obstacle. Committing to the winning side for a few
 * seconds (fallback_walk_dir/fallback_walk_until) instead of re-evaluating
 * every tick is what actually clears a corner - this is deliberately the
 * same fix the old (deleted) skirt system existed for, scoped narrowly to
 * only the case where real pathfinding has actually failed rather than
 * being the primary "how to route around things" mechanism.
 */
/datum/xeno_ai_controller/proc/navigate_around(atom/goal = current_target)
	if(!pilot || !goal)
		return FALSE

	if(fallback_walk_dir && world.time < fallback_walk_until)
		if(ai_step(fallback_walk_dir))
			return TRUE
		fallback_walk_dir = null

	var/target_dir = get_dir(pilot, goal)
	var/list/side_dirs = list(turn(target_dir, 90), turn(target_dir, -90))
	if(last_sidestep_dir && (last_sidestep_dir in side_dirs))
		side_dirs = list(last_sidestep_dir) + (side_dirs - last_sidestep_dir)

	for(var/side_dir in side_dirs)
		if(ai_step(side_dir))
			last_sidestep_dir = side_dir
			fallback_walk_dir = side_dir
			fallback_walk_until = world.time + AI_XENO_FALLBACK_WALK_DURATION
			return TRUE
	last_sidestep_dir = null
	fallback_walk_dir = null
	return FALSE

/**
 * "They should also consider corners and walls as defensive positions" -
 * a nearby turf with at least AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES
 * cardinally-adjacent dense tiles (a wall, a corner, tucked against a
 * structure), meaning fewer directions something can actually approach it
 * from. Used by a fleeing/kiting xeno as a nearer, defensible fallback
 * instead of always crossing open ground back to anchor_turf. Returns null
 * if nothing suitable exists within radius - callers just fall back to
 * their normal destination.
 */
/datum/xeno_ai_controller/proc/find_defensible_turf(radius = AI_XENO_DEFENSIBLE_SEARCH_RADIUS)
	if(!pilot)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null

	var/turf/best
	var/best_dist = INFINITY
	for(var/turf/candidate in range(radius, pilot_turf))
		if(candidate.density)
			continue
		var/dense_sides = 0
		for(var/dir_option in list(NORTH, SOUTH, EAST, WEST))
			var/turf/neighbor = get_step(candidate, dir_option)
			if(!neighbor || neighbor.density)
				dense_sides++
				continue
			for(var/obj/structure/blocker in neighbor)
				if(blocker.density)
					dense_sides++
					break
		if(dense_sides < AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES)
			continue
		var/dist = get_dist(pilot_turf, candidate)
		if(dist < best_dist)
			best_dist = dist
			best = candidate
	return best

/**
 * Like find_defensible_turf() but specifically targets REAL cover - a
 * structure with actual projectile_coverage (a smashed window's leftover
 * window_frame, a flipped table, a barricade) sitting between the candidate
 * turf and threat, not just generic wall-adjacency. Directional (ON_BORDER)
 * cover only counts when it's actually facing the right way to block a shot
 * coming from the threat's direction - the same facing check
 * projectile.dm's own get_projectile_hit_boolean() makes, so a flipped
 * table facing the wrong way is correctly treated as no protection at all.
 */
/datum/xeno_ai_controller/proc/find_cover_turf(atom/threat, radius = AI_XENO_DEFENSIBLE_SEARCH_RADIUS)
	if(!pilot || !threat)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	var/turf/threat_turf = get_turf(threat)
	if(!pilot_turf || !threat_turf)
		return null

	// "Too predictable, walking in the same 3 tiles over and over" - a pure
	// nearest-turf pick returns the exact same tile every single call for as
	// long as nothing about the room changes. Collects every candidate
	// within AI_XENO_COVER_VARIETY_TOLERANCE tiles of the closest one and
	// picks randomly among those instead, so a room with more than one
	// usable piece of cover actually gets used as more than one option.
	var/list/candidate_dists = list()
	var/best_dist = INFINITY
	for(var/turf/candidate in range(radius, pilot_turf))
		if(candidate.density)
			continue
		var/has_real_cover = FALSE
		for(var/obj/structure/S in candidate)
			if(!S.density || !S.throwpass || S.projectile_coverage < PROJECTILE_COVERAGE_MEDIUM)
				continue
			if((S.flags_atom & ON_BORDER) && !(S.dir & get_dir(candidate, threat_turf)))
				continue // Directional cover (flipped table/barricade) facing the wrong way - no real protection from this threat.
			has_real_cover = TRUE
			break
		if(!has_real_cover)
			continue
		var/dist = get_dist(pilot_turf, candidate)
		candidate_dists[candidate] = dist
		if(dist < best_dist)
			best_dist = dist
	if(!length(candidate_dists))
		return null

	var/list/near_best = list()
	for(var/turf/candidate in candidate_dists)
		if(candidate_dists[candidate] <= best_dist + AI_XENO_COVER_VARIETY_TOLERANCE)
			near_best += candidate
	return pick(near_best)

/**
 * Wraps find_cover_turf() with the same "commit for a while instead of re-deriving every
 * tick" pattern get_blocking_obstacle() already uses for committed_obstacle.
 * find_cover_turf()'s own near-tied pick(near_best) is deliberate (see its doc comment), but
 * called fresh and uncached every tick from a hide/retreat branch it reads as visibly
 * oscillating between two nearby cover tiles instead of committing to one. Every existing
 * caller already falls back to find_defensible_turf() on a null return, so this only needs to
 * cache the find_cover_turf() half.
 */
/datum/xeno_ai_controller/proc/get_or_pick_cover_turf(atom/threat)
	if(!pilot || !threat)
		return null
	if(committed_cover_turf && world.time < committed_cover_until && !committed_cover_turf.density)
		return committed_cover_turf
	committed_cover_turf = find_cover_turf(threat)
	committed_cover_until = world.time + AI_XENO_COVER_COMMIT_DURATION
	return committed_cover_turf

/**
 * "Flipping tables to use as cover" - if an unflipped table is adjacent,
 * flip it to face the current threat instead of only ever using cover that
 * already happens to exist. flip() (tables_racks.dm) is the same real proc
 * the player-facing verb uses - already handles its own cooldown/geometry
 * checks, this just calls it directly instead of routing through the
 * usr-based verb wrapper, the same established pattern
 * attempt_climb_obstacle() already uses for do_climb().
 */
/datum/xeno_ai_controller/proc/attempt_flip_table_for_cover(atom/threat)
	if(!pilot || !threat)
		return FALSE
	var/turf/threat_turf = get_turf(threat)
	if(!threat_turf)
		return FALSE
	for(var/obj/structure/surface/table/table in range(1, pilot))
		if(table.flipped)
			continue
		var/needed_dir = get_dir(get_turf(table), threat_turf)
		if(!needed_dir)
			continue
		table.flip(needed_dir)
		return TRUE
	return FALSE

/**
 * Best-effort dodge for a ranged xeno holding position in her kiting band
 * (see maintain_kiting_distance()'s seek_cover param) instead of just
 * freezing there - flips a nearby table for instant cover first, then
 * steps toward existing real cover (find_cover_turf()) if any is in reach,
 * and failing both, still takes a lateral step perpendicular to the
 * threat's line of fire rather than standing dead still - harder to hit
 * even in the open.
 */
/datum/xeno_ai_controller/proc/attempt_seek_cover_step(atom/threat)
	if(!pilot || !threat)
		return FALSE
	if(attempt_flip_table_for_cover(threat))
		return TRUE
	var/turf/cover_turf = find_cover_turf(threat)
	if(cover_turf && get_turf(pilot) != cover_turf)
		return cardinal_step_towards(cover_turf)
	var/facing_dir = get_dir(threat, pilot)
	if(!facing_dir)
		return FALSE
	return ai_step(pick(turn(facing_dir, 90), turn(facing_dir, -90)))

/**
 * "An enemy that is ready for it" - a marine with a weapon actually raised
 * (aiming down sights, or a gun wielded two-handed) is a live, accurate
 * threat right now; one who hasn't reacted yet is a completely different
 * risk to press an attack against. Used to gate whether climbing/smashing
 * straight toward a target is actually worth it (is_direct_approach_too_risky())
 * rather than treating every target as equally dangerous to approach.
 */
/datum/xeno_ai_controller/proc/is_target_a_ready_threat(atom/target)
	if(!ishuman(target))
		return FALSE
	var/mob/living/carbon/human/human_target = target
	if(human_target.is_zoomed)
		return TRUE
	var/obj/item/weapon/gun/held_gun = human_target.get_active_hand()
	return istype(held_gun) && (held_gun.flags_item & WIELDED)

/**
 * "Is what I'm doing right now worth it" - climbing through a window or
 * smashing a wall directly toward a target that's already aimed and close
 * means being exposed mid-vault/mid-swing right in their kill zone.
 * Deliberately only gates a FRESH decision: an obstacle already committed
 * to (get_blocking_obstacle()'s committed_obstacle) is exempt, since
 * abandoning a smash halfway through for being "too risky" would just waste
 * the commitment for nothing. Only actually holds back if real cover is
 * somewhere to retreat to - pressing on is still the only option when
 * there's nowhere safer to go.
 */
/datum/xeno_ai_controller/proc/is_direct_approach_too_risky(atom/obstacle, atom/threat)
	if(!pilot || !threat || obstacle == committed_obstacle)
		return FALSE
	if(!is_target_a_ready_threat(threat))
		return FALSE
	if(get_dist(pilot, threat) > AI_XENO_RISKY_APPROACH_RANGE)
		return FALSE
	return find_cover_turf(threat) != null

/// Steps toward the nearest real cover from threat, if any exists and isn't already where the pilot's standing. Returns FALSE (no-op) if there's nowhere better to go - callers fall through to their normal smash/climb behavior.
/datum/xeno_ai_controller/proc/retreat_to_cover(atom/threat)
	var/turf/cover_turf = find_cover_turf(threat)
	if(!cover_turf || get_turf(pilot) == cover_turf)
		return FALSE
	return cardinal_step_towards(cover_turf)

/**
 * Cardinal-only replacement for BYOND's step_towards() - this AI never
 * moves diagonally by design (the native pathfinder's own DIRECTIONS list
 * is cardinal-only), but step_towards() doesn't know that and will happily
 * cut a diagonal corner whenever the goal is both north/south AND east/west
 * of the pilot. Every direct chase/return/search step in this AI goes
 * through here instead of calling step_towards() itself, so a diagonal goal
 * always resolves into exactly one cardinal step - along whichever axis has
 * the larger remaining distance first, falling back to the other axis if
 * that step is blocked (mirrors navigate_around()'s two-option fallback).
 */
/datum/xeno_ai_controller/proc/cardinal_step_towards(atom/goal, avoid_mobs = FALSE)
	if(!pilot || !goal)
		return FALSE

	var/list/candidates = get_cardinal_candidates(goal)
	if(!candidates)
		return FALSE

	var/primary_dir = candidates[1]
	var/secondary_dir = candidates[2]

	if(!(avoid_mobs && turf_occupied_by_other_mob(get_step(pilot, primary_dir))) && ai_step(primary_dir))
		return TRUE
	if(!secondary_dir)
		return FALSE
	if(avoid_mobs && turf_occupied_by_other_mob(get_step(pilot, secondary_dir)))
		return FALSE
	return ai_step(secondary_dir)

/**
 * Decomposes a possibly-diagonal direction to goal into the exact one or two
 * cardinal directions cardinal_step_towards() will actually attempt, tied
 * off on whichever axis has the larger remaining distance first. Shared with
 * get_blocking_obstacle() so obstacle-forcing always targets one of the same
 * tiles movement itself already tried and failed on, rather than an
 * independently-computed diagonal tile neither of those attempts covered.
 * Returns list(primary_dir, secondary_dir) - secondary_dir is null when
 * dir_to_goal is already a pure cardinal direction (nothing to decompose).
 */
/datum/xeno_ai_controller/proc/get_cardinal_candidates(atom/goal)
	if(!pilot || !goal)
		return null

	var/dir_to_goal = get_dir(pilot, goal)
	if(!dir_to_goal)
		return null
	if(!(dir_to_goal & (dir_to_goal - 1))) // Single bit set - already a pure cardinal direction, nothing to decompose.
		return list(dir_to_goal, null)

	var/turf/pilot_turf = get_turf(pilot)
	var/turf/goal_turf = get_turf(goal)
	if(!pilot_turf || !goal_turf)
		return null

	var/dx = goal_turf.x - pilot_turf.x
	var/dy = goal_turf.y - pilot_turf.y
	var/primary_dir = (abs(dx) >= abs(dy)) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/secondary_dir = (primary_dir == EAST || primary_dir == WEST) ? (dy > 0 ? NORTH : SOUTH) : (dx > 0 ? EAST : WEST)
	return list(primary_dir, secondary_dir)

/**
 * "They need to stop pushing each other around when idle, consider the mob
 * standing on a turf before moving to it" - xenos pass freely through each
 * other (initialize_pass_flags()'s PASS_MOB_THRU_XENO, needed so a chase
 * doesn't get stuck behind a crowd of allies mid-fight), so nothing ever
 * stopped two idling xenos from freely overlapping and shuffling on and off
 * the same tile. Checked only by idle-only movement (wander/patrol/pack
 * cohesion/ambush hide/rest-seeking/build-site walks via cardinal_step_towards's
 * avoid_mobs param) - deliberately NOT applied to combat movement
 * (chasing/retreating/kiting), which still relies on walking straight through
 * allies to reach a target or cover.
 */
/datum/xeno_ai_controller/proc/turf_occupied_by_other_mob(turf/destination)
	if(!destination)
		return FALSE
	for(var/mob/living/occupant in destination)
		if(occupant != pilot && occupant.stat != DEAD)
			return TRUE
	return FALSE

/**
 * "Pathfinding is very messed up when it comes to none blocking, blocking
 * tiles like tables, vehicles, and fences" - a climbable structure (table,
 * some fences/crates) directly ahead of a raw step() from ordinary floor is
 * NOT actually passable for free the way an earlier version of this comment
 * assumed: tables_racks.dm's own BlockedPassDirs() only waives the block
 * when the mover is already standing on some other climbable structure
 * (hopping furniture to furniture), not from plain ground. A real player
 * instead climbs over it directly (do_climb(), a MouseDrop/verb
 * interaction) - see get_climbable_obstacle()/attempt_climb_obstacle()
 * below for the AI equivalent, checked before this proc in
 * process_movement(). This proc is left for what genuinely does need
 * force: locked airlocks, windows, girders, and walls a strong-enough
 * caste can actually melt through - xenos can't badge through
 * access-locked doors, can't walk through glass, and can't walk through
 * walls unless their claws are strong enough, so they attack instead, same
 * as a player would.
 */
/**
 * Cheap one-tile lookahead shared by get_blocking_obstacle() (walls only) and travel_to()'s
 * climb branch: is there open ground immediately beside the blocked direction? Checks the
 * same two perpendicular directions navigate_around()'s own sidestep fallback would try
 * (turn(blocked_dir, ±90)) - doesn't move the pilot, just answers "would a sidestep actually
 * go somewhere right now," using the same density/climbable-structure check
 * find_charge_lane() already uses for its own lane-clearing scan. "Which is faster, going
 * around or smashing a wall" / "is climbing a table worth it" both come down to this: if a
 * free tile is sitting right beside the obstacle, take it instead of paying to break through
 * or vault it.
 */
/datum/xeno_ai_controller/proc/has_open_detour(blocked_dir)
	if(!pilot || !blocked_dir)
		return FALSE
	for(var/side_dir in list(turn(blocked_dir, 90), turn(blocked_dir, -90)))
		var/turf/side_turf = get_step(pilot, side_dir)
		if(!side_turf || side_turf.density)
			continue
		var/blocked = FALSE
		for(var/obj/structure/blocker in side_turf)
			if(blocker.density && !blocker.climbable)
				blocked = TRUE
				break
		if(!blocked)
			return TRUE
	return FALSE

/datum/xeno_ai_controller/proc/get_blocking_obstacle(atom/goal)
	if(!pilot || !goal)
		return null

	// Stays committed to whatever's already mid-smash for a while (see
	// AI_XENO_OBSTACLE_COMMIT_DURATION), as long as it's actually still
	// there/blocking and still reachable, instead of re-picking a target
	// obstacle fresh every tick and abandoning partial progress whenever a
	// target shifts behind a different piece of cover. A destroyed obstacle
	// or one the pilot's since moved away from falls through to a fresh pick
	// below.
	if(committed_obstacle && world.time < committed_obstacle_until && is_obstacle_still_blocking(committed_obstacle))
		return committed_obstacle
	committed_obstacle = null

	// Reuses cardinal_step_towards()'s own candidate tiles rather than
	// independently recomputing a raw (possibly diagonal) direction to goal -
	// otherwise this could pick a wall/window on a third tile neither
	// cardinal attempt covered, ignoring a door that one of those two
	// attempts already found open and would have walked through.
	var/list/candidates = get_cardinal_candidates(goal)
	if(!candidates)
		return null

	var/obj/structure/door_candidate
	var/obj/structure/other_candidate
	var/atom/vehicle_candidate
	var/turf/closed/wall/wall_candidate
	var/wall_candidate_dir

	for(var/candidate_dir in candidates)
		if(!candidate_dir)
			continue
		var/turf/next_turf = get_step(pilot, candidate_dir)
		if(!next_turf)
			continue
		for(var/obj/structure/blocking_obstacle in next_turf)
			if(!blocking_obstacle.density || blocking_obstacle.unslashable || blocking_obstacle.climbable)
				continue
			if(istype(blocking_obstacle, /obj/structure/machinery/door))
				door_candidate = door_candidate || blocking_obstacle
			else
				other_candidate = other_candidate || blocking_obstacle
		// /obj/vehicle is a sibling of /obj/structure, not a subtype - the loop
		// above never matches one, so a parked vehicle directly in the way was
		// invisible to this whole obstacle-forcing chain regardless of caste.
		if(!vehicle_candidate)
			for(var/obj/vehicle/blocking_vehicle in next_turf)
				if(blocking_vehicle.density)
					vehicle_candidate = blocking_vehicle
					break
		// Mirrors walls.dm's own attack_alien() gates exactly, so this never
		// commits to a wall whose attack would silently no-op (the base
		// attack_alien() fallthrough does zero damage with no message or
		// animation, so a pilot committed to one would stand there
		// "attacking" it forever with no effect and no way out):
		// - TURF_HULL walls are invincible to everyone.
		// - claw_type below the wall's claws_minimum can't scratch it.
		// - an acided_hole wall only progresses for mob_size >= MOB_SIZE_BIG
		//   (expand_hole()) - smaller pilots can no longer do anything to it.
		// Excluded the same way an unslashable/climbable structure already
		// is above.
		if(!wall_candidate && istype(next_turf, /turf/closed/wall))
			var/turf/closed/wall/candidate_wall = next_turf
			if(!(candidate_wall.turf_flags & TURF_HULL) && pilot.claw_type >= candidate_wall.claws_minimum && !(candidate_wall.acided_hole && pilot.mob_size < MOB_SIZE_BIG))
				wall_candidate = candidate_wall
				wall_candidate_dir = candidate_dir

	// A door is the intended route through a structure - worth forcing
	// before opening a fresh hole in a wall/window on the other candidate.
	if(door_candidate)
		return commit_to_obstacle(door_candidate)
	if(other_candidate)
		return commit_to_obstacle(other_candidate)
	if(vehicle_candidate)
		return commit_to_obstacle(vehicle_candidate)
	// Walls only (doors/vehicles/other structures above are already the
	// intended route, left unconditional): "which is faster, going around or
	// smashing a wall" - a wall is only ever the one thing genuinely optional
	// to force through, so it's the one case worth a cheap side-check first.
	if(wall_candidate && !has_open_detour(wall_candidate_dir))
		return commit_to_obstacle(wall_candidate)
	return null

/**
 * A pilot with Corrosive Acid melts a blocking structure instead of only
 * ever clawing it - the same acid a player drops on a barricade line. Only
 * fires once per obstacle (acid keeps working on its own; the claws keep
 * swinging meanwhile), never on turf walls (too slow to be the plan), and
 * respects unacidable. Returns TRUE when acid was applied this call.
 */
/datum/xeno_ai_controller/proc/attempt_acid_on_obstacle(atom/target_obstacle)
	if(!pilot || isturf(target_obstacle))
		return FALSE
	var/obj/obstacle_obj = target_obstacle
	if(!istype(obstacle_obj) || obstacle_obj.unacidable)
		return FALSE
	var/datum/action/xeno_action/activable/corrosive_acid/acid = get_ability(/datum/action/xeno_action/activable/corrosive_acid)
	if(!acid || !acid.action_cooldown_check())
		return FALSE
	var/turf/obstacle_turf = get_turf(target_obstacle)
	if(obstacle_turf)
		for(var/obj/effect/xenomorph/acid/existing in obstacle_turf)
			if(existing.acid_t == target_obstacle)
				return FALSE // Already melting - keep clawing instead of wasting plasma.
	acid.use_ability(target_obstacle)
	return TRUE

/// Sets/refreshes the obstacle commitment (see get_blocking_obstacle()'s doc comment) and returns it, so every "found a new obstacle" branch above stays a one-liner.
/datum/xeno_ai_controller/proc/commit_to_obstacle(atom/obstacle)
	committed_obstacle = obstacle
	committed_obstacle_until = world.time + AI_XENO_OBSTACLE_COMMIT_DURATION
	return obstacle

/// Whether a previously-committed obstacle is still actually there, still blocking, and still reachable - a destroyed structure/vehicle is QDELETED, a destroyed wall's turf type has already changed away from /turf/closed/wall (turfs are never qdel'd), and a pilot who's since been forced elsewhere is no longer adjacent to any of it.
/datum/xeno_ai_controller/proc/is_obstacle_still_blocking(atom/obstacle)
	if(!pilot || QDELETED(obstacle) || !pilot.Adjacent(obstacle))
		return FALSE
	if(istype(obstacle, /turf/closed/wall))
		var/turf/closed/wall/committed_wall = obstacle
		// The wall can turn acided_hole mid-commitment (the same attack that
		// crosses the damage threshold both deals the hit and spawns the
		// acid_hole) - re-check the same gates get_blocking_obstacle()
		// applies, so a pilot that can no longer do anything to it isn't left
		// parked on a stale commitment. TURF_HULL is included for the same
		// consistency even though hull status never changes at runtime.
		if(committed_wall.turf_flags & TURF_HULL)
			return FALSE
		if(committed_wall.acided_hole && pilot.mob_size < MOB_SIZE_BIG)
			return FALSE
		return TRUE
	if(istype(obstacle, /obj/structure) || istype(obstacle, /obj/vehicle))
		var/atom/movable/movable_obstacle = obstacle
		return movable_obstacle.density
	return FALSE

/// A climbable structure (table, some fences/crates) directly ahead on the way to goal - see get_blocking_obstacle()'s doc comment above for why this needs separate handling instead of being treated as freely passable.
/datum/xeno_ai_controller/proc/get_climbable_obstacle(atom/goal)
	if(!pilot || !goal)
		return null
	var/turf/next_turf = get_step(pilot, get_dir(pilot, goal))
	if(!next_turf)
		return null
	for(var/obj/structure/climbable_obstacle in next_turf)
		if(climbable_obstacle.density && climbable_obstacle.climbable)
			return climbable_obstacle
	return null

/// Vaults over a climbable obstacle the same way a real player's do_climb() interaction would, instead of only ever sidestepping around it or standing there unable to proceed. do_climb()'s own do_after() windup blocks this controller's tick() the same safe way Queen's Gut/Burrower's burrow already do.
/datum/xeno_ai_controller/proc/attempt_climb_obstacle(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	return obstacle.do_climb(pilot)

/**
 * "Add a decision where is it better to climb over something or just smash
 * it." Climbing is the default - it's instant (a ~0.2-2s vault, no combat
 * risk) and most climbable furniture (tables, crates) was never meant to be
 * destroyed by a xeno at all. A barricade is the one climbable structure
 * that's also genuinely built to be fought through (real health/maxhealth,
 * its own attack_alien() destruction path) - worth actually smashing down
 * instead of just hopping over it, but only when it pays off: either the
 * pilot already melts real walls (wall_smash - a strong-melee caste tears
 * through it fast) or enough same-hive allies are right behind her that
 * clearing the chokepoint permanently helps the whole push, not just her
 * own one-time crossing.
 */
/datum/xeno_ai_controller/proc/should_smash_instead_of_climb(obj/structure/obstacle)
	if(!pilot || !obstacle)
		return FALSE
	if(!istype(obstacle, /obj/structure/barricade) || obstacle.unslashable)
		return FALSE
	return pilot.wall_smash || count_nearby_hive_allies(3) >= 2

/**
 * Paces smashing to next_move the same way plain melee's own attack cadence
 * is paced (xeno_ai_attack.dm's execute_attack()) - attack_alien() never sets
 * next_move itself for a basic hit, only click.dm's do_click() dispatch does,
 * which this AI bypasses by calling attack_alien() directly, so this proc
 * has to gate the rate itself instead of inheriting it for free.
 */
/datum/xeno_ai_controller/proc/attack_blocking_obstacle(atom/target_obstacle)
	if(!pilot || !target_obstacle)
		return
	if(world.time <= pilot.next_move)
		return
	pilot.setDir(get_dir(pilot, target_obstacle))
	if(attempt_acid_on_obstacle(target_obstacle))
		pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
		return
	pilot.a_intent = INTENT_HARM
	target_obstacle.attack_alien(pilot)
	if(pilot) // attack_alien() can retaliate/kill the pilot (e.g. an explosive barricade) - don't write to it if it just died.
		pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
		if(committed_obstacle == target_obstacle)
			committed_obstacle_until = world.time + AI_XENO_OBSTACLE_COMMIT_DURATION
