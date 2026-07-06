/**
 * Warrior AI - a heavy melee brawler: closes with Lunge (a grab-range
 * closer, not a pounce-style throw) instead of walking the whole distance,
 * then prefers Punch (can fracture/target limbs) over a plain claw once
 * engaged, falling through to Tail Stab as a follow-up hit whenever Punch
 * itself is still on cooldown - "use its punch ability with its other
 * lunge ability and follow ups" - instead of a bare claw the instant Punch
 * isn't up. Patrol/search behavior is entirely inherited from the base
 * controller.
 */
/datum/xeno_ai_controller/warrior
	/// Rotational direction (90 or -90) this Warrior always sidesteps toward - same reasoning as ravager.dm's identical var, picked once so repositioning reads as one consistent circling motion.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - lets the reposition check tell "just got hit, this is a reactive dodge" from "nothing happened, this is just the baseline roll," same pattern as ravager.dm.
	var/last_known_health

/datum/xeno_ai_controller/warrior/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * Lunge before falling through to the inherited approach chain differs
 * enough from the base melee policy to warrant a full override.
 */
/datum/xeno_ai_controller/warrior/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_lunge(current_target))
		return

	return ..()

/// Fires Lunge at target if it's off cooldown and within grab range; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/warrior/proc/attempt_lunge(atom/target)
	var/datum/action/xeno_action/activable/lunge/lunge = get_ability(/datum/action/xeno_action/activable/lunge)
	if(!lunge || !lunge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > lunge.grab_range)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A lunge is a physical throw - tables/fences/barricades block it same as a wall would, same fix already applied to every other dash-type ability.
		return FALSE
	lunge.use_ability(target)
	return TRUE

/**
 * Fling (a knockback/stun/slow, adjacency-required) was granted but never
 * called anywhere - tried first as a crowd-control peel when 2+ valid
 * targets are already adjacent (same nearby-count-scan shape as crusher.dm's
 * Stomp check), before Punch/Tail Stab's normal single-target rotation.
 */
/datum/xeno_ai_controller/warrior/use_caste_ability(mob/living/target)
	if(attempt_fling(target))
		return TRUE

	var/datum/action/xeno_action/activable/warrior_punch/punch = get_ability(/datum/action/xeno_action/activable/warrior_punch)
	if(punch && punch.action_cooldown_check())
		punch.use_ability(target)
		return TRUE
	return attempt_tail_stab(target)

/// Only worth the knockback when actually surrounded - a lone target is better handled by Punch/Tail Stab's straight damage.
/datum/xeno_ai_controller/warrior/proc/attempt_fling(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/fling/fling = get_ability(/datum/action/xeno_action/activable/fling)
	if(!fling || !fling.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(1, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	if(nearby_targets < 2)
		return FALSE
	fling.use_ability(target)
	return TRUE

/// Warrior had no post-attack repositioning at all - same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step.
/datum/xeno_ai_controller/warrior/get_flee_threshold()
	return AI_WARRIOR_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/warrior/process_attack()
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
