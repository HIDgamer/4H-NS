/**
 * Boiler AI - "should only use ranged attacks, and only attack if enemies
 * get too close, otherwise attack ranged, hide, then come out to attack
 * again once the ability has recharged." Bombard has a genuine 60s cooldown
 * (general_abilities.dm's base xeno_spit, which bombard inherits unchanged)
 * - the ranged base's own melee fallback (ranged.dm's process_attack(), used
 * whenever nothing's off cooldown) would have her closing to melee for most
 * of that minute, exactly the opposite of "only use ranged attacks." Fully
 * overrides both process_attack() and process_movement() instead of
 * inheriting the shared kiting policy: rotates Bombard/Spray Acid (10s
 * cooldown - the old code never actually looked at this second ability, so
 * there was nothing to fall back on but melee) when either is up, actively
 * retreats out to a safe distance whenever both are on cooldown instead of
 * holding the kiting band and waiting to get pounced on, and only ever
 * swings in melee once something is already adjacent.
 */
/datum/xeno_ai_controller/ranged/boiler

/datum/xeno_ai_controller/ranged/boiler/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_BOILER_ATTACK_DISTANCE

/datum/xeno_ai_controller/ranged/boiler/get_flee_threshold()
	return AI_BOILER_FLEE_HEALTH_PERCENT

/**
 * Trapper strain removes bombard/spray_acid entirely (get_ability() already
 * no-ops the base chain below for her), so her own ranged kit - Acid Mine
 * (the strain's real cooldown-gated hitter) then Acid Shotgun (always-there
 * filler, same "return it regardless of cooldown, let the caller check"
 * shape the base spray_acid fallback already uses) - is checked first.
 */
/datum/xeno_ai_controller/ranged/boiler/get_ranged_ability()
	var/datum/action/xeno_action/activable/acid_mine/mine = get_ability(/datum/action/xeno_action/activable/acid_mine)
	if(mine && mine.action_cooldown_check())
		return mine
	var/datum/action/xeno_action/activable/acid_shotgun/shotgun = get_ability(/datum/action/xeno_action/activable/acid_shotgun)
	if(shotgun)
		return shotgun
	var/datum/action/xeno_action/activable/xeno_spit/bombard/bombard = get_ability(/datum/action/xeno_action/activable/xeno_spit/bombard)
	if(bombard && bombard.action_cooldown_check())
		return bombard
	return get_ability(/datum/action/xeno_action/activable/spray_acid/boiler)

/**
 * "Different gas types, Boiler doesn't switch between them on demand" -
 * shift_spits/boiler is a plain toggle between neurotoxin gas
 * (boiler_gas - crowd-control smoke, stun/knockdown/DAZE) and acid gas
 * (boiler_gas/acid - straight damage-over-time smoke, xeno.dm's two ammo
 * types), granted to base Boiler only (Trapper removes it - get_ability()
 * already no-ops this for her). Same compare-desired-against-current-then-
 * toggle-only-if-different pattern as queen.dm's select_spit_type(): neuro
 * gas when the target isn't alone (crowd control is worth more against a
 * group), acid gas otherwise (straight damage against a lone/tanky target).
 */
/datum/xeno_ai_controller/ranged/boiler/proc/attempt_shift_spits(mob/living/target)
	if(!pilot)
		return
	var/nearby_targets = 0
	for(var/mob/living/carbon/nearby in orange(3, target))
		if(!is_valid_target(nearby))
			continue
		nearby_targets++
		if(nearby_targets >= 2)
			break
	var/desired_type = (nearby_targets >= 2) ? /datum/ammo/xeno/boiler_gas : /datum/ammo/xeno/boiler_gas/acid
	if(pilot.ammo == GLOB.ammo_list[desired_type])
		return
	var/datum/action/xeno_action/onclick/shift_spits/boiler/shift = get_ability(/datum/action/xeno_action/onclick/shift_spits/boiler)
	shift?.use_ability(pilot)

