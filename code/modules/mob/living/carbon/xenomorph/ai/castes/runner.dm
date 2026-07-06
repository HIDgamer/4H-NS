/**
 * Runner AI - a fast, fragile harasser: dash in with Pounce, land a hit,
 * then keep moving instead of trading blows toe-to-toe like a Warrior
 * would. Patrol/search behavior is entirely inherited from the base
 * controller.
 *
 * - Fires Pounce to close distance the same way Crusher/Ravager use their
 *   own dashes - Runner's has a much shorter cooldown (3s vs their 14s) and
 *   shorter range (6 tiles, the pounce base default), matching its role as
 *   a constant, low-commitment opener rather than an occasional finisher.
 * - Flees at a much higher health fraction than the default - she's the
 *   hive's glass cannon (lowest HP, no armor - XENO_HEALTH_RUNNER/
 *   XENO_NO_ARMOR), meant to hit and run, not to trade hits and die trying.
 * - "Too insane, completely spinning around like a feral dog - they should
 *   circle the battlefield attacking and dodging, very fast but very weak
 *   and small." Stepping straight away after every attack (the old
 *   behavior) reads exactly like that: pounce in, back straight out, get
 *   pulled straight back in by the base approach chain, repeat every ~1-2
 *   ticks - a jittery in-out twitch, not motion. Now sidesteps to a
 *   flanking tile instead, same shape as Ravager's own circling
 *   (circle_dir below - one consistent rotational direction, not a
 *   re-rolled left-right wobble).
 *
 * "Runners are way too difficult, able to attack 2 people alone and win the
 * fight... calmer to give players a chance." Her raw stats are actually
 * undertuned relative to a normal melee caste (lowest HP/no armor in the
 * roster, tier-1 damage, the same flat plain-melee cadence every caste
 * gets) - the overtuning was entirely in the AI's decision-making: Pounce
 * (an essentially free, 3s-cooldown knockdown) fired unconditionally the
 * instant it was off cooldown, and the flanking sidestep below fired
 * unconditionally after every single attack with no gate at all, unlike
 * Ravager's damage-reactive-plus-baseline-roll pattern. Both are now gated
 * (see attempt_pounce()/process_attack()) - the ability's own numbers
 * (plasma cost/cooldown/knockdown) are untouched, since those are shared
 * with human-played Runners and nerfing them would be a PvP balance change
 * beyond what was asked.
 */
/datum/xeno_ai_controller/runner
	/// Rotational direction (90 or -90) this Runner always circles toward - see Ravager's identical var for why this is picked once instead of re-rolled.
	var/circle_dir
	/// pilot.health as of the last process_attack() call - lets the sidestep tell "just got hit, this is a reactive dodge" from "nothing happened, this is just the baseline roll," same pattern as ravager.dm.
	var/last_known_health
	/// Acider: world.time the pre-detonation hold ends - the player pattern of waiting a few tiles out for the right moment before running in to explode. 0 when not holding.
	var/detonation_hold_until = 0
	/// Acider: TRUE once committed to the detonation run - attempt_for_the_hive() fires on reaching the target regardless of own health.
	var/detonation_committed = FALSE

/datum/xeno_ai_controller/runner/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	circle_dir = pick(90, -90)

/datum/xeno_ai_controller/runner/get_flee_threshold()
	return AI_RUNNER_FLEE_HEALTH_PERCENT

/**
 * Same duplication tradeoff as crusher.dm/ravager.dm - attempting the dash
 * before falling through to the inherited approach chain is different
 * enough from the base melee policy to warrant a full override rather than
 * a shared helper.
 */
/datum/xeno_ai_controller/runner/process_movement()
	if(!pilot || !current_target)
		return

	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)

	if(get_dist(pilot, current_target) <= 1 && pilot.Adjacent(current_target))
		ai_state = AI_STATE_ATTACKING
		blocked_attempts = 0
		path_queue = null
		return

	if(check_detonation_run())
		return

	if(attempt_pounce(current_target))
		return

	return ..()

/**
 * Acider-strain-only: the player detonation pattern - with a charged acid
 * tank, hold a few tiles out from the fight, then commit and run in to
 * explode, tanking whatever lands during the approach (the low-health bail
 * that governs everyone else deliberately doesn't apply once committed;
 * dying on the way just wastes the run, dying ON them is the whole point).
 * Commit triggers: a sister engages the target (their attention is split),
 * taking fire during the hold (standing still is worse), or the hold timer
 * lapsing. Returns TRUE while holding (no other movement this tick).
 */
