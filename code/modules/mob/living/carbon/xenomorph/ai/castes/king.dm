/**
 * King AI - the Yautja-hive counterpart to Queen: a solo tier-4 boss, not a
 * population-scale caste, so (like Queen) he gets real per-tick reasoning
 * instead of the simpler population-budget logic every other caste uses.
 *
 * - Rend is cheap and short-cooldown (2.5s) - used as the default option
 *   over a plain claw whenever it's off cooldown, not gated on anything.
 * - Doom (AoE daze/blind/slow, 45s CD) and Destroy (huge-damage AoE slam,
 *   60s CD) used to be reserved for 2+ nearby targets on the theory that
 *   either would "waste most of their value" on a lone target - false for
 *   both (Destroy's damage number doesn't care how many mobs it hit, and
 *   dazing/slowing even one marine solo is a big setup for the follow-up),
 *   and since most engagements are actually 1v1, that gate meant "does not
 *   use its abilities well at all" - he'd sit on Rend alone almost every
 *   fight. Now used on cooldown against any live target. Destroy is
 *   preferred over Doom when both are available, since it's the bigger
 *   payoff.
 *
 * Proactively pops King Shield (a party-wide damage-cap buff) once he's
 * actually taking a beating - see attempt_shield() - rather than only ever
 * using his offensive kit and going down without ever bolstering himself or
 * nearby daughters.
 *
 * "Coordination with other AI xenos is very poor" - King never broadcast a
 * hive alert or escort call the way Queen does, so other AI xenos never
 * rallied to a fight he was personally in. broadcast_hive_alert()/
 * broadcast_escort_call() are shared base-controller procs (promoted off
 * Queen's controller, xeno_ai_controller.dm) - process_target()/
 * process_attack() below call them the same way Queen's own tick() does,
 * just without needing King to override the whole state machine the way
 * she does (he has no economy/command loop of his own to layer on top of).
 */
/datum/xeno_ai_controller/king

/// "King needs a face lift as well in the combat department and pathfinding" - he's the same kind of one-per-round solo boss as Queen but had no New() override at all, leaving him on the flat population-default attack/return radius instead of a boss-scale one.
/datum/xeno_ai_controller/king/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_KING_ATTACK_DISTANCE
	return_distance = AI_KING_RETURN_DISTANCE

/// Destroy (King.dm) self-immobilizes for its leap windup - King.dm uses a bare "Destroy" string as the trait source, not the TRAIT_SOURCE_ABILITY() macro, so this has to match that literally rather than reusing the macro like every other override does.
/datum/xeno_ai_controller/king/can_act_while_immobilized()
	if(..())
		return TRUE
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, "Destroy")

/// Exactly as hard to replace as Queen (one-per-round investment) - mirrors AI_QUEEN_FLEE_HEALTH_PERCENT, which he never had a matching override for before Phase 3.
/datum/xeno_ai_controller/king/get_flee_threshold()
	return AI_KING_FLEE_HEALTH_PERCENT

/// Broadcasts the instant he acquires a target, same as Queen's own tick() does for her - other AI xenos don't have to wait for him to already be swinging before they hear about it.
/datum/xeno_ai_controller/king/process_target()
	. = ..()
	if(current_target)
		broadcast_hive_alert(pilot)
		broadcast_escort_call(pilot, FALSE)

/// Keeps refreshing both broadcasts every attack tick, same as Queen's tick() does every tick she has a live target - so the alert/escort call stay fresh for as long as he's actually fighting.
/datum/xeno_ai_controller/king/process_attack()
	if(current_target)
		broadcast_hive_alert(pilot)
		broadcast_escort_call(pilot, FALSE)
	return ..()

/**
 * "Works best with teamwork... if caught in the open without defense, can be
 * killed easily" - he only commits to a distant fight with sisters actually
 * at his side; alone, he holds where he is and keeps calling (the escort
 * broadcast is already firing every tick he has a target), letting a
 * bodyguard form up around him first. A target already close is fought
 * regardless - holding never means standing there eating hits.
 */
/datum/xeno_ai_controller/king/process_movement()
	if(pilot && current_target && get_dist(pilot, current_target) > AI_KING_COMMIT_RANGE && count_nearby_hive_allies(AI_KING_ESCORT_RADIUS) < AI_KING_ESCORT_MIN)
		pilot.setDir(get_dir(pilot, current_target))
		return
	return ..()

/datum/xeno_ai_controller/king/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	attempt_shield() // Side effect only (its own independent cooldown/plasma cost) - never blocks also using an offensive ability the same tick below.

	var/datum/action/xeno_action/activable/destroy/destroy = get_ability(/datum/action/xeno_action/activable/destroy)
	if(destroy && destroy.action_cooldown_check())
		destroy.use_ability(pilot)
		return TRUE

	var/datum/action/xeno_action/activable/doom/doom = get_ability(/datum/action/xeno_action/activable/doom)
	if(doom && doom.action_cooldown_check())
		doom.use_ability(target)
		return TRUE

	var/datum/action/xeno_action/onclick/rend/rend = get_ability(/datum/action/xeno_action/onclick/rend)
	if(rend && rend.action_cooldown_check())
		rend.use_ability(pilot)
		return TRUE

	// King grants tail_stab (King.dm) but was silently falling through to
	// plain melee whenever Destroy/Doom/Rend were all on cooldown - Queen
	// already does this exact fallback (queen.dm).
	return attempt_tail_stab(target)

/// Pops King Shield once he's actually taking a beating (below half health) - the same "is the fight bad enough" bar crusher.dm's own attempt_shield() uses, not just whenever it happens to be off cooldown.
/datum/xeno_ai_controller/king/proc/attempt_shield()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= 0.5)
		return FALSE
	var/datum/action/xeno_action/onclick/king_shield/shield = get_ability(/datum/action/xeno_action/onclick/king_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	shield.use_ability(pilot)
	return TRUE
