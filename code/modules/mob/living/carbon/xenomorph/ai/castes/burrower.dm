/**
 * Burrower AI - a trap-setting builder-brawler hybrid: builds weeds during
 * downtime like Drone/Hivelord (she has plant_weeds in her own
 * base_actions), and uses Tremor (a self-centered AoE knockdown) as her
 * opener whenever it's off cooldown.
 *
 * "Burrower should be able to use its burrow ability to go from one turf to
 * another, this helps ambush marines. Once out of the burrowing state, use
 * stomp, slash the enemy a bit, and burrow back to safety again" - Burrow
 * is dual-purpose on a real click too (burrower_abilities.dm's
 * use_ability()): clicking it while surfaced goes underground in place;
 * clicking it again while burrowed tunnels to wherever was clicked, then
 * auto-surfaces on arrival and knocks down anything standing on that tile
 * (Burrower.dm's do_tunnel()/burrow_off()) - a real ambush payoff, not just
 * a hiding spot. process_movement() below chains the two: burrow in place
 * while still approaching, then tunnel the rest of the way onto the
 * target's own tile once burrowed. can_act_while_immobilized() keeps her AI
 * ticking through both the "waiting underground" and "mid-tunnel" phases -
 * TRAIT_IMMOBILIZED would otherwise freeze the whole state machine, same
 * as it does for an ordinary knockdown, leaving her to resurface wherever
 * she happened to start rather than actually choosing to close in.
 *
 * Once surfaced next to a live target, use_caste_ability() below fights
 * normally (Tremor, falling through to plain slashes - "slash the enemy a
 * bit") for as long as the target's actually down or she's still healthy;
 * once it's back up and she's taken real damage doing it, THAT's the
 * decision point where she queues a tactical retreat (start_tactical_
 * retreat(), the shared hit-and-run helper) so process_movement() ducks her
 * back underground once there's room - a real decision reacting to the
 * fight, not a reflex after every opener or a coin flip after every swing.
 */
/datum/xeno_ai_controller/burrower
	/// Rotational direction (90 or -90) this Burrower always sidesteps toward - same reasoning as ravager.dm's identical var.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - see the reactive-dodge check there, same pattern as ravager.dm.
	var/last_known_health

/datum/xeno_ai_controller/burrower/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/// See the caste doc comment above - lets her keep deciding what to do next while burrowed/tunneling instead of freezing entirely.
/datum/xeno_ai_controller/burrower/can_act_while_immobilized()
	if(..())
		return TRUE
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	return istype(burrower_pilot) && HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED)

/// See attempt_opportunistic_drag()'s doc comment (xeno_ai_controller.dm) - pure refactor, same chance she's always rolled for this.
/datum/xeno_ai_controller/burrower/get_drag_chance()
	return AI_BURROWER_DRAG_CHANCE

/datum/xeno_ai_controller/burrower/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_build_defense())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_BURROWER_AMBUSH_CHANCE) && attempt_burrow_ambush())
		idle_activity = IDLE_ACTIVITY_AMBUSH
		return
	// "A trap-setting builder-brawler" per her own caste doc comment, but
	// Place Trap (a resin trap hole) was granted and never used - same idle-
	// build-roll shape as attempt_plant_weeds() above.
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_place_trap())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// Lower-priority infrastructure roll, checked last among her own build
	// options - extending the hive's tunnel network is a nice-to-have, not
	// worth pre-empting weeding/trapping/ambushing for.
	if(prob(AI_BURROWER_TUNNEL_BUILD_CHANCE) && attempt_build_hive_tunnel())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// Lightweight pre-check for pick_hive_tunnel_site() below - mirrors the cheap, obviously-disqualifying checks build_tunnel/use_ability() (Burrower.dm) itself does before its plasma/do_after/naming work, so a clearly bad candidate is rejected here instead of walking all the way there first. Not exhaustive (area is_resin_allowed/AREA_UNWEEDABLE, plasma, empty-hand are left to use_ability() itself - it already safely no-ops with just a chat message an AI has no client to see).
/datum/xeno_ai_controller/burrower/proc/is_valid_hive_tunnel_site(turf/candidate)
	if(!candidate || candidate.density || !is_ground_level(candidate.z) || !candidate.can_dig_xeno_tunnel())
		return FALSE
	if(locate(/obj/structure/tunnel) in candidate)
		return FALSE
	if(locate(/obj/structure/machinery/sentry_holder/landing_zone) in candidate)
		return FALSE
	return TRUE

