/**
 * Attack execution for xeno_ai_controller. Reuses the real, input-agnostic
 * attack_alien() receiver chain (code/modules/mob/living/carbon/xenomorph/attack_alien.dm)
 * instead of any player-facing UI/ability-click layer - attack_alien() already reads
 * the attacker's a_intent and works identically regardless of whether a client set it.
 */
/datum/xeno_ai_controller/proc/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	// A hit-and-run caste (Burrower/Praetorian/Ravager) queues a tactical
	// retreat (start_tactical_retreat()) from inside use_caste_ability(),
	// called below via execute_attack() - but staying adjacent to
	// current_target would otherwise keep landing her right back in
	// process_attack() every tick forever (the plain Adjacent() check below
	// never routes through process_movement(), where the actual retreat
	// step lives), so the fight never actually breaks off. Forcing
	// APPROACHING here is what makes retreating happen at all once queued.
	if(is_tactical_retreating())
		ai_state = AI_STATE_APPROACHING
		return

	if(!pilot.Adjacent(current_target))
		ai_state = AI_STATE_APPROACHING
		return

	execute_attack(current_target)

	// execute_attack() has no failure return value of its own (abilities/melee
	// both just fire-and-forget through attack_alien()), so lack of progress is
	// read back off stale_attack_ticks (record_damage_dealt()) instead - a
	// target the pilot mechanically can't damage (behind an unbreakable
	// barrier, immune, etc.) would otherwise be attacked forever, unlike
	// movement (blocked_attempts) and search (AI_XENO_SEARCH_TIMEOUT), which
	// already both give up.
	if(stale_attack_ticks >= AI_PRIORITY_STALE_ATTACK_GIVEUP)
		if(GLOB.ai_debug_pathing)
			log_debug("XENO AI STALE ATTACK GIVEUP: [pilot] ([pilot.type]) landed no damage on [current_target] for [stale_attack_ticks] ticks - [get_ai_debug_snapshot()]")
		drop_target()

/**
 * Orientation is only touched here, at the moment of the strike - never polled
 * every tick - per the reference implementation's own performance approach.
 * Branches on target type: living targets go through the full
 * ability/facehugger/melee chain below, while structures (sentry turrets)
 * skip straight to attack_alien() - abilities and facehugger logic don't
 * apply to attacking machinery.
 */
/datum/xeno_ai_controller/proc/execute_attack(atom/movable/target)
	if(!pilot || !target || QDELETED(target))
		return

	pilot.setDir(get_dir(pilot, target))

	if(!isliving(target))
		if(world.time <= pilot.next_move)
			return
		pilot.a_intent = INTENT_HARM
		target.attack_alien(pilot)
		if(pilot) // attack_alien() can retaliate/kill the pilot (e.g. an explosive barricade) - don't write to it if it just died.
			pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
		return

	var/mob/living/living_target = target
	var/health_before = living_target.health

	// Caste abilities are NOT gated on next_move below - a real player fires
	// these from the action bar, a separate input path from click.dm's
	// attack-click dispatch, gated only by the ability's own
	// action_cooldown_check()/xeno_cooldown. That's already enforced inside
	// use_caste_ability()'s own implementations.
	if(use_caste_ability(living_target))
		// "Casts really do not use all their special abilities" is hard to
		// verify by feel during a fast-paced live test - this makes it
		// checkable at a glance in the hive status roster instead (see
		// event_tab.dm/AdminHiveStatus.jsx), rather than guessing blind
		// again whether the logic actually fires or just looks right on paper.
		if(GLOB.ai_debug_pathing)
			log_debug("XENO AI ABILITY USED: [pilot] ([pilot.type]) used a caste ability on [living_target] - [get_ai_debug_snapshot()]")
		last_ability_time = world.time
		record_damage_dealt(living_target, health_before)
		return

	// Facehuggers don't claw - they climb onto a downed human's face. Reusing the
	// generic melee fallback below would be actively wrong for this caste, not
	// just suboptimal, so it's special-cased here rather than left for the
	// Stage 2+ per-caste audit.
	if(istype(pilot, /mob/living/carbon/xenomorph/facehugger))
		execute_facehugger_hug(living_target)
		return

	// A real player's plain-melee attack rate is throttled by click.dm's
	// do_click()/click_adjacent() - `next_move = world.time` then `+= 4` for
	// an unarmed hit on a living target - not by attack_alien() itself, which
	// never touches next_move for a basic claw (only a handful of special
	// interactions like prying doors do, via xeno_attack_delay()). This AI
	// calls attack_alien() directly and never goes through that dispatch, so
	// without enforcing the same cooldown here itself, a fast decision loop
	// (see AI_XENO_DEFAULT_HEARTBEAT) could re-attack every single game tick -
	// unlimited-rate melee spam, exactly what was reported.
	if(world.time <= pilot.next_move)
		return
	// "I would love if the aliens would utilize disarm intent as well to
	// maybe stun players" - INTENT_DISARM on a human target is a real tackle
	// attempt (attempt_tackle() -> Stun(), attack_alien.dm), not just a
	// weaker claw - occasionally tackling instead of always clawing gives a
	// real knockdown option instead of pure damage every single swing.
	pilot.a_intent = (ishuman(living_target) && prob(AI_XENO_DISARM_CHANCE)) ? INTENT_DISARM : INTENT_HARM
	living_target.attack_alien(pilot)
	if(pilot) // attack_alien() can retaliate/kill the pilot (e.g. a lit welder, thorns) - don't write to it if it just died.
		pilot.next_move = world.time + XENO_MELEE_ATTACK_DELAY
	record_damage_dealt(living_target, health_before)

