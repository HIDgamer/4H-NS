/**
 * Crusher AI - the hive's frontline tank: a slow, heavily-armored charger
 * built to soak damage and punch a hole in whatever's in front of it,
 * matching the user's "head-on scary" caste design (as opposed to
 * Ravager's hit-and-reposition style - see ravager.dm). Patrol/search
 * behavior is entirely inherited from the base controller - the three
 * overrides below are what make a Crusher feel different to fight:
 *
 * - While closing on a target still out of melee range, fires its Charge
 *   ability (a long dash that knocks down and hits hard on landing)
 *   instead of plodding over on foot - a Crusher is XENO_SPEED_TIER_2
 *   (the slowest AI caste built so far), so without this it would take
 *   noticeably longer than every other caste to actually reach a target.
 * - Stomps (a self-centered AoE) instead of a plain melee swing whenever
 *   more than one valid target is already in range, so a Crusher wading
 *   into a cluster of marines hits all of them, not just whichever one
 *   it happens to be facing.
 * - Flees at a much lower health fraction than the default - a Crusher
 *   is meant to be the wall the hive leans on, not a caste that breaks
 *   off at the first sign of trouble like a squishier one would.
 *
 * Also proactively pops its defensive Shield (explosion immunity + a
 * per-hit damage cap) once actually taking a beating (below half health)
 * but not yet at the much lower flee threshold - "hurt but still fighting,"
 * not a panic button held in reserve forever.
 *
 * Phase 3 audit note: deliberately has no post-attack reposition/dodge
 * logic (unlike Ravager/Warrior/etc's damage-reactive circle-step) - she's
 * the wall the hive leans on, standing and tanking IS her identity, not an
 * oversight. Base kit (Charge/Stomp/Shield) confirmed fully used and
 * sensibly gated; don't "fix" the missing dodge without re-reading this.
 */
/datum/xeno_ai_controller/crusher
	/// Charger strain: far end of the current momentum-lane pass (see check_charger_lane()) - null when not mid-pass.
	var/turf/charge_lane_end

/datum/xeno_ai_controller/crusher/get_flee_threshold()
	return AI_CRUSHER_FLEE_HEALTH_PERCENT

/**
 * Duplicates the base controller's adjacency-to-attacking transition and
 * obstacle-handling tail (see xeno_ai_movement.dm's process_movement())
 * rather than sharing it, since the trigger condition for "close in" is
 * fundamentally different here - a real shared-helper refactor is a
 * reasonable follow-up, not done here to avoid touching the
 * already-verified base melee path (same tradeoff ranged.dm already
 * made for the same reason).
 */
/datum/xeno_ai_controller/crusher/process_movement()
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

	if(attempt_charge(current_target))
		return

	attempt_charger_charge() // Side effect only (toggle) - never blocks the fallthrough walk below.

	if(check_charger_lane())
		return

	return ..()

/**
 * Charger-strain "moving train" pattern: momentum builds off sustained
 * straight-line movement (charger_charge, crusher_powers.dm), so instead of
 * pathing tightly to the target like everyone else - constant turns, zero
 * momentum - she picks a straight open LANE through the target's row/column,
 * runs it end to end (clipping whatever's in the path), then turns around
 * and picks the next pass. Needs open ground: no lane long enough means
 * cramped interior fighting, where she falls through to base Crusher
 * behavior instead. Returns TRUE while running a pass.
 */
/datum/xeno_ai_controller/crusher/proc/check_charger_lane()
	if(!get_ability(/datum/action/xeno_action/onclick/charger_charge))
		return FALSE // Not the Charger strain.

	if(charge_lane_end)
		if(get_dist(pilot, charge_lane_end) < 1 || get_turf(pilot) == charge_lane_end)
			charge_lane_end = null // Pass complete - turn around and line up the next one.
		else if(cardinal_step_towards(charge_lane_end))
			return TRUE
		else
			charge_lane_end = null // Pass got blocked mid-run - re-derive.

	charge_lane_end = find_charge_lane()
	if(!charge_lane_end)
		return FALSE
	cardinal_step_towards(charge_lane_end)
	return TRUE