/// FALSE if any existing hive tunnel node already sits within AI_BURROWER_TUNNEL_MIN_SPACING of location - this is specifically about not spamming redundant entrances close together, not about whether digging there is otherwise legal (is_valid_hive_tunnel_site() already covers that separately).
/datum/xeno_ai_controller/burrower/proc/is_hive_tunnel_network_sparse_near(turf/location)
	if(!pilot?.hive || !location)
		return FALSE
	for(var/obj/structure/tunnel/existing as anything in pilot.hive.tunnels)
		if(get_dist(location, existing) < AI_BURROWER_TUNNEL_MIN_SPACING)
			return FALSE
	return TRUE

/**
 * Site selection for attempt_build_hive_tunnel() below - prefers the hive's
 * current assault_alert_turf (same staleness window respond_to_hive_alert()
 * already reads, hive_status.dm) over the pilot's own position when there's
 * a live one, so a new entrance actually lands near an active fight instead
 * of wherever she happened to be idling. Returns null (skip this roll
 * entirely rather than searching for a fallback site) if the preferred spot
 * fails either the spacing or legality check - this is a low-priority
 * infrastructure roll, not worth a wider search on top of the ambush/build/
 * weed rolls already ahead of it in patrol().
 */
/datum/xeno_ai_controller/burrower/proc/pick_hive_tunnel_site()
	if(!pilot?.hive)
		return null
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf)
		return null

	var/turf/preferred = pilot_turf
	if(pilot.hive.assault_alert_turf && world.time - pilot.hive.assault_alert_time <= AI_XENO_HIVE_ALERT_WINDOW)
		preferred = pilot.hive.assault_alert_turf

	if(!is_hive_tunnel_network_sparse_near(preferred) || !is_valid_hive_tunnel_site(preferred))
		return null
	return preferred

/**
 * Autonomous use of build_tunnel (Burrower.dm) - a player-only ability as
 * written (its input() naming prompt now guarded behind xenomorph.client,
 * see that file). Same "commit to a site, walk there across multiple idle
 * ticks, act on arrival" pattern attempt_build_human_cap() uses, except
 * arrival requires standing EXACTLY on hive_tunnel_build_turf rather than
 * just within build range - use_ability() digs at the pilot's own loc, not a
 * passed-in target, so "close enough" isn't good enough here.
 */
/datum/xeno_ai_controller/burrower/proc/attempt_build_hive_tunnel()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || !burrower_pilot.hive || burrower_pilot.tunnel_delay)
		return FALSE

	if(hive_tunnel_build_turf)
		if(!is_valid_hive_tunnel_site(hive_tunnel_build_turf))
			hive_tunnel_build_turf = null
		else if(get_turf(pilot) != hive_tunnel_build_turf)
			travel_to(hive_tunnel_build_turf, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_AVOID_MOBS|TRAVEL_FLAG_STATIC_GOAL)
			return TRUE
		else
			var/datum/action/xeno_action/onclick/build_tunnel/action = get_ability(/datum/action/xeno_action/onclick/build_tunnel)
			action?.use_ability(pilot)
			hive_tunnel_build_turf = null
			return TRUE

	var/turf/build_turf = pick_hive_tunnel_site()
	if(!build_turf)
		return FALSE

	hive_tunnel_build_turf = build_turf
	return TRUE

/// Self-turf placement (place_trap/use_ability(), general_powers.dm) - the passed atom arg is unused, a plain self-target call is enough. Already refuses to fire while burrowed (the ability's own check), so no extra guard needed here.
/datum/xeno_ai_controller/burrower/proc/attempt_place_trap()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/place_trap/trap = get_ability(/datum/action/xeno_action/onclick/place_trap)
	if(!trap || !trap.action_cooldown_check())
		return FALSE
	trap.use_ability(pilot)
	return TRUE

