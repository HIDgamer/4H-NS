/**
 * AI vent-crawling: enter a vent, travel through the connected pipe network,
 * exit at another vent - for ambush setups and undetected repositioning.
 * Deliberately its own file rather than folded into xeno_ai_controller.dm/
 * xeno_ai_movement.dm - self-contained enough (its own registry, its own
 * pathfinder, its own entry/traversal/exit mechanics) to deserve one.
 *
 * This was previously attempted for AI use in this fork and abandoned -
 * pipes.dm's relaymove() still carries a defensive `if(user.client)` guard
 * with a comment noting it's "kept even though AI xenos no longer
 * vent-crawl," meaning it was reachable and partly working before being
 * dropped, not blocked by an engine limitation. The actual gaps were: no
 * registry of every vent on the map (unlike GLOB.ladder_list), no
 * pathfinding over the pipe graph (an arbitrary graph via connected_to, not
 * a simple point-to-point hop like a ladder or tunnel), and no programmatic
 * multi-hop traversal. All three are filled below.
 *
 * Mechanically, real vent-crawling (ventcrawl.dm/pipes.dm) has three
 * distinct phases with very different timing, all replicated here minus the
 * parts that only make sense for a real client (a tgui vent picker, and
 * entry's own `!client` abort after its channel - clearly meant to catch a
 * player disconnecting mid-animation, not a deliberate anti-AI gate, but it
 * would incorrectly block a legitimately clientless AI mob that never had a
 * client to begin with):
 * - Entry (handle_ventcrawl()): a real 45-tick do_after channel.
 * - Intermediate pipe-to-pipe movement (relaymove(), when a connected pipe
 *   exists in the requested direction): INSTANT, no do_after at all - a
 *   player moving through connected pipes does so as fast as they can send
 *   directional input. ai_ventcrawl_traverse() below deliberately does NOT
 *   mimic this timing exactly (see AI_VENT_HOP_DELAY's own doc comment).
 * - Exit (relaymove(), when no connected pipe exists in the requested
 *   direction and the current segment is a vent): a real 20-tick do_after
 *   channel.
 */

/**
 * BFS over the pipe network's connected_to graph (pipes.dm) from entry to
 * exit. BFS, not Dijkstra/A*: connected_to is an unweighted adjacency list
 * (one hop = one edge) and pipe runs don't follow any coordinate-based
 * heuristic worth exploiting, so plain BFS already gives the shortest-hop
 * path with no wasted overhead. Bounded by AI_VENT_PATHFIND_MAX_NODES so a
 * malformed or absurdly large duct network can't hang the calling coroutine.
 * Returns an ordered list of /obj/structure/pipes nodes from entry to exit
 * inclusive, or null if unreachable or the search exhausted its budget.
 */
/proc/find_vent_path(obj/structure/pipes/entry, obj/structure/pipes/exit)
	if(!entry || !exit || QDELETED(entry) || QDELETED(exit))
		return null
	if(entry == exit)
		return list(entry)
	if(entry.z != exit.z) // The pipe graph never crosses z - search_for_connections() (pipes.dm) only ever walks get_step() on the same level.
		return null

	var/list/visited = list(entry = TRUE)
	var/list/parent = list()
	var/list/frontier = list(entry)
	var/visited_count = 1

	while(length(frontier))
		var/list/next_frontier = list()
		for(var/obj/structure/pipes/current as anything in frontier)
			for(var/obj/structure/pipes/neighbor as anything in current.connected_to)
				if(QDELETED(neighbor) || visited[neighbor])
					continue
				if(neighbor == exit)
					parent[neighbor] = current
					return ai_ventcrawl_reconstruct_path(parent, exit)
				visited[neighbor] = TRUE
				parent[neighbor] = current
				if(++visited_count > AI_VENT_PATHFIND_MAX_NODES)
					return null
				next_frontier += neighbor
		frontier = next_frontier
	return null