/datum/xeno_ai_controller/runner/proc/check_detonation_run()
	var/datum/behavior_delegate/runner_acider/acider = pilot?.behavior_delegate
	if(!istype(acider) || acider.acid_amount < acider.max_acid * AI_ACIDER_CHARGED_PERCENT)
		detonation_hold_until = 0
		detonation_committed = FALSE
		return FALSE
	if(detonation_committed)
		return FALSE // Committed - the normal approach chain closes the distance; attempt_for_the_hive() fires on arrival.

	if(detonation_hold_until)
		if(world.time >= detonation_hold_until || (last_known_health && pilot.health < last_known_health) || count_engaged_allies(current_target))
			detonation_hold_until = 0
			detonation_committed = TRUE
			return FALSE
		pilot.setDir(get_dir(pilot, current_target))
		last_known_health = pilot.health
		return TRUE

	var/dist = get_dist(pilot, current_target)
	if(dist <= AI_ACIDER_HOLD_RANGE && dist > 2)
		detonation_hold_until = world.time + AI_ACIDER_HOLD_MAX_WAIT
		stage_start_health = pilot.health
		last_known_health = pilot.health
		pilot.setDir(get_dir(pilot, current_target))
		return TRUE
	return FALSE

/**
 * Fires Pounce at target if it's off cooldown and within its reach; returns
 * FALSE (and does nothing else) otherwise, so the caller falls back to the
 * inherited approach/pathfinding chain. "Calmer" pass: even once all the
 * real checks pass, only actually commits AI_RUNNER_POUNCE_CHANCE% of the
 * time - the rest of the time she just walks in normally, giving the target
 * a reaction window before the knockdown lands instead of eating it the
 * instant the ability comes off cooldown every single approach.
 */
/datum/xeno_ai_controller/runner/proc/attempt_pounce(atom/target)
	var/datum/action/xeno_action/activable/pounce/runner/pounce = get_ability(/datum/action/xeno_action/activable/pounce/runner)
	if(!pounce || !pounce.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > pounce.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // A pounce is a physical dash - tables/fences/barricades block it same as a wall would, not just line-of-sight.
		return FALSE
	if(!prob(AI_RUNNER_POUNCE_CHANCE))
		return FALSE
	pounce.use_ability(target)
	return TRUE

/**
 * Sidesteps to a flanking tile after landing an attack instead of either
 * standing adjacent or backing straight out - keeps her circling the
 * battlefield while attacking and dodging. Tries the preferred rotational
 * side first, then the opposite side if that's blocked, so a single
 * obstruction doesn't cancel the movement outright.
 *
 * Matches ravager.dm's own reposition gate: a reactive dodge is guaranteed
 * the instant she's actually taken damage since her last attack, otherwise
 * it's a AI_RUNNER_REPOSITION_CHANCE% baseline roll, not a certainty - she
 * still reads as constantly circling in a real fight (she's getting hit
 * plenty), just not literally every single tick regardless of whether
 * anything's happening.
 */
/datum/xeno_ai_controller/runner/process_attack()
	. = ..()
	if(!pilot || !current_target || ai_state != AI_STATE_ATTACKING)
		return
	// The signature Runner play: a marine she's knocked down gets dragged
	// out of their squad's cover fire to be finished off alone (isolation
	// only, never nesting - process_drag() owns the tow from here).
	if(ishuman(current_target))
		var/mob/living/carbon/human/downed = current_target
		if((downed.is_mob_incapacitated() || downed.body_position == LYING_DOWN) && prob(AI_RUNNER_DRAG_CHANCE) && attempt_start_drag(downed))
			drop_target()
			return
	var/took_damage = (last_known_health != null) && (pilot.health < last_known_health)
	last_known_health = pilot.health
	if(!took_damage && !prob(AI_RUNNER_REPOSITION_CHANCE))
		return
	var/target_dir = get_dir(pilot, current_target)
	if(!ai_step(turn(target_dir, circle_dir)))
		ai_step(turn(target_dir, -circle_dir))

/**
 * Acider-strain-only. attempt_pounce() above already no-ops for her -
 * Pounce is removed by the strain (actions_to_remove, acid.dm) - so no
 * separate branch is needed to skip it; she just fights in plain melee,
 * building acid passively off her own slashes (acid.dm's own mechanics,
 * nothing the AI needs to drive).
 */
/datum/xeno_ai_controller/runner/use_caste_ability(mob/living/target)
	return attempt_for_the_hive(target) || attempt_tail_stab(target)

/**
 * Fires the self-destruct on either of two triggers: (a) a committed
 * detonation run reaching its target (see check_detonation_run() - the
 * player pattern, charged acid walked deliberately into a group), or (b)
 * the original last stand - too hurt to matter AND cornered adjacent, where
 * exploding beats dying for nothing. Kills the caster outright (respawning
 * her as larva, acid.dm's do_caboom()); the ability's own acid_amount check
 * (runner_powers.dm) silently rejects a call without enough acid stored.
 */
/datum/xeno_ai_controller/runner/proc/attempt_for_the_hive(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/last_stand = pilot.maxHealth && (pilot.health / pilot.maxHealth) < AI_ACIDER_LAST_STAND_HEALTH_PERCENT && pilot.Adjacent(target)
	if(!detonation_committed && !last_stand)
		return FALSE
	if(detonation_committed && get_dist(pilot, target) > 1)
		return FALSE // Committed but not on them yet - keep closing.
	var/datum/action/xeno_action/activable/acider_for_the_hive/caboom = get_ability(/datum/action/xeno_action/activable/acider_for_the_hive)
	if(!caboom || !caboom.action_cooldown_check())
		return FALSE
	caboom.use_ability(pilot)
	return TRUE