/**
 * Picks an adjacent-to-target tile to tunnel up into instead of always
 * surfacing directly on top of the target - tunneling onto the target's own
 * tile (the old, still-default behavior via the caller's `|| target` fallback)
 * gives a free knockdown via do_tunnel()'s burrow_off(), but zero flanking;
 * this trades that away for surfacing from an actually unguarded angle when
 * one's available. Candidate ring and every rejection check below mirror
 * tunnel()'s own validation exactly (Burrower.dm) - not just "roughly
 * similar" - so this never approves a tile tunnel() would then itself
 * refuse: not dense, not open space, within 15 tiles of the pilot (tunnel()
 * measures from the Burrower's own position, not the target's), area not
 * AREA_NOTUNNEL, and no dense non-ON_BORDER /obj already occupying it (the
 * exact object-type tunnel() checks - deliberately not /atom/movable, since
 * tunnel() itself doesn't treat a mob standing there as a blocker).
 *
 * Scoring then penalizes two things: a candidate roughly in the target's own
 * facing direction (not a flank at all), and a candidate on the same side an
 * ally already fighting this exact target is standing on (so multiple
 * Burrowers/allies converging on one victim don't all pile onto the same
 * side and leave the rest of the target's flanks wide open). Falls back to
 * null if nothing in the ring qualifies - the caller's `|| target` then
 * preserves today's on-target behavior exactly, so open ground with no
 * allies around behaves identically to before this proc existed.
 */
/datum/xeno_ai_controller/burrower/proc/pick_burrower_flank_turf(atom/movable/target)
	if(!pilot || !target)
		return null
	var/turf/target_turf = get_turf(target)
	if(!target_turf)
		return null

	var/list/candidates = list()
	for(var/turf/candidate in orange(1, target_turf))
		if(candidate.density || istype(candidate, /turf/open/space))
			continue
		if(get_dist(pilot, candidate) > 15)
			continue
		var/area/candidate_area = get_area(candidate)
		if(candidate_area?.flags_area & AREA_NOTUNNEL)
			continue
		var/blocked = FALSE
		for(var/obj/blocker in candidate.contents)
			if(blocker.density && !(blocker.flags_atom & ON_BORDER))
				blocked = TRUE
				break
		if(blocked)
			continue
		candidates += candidate
	if(!length(candidates))
		return null

	// Which side(s) of the target are already claimed by an ally actively
	// fighting them - scanned once, reused for every candidate's score below,
	// rather than re-scanning per candidate.
	var/list/ally_dirs = list()
	for(var/mob/living/carbon/xenomorph/ally in range(AI_BURROWER_FLANK_ALLY_SCAN_RADIUS, target_turf))
		if(ally == pilot || ally.stat == DEAD || ally.hivenumber != pilot.hivenumber)
			continue
		if(ally.ai_controller?.current_target == target)
			ally_dirs += get_dir(target_turf, get_turf(ally))

	var/list/best_candidates = list()
	var/best_score = -INFINITY
	for(var/turf/candidate in candidates)
		var/candidate_dir = get_dir(target_turf, candidate)
		var/score = 0
		if(candidate_dir == target.dir)
			score -= 2 // Roughly in front of them - not a flank.
		if(candidate_dir in ally_dirs)
			score -= 3 // Already someone else's side.
		if(score > best_score)
			best_score = score
			best_candidates = list(candidate)
		else if(score == best_score)
			best_candidates += candidate
	return pick(best_candidates)

/// Fires Burrow if she's currently eligible (not already burrowed/tunneling/on cooldown) - see the caste doc comment above for why blocking tick() through the windup is safe here.
/datum/xeno_ai_controller/burrower/proc/attempt_burrow_ambush()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || burrower_pilot.used_burrow || burrower_pilot.tunnel || HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED))
		return FALSE
	var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
	if(!burrow_ability)
		return FALSE
	burrow_ability.use_ability(burrower_pilot)
	return TRUE

/**
 * Combat movement: while burrowed, either tunnels the rest of the way onto
 * the target (ambush) or just waits out an already-in-progress tunnel;
 * while chasing on the surface, has a chance to burrow in place first
 * instead of always closing the distance on foot; while tactically
 * retreating, backs off and ducks underground once there's room instead of
 * only ever backing away in the open. Otherwise inherits the normal
 * approach/attack chain unchanged.
 */