/// Walks find_vent_path()'s parent-chain backward from exit to entry, then reverses it into forward (entry-first) order.
/proc/ai_ventcrawl_reconstruct_path(list/parent, obj/structure/pipes/exit)
	var/list/path = list(exit)
	var/obj/structure/pipes/walker = exit
	while(parent[walker])
		walker = parent[walker]
		path.Insert(1, walker)
	return path

/**
 * AI-safe re-implementation of handle_ventcrawl()'s entry sequence
 * (ventcrawl.dm) - not a call into that proc directly, since its own
 * post-channel validation requires a live client (`!client` is one of its
 * abort conditions, correctly so for a real player who might disconnect
 * mid-animation, but wrong for a pilot that never had a client at all).
 * Every other check here mirrors it exactly: welded, ventcrawl_carry()
 * (no items equipped/carried unless TRAIT_CRAWLER), the weeds-blocking-
 * entrance check, connected_to non-empty (a vent with nothing to crawl
 * into is a dead end regardless), action_busy, then the real 45-tick
 * do_after channel.
 */
/datum/xeno_ai_controller/proc/ai_ventcrawl_enter(obj/structure/pipes/vents/entry_vent)
	if(!pilot || !entry_vent || QDELETED(entry_vent))
		return FALSE
	if(pilot.stat || pilot.is_mob_incapacitated())
		return FALSE
	if(entry_vent.welded)
		return FALSE
	if(!pilot.ventcrawl_carry())
		return FALSE
	var/obj/effect/alien/weeds/entry_weeds = locate(/obj/effect/alien/weeds) in entry_vent.loc
	if(entry_weeds && pilot.hivenumber != entry_weeds.linked_hive.hivenumber)
		return FALSE
	if(!length(entry_vent.connected_to))
		return FALSE
	if(pilot.action_busy)
		return FALSE

	pilot.visible_message(SPAN_NOTICE("[pilot] begins climbing into [entry_vent]."), SPAN_NOTICE("We begin climbing into [entry_vent]."))
	entry_vent.animate_ventcrawl()
	if(!do_after(pilot, 45, INTERRUPT_NO_NEEDHAND, BUSY_ICON_GENERIC))
		entry_vent.animate_ventcrawl_reset()
		return FALSE

	entry_vent.animate_ventcrawl_reset()
	if(!pilot || QDELETED(pilot) || pilot.is_mob_incapacitated() || pilot.health < 0 || !pilot.ventcrawl_carry())
		return FALSE

	pilot.visible_message(SPAN_DANGER("[pilot] scrambles into [entry_vent]!"), SPAN_WARNING("We climb into [entry_vent]."))
	playsound(pilot, pick('sound/effects/alien_ventpass1.ogg', 'sound/effects/alien_ventpass2.ogg'), 35, 1)
	pilot.forceMove(entry_vent)
	pilot.is_ventcrawling = TRUE
	return TRUE

/**
 * Drives the pilot through an already-resolved pipe route (find_vent_path())
 * node by node via forceMove(). Deliberately does NOT re-derive a direction
 * and call relaymove() at each hop - relaymove()'s own get_connection(dir)
 * has its own tie-break (prefers whichever neighbor has more connections)
 * that could disagree with which specific node the BFS already committed to
 * at a junction with multiple neighbors in the same direction; walking the
 * resolved node list directly removes that as a second, potentially
 * conflicting source of truth. Every hop re-validates: pilot still alive/not
 * incapacitated, still actually at the previous node (catches an external
 * forceMove/pull), and the next node still listed in the previous node's
 * connected_to (catches a segment welded/unwrenched/destroyed mid-transit).
 *
 * A real player interrupted mid-crawl (stunned, or a route dead-ending
 * ahead of them) just sits in whatever pipe segment they were last in until
 * their own next relaymove() input tries something else - they always have
 * that manual fallback. The AI has no equivalent "find my own way out"
 * behavior, so being left stuck inside a pipe object with no turf location
 * would be a permanent soft-lock, not a faithfully-replicated inconvenience.
 * The route-broke-ahead case (the realistic one - a marine welds a vent
 * mid-hunt) is therefore explicitly recovered from: ejected back onto the
 * last good node's own turf so ordinary AI movement can resume next tick.
 * Incapacitation is deliberately left alone (not force-ejected) - that
 * matches what actually happens to a player in the same spot, and if the
 * pilot's dead it doesn't matter anyway.
 */
