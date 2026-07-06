/**
 * Ravager AI - the hive's mobile bruiser: no innate dodge/evasion actually
 * exists on the base caste (evasion = XENO_EVASION_NONE, confirmed against
 * Xenomorph.dm's recalculate_evasion() and projectile.dm's hit-chance
 * calc), so "nimble and good at dodging" per the user's original design
 * is built here as a behavior instead of a stat: a Ravager sidesteps to a
 * flanking tile after most attacks rather than trading blows standing
 * still like every other melee caste, and prefers its multi-target
 * abilities over a plain swing whenever a fight is worth escalating.
 * Patrol/search behavior is entirely inherited from the base controller.
 *
 * - While closing on a target still out of melee range, fires Charge to
 *   dash in instead of walking the whole distance - same reasoning as
 *   crusher.dm, just a shorter-range dash (Ravager's Charge distance is
 *   5, versus the Crusher's 9).
 * - Sweeps with Scissor Cut (a frontal line attack reaching several tiles
 *   ahead) instead of a plain melee swing whenever more than one valid
 *   target is nearby, so a Ravager fighting a cluster hits several of
 *   them in one motion rather than only the one it's facing.
 * - Arms Empower when several hostiles are nearby at once (a real group
 *   fight, e.g. an LZ siege) rather than every engagement - Empower's
 *   payoff scales with how many enemies are close when it resolves, so
 *   using it in a 1-on-1 would waste most of its value. Once armed, its
 *   own built-in timeout auto-resolves it a few seconds later (see
 *   empower/timeout() in Ravager.dm) - the AI doesn't need to remember to
 *   fire it a second time itself.
 * - After landing an attack, has a chance to sidestep to a flanking tile
 *   instead of standing in place - a Ravager should look like it's
 *   circling its prey, not slugging it out toe-to-toe. Always circles the
 *   same rotational direction (picked once, see circle_dir) rather than
 *   re-rolling left-vs-right each time - randomizing the side every attack
 *   produced a visible left-right-left wobble ("walks in triangles")
 *   instead of an actual circling motion.
 *
 * Repositioning isn't just a flat probability roll - see process_attack():
 * taking damage since her own last attack forces a reposition outright (a
 * real reactive dodge, "I just got hit, circle now") on top of the base
 * chance the rest of the time, so getting shot actually makes her harder to
 * pin down instead of only ever moving on an unrelated random tick.
 */
/datum/xeno_ai_controller/ravager
	/// Rotational direction (90 or -90, relative to the direction facing the target) this Ravager always sidesteps toward - picked once so its circling reads as one consistent motion instead of a random left-right wobble.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - see the reactive-dodge check there.
	var/last_known_health

/datum/xeno_ai_controller/ravager/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/**
 * "Using a few abilities would send the casts into daydreaming and doing
 * nothing... one or two ability uses makes the AI stop in its tracks" -
 * Berserker's Eviscerate (berserker.dm) ADD_TRAITs TRAIT_IMMOBILIZED on
 * herself for its windup, same as Defender's Fortify/Burrower's Burrow -
 * without this override the base tick()'s generic immobilize freeze check
 * skipped ALL AI logic (movement, retreating, everything) for the entire
 * windup, every single time she cast it. HAS_TRAIT_FROM_ONLY (not a bare
 * HAS_TRAIT check) matters here - TRAIT_IMMOBILIZED isn't exclusively
 * self-inflicted (e.g. TRAIT_KNOCKEDOUT from a marine-landed stun forces it
 * too, living.dm), so this only lets her keep acting when Eviscerate is the
 * *only* thing holding the trait, not when a real hostile stun is stacked
 * on top of it.
 */
/datum/xeno_ai_controller/ravager/can_act_while_immobilized()
	if(..())
		return TRUE
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Eviscerate"))

/**
 * "Lunge in and out of combat once too low on health to heal and relax" -
 * the out-and-heal half already works (should_flee() -> flee -> rest/fruit
 * on weeds), but nothing ever brought her BACK. Once recovered past the
 * re-engage threshold, she heads for where the fight was (last_threat_turf,
 * recorded by the flee transition) instead of idling at anchor forever -
 * the normal target scan re-acquires whatever's still there on arrival.
 */