/**
 * A straight, fully-open cardinal lane from the pilot through the target's
 * row/column plus a few tiles of overrun - the space a real charge pass
 * needs. Null when the ground is too cramped for the play at all.
 */
/datum/xeno_ai_controller/crusher/proc/find_charge_lane()
	var/turf/pilot_turf = get_turf(pilot)
	var/turf/target_turf = get_turf(current_target)
	if(!pilot_turf || !target_turf || pilot_turf.z != target_turf.z)
		return null

	var/dx = target_turf.x - pilot_turf.x
	var/dy = target_turf.y - pilot_turf.y
	var/lane_dir = (abs(dx) >= abs(dy)) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/horizontal = (lane_dir == EAST || lane_dir == WEST)

	var/turf/cursor = pilot_turf
	var/turf/last_open
	var/steps = 0
	var/crossed_target = FALSE
	var/overrun = 0
	while(steps < AI_CHARGER_LANE_MAX_LENGTH && overrun < AI_CHARGER_LANE_OVERRUN)
		cursor = get_step(cursor, lane_dir)
		if(!cursor || cursor.density)
			break
		var/blocked = FALSE
		for(var/obj/structure/blocker in cursor)
			if(blocker.density && !blocker.climbable)
				blocked = TRUE
				break
		if(blocked)
			break
		last_open = cursor
		steps++
		if(!crossed_target && (horizontal ? (cursor.x == target_turf.x) : (cursor.y == target_turf.y)))
			crossed_target = TRUE
		else if(crossed_target)
			overrun++

	// The pass has to actually cross the target's line AND be long enough
	// for momentum to mean anything - otherwise this isn't Charger country.
	if(!crossed_target || steps < AI_CHARGER_LANE_MIN_LENGTH)
		return null
	return last_open

/// Fires Charge at target if it's off cooldown and within its reach; returns FALSE (and does nothing else) otherwise, so the caller falls back to the inherited approach/pathfinding chain.
/datum/xeno_ai_controller/crusher/proc/attempt_charge(atom/target)
	var/datum/action/xeno_action/activable/pounce/crusher_charge/charge = get_ability(/datum/action/xeno_action/activable/pounce/crusher_charge)
	if(!charge || !charge.action_cooldown_check())
		return FALSE
	if(get_dist(pilot, target) > charge.distance)
		return FALSE
	if(!has_line_of_sight(target, physical_path = TRUE)) // "Immediately lunge and often get stuck on easily avoidable terrain (tables, fences, barricades)" - a dash needs a clear physical line, not just distance/no-walls, or she rams straight into furniture between her and the target.
		return FALSE
	charge.use_ability(target)
	return TRUE

/**
 * Charger-strain-only (Charge replaces base Crusher's pounce-based dash entirely, so
 * attempt_charge() above already no-ops for her via get_ability() returning null). Charge is
 * a persistent toggle (crusher_powers.dm's onclick/charger_charge/use_ability()) that builds
 * momentum automatically off her own movement once active, not a one-shot dash aimed at a
 * target - turning it on once and leaving it on for the walk-in gets the momentum/knockdown
 * payoff for free through the normal approach chain process_movement() already falls through
 * to below.
 */
/datum/xeno_ai_controller/crusher/proc/attempt_charger_charge()
	if(!pilot)
		return FALSE
	var/datum/action/xeno_action/onclick/charger_charge/charge = get_ability(/datum/action/xeno_action/onclick/charger_charge)
	if(!charge)
		return FALSE
	if(!charge.activated)
		charge.use_ability(pilot)
	return TRUE

