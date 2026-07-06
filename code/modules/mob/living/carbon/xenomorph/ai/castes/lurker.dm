/**
 * Lurker AI - the hive's stealth ambush predator: cloaks while stalking a
 * target instead of closing in visibly, pounces once in range (cloaked
 * Lurkers get a speed buff, making the cloak-then-pounce combo the fast
 * option too, not just the sneaky one), and arms Assassinate for a
 * bonus-damage opener before the first real hit lands. Decloaking itself
 * on attack/bump is already handled by the caste's own signal handlers
 * (Lurker.dm) - nothing extra needed here for that part.
 *
 * "Use their abilities to attack enemies as is, but make retreating a
 * strategic part of their attack plan too, as they attack and die" - she's
 * fast but low-HP/no-armor, exactly the caste that should never just stand
 * and trade once the opener's spent. use_caste_ability() below queues a
 * tactical retreat after a few hits (the shared hit-and-run helper, same as
 * Praetorian/Ravager/Burrower), and process_movement() re-cloaks while
 * pulling out so she actually vanishes again instead of retreating in
 * plain sight, ready to re-pounce once she's got room.
 */
/datum/xeno_ai_controller/lurker

/// "Fast but low-HP/no-armor, exactly the caste that should never just stand and trade" (this file's own header) - the reasoning already existed, she just never got a real override before Phase 3.
/datum/xeno_ai_controller/lurker/get_flee_threshold()
	return AI_LURKER_FLEE_HEALTH_PERCENT

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm - attempting
 * the pounce (and keeping cloak up while closing) differs enough from the
 * base melee policy to warrant a full override.
 */
/datum/xeno_ai_controller/lurker/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	attempt_cloak()

	if(is_tactical_retreating())
		// Cornered with nowhere to actually back into cancels the retreat
		// outright instead of standing frozen for the rest of the window.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_pounce(current_target))
		return
	if(attempt_rush(current_target))
		return
	if(attempt_tail_jab(current_target))
		return

	return ..()

/// Cloaks while hunting if not already cloaked and off cooldown - a silent approach instead of announcing the chase.
/datum/xeno_ai_controller/lurker/proc/attempt_cloak()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(xeno_pilot.stealth)
		return
	var/datum/action/xeno_action/onclick/lurker_invisibility/cloak = get_ability(/datum/action/xeno_action/onclick/lurker_invisibility)
	if(!cloak || !cloak.action_cooldown_check())
		return
	cloak.use_ability(xeno_pilot)

/// Fires Pounce at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/lurker/proc/attempt_pounce(atom/target)
	var/datum/action/xeno_action/activable/pounce/lurker/pounce = get_ability(/datum/action/xeno_action/activable/pounce/lurker)
	if(!pounce || !pounce.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > pounce.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A pounce is a physical dash - tables/fences/barricades block it same as a wall would, not just line-of-sight.
		return FALSE
	pounce.use_ability(target)
	return TRUE

/// Vampire-strain-only. Rush is a sibling subtype of base pounce (activable/pounce/rush, not activable/pounce/lurker), so attempt_pounce() above already no-ops for her via get_ability() - same shape, separate typepath.
/datum/xeno_ai_controller/lurker/proc/attempt_rush(atom/target)
	var/datum/action/xeno_action/activable/pounce/rush/rush = get_ability(/datum/action/xeno_action/activable/pounce/rush)
	if(!rush || !rush.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > rush.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE))
		return FALSE
	rush.use_ability(target)
	return TRUE

/// Vampire-strain-only ranged poke (range 2) while still closing - fired only before adjacency, since process_movement()'s own adjacency check above already routes to AI_STATE_ATTACKING (and use_caste_ability()'s Flurry/Headbite) once she's actually next to the target.
/datum/xeno_ai_controller/lurker/proc/attempt_tail_jab(atom/target)
	var/datum/action/xeno_action/activable/tail_jab/jab = get_ability(/datum/action/xeno_action/activable/tail_jab)
	if(!jab || !jab.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > 2)
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	jab.use_ability(target)
	return TRUE

/**
 * Arms a bonus-damage slash before the first hit if it isn't armed already -
 * an opener, not something to keep re-arming mid-fight.
 *
 * Vampire strain: Headbite (execute an unconscious target, big self-heal)
 * and Flurry (cleave, hits/heals off multiple nearby targets) both take
 * priority over Assassinate below, which is removed by the strain anyway
 * (get_ability() already no-ops it for her).
 */
/datum/xeno_ai_controller/lurker/use_caste_ability(mob/living/target)
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot

	if(attempt_headbite(target))
		return TRUE
	if(attempt_flurry(target))
		return TRUE

	var/datum/behavior_delegate/lurker_base/behavior = xeno_pilot.behavior_delegate
	if(istype(behavior) && behavior.next_slash_buffed)
		return FALSE

	var/datum/action/xeno_action/onclick/lurker_assassinate/assassinate = get_ability(/datum/action/xeno_action/onclick/lurker_assassinate)
	if(assassinate && assassinate.action_cooldown_check())
		assassinate.use_ability(xeno_pilot)
		return FALSE // Arms the next swing rather than replacing it - always fall through to the plain melee attack this tick.

	if(prob(AI_LURKER_RETREAT_CHANCE))
		start_tactical_retreat(AI_LURKER_RETREAT_DURATION)
	return FALSE

/// Vampire-strain-only execute - only valid against an unconscious, adjacent target (headbite/use_ability()'s own gate), so this just needs to confirm that before spending the cooldown call.
/datum/xeno_ai_controller/lurker/proc/attempt_headbite(mob/living/target)
	if(!pilot || !target)
		return FALSE
	if(!(HAS_TRAIT(target, TRAIT_KNOCKEDOUT) || target.stat == UNCONSCIOUS))
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	var/datum/action/xeno_action/activable/headbite/headbite = get_ability(/datum/action/xeno_action/activable/headbite)
	if(!headbite || !headbite.action_cooldown_check())
		return FALSE
	headbite.use_ability(target)
	return TRUE

/// Vampire-strain-only forward cleave - fires whenever 2+ valid targets are directly in front of her, same nearby-count-gate spirit as crusher.dm's Stomp check (though Flurry's own 1x3 cone means a plain radius scan isn't a perfect match - close enough to gate a channel-free AoE from firing on a lone target).
/datum/xeno_ai_controller/lurker/proc/attempt_flurry(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/flurry/flurry = get_ability(/datum/action/xeno_action/activable/flurry)
	if(!flurry || !flurry.action_cooldown_check())
		return FALSE
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(2, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	if(nearby_targets < 2)
		return FALSE
	flurry.use_ability(target)
	return TRUE