/datum/xeno_ai_controller/burrower/process_movement()
	var/mob/living/carbon/xenomorph/burrower_pilot = pilot
	if(!istype(burrower_pilot) || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(HAS_TRAIT(burrower_pilot, TRAIT_ABILITY_BURROWED))
		if(burrower_pilot.tunnel)
			return // Already mid-tunnel - do_tunnel() surfaces her automatically on arrival.
		if(!burrower_pilot.used_tunnel)
			// tunnel()/do_tunnel() (Burrower.dm) never actually validate that
			// their destination turf is on the same z as the Burrower herself
			// - get_dist() ignores z and forceMove() crosses it freely - so a
			// target who's crossed a deck mid-chase would otherwise get
			// tunneled at on the same x/y but the WRONG z, surfacing her
			// somewhere on an unrelated level with zero guarantee there's even
			// open ground there. Guarded here rather than in the shared
			// player-facing proc: stay burrowed and wait out the timer
			// (burrow_off() resurfaces her automatically) rather than tunnel
			// blind - the target catching up to her level first is what lets
			// travel_to()/advance_towards_z() close the gap safely instead.
			var/turf/burrower_turf = get_turf(burrower_pilot)
			var/turf/target_turf = get_turf(current_target)
			if(burrower_turf && target_turf && burrower_turf.z != target_turf.z)
				return
			var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
			// pick_burrower_flank_turf() surfaces her adjacent to the target
			// from an unclaimed angle instead of always on top of them - falls
			// back to current_target itself (today's exact behavior, free
			// knockdown via burrow_off()) whenever no qualifying flank tile
			// exists, e.g. open ground with no allies around.
			burrow_ability?.use_ability(pick_burrower_flank_turf(current_target) || current_target)
		return

	if(is_tactical_retreating())
		if(get_dist(burrower_pilot, current_target) >= AI_BURROWER_RETREAT_SAFE_DISTANCE)
			attempt_burrow_ambush() // Far enough out now - duck underground and let the retreat/cooldown run out safely instead of just standing in the open.
			return
		// Cornered with nowhere to actually back into cancels the retreat
		// outright instead of standing frozen for the rest of the window -
		// same fix as every other hit-and-run caste.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	last_seen_turf = get_turf(current_target)
	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(!burrower_pilot.used_burrow && prob(AI_BURROWER_AMBUSH_ENGAGE_CHANCE))
		var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
		if(burrow_ability)
			burrow_ability.use_ability(burrower_pilot) // Sets up the tunnel-in above rather than trudging the rest of the way over on foot.
			return

	return ..()

/**
 * "Crusher, and burrower never use their stomping ability when near
 * enemies" - Tremor knocks down everything it hits, same as Crusher's
 * Stomp, so a single-target hit is still a real win; it was wrong to gate
 * it behind a headcount that rarely happened in an ordinary 1v1.
 *
 * "A good start, but they burrow a lot until they die - they should
 * consider slashing until the enemy is up, and then they get to decide to
 * flee or keep fighting." Used to queue a tactical retreat automatically
 * the instant Tremor landed, and separately roll a flat percent chance to
 * retreat after every single plain swing regardless of how the fight was
 * actually going - between the two she was ducking out almost immediately
 * and constantly, never actually committing to a fight. Now she just fights
 * (Tremor as an opener, falling through to plain slashes) while the target
 * is still down from it; once it's back up and still a real threat, THAT's
 * the actual decision point - retreat only if she's taken real damage
 * doing it, not a blind reflex or a coin flip.
 */
/datum/xeno_ai_controller/burrower/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	// "Kidnapping a human for the hive at times before burrowing back to
	// safety" - the drag-and-isolate tow itself now lives centrally in
	// attempt_opportunistic_drag() (xeno_ai_controller.dm), called from
	// execute_attack() before use_caste_ability() is even reached, so a
	// downed target still gets grabbed before Tremor (which would just knock
	// them right back down) without needing its own check here - see
	// get_drag_chance()'s override below for her AI_BURROWER_DRAG_CHANCE.

	var/datum/action/xeno_action/onclick/tremor/tremor = get_ability(/datum/action/xeno_action/onclick/tremor)
	if(tremor && tremor.action_cooldown_check())
		var/found_target = FALSE
		for(var/mob/living/carbon/nearby in orange(2, pilot))
			if(is_valid_target(nearby))
				found_target = TRUE
				break
		if(found_target)
			tremor.use_ability(pilot)
			return TRUE

	if(!HAS_TRAIT(target, TRAIT_FLOORED) && !target.is_mob_incapacitated() && pilot.health < pilot.maxHealth * AI_BURROWER_CAUTIOUS_HEALTH_PERCENT)
		start_tactical_retreat(AI_BURROWER_RETREAT_DURATION)
	return FALSE

/// Burrower had no post-attack repositioning at all - same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step.
/datum/xeno_ai_controller/burrower/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		last_known_health = pilot?.health
		return
	var/took_damage = (last_known_health != null) && (pilot.health < last_known_health)
	last_known_health = pilot.health
	if(!took_damage && !prob(AI_WARRIOR_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir))
