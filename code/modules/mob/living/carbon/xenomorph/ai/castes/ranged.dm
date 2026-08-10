/**
 * Base controller for castes that fight from range instead of melee
 * (Spitter now; Boiler/Praetorian/Lurker are natural next additions - see
 * the plan's 2.6 section). Confirmed zero ranged AI existed anywhere to
 * port technique from, so this is new design: maintain distance instead of
 * closing to melee, back off if the target gets too close, and fire the
 * caste's ranged ability instead of attack_alien() once in range.
 *
 * Checks line-of-sight (has_line_of_sight(), xeno_ai_movement.dm) before
 * actually firing - a target at the right distance but behind a wall now
 * gets closed in on instead of plinked at uselessly through it.
 */
/datum/xeno_ai_controller/ranged

/// Concrete subtypes override this to return their ranged ability instance (or null if the pilot doesn't have it for some reason - triggers a melee/re-approach fallback in process_attack()).
/datum/xeno_ai_controller/ranged/proc/get_ranged_ability()
	return null

/**
 * Overrides the base melee movement policy entirely. Two-phase, matching
 * boiler.dm's already-correct pattern: hold/retreat to AI_XENO_RANGED_HIDE_DISTANCE
 * whenever every ranged ability is on cooldown, only closing back in to the
 * much tighter AI_XENO_RANGED_PREFERRED_DISTANCE kiting band once something's
 * actually ready to fire.
 *
 * "Sentinel/Spitter get killed a lot, too predictable, walking in the same 3
 * tiles over and over" - the old version held the same close band
 * unconditionally regardless of ability state, so a Sentinel with her one
 * long-cooldown spit on cooldown just sat at melee-adjacent-plus-five the
 * entire time instead of actually falling back, getting walked down and
 * finished off while she had nothing to answer with.
 */
/datum/xeno_ai_controller/ranged/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	var/dist = get_dist(pilot, current_target)

	var/datum/action/xeno_action/ability = get_ranged_ability()
	var/ability_ready = ability && ability.action_cooldown_check()
	if(!ability_ready)
		if(dist < AI_XENO_RANGED_HIDE_DISTANCE)
			var/turf/defensible = get_or_pick_cover_turf(current_target) || find_defensible_turf()
			if(defensible && get_dist(pilot, defensible) > 0 && cardinal_step_towards(defensible, avoid_mobs = TRUE))
				return
			var/away_dir = get_dir(current_target, pilot)
			if(!ai_step(away_dir))
				navigate_around(current_target)
			return
		return // Already far enough out - sit tight and let the cooldown run.

	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE, seek_cover = TRUE)

/**
 * Fires the ranged ability once in band. Spitter's spit is a 60-second
 * cooldown - with no fallback, the AI would just stand at range doing
 * nothing for roughly 59 of every 60 seconds mid-fight (use_ability()'s own
 * cooldown check silently no-ops), which is why get_ranged_ability() falls
 * back to Spray Acid (a much shorter cooldown) whenever the big spit isn't
 * up. Adjacent is treated as "cornered" (something closed the distance
 * despite process_movement()'s own retreat/kiting) rather than a deliberate
 * approach - fights back instead of standing there, but no longer walks
 * toward the target on its own to get there; process_movement() above owns
 * all positioning now; this proc only ever fires or fights back in place.
 */
/datum/xeno_ai_controller/ranged/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there and dying.
		execute_attack(current_target)
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && ability.action_cooldown_check() && has_line_of_sight(current_target))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(current_target)
	ai_state = AI_STATE_APPROACHING // Always re-evaluate positioning next tick, win or lose - process_movement() above decides hide vs. hold vs. close in.

/**
 * Spitter - "doesn't have an AI fight preset, they just death charge" was a
 * real bug, not a design gap: this queried /xeno_spit/spitter, a cosmetic
 * subtype Spitter.dm's own base_actions never actually grants (it grants
 * the plain /xeno_spit base type instead) - get_ability()'s locate() only
 * matches a held instance that IS the queried type or a stricter subtype of
 * it, never the other way around, so this always returned null and every
 * Spitter fell straight into ranged.dm's melee fallback, permanently. Fixed
 * to query the type actually granted. That ability still has a genuine 60s
 * cooldown though (general_abilities.dm), so on its own she'd still spend
 * most of a fight in the melee fallback - falls back to Spray Acid (8s
 * cooldown, a real ranged line attack) instead of closing to melee whenever
 * the big spit isn't up, so she stays a ranged threat continuously rather
 * than only once a minute.
 */
/datum/xeno_ai_controller/ranged/spitter

/// Ranged glass cannon, no armor investment - should disengage sooner than a melee caste rather than sharing the population default.
/datum/xeno_ai_controller/ranged/spitter/get_flee_threshold()
	return AI_SPITTER_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/ranged/spitter/get_ranged_ability()
	var/datum/action/xeno_action/activable/xeno_spit/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit)
	if(spit && spit.action_cooldown_check())
		return spit
	return get_ability(/datum/action/xeno_action/activable/spray_acid/spitter)

/**
 * Charge Spit was granted but never called - its own file literally
 * comments its armor/speed buff as "so they can close the distance," the
 * exact gap-close niche every other caste's process_movement() already
 * fills with a dash. It's a one-shot self-buff (not a toggle) that also
 * empowers her next spit, so it's tried once while still outside her
 * preferred kiting band, before falling through to the base ranged
 * movement policy.
 */
/datum/xeno_ai_controller/ranged/spitter/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return
	attempt_charge_spit()
	return ..()

/**
 * Her base_actions grants tail_stab/spitter specifically (a subtype that
 * adds a molecular acid DoT on hit, Spitter.dm), not the plain base type -
 * the same "granted but never called" gap as Charge Spit above meant the
 * cornered case fell straight to plain melee unconditionally.
 * get_ability()'s subtype-matching (see attempt_tail_stab()'s own doc
 * comment) finds the /spitter variant fine even though the shared helper
 * only ever queries the plain base type.
 */
/datum/xeno_ai_controller/ranged/spitter/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)

/// Only worth firing while still closing - the speed buff is wasted once she's already holding her kiting band.
/datum/xeno_ai_controller/ranged/spitter/proc/attempt_charge_spit()
	if(!pilot || !current_target)
		return FALSE
	var/datum/action/xeno_action/onclick/charge_spit/charge = get_ability(/datum/action/xeno_action/onclick/charge_spit)
	if(!charge || charge.buffs_active || !charge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, current_target) <= AI_XENO_RANGED_PREFERRED_DISTANCE)
		return FALSE
	charge.use_ability(pilot)
	return TRUE
