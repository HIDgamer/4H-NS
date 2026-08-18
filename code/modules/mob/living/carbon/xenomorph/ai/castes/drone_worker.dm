/**
 * Drone AI - extends the shared melee/patrol controller with a build duty
 * cycle: instead of just wandering while idle, a Drone periodically expands
 * the hive's weed coverage (see xeno_ai_controller.dm's attempt_plant_weeds(),
 * shared with the Queen's own patrol()). Combat/searching/returning behavior
 * is entirely inherited unchanged (see patrol() below - that's the only
 * override), so a target wandering into range mid-build still gets chased
 * and fought normally - "aid and assist in attacking" per the user, not a
 * builder that ignores threats.
 *
 * Also occasionally builds a real defensive wall line at the hive perimeter
 * (attempt_build_fort_line(), xeno_ai_controller.dm) on top of plain
 * weeding - a repeating wall-run/paired-door-gate pattern matching the real
 * player convention, not just a single random tile/type.
 */
/datum/xeno_ai_controller/drone_worker

/// "Drones... dive to their deaths" - she's a builder pressed into a fight, not a caste actually built to brawl, so she should break off sooner than the population default.
/datum/xeno_ai_controller/drone_worker/get_flee_threshold()
	return AI_DRONE_FLEE_HEALTH_PERCENT

/// "They should mainly do support, meaning they almost never idle... no rest, castle after castle" - a builder's whole purpose is churning out hive infrastructure; voluntary idle resting/dormancy is explicitly not part of that. should_flee()/return_to_anchor()'s own combat-driven disengage-and-recover is untouched - this only removes the "stand around/lie down because there's nothing better to do" option.
/datum/xeno_ai_controller/drone_worker/can_rest()
	return FALSE

/// "Castle after castle after castle" - a fresh fort line starts almost immediately once the last one ends, instead of the shared conservative default.
/datum/xeno_ai_controller/drone_worker/get_fort_line_start_chance()
	return AI_BUILDER_FORT_LINE_START_CHANCE

/**
 * Only override needed: patrol() is called from the base tick() at exactly
 * the point where the pilot is confirmed idle with no target - rolling build
 * attempts in here instead of duplicating the whole state machine. Checks
 * for a Queen hive-alert first, same priority order as the base controller -
 * a call to arms takes precedence over routine building.
 */
/datum/xeno_ai_controller/drone_worker/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	// Healer-strain-only, checked before any building: heal a hurt ally
	// (non-lethal) takes priority over Sacrifice (which kills the caster) -
	// both no-op instantly via get_ability() for a non-Healer.
	if(attempt_apply_salve())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(attempt_sacrifice())
		return
	if(attempt_help_queen_build_core())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// "All they do is plant eggs, never building the hive and building
	// defenses" - building/weeding is the primary job now, checked first;
	// egg-carrying is a lower-priority errand that only competes for a slot
	// when there's nothing to build, and a carry already in progress always
	// finishes regardless (is_carrying_egg() bypasses the roll below).
	if(attempt_build_fort_line())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_HUMAN_CAP_BUILD_CHANCE) && attempt_build_human_cap())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// Gardener/Healer-strain-shared (fruit) and Gardener-only (surge/change) -
	// all no-op instantly for a plain Drone via get_ability().
	if(prob(AI_DRONE_BUILD_CHANCE) && attempt_plant_fruit())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	if(attempt_resin_surge())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	attempt_change_fruit() // Side effect only (plain var-set) - never blocks anything below.
	if((is_carrying_egg() || prob(AI_XENO_EGG_CARRY_CHANCE)) && attempt_carry_egg())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// A builder first, but "aid and assist in attacking" means an actual hit when it comes to that, not a bare claw.
/datum/xeno_ai_controller/drone_worker/use_caste_ability(mob/living/target)
	return attempt_tail_stab(target)

/**
 * Healer-strain-only. find_nearby_ally_xeno() (xeno_ai_controller.dm §2.2)
 * picks the most-hurt nearby ally; Apply Salve's own use_ability() chain
 * (xeno_apply_salve(), healer.dm) already re-checks range/hive/plasma/dead
 * internally, so this only needs to find a plausible candidate and let the
 * ability reject a bad one silently.
 */
/datum/xeno_ai_controller/drone_worker/proc/attempt_apply_salve()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/apply_salve/salve = get_ability(/datum/action/xeno_action/activable/apply_salve)
	if(!salve || !salve.action_cooldown_check())
		return FALSE
	var/mob/living/carbon/xenomorph/ally = find_nearby_ally_xeno(salve.max_range)
	if(!ally)
		return FALSE
	salve.use_ability(ally)
	return TRUE

