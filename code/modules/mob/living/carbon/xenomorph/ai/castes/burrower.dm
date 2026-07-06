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
	return ..() // Falls through to the base patrol() (long patrol/pack cohesion/ambush hide/wander) instead of only ever plain wander().

/// Self-turf placement (place_trap/use_ability(), general_powers.dm) - the passed atom arg is unused, a plain self-target call is enough. Already refuses to fire while burrowed (the ability's own check), so no extra guard needed here.
/datum/xeno_ai_controller/burrower/proc/attempt_place_trap()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/place_trap/trap = get_ability(/datum/action/xeno_action/onclick/place_trap)
	if(!trap || !trap.action_cooldown_check())
		return FALSE
	trap.use_ability(pilot)
	return TRUE

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
			var/datum/action/xeno_action/activable/burrow/burrow_ability = get_ability(/datum/action/xeno_action/activable/burrow)
			burrow_ability?.use_ability(current_target) // Tunnels onto the target's own tile - do_tunnel()'s burrow_off() weakens anything standing there when she surfaces.
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
