/**
 * Sentinel AI - "modify the sentinel and queen AI to only use ranged, and
 * to use melee if unable to escape or enemies are too close." Overrides
 * process_attack() so melee is only ever the explicit cornered case, never
 * incidental, and delegates actual positioning to the shared
 * maintain_kiting_distance() helper (xeno_ai_movement.dm) so she actually
 * keeps her distance instead of holding still once in range. Still arms
 * Paralyzing Slash (primes the next melee swing to knock down) whenever
 * it's off cooldown, for whenever that cornered case actually happens.
 */
/datum/xeno_ai_controller/ranged/sentinel

/// Ranged glass cannon, no armor investment - should disengage sooner than a melee caste rather than sharing the population default.
/datum/xeno_ai_controller/ranged/sentinel/get_flee_threshold()
	return AI_SENTINEL_FLEE_HEALTH_PERCENT

/**
 * "Different types of spit abilities, sentinel only uses the neuro one" -
 * her base_actions actually carries three ranged tools (Slowing Spit, 2s CD;
 * Scattered Spit, 6s CD; Corrosive Acid, a much longer CD) but this only ever
 * looked at Slowing Spit, leaving the other two to sit unused entirely.
 * Same fallback-chain pattern as Boiler/Spitter: try the fastest one first,
 * fall through to whichever else is actually off cooldown.
 */
/datum/xeno_ai_controller/ranged/sentinel/get_ranged_ability()
	var/datum/action/xeno_action/activable/slowing_spit/spit = get_ability(/datum/action/xeno_action/activable/slowing_spit)
	if(spit && spit.action_cooldown_check())
		return spit
	var/datum/action/xeno_action/activable/scattered_spit/scatter = get_ability(/datum/action/xeno_action/activable/scattered_spit)
	if(scatter && scatter.action_cooldown_check())
		return scatter
	return get_ability(/datum/action/xeno_action/activable/corrosive_acid/weak)

/datum/xeno_ai_controller/ranged/sentinel/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there.
		execute_attack(current_target)
		if(stale_attack_ticks >= AI_PRIORITY_STALE_ATTACK_GIVEUP) // This override replaces the base process_attack() entirely instead of calling ..() - without this she'd claw an undamageable cornering target forever instead of giving up like every other caste does.
			drop_target()
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && ability.action_cooldown_check() && has_line_of_sight(current_target, allow_partial_cover = TRUE))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(current_target)
	ai_state = AI_STATE_APPROACHING

/**
 * "Too predictable, walking in the same 3 tiles over and over" - the old
 * version held the same tight kiting band regardless of whether Slowing
 * Spit was actually up, so for most of its cooldown she just sat in melee-
 * adjacent-plus-five getting shot with nothing to answer with. Now matches
 * boiler.dm's already-correct pattern: falls back to AI_XENO_RANGED_HIDE_DISTANCE
 * while the ability's on cooldown, only holding the tight band once it's
 * actually ready to fire again. should_hold_and_fight() (ranged.dm) is
 * checked first though - a target already beaten or genuinely alone isn't
 * worth spending a hide cycle on, cover discipline is for real threats.
 */
/datum/xeno_ai_controller/ranged/sentinel/process_movement()
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
		if(should_hold_and_fight(current_target))
			travel_to(current_target, TRAVEL_FLAG_FORCE_OBSTACLES) // Already winning this fight - close in and finish it instead of wasting the cooldown hiding.
			return
		if(dist < AI_XENO_RANGED_HIDE_DISTANCE)
			var/turf/defensible = get_or_pick_cover_turf(current_target) || find_defensible_turf()
			if(defensible && get_dist(pilot, defensible) > 0 && cardinal_step_towards(defensible, avoid_mobs = TRUE))
				return
			var/away_dir = get_dir(current_target, pilot)
			if(!ai_step(away_dir))
				navigate_around(current_target)
			return
		return

	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE, seek_cover = TRUE)

/**
 * xeno_ai_attack.dm's attempt_tail_stab() doc comment already lists Sentinel
 * among its users, but this always returned FALSE unconditionally, so the
 * cornered case (the only time this caste ever melees at all) fell straight
 * to plain melee every time. Tail Stab has a genuine 2-tile stab_range
 * (general_abilities.dm) - worth trying before plain melee even while
 * cornered, not just a wasted ability. Paralyzing Slash is still armed
 * unconditionally first regardless of whether Tail Stab lands this tick - it
 * buffs whichever swing actually connects next, plain or stab.
 */
/datum/xeno_ai_controller/ranged/sentinel/use_caste_ability(mob/living/target)
	var/datum/action/xeno_action/onclick/paralyzing_slash/buff = get_ability(/datum/action/xeno_action/onclick/paralyzing_slash)
	if(buff && buff.action_cooldown_check())
		buff.use_ability(pilot)
	return attempt_tail_stab(target)