/**
 * Healer-strain-only, deliberately conservative - Sacrifice kills the
 * caster outright (healer_sacrifice/use_ability(), healer.dm), and an
 * AI-piloted Healer has no client to earn the free-respawn payoff a player
 * would get for banking enough prior heals, so there's no upside for her
 * beyond the heal itself. Only even considered when BOTH the ally and the
 * Healer herself are already critically hurt - a normal fight should always
 * reach for Apply Salve first (checked earlier in patrol()).
 */
/datum/xeno_ai_controller/drone_worker/proc/attempt_sacrifice()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= AI_HEALER_SACRIFICE_HEALTH_PERCENT)
		return FALSE
	var/datum/action/xeno_action/activable/healer_sacrifice/sacrifice = get_ability(/datum/action/xeno_action/activable/healer_sacrifice)
	if(!sacrifice || !sacrifice.action_cooldown_check())
		return FALSE
	var/mob/living/carbon/xenomorph/ally = find_nearby_ally_xeno(sacrifice.max_range)
	if(!ally || !ally.maxHealth || (ally.health / ally.maxHealth) >= AI_HEALER_SACRIFICE_HEALTH_PERCENT)
		return FALSE
	sacrifice.use_ability(ally)
	return TRUE

/// Gardener/Healer-strain-shared - Plant Resin Fruit (onclick/plant_resin_fruit, both strains grant a variant of the same base type) always targets her own turf regardless of the passed atom (gardener.dm), so a plain self-target call is enough.
/datum/xeno_ai_controller/drone_worker/proc/attempt_plant_fruit()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/plant_resin_fruit/fruit_ability = get_ability(/datum/action/xeno_action/onclick/plant_resin_fruit)
	if(!fruit_ability || !fruit_ability.action_cooldown_check())
		return FALSE
	fruit_ability.use_ability(pilot)
	return TRUE

/**
 * Gardener-strain-only. Resin Surge branches on what's actually at the
 * target (wall/door reinforcement, fruit growth speed-up, or a fresh
 * unstable wall on bare weeds - gardener.dm's use_ability()) - prefers an
 * immature fruit nearby (speeds up something she's already invested health
 * in) over just reinforcing her own standing turf.
 */
/datum/xeno_ai_controller/drone_worker/proc/attempt_resin_surge()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/resin_surge/surge = get_ability(/datum/action/xeno_action/activable/resin_surge)
	if(!surge || !surge.action_cooldown_check())
		return FALSE
	// use_ability(atom/target_atom, mods) reads mods["click_catcher"]
	// unconditionally, so an empty list is passed as a safe, valid mods -
	// "click_catcher" is just never present, no different from how a real
	// player's click never sets it.
	for(var/obj/effect/alien/resin/fruit/fruit in range(surge.max_range, pilot))
		if(fruit.hivenumber == pilot.hivenumber && !fruit.mature)
			surge.use_ability(fruit, list())
			return TRUE
	var/turf/own_turf = get_turf(pilot)
	var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in own_turf
	if(own_weeds && own_weeds.linked_hive.hivenumber == pilot.hivenumber)
		surge.use_ability(own_turf, list())
		return TRUE
	return FALSE

/// Gardener-strain-only. Change Fruit's use_ability() (gardener.dm) just opens a tgui picker - the actual selection is a plain var (xeno.selected_fruit), so this bypasses the UI entirely rather than trying to drive it.
/datum/xeno_ai_controller/drone_worker/proc/attempt_change_fruit()
	if(!pilot || !length(pilot.available_fruits))
		return FALSE
	if(!get_ability(/datum/action/xeno_action/onclick/change_fruit))
		return FALSE
	pilot.selected_fruit = pick(pilot.available_fruits)
	return TRUE

/**
 * "Weeds heal, slow enemies, speed up xenos" (User decision #2) - a real
 * tactical move mid-fight for Drone too, not just idle economy the way
 * patrol()'s build roll above already is. Side effect only, checked before
 * falling through to the inherited chase/attack movement
 * (xeno_ai_movement.dm's process_movement()) - attempt_plant_weeds()'s own
 * checks (weedable ground, hive ownership) already handle a bad tile
 * silently, same pattern queen.dm's identical addition uses.
 */
/datum/xeno_ai_controller/drone_worker/process_movement()
	if(current_target && prob(get_combat_weed_chance()))
		attempt_plant_weeds()
	return ..()