/datum/xeno_ai_controller/proc/ai_ventcrawl_traverse(list/path)
	if(!pilot || !length(path))
		return FALSE

	for(var/i in 2 to length(path))
		sleep(AI_VENT_HOP_DELAY)
		if(!pilot || QDELETED(pilot) || pilot.stat == DEAD || pilot.is_mob_incapacitated())
			pilot?.remove_ventcrawl()
			return FALSE
		if(pilot.loc != path[i - 1])
			pilot.remove_ventcrawl()
			return FALSE // Something else already moved her out of the pipe entirely - nothing left to eject from.
		var/obj/structure/pipes/previous_node = path[i - 1]
		var/obj/structure/pipes/next_node = path[i]
		if(QDELETED(next_node) || !(next_node in previous_node.connected_to))
			pilot.remove_ventcrawl()
			pilot.forceMove(get_turf(previous_node)) // Route broke ahead of us - eject to a real turf instead of leaving her stranded inside the pipe with no way to resume on her own.
			return FALSE
		pilot.forceMove(next_node)

	return TRUE

/**
 * AI-safe re-implementation of relaymove()'s exit branch (pipes.dm) - welded
 * and weeds-blocking-exit checks, then the real 20-tick "climbing out"
 * do_after channel. No client dependency exists in the real exit branch
 * (unlike entry), so this is a closer mirror than ai_ventcrawl_enter() needs
 * to be.
 *
 * Called only once ai_ventcrawl_traverse() has already delivered the pilot
 * to exit_vent itself, so any failure here (welded shut right as she
 * arrives, weeds ownership changed, the channel interrupted) would strand
 * her inside the exit vent object with no way to resume on her own - same
 * risk ai_ventcrawl_traverse() guards against for a route breaking mid-
 * transit, see that proc's doc comment. Every failure branch below ejects
 * her onto exit_vent's own turf rather than leaving her inside it.
 */
/datum/xeno_ai_controller/proc/ai_ventcrawl_exit(obj/structure/pipes/vents/exit_vent)
	if(!pilot || !exit_vent || QDELETED(exit_vent))
		return FALSE
	if(exit_vent.welded)
		pilot.remove_ventcrawl()
		pilot.forceMove(get_turf(exit_vent))
		return FALSE
	var/obj/effect/alien/weeds/exit_weeds = locate(/obj/effect/alien/weeds) in exit_vent.loc
	if(exit_weeds && pilot.hivenumber != exit_weeds.linked_hive.hivenumber)
		pilot.remove_ventcrawl()
		pilot.forceMove(get_turf(exit_vent))
		return FALSE

	var/turf/alert_turf = get_turf(exit_vent)
	alert_turf?.visible_message(SPAN_HIGHDANGER("You hear something squeezing through the ducts."))
	if(!do_after(pilot, 20, INTERRUPT_NO_NEEDHAND))
		if(pilot && !QDELETED(pilot))
			pilot.remove_ventcrawl()
			pilot.forceMove(alert_turf)
		return FALSE

	if(!pilot || QDELETED(pilot))
		return FALSE
	pilot.remove_ventcrawl()
	pilot.forceMove(exit_vent.loc)
	pilot.visible_message(SPAN_HIGHDANGER("[pilot] bursts out of [exit_vent]!"), SPAN_NOTICE("We climb out of [exit_vent]."))
	playsound(pilot, pick('sound/effects/alien_ventpass1.ogg', 'sound/effects/alien_ventpass2.ogg'), 35, 1)
	return TRUE

