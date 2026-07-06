/**
 * Facehugger AI - a pure ambush predator. Leap (the pounce ability) can hug
 * on landing regardless of whether the target is standing or lying down -
 * can_hug() (Facehuggers.dm) never checks body_position at all, only the
 * slow manual melee windup (UnarmedAttack()/execute_facehugger_hug()) is
 * restricted to LYING_DOWN targets. So the correct AI is: always prefer
 * leaping, at any range including already-adjacent, since it's strictly
 * better than the interruptible windup and works on anyone; only fall back
 * to approaching/waiting on the slow windup while Leap is on cooldown (a
 * short one, 3 seconds), which will only actually connect if the target
 * happens to already be down.
 *
 * Also hides (xenohide) while patrolling, same "lie in wait" identity the
 * caste already has via its own base_actions - nothing un-hides it again
 * since neither moving nor landing a hug breaks the hide (only a stat
 * change does, per the ability's own signal handler), which suits an
 * ambush predator fine.
 */
/datum/xeno_ai_controller/facehugger

/**
 * **Real bug, not a tuning nit**: had no should_flee()/get_flee_threshold()
 * override at all before Phase 3, so a one-hit-fragile (max_health =
 * XENO_HEALTH_LARVA) caste with no attack worth trading inherited the base
 * should_flee()'s "target's in the same rough shape, finish it" and "not
 * fighting alone" exceptions - both assume a xeno that can actually win a
 * fight, which she never can. This deliberately does NOT mirror larva.dm's
 * "flee from any spotted hostile" override - her whole gameplan is closing
 * distance and Leaping (process_movement()/attempt_leap() above, confirmed
 * correct this session), so should_flee() only needs to matter AFTER she's
 * actually taken real damage, at a much higher threshold than the
 * population default, with none of the base version's talk-herself-back-
 * into-a-fight exceptions.
 */
/datum/xeno_ai_controller/facehugger/should_flee()
	if(!pilot || !pilot.maxHealth)
		return FALSE
	return (pilot.health / pilot.maxHealth) < AI_FACEHUGGER_FLEE_HEALTH_PERCENT

/// Never - same reasoning as larva.dm's identical override, she has no attack worth turning around for.
/datum/xeno_ai_controller/facehugger/get_desperate_threshold()
	return 0

/datum/xeno_ai_controller/facehugger/patrol()
	if(attempt_cover_tuck())
		return
	attempt_hide()
	return ..()

/datum/xeno_ai_controller/facehugger/proc/attempt_hide()
	if(!pilot || pilot.layer == XENO_HIDING_LAYER)
		return
	var/datum/action/xeno_action/onclick/xenohide/hide = get_ability(/datum/action/xeno_action/onclick/xenohide)
	hide?.use_ability(pilot)

/**
 * "Can hide under tables and items to ambush" - seeks a nearby table/rack
 * tile and tucks under it before flattening, instead of hiding in the open
 * wherever she happens to be standing. Returns TRUE while walking to cover
 * (owns the patrol tick); once on a cover tile the normal hide/ambush idle
 * takes over.
 */
/datum/xeno_ai_controller/facehugger/proc/attempt_cover_tuck()
	if(!pilot)
		return FALSE
	var/turf/pilot_turf = get_turf(pilot)
	if(!pilot_turf || (locate(/obj/structure/surface) in pilot_turf))
		return FALSE // Already tucked under something - flatten in place via the normal hide.
	var/obj/structure/surface/best
	var/best_dist = INFINITY
	for(var/obj/structure/surface/cover in range(AI_HUGGER_COVER_SEARCH_RADIUS, pilot))
		var/cover_dist = get_dist(pilot, cover)
		if(cover_dist < best_dist)
			best_dist = cover_dist
			best = cover
	if(!best)
		return FALSE
	idle_activity = IDLE_ACTIVITY_AMBUSH
	travel_to(best, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_AVOID_MOBS)
	return TRUE

/**
 * "Can teamup with other hive members to stun and capture" - a marine a
 * sister has already stunned or floored is the perfect hug; prefer them over
 * whoever the generic nearest-hostile scan happened to pick.
 */
/datum/xeno_ai_controller/facehugger/process_target()
	. = ..()
	if(!pilot)
		return
	if(current_target && ishuman(current_target))
		var/mob/living/carbon/human/current_human = current_target
		if(current_human.is_mob_incapacitated() || current_human.body_position == LYING_DOWN)
			return // Already locked onto a downed host.
	for(var/mob/living/carbon/human/candidate in range(attack_distance, pilot))
		if(candidate == current_target || candidate.stat == DEAD || !is_valid_target(candidate))
			continue
		if(candidate.is_mob_incapacitated() || candidate.body_position == LYING_DOWN)
			acquire_target(candidate)
			return

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * the leap (checked even when already adjacent, unlike every other dash
 * caste's controller) differs enough from the base melee policy to warrant
 * a full override.
 */
/datum/xeno_ai_controller/facehugger/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(attempt_leap(current_target))
		return

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	return ..()

/// Fires Leap at target if it's off cooldown and within its reach (including adjacent - it's still strictly better than the slow melee windup); returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/wait behavior.
/datum/xeno_ai_controller/facehugger/proc/attempt_leap(atom/target)
	var/datum/action/xeno_action/activable/pounce/facehugger/leap = get_ability(/datum/action/xeno_action/activable/pounce/facehugger)
	if(!leap || !leap.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > leap.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A leap is a physical pounce - tables/fences/barricades block it same as a wall would.
		return FALSE
	leap.use_ability(target)
	return TRUE
