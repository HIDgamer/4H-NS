/**
 * Predalien AI - "could use a face lift in the combat department too." The
 * old AI only ever threw Feral Smash and nothing else, despite a real kit
 * of five offensive/support actions (Predalien.dm's base_actions):
 *
 * - Feral Rush (self speed/armor buff, no target) - popped once at the
 *   start of an engagement rather than never used at all.
 * - Feral Smash (grab-lunge-slam, works from range same as Warrior's
 *   Lunge) - now fired as a gap-closer while still approaching, on top of
 *   its existing use as a hard-hitting finisher once adjacent.
 * - Eviscerate/Devastate (feralfrenzy, single-target by default per
 *   toggle_gut_targeting's initial value) - the actual biggest finisher in
 *   the kit, immobilizes both her and the target for a windup then deals
 *   heavy damage; preferred over a plain Feral Smash reuse once adjacent.
 * - Predalien Roar (AoE debuff on nearby humans + a stacking buff for
 *   nearby same-hive xenos) - fired opportunistically on engagement, cheap
 *   value that cost nothing to add.
 * - Tail Stab - the plain melee fallback once everything else is on
 *   cooldown, instead of a bare claw swing.
 */
/datum/xeno_ai_controller/predalien
	/// Rotational direction (90 or -90) this Predalien always sidesteps toward - same reasoning as ravager.dm's identical var.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - see the reactive-dodge check there, same pattern as ravager.dm.
	var/last_known_health

/datum/xeno_ai_controller/predalien/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/// Eviscerate/Devastate (feralfrenzy, predalien_powers.dm) "immobilizes both her and the target for a windup" per this file's own header - a real gap missed until now, no override existed at all despite that already being documented.
/datum/xeno_ai_controller/predalien/can_act_while_immobilized()
	if(..())
		return TRUE
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Eviscerate")) || HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Devastate"))

/datum/xeno_ai_controller/predalien/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	attempt_feral_rush()
	attempt_roar()

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	var/datum/action/xeno_action/activable/feral_smash/smash = get_ability(/datum/action/xeno_action/activable/feral_smash)
	if(smash && smash.action_cooldown_check() && get_dist(pilot, current_target) <= smash.grab_range && has_line_of_sight(current_target, physical_path = TRUE))
		smash.use_ability(current_target)
		return

	return ..()

/// Self-buff, no target needed - fires once per cooldown rather than never at all.
/datum/xeno_ai_controller/predalien/proc/attempt_feral_rush()
	var/datum/action/xeno_action/onclick/feralrush/rush = get_ability(/datum/action/xeno_action/onclick/feralrush)
	if(!rush || !rush.action_cooldown_check())
		return FALSE
	rush.use_ability(pilot)
	return TRUE

/// AoE debuff/support - opportunistic, no real downside to firing it the moment it's off cooldown while a fight's on.
/datum/xeno_ai_controller/predalien/proc/attempt_roar()
	var/datum/action/xeno_action/onclick/predalien_roar/roar = get_ability(/datum/action/xeno_action/onclick/predalien_roar)
	if(!roar || !roar.action_cooldown_check())
		return FALSE
	roar.use_ability(pilot)
	return TRUE

/**
 * **Safety fix, not a new-behavior addition**: Eviscerate/Devastate
 * (feralfrenzy) roots her (`TRAIT_IMMOBILIZED`) for the entire windup with
 * no check on how many hostiles are actually nearby - firing it into a
 * clustered group self-traps her in the middle of a marine squad instead of
 * landing the intended lone-target execute. Gated behind a nearby-hostile
 * scan (same shape as crusher.dm's Stomp check, inverted: only fire when
 * the count is low enough to be safe) before ever calling it.
 *
 * `attempt_toggle_gut_targeting()` reuses the same scan to flip to AoE
 * targeting when multiple targets are actually clustered nearby (a real use
 * case the base kit never took advantage of), single-target otherwise -
 * independent of the safety gate above, which stays conservative regardless
 * of targeting mode.
 */
/datum/xeno_ai_controller/predalien/use_caste_ability(mob/living/target)
	var/nearby_targets = count_nearby_targets(pilot, 1)
	attempt_toggle_gut_targeting(nearby_targets)

	var/datum/action/xeno_action/activable/feralfrenzy/frenzy = get_ability(/datum/action/xeno_action/activable/feralfrenzy)
	if(frenzy && frenzy.action_cooldown_check() && nearby_targets <= AI_PREDALIEN_FRENZY_MAX_TARGETS)
		frenzy.use_ability(target)
		return TRUE

	var/datum/action/xeno_action/activable/feral_smash/smash = get_ability(/datum/action/xeno_action/activable/feral_smash)
	if(smash && smash.action_cooldown_check())
		smash.use_ability(target)
		return TRUE

	return attempt_tail_stab(target)

/// Small local scan, capped at 3 (nothing here needs an exact count beyond "more than the safety threshold").
/datum/xeno_ai_controller/predalien/proc/count_nearby_targets(atom/center, radius)
	var/count = 0
	for(var/mob/living/carbon/nearby in orange(radius, center))
		if(!is_valid_target(nearby))
			continue
		count++
		if(count >= 3)
			break
	return count

/// Flips to AoE gutting when multiple targets are clustered, single-target otherwise - a real use case the base kit never took advantage of.
/datum/xeno_ai_controller/predalien/proc/attempt_toggle_gut_targeting(nearby_targets)
	var/datum/action/xeno_action/activable/feralfrenzy/frenzy = get_ability(/datum/action/xeno_action/activable/feralfrenzy)
	if(!frenzy)
		return FALSE
	var/desired_mode = (nearby_targets >= 2) ? AOETARGETGUT : SINGLETARGETGUT
	if(frenzy.targeting == desired_mode)
		return FALSE
	var/datum/action/xeno_action/onclick/toggle_gut_targeting/toggle = get_ability(/datum/action/xeno_action/onclick/toggle_gut_targeting)
	if(!toggle || !toggle.action_cooldown_check())
		return FALSE
	toggle.use_ability(pilot)
	return TRUE

/// Predalien had no post-attack repositioning at all - she's a front-line brawler like Ravager, same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step.
/datum/xeno_ai_controller/predalien/process_attack()
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
