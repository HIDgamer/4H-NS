/**
 * Defender AI - a stationary chokepoint tank rather than a chaser
 * (can_vent_crawl = 0, built around Fortify's big armor/explosive buff
 * while anchored in place). Patrol/search/movement are entirely inherited
 * from the base melee controller - only the attack decision differs:
 *
 * - Tail Sweep (a short AoE knockback) instead of a plain swing whenever
 *   more than one valid target is already adjacent, same threshold pattern
 *   as Crusher's Stomp.
 * - Fortify once actually engaged and not already anchored - she's meant
 *   to plant herself and hold, not fortify while still mid-chase (Fortify
 *   immobilizes her, so this only fires once adjacent/attacking).
 * - Headbutt (knockback + damage) as the default single-target option
 *   once neither of the above applies, since usable_while_fortified is
 *   only guaranteed on the steel_crest strain variant - falls through to
 *   plain melee if it's not off cooldown.
 *
 * Un-fortifies to reposition once the target's no longer adjacent instead of
 * staying planted uselessly (see process_attack() override) - Fortify sets
 * TRAIT_IMMOBILIZED, which used to hit the base tick()'s generic stun/
 * knockdown freeze check every single tick while fortified, meaning a
 * fortified Defender could never attack OR un-root herself again once the
 * fight moved out of reach - the ability effectively bricked her AI for the
 * rest of the round. can_act_while_immobilized() below carves out the
 * exception so she can still act while deliberately planted.
 */
/datum/xeno_ai_controller/defender

/// Fortify is a deliberate, voluntary immobilize - she's still meant to fight (and, per process_attack() below, un-root) from where she's planted, unlike an ordinary stun/knockdown. Chains through ..() (xeno_ai_controller.dm) so the shared Pounce exemption still applies too, on the off chance she's ever given a pounce-family ability.
/datum/xeno_ai_controller/defender/can_act_while_immobilized()
	if(..())
		return TRUE
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	return istype(xeno_pilot) && xeno_pilot.fortify

/**
 * If the target's wandered out of melee range while she's fortified, staying
 * planted accomplishes nothing - un-fortify first so the base process_attack()'s
 * own Adjacent check below can transition her to APPROACHING and she can
 * actually move again next tick (Fortify also sets anchored = TRUE, which
 * blocks movement outright until this runs).
 */
/datum/xeno_ai_controller/defender/process_attack()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(istype(xeno_pilot) && xeno_pilot.fortify && current_target && !pilot.Adjacent(current_target))
		var/datum/action/xeno_action/activable/fortify/fortify = get_ability(/datum/action/xeno_action/activable/fortify)
		fortify?.use_ability(pilot) // Toggles off - see Defender.dm's use_ability().
	return ..()

/**
 * Steelcrest strain needs almost no new wiring: headbutt/steel_crest and
 * fortify/steel_crest are subtypes of the base headbutt/fortify typepaths
 * already looked up below (get_ability()'s locate() matches subtypes), so
 * both already fire for her with zero changes. Only Tail Sweep is actually
 * removed by the strain (no AoE replacement granted) - the existing
 * nearby-count check below already degrades safely via get_ability()
 * returning null, same as every other removed-ability case this phase.
 * Soak (a proactive damage-tanking window, not a reactive panic button - it
 * pays off from damage taken *during* its 6s window, not beforehand) is
 * tried opportunistically, same side-effect shape as crusher.dm's
 * attempt_shield().
 */
/datum/xeno_ai_controller/defender/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot

	attempt_soak() // Steelcrest-only, side effect only - never blocks anything below.

	var/datum/action/xeno_action/onclick/tail_sweep/sweep = get_ability(/datum/action/xeno_action/onclick/tail_sweep)
	if(sweep && sweep.action_cooldown_check())
		var/nearby_targets = 0
		for(var/mob/living/carbon/nearby in orange(1, pilot))
			if(!is_valid_target(nearby))
				continue
			nearby_targets++
			if(nearby_targets >= AI_DEFENDER_SWEEP_MIN_TARGETS)
				break
		if(nearby_targets >= AI_DEFENDER_SWEEP_MIN_TARGETS)
			sweep.use_ability(pilot)
			return TRUE

	manage_crest_defense() // Side effect only - checked after Tail Sweep above so a same-tick toggle-on can't block that tick's sweep (crest_defense disables Tail Sweep entirely, Defender.dm).

	var/datum/action/xeno_action/activable/fortify/fortify = get_ability(/datum/action/xeno_action/activable/fortify)
	if(fortify && !xeno_pilot.fortify && !xeno_pilot.crest_defense && fortify.action_cooldown_check())
		fortify.use_ability(target)
		return TRUE

	var/datum/action/xeno_action/activable/headbutt/headbutt = get_ability(/datum/action/xeno_action/activable/headbutt)
	if(headbutt && headbutt.action_cooldown_check())
		headbutt.use_ability(target)
		return TRUE

	return FALSE

/// Steelcrest-strain-only - a proactive tank-the-hit window (damage taken during its 6s duration pays off in healing + a tail-slam cooldown reset, steel_crest.dm), so worth trying opportunistically rather than gating it on already being hurt.
/datum/xeno_ai_controller/defender/proc/attempt_soak()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/soak/soak = get_ability(/datum/action/xeno_action/onclick/soak)
	if(!soak || !soak.action_cooldown_check())
		return FALSE
	soak.use_ability(pilot)
	return TRUE

/**
 * "Meant to be a wall stance where they don't move [much] and take less
 * damage, they can't attack much" - a real defensive tradeoff (armor
 * deflection buff, knockback immunity, but a slower ability cadence and
 * Tail Sweep completely disabled while it's up, Defender.dm), not a free
 * toggle to leave on permanently. Reactive: turtles up once actually
 * taking a beating (below half health, same threshold crusher.dm's
 * attempt_shield() uses) and not already Fortified (mutually exclusive -
 * toggle_crest's own use_ability() already refuses this, checked here too
 * so the cooldown isn't wasted on a call that would just no-op), raises
 * her crest back once health has meaningfully recovered rather than the
 * instant she ticks past the same threshold (hysteresis - stops her
 * flip-flopping the stance every other tick right at the boundary).
 */
/datum/xeno_ai_controller/defender/proc/manage_crest_defense()
	if(!pilot)
		return
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(!xeno_pilot.maxHealth || xeno_pilot.fortify)
		return
	var/datum/action/xeno_action/onclick/toggle_crest/crest = get_ability(/datum/action/xeno_action/onclick/toggle_crest)
	if(!crest || !crest.action_cooldown_check())
		return
	var/health_fraction = xeno_pilot.health / xeno_pilot.maxHealth
	if(!xeno_pilot.crest_defense && health_fraction < 0.5)
		crest.use_ability(pilot)
	else if(xeno_pilot.crest_defense && health_fraction >= 0.7)
		crest.use_ability(pilot)

/**
 * The ability-speed debuff crest_defense carries (Defender.dm) would slow
 * her down while trying to actually get away - raise the crest before
 * falling through to the normal walk home, mirroring the tactical-retreat
 * gap-close/escape convention every other caste's return_to_anchor()
 * override already follows.
 */
/datum/xeno_ai_controller/defender/return_to_anchor()
	var/mob/living/carbon/xenomorph/xeno_pilot = pilot
	if(istype(xeno_pilot) && xeno_pilot.crest_defense)
		var/datum/action/xeno_action/onclick/toggle_crest/crest = get_ability(/datum/action/xeno_action/onclick/toggle_crest)
		if(crest && crest.action_cooldown_check())
			crest.use_ability(pilot)
	return ..()
