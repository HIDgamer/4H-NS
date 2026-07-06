/**
 * Praetorian AI - a melee-primary hybrid "warleader": closes with Dash like
 * Crusher/Ravager's own dashes, throws Acid Ball as a heavy periodic hit in
 * between plain swings, then deliberately breaks off - "hop into action,
 * use its abilities, slash marines, and hop back into safety, and repeat."
 * Per the user's explicit design ("use retreating in combat instead of low
 * health = retreat"), this is a proactive hit-and-run rotation, not
 * should_flee()'s health-threshold panic button - see the shared
 * start_tactical_retreat()/is_tactical_retreating() helpers.
 */
/datum/xeno_ai_controller/praetorian
	/// Vanguard-strain-only, set the first time attempt_toggle_cleave() runs - Toggle Cleave has no cooldown of its own, so without a one-time latch the AI would flip-flop the root/fling stance uselessly on every patrol() tick instead of picking one and sticking with it.
	var/cleave_stance_set = FALSE

/**
 * "Using a few abilities would send the casts into daydreaming and doing
 * nothing... one or two ability uses makes the AI stop in its tracks" -
 * Oppressor's Prae Abduct and Valkyrie's Prae Retrieve (oppressor.dm/
 * valkyrie.dm) both ADD_TRAIT TRAIT_IMMOBILIZED on the Praetorian herself
 * for their windup, same as Defender's Fortify/Burrower's Burrow - without
 * this override the base tick()'s generic immobilize freeze check skipped
 * ALL AI logic for the entire windup, every single cast. HAS_TRAIT_FROM_ONLY
 * (not a bare HAS_TRAIT check) matters - TRAIT_IMMOBILIZED isn't
 * exclusively self-inflicted (e.g. TRAIT_KNOCKEDOUT from a marine-landed
 * stun forces it too, living.dm), so this only lets her keep acting when
 * one of her own abilities is the *only* thing holding the trait, not when
 * a real hostile stun is stacked on top of it.
 */
/datum/xeno_ai_controller/praetorian/can_act_while_immobilized()
	if(..())
		return TRUE
	return HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Abduct")) || HAS_TRAIT_FROM_ONLY(pilot, TRAIT_IMMOBILIZED, TRAIT_SOURCE_ABILITY("Praetorian Retrieve"))

/**
 * Praetorian didn't need a patrol() override before Phase 2 - Valkyrie's
 * support kit (Rage/Fight or Flight/Retrieve) all target allies rather than
 * hostiles, so they're checked here (idle-driven) rather than in
 * use_caste_ability() (which only fires while already fighting a hostile).
 * Vanguard's one-time stance pick lives here too. All four no-op instantly
 * for a non-Valkyrie/non-Vanguard Praetorian via get_ability().
 */
/datum/xeno_ai_controller/praetorian/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	attempt_toggle_cleave() // Side effect only, one-time - never blocks anything below.
	if(attempt_prae_retrieve())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(attempt_fight_or_flight())
		return
	if(attempt_valkyrie_rage())
		return
	return ..()

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm/runner.dm/warrior.dm -
 * attempting the dash before falling through to the inherited approach
 * chain differs enough from the base melee policy to warrant a full
 * override.
 */
/datum/xeno_ai_controller/praetorian/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(is_tactical_retreating())
		// "Hop back into safety" - Dash only ever closes distance, so
		// retreating is a plain backstep, same as every other hit-and-run
		// caste. Cornered with nowhere to actually back into cancels the
		// retreat outright and falls through to fighting instead of
		// standing frozen for the rest of the retreat window.
		if(step_away_from_target())
			return
		tactical_retreat_until = 0

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(attempt_dash(current_target))
		return
	if(attempt_tail_seize(current_target))
		return
	if(attempt_prae_dash(current_target))
		return
	if(attempt_high_gallop(current_target))
		return
	if(attempt_prae_spit(current_target))
		return

	return ..()

/// Fires Dash at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/praetorian/proc/attempt_dash(atom/target)
	var/datum/action/xeno_action/activable/pounce/base_prae_dash/dash = get_ability(/datum/action/xeno_action/activable/pounce/base_prae_dash)
	if(!dash || !dash.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > dash.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A dash is a physical lunge - furniture blocks it same as a wall would.
		return FALSE
	dash.use_ability(target)
	return TRUE

/// Oppressor-strain-only ranged pull while still closing - Dash is removed by the strain (attempt_dash() above already no-ops for her), so this is her actual gap-closer/opener instead.
/datum/xeno_ai_controller/praetorian/proc/attempt_tail_seize(atom/target)
	var/datum/action/xeno_action/activable/tail_stab/tail_seize/seize = get_ability(/datum/action/xeno_action/activable/tail_stab/tail_seize)
	if(!seize || !seize.action_cooldown_check())
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	seize.use_ability(target)
	return TRUE

/// Base-kit-only. Xeno Spit was granted but never called - a ranged poke while still closing, same shape as ravager.dm/hedgehog.dm's rav_spikes.
/datum/xeno_ai_controller/praetorian/proc/attempt_prae_spit(atom/target)
	var/datum/action/xeno_action/activable/xeno_spit/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit)
	if(!spit || !spit.action_cooldown_check())
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	spit.use_ability(target)
	return TRUE