/datum/xeno_ai_controller/ravager/patrol()
	if(last_threat_turf && pilot?.maxHealth && (pilot.health / pilot.maxHealth) >= AI_RAVAGER_REENGAGE_HEALTH_PERCENT)
		if(get_dist(pilot, last_threat_turf) > 2)
			idle_activity = IDLE_ACTIVITY_ALERT
			travel_to(last_threat_turf, TRAVEL_FLAG_FORCE_OBSTACLES)
			return
		last_threat_turf = null // Arrived and nothing re-acquired yet - back to normal patrol.
	return ..()

/**
 * Same duplication tradeoff as crusher.dm - the "close in" trigger
 * condition (attempt a dash first) differs enough from the base melee
 * approach that this is a full override rather than a shared helper.
 */
/datum/xeno_ai_controller/ravager/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	// "Ravagers are pretty aggressive and should behave just like
	// Praetorian" - retreating in combat instead of only at low health.
	// Takes priority over the plain post-attack flank step below: circling
	// stays adjacent, this is a real disengage-and-reset.
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

	if(attempt_charge(current_target))
		return

	attempt_apprehend() // Berserker-only self-buff opener, side effect only - never blocks the fallthrough below.

	if(attempt_rav_spikes(current_target))
		return

	return ..()

/// Fires Charge at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/ravager/proc/attempt_charge(atom/target)
	var/datum/action/xeno_action/activable/pounce/charge/charge = get_ability(/datum/action/xeno_action/activable/pounce/charge)
	if(!charge || !charge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > charge.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A charge is a physical dash - tables/fences/barricades block it same as a wall would, not just line-of-sight.
		return FALSE
	charge.use_ability(target)
	return TRUE

/// Berserker-strain-only self-buff opener (target arg unused) - next slash gets bonus damage+slow. get_ability() returning null on a non-Berserker is the strain check.
/datum/xeno_ai_controller/ravager/proc/attempt_apprehend()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/apprehend/apprehend = get_ability(/datum/action/xeno_action/onclick/apprehend)
	if(!apprehend || !apprehend.action_cooldown_check())
		return FALSE
	apprehend.use_ability(pilot)
	return TRUE

/// Berserker-strain-only targeted fling+self-heal, needs an adjacent target - tried before Eviscerate/plain melee in use_caste_ability() below.
/datum/xeno_ai_controller/ravager/proc/attempt_clothesline(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/clothesline/clothesline = get_ability(/datum/action/xeno_action/activable/clothesline)
	if(!clothesline || !clothesline.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	clothesline.use_ability(target)
	return TRUE

/// Hedgehog-strain-only ranged poke while still closing distance - ammo cost is shard-gated via the ability's own action_cooldown_check() override, no separate resource check needed here.
/datum/xeno_ai_controller/ravager/proc/attempt_rav_spikes(atom/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/rav_spikes/spikes = get_ability(/datum/action/xeno_action/activable/rav_spikes)
	if(!spikes || !spikes.action_cooldown_check())
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	spikes.use_ability(target)
	return TRUE

/// Hedgehog-strain-only reactive shield, same below-half-health trigger shape as crusher.dm's attempt_shield() - shard cost is already folded into the ability's own action_cooldown_check() override.
/datum/xeno_ai_controller/ravager/proc/attempt_spike_shield()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= 0.5)
		return FALSE
	var/datum/action/xeno_action/onclick/spike_shield/shield = get_ability(/datum/action/xeno_action/onclick/spike_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	shield.use_ability(pilot)
	return TRUE

/// Hedgehog-strain-only self-AoE - same "2+ targets already adjacent" gate as attempt_eviscerate() above, since it also disables shard generation for 30s afterward (a real commitment, not a free panic button).
/datum/xeno_ai_controller/ravager/proc/attempt_spike_shed()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/spike_shed/shed = get_ability(/datum/action/xeno_action/onclick/spike_shed)
	if(!shed || !shed.action_cooldown_check())
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
	shed.use_ability(pilot)
	return TRUE

/// Berserker-strain-only channeled AoE finisher - fires only when 2+ valid targets are already adjacent (a windup that immobilizes her is a bad trade against a single target), same nearby-count scan shape as crusher.dm's Stomp check.
/datum/xeno_ai_controller/ravager/proc/attempt_eviscerate()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/eviscerate/eviscerate = get_ability(/datum/action/xeno_action/activable/eviscerate)
	if(!eviscerate || !eviscerate.action_cooldown_check())
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
	eviscerate.use_ability(pilot)
	return TRUE

/**
 * Prefers Scissor Cut (hits everything in a line several tiles ahead)
 * over a plain melee swing whenever more than one valid target is
 * nearby, then considers arming Empower when a real group fight is
 * happening. Falls through to the inherited single-target melee whenever
 * neither condition is met (the common case: a normal 1-on-1).
 *
 * Berserker strain: attempt_clothesline()/attempt_eviscerate() above take
 * priority - Scissor Cut/Empower are both removed by the strain so
 * get_ability() already no-ops them for her.
 */
/datum/xeno_ai_controller/ravager/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	attempt_spike_shield() // Hedgehog-only reactive shield, side effect only - never blocks anything below.

	if(attempt_clothesline(target))
		return TRUE
	if(attempt_eviscerate())
		return TRUE
	if(attempt_spike_shed())
		return TRUE

	var/datum/action/xeno_action/activable/scissor_cut/cut = get_ability(/datum/action/xeno_action/activable/scissor_cut)
	if(cut && cut.action_cooldown_check())
		var/nearby_targets = 0
		for(var/mob/living/carbon/nearby in orange(4, pilot))
			if(!is_valid_target(nearby))
				continue
			nearby_targets++
			if(nearby_targets >= AI_RAVAGER_SCISSOR_MIN_TARGETS)
				break
		if(nearby_targets >= AI_RAVAGER_SCISSOR_MIN_TARGETS)
			cut.use_ability(target)
			start_tactical_retreat(AI_RAVAGER_RETREAT_DURATION)
			return TRUE

	var/datum/action/xeno_action/onclick/empower/empower = get_ability(/datum/action/xeno_action/onclick/empower)
	if(empower && !empower.activated_once && empower.action_cooldown_check())
		var/hostiles_nearby = 0
		for(var/mob/living/carbon/nearby in orange(empower.empower_range, pilot))
			if(!is_valid_target(nearby))
				continue
			hostiles_nearby++
			if(hostiles_nearby >= AI_RAVAGER_EMPOWER_MIN_TARGETS)
				break
		if(hostiles_nearby >= AI_RAVAGER_EMPOWER_MIN_TARGETS)
			empower.use_ability(pilot)
			return TRUE

	// "Use retreating in combat instead of low health = retreat" - same
	// hit-and-run design as Praetorian, layered on top of the existing
	// flank-circling below rather than replacing it. A Hedgehog with a low
	// shard tank deliberately skips it: her whole strain identity is
	// standing IN the incoming fire to charge shards off the damage
	// (shards_per_projectile/shards_per_slash, hedgehog.dm) - backing off
	// while uncharged throws away exactly the exchange she's built to win.
	var/datum/behavior_delegate/ravager_hedgehog/hedgehog = pilot.behavior_delegate
	if(istype(hedgehog) && !hedgehog.shards_locked && hedgehog.shards < hedgehog.max_shards * AI_HEDGEHOG_SHARD_HOLD_PERCENT)
		return FALSE
	if(prob(AI_RAVAGER_RETREAT_CHANCE))
		start_tactical_retreat(AI_RAVAGER_RETREAT_DURATION)
	return FALSE

/**
 * Adds a post-attack flanking step on top of the base attack handling -
 * this is the "nimble" half of the caste's identity, independent of
 * whichever ability (or plain melee) actually landed above.
 */
/datum/xeno_ai_controller/ravager/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		last_known_health = pilot?.health
		return // Target died/escaped/moved out of melee range during the attack above - nothing to flank around.

	var/took_damage = (last_known_health != null) && (pilot.health < last_known_health)
	last_known_health = pilot.health
	if(!took_damage && !prob(AI_RAVAGER_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir)) // Preferred side is blocked - try the other rather than staying locked out of repositioning entirely this attack.
