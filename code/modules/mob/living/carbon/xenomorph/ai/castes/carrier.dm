/**
 * Carrier AI - pure logistics/support (throws facehuggers/eggs at range,
 * no offensive ability beyond a plain tail_stab per Carrier.dm), MOB_SIZE_BIG
 * and slow off weeds, no vent-crawl. Not built to fight or to run, so the
 * only sensible AI treatment is to disengage sooner than the population
 * default rather than trading blows she has no real tools to win.
 *
 * Proactively throws a stored facehugger at a target while still closing
 * distance (see process_movement()/attempt_hugger_throw()) instead of never
 * using her signature tool at all - has to happen during the approach, not
 * from the usual use_caste_ability() hook, since that only fires once
 * already adjacent and a thrown hugger needs real distance to be worth
 * using over just letting her walk up. Throwing is a real two-step
 * interaction even for a player (empty hand grabs one from storage, a
 * second throw actually launches it) - this plays out over two AI ticks the
 * same way, rather than trying to special-case both steps into one call.
 */
/datum/xeno_ai_controller/carrier

/datum/xeno_ai_controller/carrier/get_flee_threshold()
	return AI_CARRIER_FLEE_HEALTH_PERCENT

/// "Carrier will restock on eggs as well" - checked before falling through to the base patrol() (long patrol/pack cohesion/wander), same priority tier attempt_carry_egg() gets on Drone/Hivelord.
/datum/xeno_ai_controller/carrier/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	manage_egg_generation()
	if(attempt_carry_egg())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// Place Trap (a resin trap hole) was granted and never used - low
	// priority (she's a non-combatant support caste, this is downtime
	// value-add, not combat-critical), same idle-build-roll shape as every
	// other caste's attempt_plant_weeds() roll. Emit Pheromones (also
	// granted, Carrier.dm) needs no wiring here - xeno_ai_controller.dm's
	// shared attempt_combat_pheromones() already fires it generically for
	// any caste that has it, Carrier included.
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_place_trap())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..()

/// Self-turf placement (place_trap/use_ability(), general_powers.dm) - the passed atom arg is unused, a plain self-target call is enough.
/datum/xeno_ai_controller/carrier/proc/attempt_place_trap()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/place_trap/trap = get_ability(/datum/action/xeno_action/onclick/place_trap)
	if(!trap || !trap.action_cooldown_check())
		return FALSE
	trap.use_ability(pilot)
	return TRUE

/**
 * Eggsac-strain-only toggle convention, same shape as hivelord.dm's
 * manage_resin_walker() - Generate Eggs (active_toggle/generate_egg) drains
 * no plasma once eggs_cur reaches eggs_max (its own should_use_plasma()
 * override gates that), so unlike Resin Walker there's no footing condition
 * to reconcile against: just turn it on once and leave it, it's a
 * plasma-free no-op whenever she's already full.
 */
/datum/xeno_ai_controller/carrier/proc/manage_egg_generation()
	if(!pilot)
		return
	var/datum/action/xeno_action/active_toggle/generate_egg/generator = get_ability(/datum/action/xeno_action/active_toggle/generate_egg)
	if(!generator || generator.action_active)
		return
	generator.action_activate()

/datum/xeno_ai_controller/carrier/process_movement()
	if(!pilot || !current_target)
		return
	if(is_valid_target(current_target) && get_dist(pilot, current_target) >= 2)
		attempt_hugger_throw(current_target)
	return ..()

/// See the caste doc comment above for why this has to run during the approach rather than through the normal use_caste_ability() hook.
/datum/xeno_ai_controller/carrier/proc/attempt_hugger_throw(mob/living/target)
	if(!pilot || !ishuman(target))
		return FALSE
	var/mob/living/carbon/xenomorph/carrier/carrier_pilot = pilot
	if(!istype(carrier_pilot) || carrier_pilot.threw_a_hugger)
		return FALSE

	var/mob/living/carbon/human/human_target = target
	if(human_target.stat == DEAD)
		return FALSE

	if(get_dist(pilot, target) > 7) // Too far for a realistic throw - let the normal approach close in first.
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE

	var/datum/action/xeno_action/activable/throw_hugger/throw_ability = get_ability(/datum/action/xeno_action/activable/throw_hugger)
	if(!throw_ability)
		return FALSE

	var/obj/item/clothing/mask/facehugger/held = carrier_pilot.get_active_hand()
	if(!istype(held) && carrier_pilot.huggers_cur <= 0)
		return FALSE // Nothing in hand and nothing left in storage - genuinely nothing to throw.

	pilot.setDir(get_dir(pilot, target))
	throw_ability.use_ability(target) // Grabs one from storage into hand if empty-handed, or throws the one already held - see the doc comment above.
	return TRUE

/// "No offensive ability beyond a plain tail_stab" - true, but nothing was actually using even that; a slightly harder hit than a bare claw once she's cornered into melee.
/datum/xeno_ai_controller/carrier/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)