/// Nearest reachable (non-empty connected_to), unwelded vent to the pilot's own position - the entry side, always distance-only.
/datum/xeno_ai_controller/proc/ai_ventcrawl_find_entry()
	if(!pilot)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null
	var/obj/structure/pipes/vents/best
	var/best_dist = INFINITY
	for(var/obj/structure/pipes/vents/candidate as anything in GLOB.vent_list)
		if(QDELETED(candidate) || candidate.welded || !length(candidate.connected_to))
			continue
		var/turf/candidate_turf = get_turf(candidate)
		if(!candidate_turf || candidate_turf.z != pilot_turf.z)
			continue
		var/d = get_dist(pilot, candidate)
		if(d < best_dist)
			best_dist = d
			best = candidate
	return best

/// Nearest reachable, unwelded vent to goal_turf, excluding entry - the exit side. Shared by both AI use cases (the caller decides what goal_turf actually is - a target's position for an ambush, or a patrol waypoint for undetected travel).
/datum/xeno_ai_controller/proc/ai_ventcrawl_find_exit(turf/goal_turf, obj/structure/pipes/vents/exclude)
	if(!goal_turf)
		return null
	var/obj/structure/pipes/vents/best
	var/best_dist = INFINITY
	for(var/obj/structure/pipes/vents/candidate as anything in GLOB.vent_list)
		if(QDELETED(candidate) || candidate == exclude || candidate.welded || !length(candidate.connected_to))
			continue
		var/turf/candidate_turf = get_turf(candidate)
		if(!candidate_turf || candidate_turf.z != goal_turf.z)
			continue
		var/d = get_dist(candidate, goal_turf)
		if(d < best_dist)
			best_dist = d
			best = candidate
	return best

/**
 * Top-level entry point - attempts a full vent-crawl trip toward goal_turf
 * when it meaningfully beats walking there directly. Same distance-savings
 * gating philosophy as attempt_tunnel_shortcut() (xeno_ai_controller.dm),
 * adapted for vents: unlike the tunnel network's guaranteed-direct hop
 * between two fixed points, a resolved pipe ROUTE can itself be circuitous
 * (real duct runs don't follow open terrain), so the gate compares against
 * the actual BFS-resolved hop count, not just entry/exit walking distance.
 *
 * Only ever attempts the crawl once the pilot is already standing at the
 * entry vent - travel_to() (xeno_ai_movement.dm) handles getting her there
 * first, exactly like get_or_pick_z_transition()'s ladder branch
 * (xeno_ai_controller.dm) already does for a non-adjacent target.
 */
/datum/xeno_ai_controller/proc/attempt_ventcrawl_travel(turf/goal_turf)
	if(!pilot || !goal_turf || !pilot.can_ventcrawl())
		return FALSE
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || pilot_turf.z != goal_turf.z)
		return FALSE // Same-z only - the pipe graph itself never crosses z (see find_vent_path()'s own check), separate from the multi-z stairs/ladder bridging travel_to() already does.
	var/direct_dist = get_dist(pilot, goal_turf)
	if(direct_dist < AI_VENT_MIN_TRIP)
		return FALSE

	var/obj/structure/pipes/vents/entry = ai_ventcrawl_find_entry()
	if(!entry)
		return FALSE
	var/obj/structure/pipes/vents/exit = ai_ventcrawl_find_exit(goal_turf, entry)
	if(!exit || exit == entry)
		return FALSE

	var/list/path = find_vent_path(entry, exit)
	if(!path || length(path) > AI_VENT_MAX_HOPS)
		return FALSE

	var/entry_dist = get_dist(pilot, entry)
	var/exit_dist = get_dist(exit, goal_turf)
	if(entry_dist + length(path) + exit_dist + AI_VENT_TRIP_OVERHEAD >= direct_dist)
		return FALSE

	if(!pilot.Adjacent(entry))
		travel_to(entry, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_AVOID_MOBS)
		return TRUE

	if(!ai_ventcrawl_enter(entry))
		return FALSE
	if(!ai_ventcrawl_traverse(path))
		return TRUE // Entry succeeded even if the transit itself got interrupted partway - still real progress this call.
	ai_ventcrawl_exit(exit)
	return TRUE