/datum/xeno_ai_controller/ranged/boiler/process_attack()
	if(!pilot || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(pilot.Adjacent(current_target)) // Cornered - fight back rather than just standing there and dying.
		execute_attack(current_target)
		return

	var/datum/action/xeno_action/ability = get_ranged_ability()
	if(ability && ability.action_cooldown_check() && has_line_of_sight(current_target))
		pilot.setDir(get_dir(pilot, current_target))
		ability.use_ability(get_ranged_aim_point(ability, current_target))
	ai_state = AI_STATE_APPROACHING // Always re-evaluate positioning next tick, win or lose - process_movement() below decides hide vs. hold vs. close in.

/**
 * "Consider adjusting their aim instead of firing at the position the enemy
 * was first in" - Bombard's own windup (xeno_spit/use_ability(), general_powers.dm)
 * snapshots its aim turf once, before a genuine 5-second cast bar, and never
 * re-checks it once committed - a real, presumably intentional player-facing
 * "dodge the bombardment by moving during the tell" mechanic, not something
 * to change for players by touching the shared ability. The AI-side fix
 * belongs entirely in WHERE she aims, not in the ability itself: lead the
 * shot using the target's most recent heading (last_seen_turf, already
 * tracked every process_movement() tick) instead of firing at exactly where
 * they're standing the instant she commits. Spray Acid re-derives its target
 * position live after its own delay (general_powers.dm's spray_acid/use_ability()
 * calls get_turf(A)/get_line(X, A, ...) AFTER the do_after(), not before) -
 * no staleness to correct for there, so this only actually changes anything
 * for Bombard.
 */
/datum/xeno_ai_controller/ranged/boiler/proc/get_ranged_aim_point(datum/action/xeno_action/ability, atom/target)
	var/turf/current_turf = get_turf(target)
	if(!istype(ability, /datum/action/xeno_action/activable/xeno_spit/bombard) || !current_turf || !last_seen_turf || last_seen_turf == current_turf)
		return current_turf // Nothing to lead with - already-correct ability, no turf, or target hasn't moved since we last looked.

	var/lead_dir = get_dir(last_seen_turf, current_turf)
	if(!lead_dir)
		return current_turf

	var/turf/lead_turf = current_turf
	for(var/i in 1 to AI_BOILER_BOMBARD_LEAD_TILES)
		var/turf/next_step = get_step(lead_turf, lead_dir)
		if(!next_step || next_step.density)
			break
		lead_turf = next_step
	return lead_turf

/**
 * "Attack ranged, hide, then come out to attack again once the ability has
 * recharged" - retreats to a wider, safer distance whenever nothing's off
 * cooldown, instead of holding the plain ranged kiting band and waiting
 * around to get closed on. Once something's ready again, closes back in to
 * the normal preferred band so process_attack() can actually use it.
 */
/datum/xeno_ai_controller/ranged/boiler/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	last_seen_turf = get_turf(current_target)
	attempt_boiler_trap(current_target) // Trapper-only, side effect only - never blocks anything below.
	attempt_shift_spits(current_target) // Base-kit-only (Trapper has no shift_spits, removed by the strain), side effect only.
	var/dist = get_dist(pilot, current_target)

	// "Boiler just stands there instead of taking cover and then returning
	// once their main glob attack is restarted" - get_ranged_ability()
	// always returns *something* once Bombard's on cooldown (it falls back
	// to Spray Acid unconditionally, existence only), so `!!get_ranged_ability()`
	// was truthy essentially all the time regardless of whether Spray Acid
	// itself was actually off cooldown - the hide branch below could never
	// trigger. Checks the returned ability's own cooldown directly instead.
	var/datum/action/xeno_action/ability = get_ranged_ability()
	var/ability_ready = ability && ability.action_cooldown_check()
	if(!ability_ready)
		if(dist < AI_BOILER_HIDE_DISTANCE)
			attempt_acid_shroud_retreat() // Side effect only - covers the walk-away below, doesn't change whether it happens.
			var/turf/defensible = find_cover_turf(current_target) || find_defensible_turf()
			if(defensible && get_dist(pilot, defensible) > 0 && cardinal_step_towards(defensible, avoid_mobs = TRUE))
				return
			var/away_dir = get_dir(current_target, pilot)
			if(!ai_step(away_dir))
				navigate_around(current_target)
			return
		return // Already far enough out - just sit tight and let the cooldown run.

	// Ability's up - same continuous-kiting policy every other ranged caste
	// uses (xeno_ai_movement.dm's maintain_kiting_distance()) instead of the
	// old static hold-band that let a marine close in unopposed. seek_cover
	// so holding the band while ready to fire doesn't mean standing dead
	// still either.
	maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE, seek_cover = TRUE)

/**
 * Trapper-strain-only. Deviates from the Phase 2 plan's original "idle
 * patrol()-driven placement" wording - Boiler Trap needs a real, visible
 * atom to aim at (can_see()-gated), and she has no target reference while
 * genuinely idle. Firing it at current_target while still closing lays it
 * directly in the path of the thing she's actually fighting instead of a
 * blind guess at nothing while wandering.
 */
/datum/xeno_ai_controller/ranged/boiler/proc/attempt_boiler_trap(atom/target)
	if(!pilot || !target)
		return FALSE
	var/datum/action/xeno_action/activable/boiler_trap/trap = get_ability(/datum/action/xeno_action/activable/boiler_trap)
	if(!trap || !trap.action_cooldown_check())
		return FALSE
	if(!can_see(pilot, target, TRAPPER_VIEWRANGE))
		return FALSE
	trap.use_ability(target)
	return TRUE

/**
 * "Cover the retreat instead of a plain visible walk-away" (§1.7's
 * gap-close/escape theme). Acid Shroud drops a blinding gas cloud on
 * herself - firing it right as she turns to hide buys the same moment of
 * cover a smoke grenade would, instead of it sitting unused as a button the
 * AI never otherwise reaches for. Health-gated to AI_BOILER_FLEE_HEALTH_PERCENT
 * so it's spent when the retreat is actually urgent, not on every routine
 * cooldown-hide cycle.
 */
/datum/xeno_ai_controller/ranged/boiler/proc/attempt_acid_shroud_retreat()
	if(!pilot || !pilot.maxHealth || (pilot.health / pilot.maxHealth) >= AI_BOILER_FLEE_HEALTH_PERCENT)
		return FALSE
	var/datum/action/xeno_action/onclick/acid_shroud/shroud = get_ability(/datum/action/xeno_action/onclick/acid_shroud)
	if(!shroud || !shroud.action_cooldown_check())
		return FALSE
	shroud.use_ability(pilot)
	return TRUE