/**
 * Backs the hive status roster's "damage done" column (see event_tab.dm's
 * admin panel) - measures the target's own health delta rather than trying
 * to intercept every possible damage source (abilities, plain melee) with
 * its own return value, which would mean touching every attack path
 * individually. QDELETED-guarded since a caste ability can gib/delete the
 * target outright (Queen's Gut) before returning here.
 */
/datum/xeno_ai_controller/proc/record_damage_dealt(mob/living/target, health_before)
	if(QDELETED(target))
		return
	var/dealt = health_before - target.health
	if(dealt > 0)
		damage_dealt += dealt
		stale_attack_ticks = 0
	else if(target == current_target)
		stale_attack_ticks++

/**
 * Shared melee fallback for any caste with Tail Stab in its kit (Warrior,
 * Sentinel, King, Ravager, Hivelord, Queen, Predalien, Drone, Praetorian,
 * Lesser Drone, Lurker, Crusher, Defender, Carrier, Burrower - most of the
 * roster) - "all casts really do not use all their special abilities" was
 * true of this one universally: nothing in the AI ever called it despite
 * how widely it's granted. get_ability() queries the plain base type here
 * deliberately, not any specific caste subtype (tail_stab/slam, /spitter,
 * /tail_seize, /tail_fountain, /boiler) - locate(type) in list matches a
 * held instance of that type OR any stricter subtype of it, so this finds
 * whichever variant a given caste actually has without needing to know
 * which one ahead of time.
 */
/datum/xeno_ai_controller/proc/attempt_tail_stab(mob/living/target)
	var/datum/action/xeno_action/activable/tail_stab/stab = get_ability(/datum/action/xeno_action/activable/tail_stab)
	if(!stab || !stab.action_cooldown_check())
		return FALSE
	stab.use_ability(target)
	return TRUE

/**
 * Hook point for Stage 2+ caste-specific offensive abilities (see the plan's caste
 * audit, section 2.6): a caste's controller subtype can override this to call a
 * specific /datum/action/xeno_action's use_ability() body directly, bypassing the
 * click/mouse input layer, and return TRUE to skip the plain-melee fallback below.
 * Drone has no offensive ability worth AI-triggering, so this always falls through.
 */
/datum/xeno_ai_controller/proc/use_caste_ability(mob/living/target)
	return FALSE

/**
 * Mirrors the validity checks and windup in Facehugger.dm's UnarmedAttack()/
 * handle_hug() (can only hug a target that's lying down), but skips the
 * click-driven visible_message flavor since nobody needs to read it for an
 * NPC. Calls the same handle_hug() so the actual infection logic is identical
 * to a player-controlled hugger. No-ops (waits adjacent) against a standing
 * target rather than doing anything else - a real hugger has no other attack.
 */
/datum/xeno_ai_controller/proc/execute_facehugger_hug(mob/living/target)
	if(!ishuman(target))
		return
	var/mob/living/carbon/human/human_target = target
	var/mob/living/carbon/xenomorph/facehugger/hugger = pilot
	if(!istype(hugger))
		return
	if(human_target.body_position != LYING_DOWN)
		return
	if(!can_hug(human_target, hugger.hivenumber))
		return
	// Already running on the AI controller itself here (src), unlike the shared ability
	// files - no ai_controller null-check needed, this proc only ever runs AI-side.
	if(!do_after(hugger, FACEHUGGER_WINDUP_DURATION, INTERRUPT_ALL, BUSY_ICON_HOSTILE, human_target, INTERRUPT_MOVED, BUSY_ICON_HOSTILE, extra_interrupt_check = CALLBACK(src, PROC_REF(should_abort_action), human_target)))
		return
	if(human_target.body_position != LYING_DOWN || !can_hug(human_target, hugger.hivenumber))
		return
	hugger.handle_hug(human_target)
