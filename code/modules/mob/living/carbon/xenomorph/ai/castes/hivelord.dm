/**
 * Hivelord AI - a dedicated fast/cheap builder (build_time_mult = 0.5x per
 * Hivelord.dm), same build-duty pattern as Drone (see drone_worker.dm) just
 * at her own higher build chance to match how much more efficient she is
 * at it. Combat/searching/returning is entirely inherited from the base
 * controller, same reasoning as Drone - "aid and assist in attacking", not
 * a builder that ignores threats.
 *
 * Toggles Resin Walker (a continuous plasma-draining speed buff) on while
 * standing on her own hive's weeds and off the moment she isn't - the
 * ability's own life_tick() already auto-disables it outright the instant
 * plasma actually runs dry (xeno_action.dm's active_toggle/life_tick()), so
 * there was never really a "stranded out of plasma" risk to manage here;
 * left on during an approach once a target's spotted is a feature, not a
 * risk - getting into the fight faster.
 */
/datum/xeno_ai_controller/hivelord
	/// Rotational direction (90 or -90) this Hivelord always sidesteps toward - same reasoning as ravager.dm's identical var.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - see the reactive-dodge check there, same pattern as ravager.dm.
	var/last_known_health

/datum/xeno_ai_controller/hivelord/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/// Same "builder pressed into combat" reasoning as Drone's own override - she never got one before Phase 3.
/datum/xeno_ai_controller/hivelord/get_flee_threshold()
	return AI_HIVELORD_FLEE_HEALTH_PERCENT

/datum/xeno_ai_controller/hivelord/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	manage_resin_walker()
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// "All they do is plant eggs, never building the hive and building
	// defenses" - building/weeding is the primary job now, checked first;
	// egg-carrying is a lower-priority errand that only competes for a slot
	// when there's nothing to build, and a carry already in progress always
	// finishes regardless (is_carrying_egg() bypasses the roll below).
	if(prob(AI_DEFENSE_BUILD_CHANCE) && attempt_build_defense())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_HIVELORD_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// Resin-Whisperer-strain-only - attempt_build_defense()/attempt_plant_weeds()
	// above both already no-op for her (her strain removes the actions they
	// use), so without this she'd have no build behavior at all.
	if(prob(AI_HIVELORD_BUILD_CHANCE) && attempt_coerce_resin())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if((is_carrying_egg() || prob(AI_XENO_EGG_CARRY_CHANCE)) && attempt_carry_egg())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// Keeps Resin Walker on precisely while standing on own-hive weeds, off otherwise - see the caste doc comment above for why this doesn't need to worry about stranding her out of plasma.
/datum/xeno_ai_controller/hivelord/proc/manage_resin_walker()
	if(!pilot)
		return
	var/datum/action/xeno_action/active_toggle/toggle_speed/walker = get_ability(/datum/action/xeno_action/active_toggle/toggle_speed)
	if(!walker)
		return
	var/obj/effect/alien/weeds/weeds = locate(/obj/effect/alien/weeds) in get_turf(pilot)
	var/on_own_weeds = weeds && weeds.linked_hive.hivenumber == pilot.hivenumber
	if(on_own_weeds != walker.action_active)
		walker.action_activate()

/// A builder first, but "aid and assist in attacking" means an actual hit when it comes to that, not a bare claw.
/datum/xeno_ai_controller/hivelord/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)

/// Hivelord had no post-attack repositioning at all - same damage-reactive-plus-baseline-roll shape as ravager.dm's own circle-step. Secondary priority (she's a builder first), but cheap and consistent to add.
/datum/xeno_ai_controller/hivelord/process_attack()
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

/**
 * "Weeds heal, slow enemies, speed up xenos" (User decision #2) - a real
 * tactical move mid-fight for Hivelord too, not just idle economy the way
 * patrol()'s build roll above already is. Side effect only, checked before
 * falling through to the inherited chase/attack movement
 * (xeno_ai_movement.dm's process_movement()) - attempt_plant_weeds()'s own
 * checks (weedable ground, hive ownership) already handle a bad tile
 * silently, same pattern queen.dm's identical addition uses.
 */
/datum/xeno_ai_controller/hivelord/process_movement()
	if(current_target && prob(AI_XENO_COMBAT_WEED_CHANCE))
		attempt_plant_weeds()
	return ..()

/**
 * "On entering a flee/tactical-retreat state" (§1.7's gap-close/escape
 * theme) - tries the speed buff once before falling through to the normal
 * walk home, same shape as crusher.dm's attempt_tumble_retreat().
 */
/datum/xeno_ai_controller/hivelord/return_to_anchor()
	attempt_resin_walker_retreat()
	return ..()

/**
 * manage_resin_walker() (patrol()-driven) already keeps Resin Walker on any
 * time she's standing on own-hive weeds, but a flee is exactly the moment
 * she's likely NOT on weeds - the fight came to her, not the other way
 * round - and speed matters most right then. Forces it on for the walk home
 * regardless of footing; life_tick() (xeno_action.dm) already auto-disables
 * it the instant plasma actually runs dry, so there's nothing else to guard
 * here. Doesn't force it back off on arrival - the next patrol() tick's
 * manage_resin_walker() call reconciles it against her actual footing same
 * as always.
 */
/datum/xeno_ai_controller/hivelord/proc/attempt_resin_walker_retreat()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/active_toggle/toggle_speed/walker = get_ability(/datum/action/xeno_action/active_toggle/toggle_speed)
	if(!walker || walker.action_active)
		return FALSE
	walker.action_activate()
	return TRUE

/**
 * Resin-Whisperer-strain-only remote build - plant_weeds/secrete_resin
 * (her normal build tools) are both removed by the strain, so Coerce Resin
 * is her only way to build at all. Targets her own turf for a safe,
 * always-in-range/always-in-line-of-sight build (can_remote_build(),
 * resin_whisperer.dm, only requires standing on weeds - the target atom
 * itself can be anywhere in view(10)) rather than picking a distant point -
 * a real "build somewhere useful at range" placement policy is a
 * reasonable future refinement, not attempted here.
 */
/datum/xeno_ai_controller/hivelord/proc/attempt_coerce_resin()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/secrete_resin/remote/coerce = get_ability(/datum/action/xeno_action/activable/secrete_resin/remote)
	if(!coerce || !coerce.action_cooldown_check())
		return FALSE
	var/turf/own_turf = get_turf(pilot)
	if(!own_turf)
		return FALSE
	coerce.use_ability(own_turf, list()) // use_ability()'s mods param is read unconditionally (mods["click_catcher"], resin_whisperer.dm) - an empty list keeps it a safe, valid mods.
	return TRUE