/**
 * "Crusher never uses their stomping ability when near enemies" - Stomp
 * isn't just a self-centered AoE, it also knocks down everything it hits
 * (crusher_powers.dm's create_stomp()/get_xeno_stun_duration()), so it was
 * wrong to treat it as "strictly worse than a normal attack" against a lone
 * target and gate it behind 2+ nearby marines - a single-target knockdown
 * is still a big win, and 2+ marines standing that close together is the
 * less common case in practice, which is exactly why it read as "never"
 * firing. Now fires on anything valid in range, no minimum headcount.
 */
/datum/xeno_ai_controller/crusher/use_caste_ability(mob/living/target)
	if(!pilot)
		return FALSE

	attempt_shield() // Side effect only (own independent cooldown/plasma cost) - never blocks also using Stomp the same tick below.

	if(attempt_charger_fling(target))
		return TRUE

	var/datum/action/xeno_action/onclick/crusher_stomp/stomp = get_ability(/datum/action/xeno_action/onclick/crusher_stomp)
	if(!stomp || !stomp.action_cooldown_check())
		return FALSE

	var/found_target = FALSE
	for(var/mob/living/carbon/nearby in orange(stomp.distance, pilot))
		if(is_valid_target(nearby))
			found_target = TRUE
			break
	if(!found_target)
		return FALSE

	stomp.use_ability(pilot) // Atom arg is unused by this ability (self-centered AoE) - see crusher_powers.dm.
	return TRUE

/**
 * Charger-strain-only. Fling (shared with Warrior, granted here as
 * activable/fling/charger) needs an adjacent target - useful as a quick shove right as she
 * closes in on an isolated target, distinct from Stomp's AoE role below (checked first here
 * so a single target gets shoved rather than always eating the AoE).
 */
/datum/xeno_ai_controller/crusher/proc/attempt_charger_fling(mob/living/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/fling/charger/fling = get_ability(/datum/action/xeno_action/activable/fling/charger)
	if(!fling || !fling.action_cooldown_check())
		return FALSE
	if(!pilot.Adjacent(target))
		return FALSE
	fling.use_ability(target)
	return TRUE

/// Pops Shield once actually taking a beating (below half health) but above the much lower flee threshold - "hurt but still fighting."
/datum/xeno_ai_controller/crusher/proc/attempt_shield()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= 0.5)
		return FALSE
	var/datum/action/xeno_action/onclick/crusher_shield/shield = get_ability(/datum/action/xeno_action/onclick/crusher_shield)
	if(!shield || !shield.action_cooldown_check())
		return FALSE
	shield.use_ability(pilot)
	return TRUE

/**
 * "Instead of approaching, xenos should consider using abilities to close the
 * gap... not just to get to the enemy faster but escape it faster too" - a
 * Crusher is XENO_SPEED_TIER_2, the slowest AI caste built so far, so a plain
 * walk home is exactly the scenario this theme is meant to fix. Tries once
 * per return_to_anchor() tick before falling through to the normal walk, same
 * shape as attempt_charge()'s gap-close call in process_movement().
 */
/datum/xeno_ai_controller/crusher/return_to_anchor()
	attempt_tumble_retreat()
	return ..()

/**
 * Charger-strain-only - a baseline Crusher has no Tumble action at all, so
 * get_ability() returning null here IS the strain check, no separate lookup
 * needed. Tumble's use_ability() (crusher_powers.dm) needs a real atom to
 * compute which perpendicular direction to dodge toward - by the time
 * return_to_anchor() runs, tick()'s flee transition has already called
 * drop_target() and nulled current_target, so last_threat_turf (set at that
 * same transition, xeno_ai_controller.dm) stands in for the threat she's
 * putting distance from.
 */
/datum/xeno_ai_controller/crusher/proc/attempt_tumble_retreat()
	if(!pilot || !last_threat_turf)
		return FALSE
	var/datum/action/xeno_action/activable/tumble/tumble = get_ability(/datum/action/xeno_action/activable/tumble)
	if(!tumble || !tumble.action_cooldown_check())
		return FALSE
	tumble.use_ability(last_threat_turf)
	return TRUE