/**
 * "Slash marines and hop back into safety" - Acid Ball is the "use its
 * abilities" hit that ends the engagement window; without it, a chance per
 * plain swing still eventually breaks off the fight.
 *
 * Dancer strain: Impale (bonus damage on a tagged target)/Tail Trip
 * (control) take priority. Oppressor strain: Prae Abduct (multi-target
 * pull)/Oppressor Punch (finisher) take priority. Acid Ball is removed by
 * both strains, so get_ability() already no-ops it for them.
 *
 * Base kit also grants Pierce and Tail Lash (praetorian_abilities.dm) -
 * carried over unwired from the Phase 2 strain pass (Pierce is Vanguard's
 * primary attack, Tail Lash is Oppressor's AoE) - both now have real
 * attempt_*() procs, tried after Acid Ball since neither should preempt her
 * signature heavy hit.
 */
/datum/xeno_ai_controller/praetorian/use_caste_ability(mob/living/target)
	if(attempt_impale(target))
		return TRUE
	if(attempt_tail_trip(target))
		return TRUE
	if(attempt_prae_abduct(target))
		return TRUE
	if(attempt_oppressor_punch(target))
		return TRUE
	if(attempt_cleave(target))
		return TRUE
	if(attempt_pierce(target))
		return TRUE

	var/datum/action/xeno_action/activable/prae_acid_ball/acid_ball = get_ability(/datum/action/xeno_action/activable/prae_acid_ball)
	if(acid_ball && acid_ball.action_cooldown_check())
		acid_ball.use_ability(target)
		start_tactical_retreat(AI_PRAETORIAN_RETREAT_DURATION)
		return TRUE

	if(attempt_spray_acid(target))
		return TRUE
	if(attempt_tail_lash(target))
		return TRUE

	if(prob(AI_PRAETORIAN_RETREAT_CHANCE))
		start_tactical_retreat(AI_PRAETORIAN_RETREAT_DURATION)
	return FALSE

/// Base-kit-only. Spray Acid was granted but never called - a line-AoE alternative once Acid Ball itself is on cooldown.
/datum/xeno_ai_controller/praetorian/proc/attempt_spray_acid(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/spray_acid/base_prae_spray_acid/spray = get_ability(/datum/action/xeno_action/activable/spray_acid/base_prae_spray_acid)
	if(!spray || !spray.action_cooldown_check())
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	spray.use_ability(target)
	return TRUE

/// Vanguard-strain-only primary attack, granted alongside Prae Dash/Cleave but missed during Phase 2's strain pass - a line-melee, capped at 3 tiles internally by the ability itself (pierce.dm's own get_line() truncation).
/datum/xeno_ai_controller/praetorian/proc/attempt_pierce(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/pierce/pierce = get_ability(/datum/action/xeno_action/activable/pierce)
	if(!pierce || !pierce.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > 3)
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	pierce.use_ability(target)
	return TRUE

/// Oppressor-strain-only AoE, granted alongside Tail Seize/Prae Abduct/Oppressor Punch but missed during Phase 2's strain pass - only worth it with 2+ nearby targets, same gate as Prae Abduct.
/datum/xeno_ai_controller/praetorian/proc/attempt_tail_lash(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/tail_lash/lash = get_ability(/datum/action/xeno_action/activable/tail_lash)
	if(!lash || !lash.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > 2)
		return FALSE
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(2, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	if(nearby_targets < 2)
		return FALSE
	lash.use_ability(target)
	return TRUE

/// Dancer-strain-only primary melee - hits twice for bonus damage against an already-tagged target (dancer_tag effect, applied by her own melee_attack_additional_effects_target()), needs adjacency.
/datum/xeno_ai_controller/praetorian/proc/attempt_impale(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/prae_impale/impale = get_ability(/datum/action/xeno_action/activable/prae_impale)
	if(!impale || !impale.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	impale.use_ability(target)
	return TRUE

/// Dancer-strain-only control tool - not gated on tag state since it does something useful either way (slow if untagged, knockdown/daze if tagged); its own range var handles the distance check.
/datum/xeno_ai_controller/praetorian/proc/attempt_tail_trip(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/prae_tail_trip/trip = get_ability(/datum/action/xeno_action/activable/prae_tail_trip)
	if(!trip || !trip.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > trip.range)
		return FALSE
	trip.use_ability(target)
	return TRUE

/// Oppressor-strain-only multi-target line pull - a do_after windup that immobilizes her, same shape as base Praetorian's Acid Ball, so only worth it when 2+ targets are actually clustered in front of her (same nearby-count-gate spirit as crusher.dm's Stomp check).
/datum/xeno_ai_controller/praetorian/proc/attempt_prae_abduct(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/prae_abduct/abduct = get_ability(/datum/action/xeno_action/activable/prae_abduct)
	if(!abduct || !abduct.action_cooldown_check())
		return FALSE
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(abduct.max_distance, pilot))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	if(nearby_targets < 2)
		return FALSE
	abduct.use_ability(target)
	return TRUE

/// Oppressor-strain-only melee finisher - needs adjacency, reduces her other cooldowns on hit (oppressor.dm) so using it opportunistically also helps Prae Abduct/Tail Lash come back faster.
/datum/xeno_ai_controller/praetorian/proc/attempt_oppressor_punch(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/oppressor_punch/punch = get_ability(/datum/action/xeno_action/activable/oppressor_punch)
	if(!punch || !punch.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	punch.use_ability(target)
	return TRUE

/**
 * "Instead of approaching, xenos should consider using abilities to close
 * the gap... not just to get to the enemy faster but escape it faster too"
 * (§1.7's gap-close/escape theme) - Prae Dodge is a speed buff that also
 * phases her through mobs, a real escape tool base Praetorian doesn't have.
 * Tries it once per return_to_anchor() tick before falling through to the
 * normal walk, same shape as crusher.dm's attempt_tumble_retreat().
 */
/datum/xeno_ai_controller/praetorian/return_to_anchor()
	attempt_prae_dodge()
	return ..()

/// Dancer-strain-only self-buff (target arg unused) - get_ability() returning null on a non-Dancer is the strain check.
/datum/xeno_ai_controller/praetorian/proc/attempt_prae_dodge()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/prae_dodge/dodge = get_ability(/datum/action/xeno_action/onclick/prae_dodge)
	if(!dodge || !dodge.action_cooldown_check())
		return FALSE
	dodge.use_ability(pilot)
	return TRUE

/**
 * Vanguard-strain-only two-stage dash - Dash is removed by the strain
 * (attempt_dash() above already no-ops for her), and Prae Dash's own
 * built-in timeout (vanguard.dm's timeout()/addtimer) auto-resolves the AoE
 * payoff a few seconds after the first call even if never triggered a
 * second time, same "fire and forget" shape as Ravager's Empower - no
 * bespoke state var needed here, activated_once is already tracked on the
 * action itself. First call (activated_once FALSE) moves+windups; second
 * call (activated_once TRUE, while still close) fires the AoE early instead
 * of waiting out the timeout.
 */
/datum/xeno_ai_controller/praetorian/proc/attempt_prae_dash(atom/target)
	var/datum/action/xeno_action/activable/pounce/prae_dash/dash = get_ability(/datum/action/xeno_action/activable/pounce/prae_dash)
	if(!dash)
		return FALSE
	if(dash.activated_once)
		if(get_dist(pilot, target) > 1)
			return FALSE
		dash.use_ability(target)
		return TRUE
	if(!dash.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > dash.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE))
		return FALSE
	dash.use_ability(target)
	return TRUE

/// Vanguard-strain-only toggle, called once (see cleave_stance_set) - Toggle Cleave has no cooldown of its own, so this just picks a random stance instead of always defaulting to whichever root_toggle's initial value happens to be.
/datum/xeno_ai_controller/praetorian/proc/attempt_toggle_cleave()
	if(!pilot || cleave_stance_set)
		return FALSE
	var/datum/action/xeno_action/onclick/toggle_cleave/toggle = get_ability(/datum/action/xeno_action/onclick/toggle_cleave)
	if(!toggle)
		return FALSE
	cleave_stance_set = TRUE
	if(prob(50))
		toggle.use_ability(pilot)
	return TRUE

/// Vanguard-strain-only melee - needs adjacency; roots or flings depending on the stance attempt_toggle_cleave() picked (cleave.dm's own root_toggle var), amplified if her shield is up (buffed).
/datum/xeno_ai_controller/praetorian/proc/attempt_cleave(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/cleave/cleave = get_ability(/datum/action/xeno_action/activable/cleave)
	if(!cleave || !cleave.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	cleave.use_ability(target)
	return TRUE

/// Valkyrie-strain-only ally buff - prefers a nearby Crusher/Ravager ally (the ability's own bonus branch, valkyrie.dm) over a plain armor buff, falling back to any other valid ally. Doesn't reuse find_nearby_ally_xeno() (xeno_ai_controller.dm) since this isn't damage-based targeting - a full-health ally is just as valid a target as a hurt one.
/datum/xeno_ai_controller/praetorian/proc/attempt_valkyrie_rage()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/valkyrie_rage/rage = get_ability(/datum/action/xeno_action/activable/valkyrie_rage)
	if(!rage || !rage.action_cooldown_check())
		return FALSE
	var/mob/living/carbon/xenomorph/best_ally
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.xeno_mob_list) // GLOB.xeno_mob_list already covers AI-piloted xenos too - see find_nearby_ally_xeno()'s doc comment (xeno_ai_controller.dm).
		if(ally == pilot || ally.stat == DEAD || !ally.ally_of_hivenumber(pilot.hivenumber))
			continue
		if(get_dist(pilot, ally) > AI_XENO_ALLY_SCAN_RADIUS)
			continue
		if(istype(ally.strain, /datum/xeno_strain/valkyrie) || HAS_TRAIT(ally, TRAIT_VALKYRIE_ARMORED))
			continue
		if(istype(ally.caste, /datum/caste_datum/crusher) || istype(ally.caste, /datum/caste_datum/ravager))
			best_ally = ally
			break
		if(!best_ally)
			best_ally = ally
	if(!best_ally)
		return FALSE
	rage.use_ability(best_ally)
	return TRUE

/// Valkyrie-strain-only ranged AoE knockdown - doesn't move her (not a true dash like Dash/Prae Dash), but still a useful pre-engagement poke while closing, same call site as the other gap-close attempts.
/datum/xeno_ai_controller/praetorian/proc/attempt_high_gallop(atom/target)
	var/datum/action/xeno_action/activable/high_gallop/gallop = get_ability(/datum/action/xeno_action/activable/high_gallop)
	if(!gallop || !gallop.action_cooldown_check())
		return FALSE
	if(!has_line_of_sight(target))
		return FALSE
	gallop.use_ability(target)
	return TRUE

/// Valkyrie-strain-only self-AoE heal - reactive when 2+ nearby allies are actually hurt, same "worth the cooldown" gate as crusher.dm's Stomp check.
/datum/xeno_ai_controller/praetorian/proc/attempt_fight_or_flight()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/fight_or_flight/heal = get_ability(/datum/action/xeno_action/onclick/fight_or_flight)
	if(!heal || !heal.action_cooldown_check())
		return FALSE
	var/hurt_allies = 0
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.xeno_mob_list) // GLOB.xeno_mob_list already covers AI-piloted xenos too - see find_nearby_ally_xeno()'s doc comment (xeno_ai_controller.dm).
		if(ally == pilot || ally.stat == DEAD || !ally.ally_of_hivenumber(pilot.hivenumber))
			continue
		if(get_dist(pilot, ally) > AI_XENO_ALLY_SCAN_RADIUS)
			continue
		if(!ally.maxHealth || (ally.health / ally.maxHealth) >= 1)
			continue
		hurt_allies++
		if(hurt_allies >= 2)
			break
	if(hurt_allies < 2)
		return FALSE
	heal.use_ability(pilot)
	return TRUE

/**
 * Valkyrie-strain-only rescue pull - most speculative wiring in this phase
 * (no "downed ally" detection pattern existed before this), so built
 * minimally: a downed ally is one that's unconscious or resting
 * (body_position LYING_DOWN), same states the ability's own use_ability()
 * accepts (valkyrie.dm).
 */
/datum/xeno_ai_controller/praetorian/proc/attempt_prae_retrieve()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/activable/prae_retrieve/retrieve = get_ability(/datum/action/xeno_action/activable/prae_retrieve)
	if(!retrieve || !retrieve.action_cooldown_check())
		return FALSE
	for(var/mob/living/carbon/xenomorph/ally as anything in GLOB.xeno_mob_list) // GLOB.xeno_mob_list already covers AI-piloted xenos too - see find_nearby_ally_xeno()'s doc comment (xeno_ai_controller.dm).
		if(ally == pilot || ally.stat == DEAD || !ally.ally_of_hivenumber(pilot.hivenumber))
			continue
		if(ally.body_position != LYING_DOWN && ally.stat != UNCONSCIOUS)
			continue
		if(ally.anchored || get_dist(pilot, ally) > 7)
			continue
		retrieve.use_ability(ally)
		return TRUE
	return FALSE
