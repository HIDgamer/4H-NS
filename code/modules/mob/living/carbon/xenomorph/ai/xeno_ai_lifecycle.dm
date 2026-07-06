/**
 * Attach/detach lifecycle for NPC-piloted xenomorphs, and the single canonical
 * spawn entry point. Both Stage 1's admin test spawn and Stage 2's wave/objective
 * spawners must funnel through spawn_ai_xeno() so the population cap is enforced
 * in exactly one place.
 *
 * Ghost takeover reuses the already-existing, unmodified /mob/proc/free_for_ghosts()
 * (code/modules/mob/mob_helpers.dm) and its claim_freed href handling
 * (code/modules/mob/dead/observer/observer.dm) - the same mechanism an unclaimed
 * King hatch already relies on. A ghost claiming the mob triggers a normal
 * mind.transfer_to(), which attaches a client and fires Login() exactly like any
 * other xeno join; the detach itself happens there (see login.dm).
 */

/// Support and assault roles ai_evolve_xeno() prefers filling over ranged/other options when both are eligible evolve targets - see the caste-selection loop there.
GLOBAL_LIST_INIT(ai_evolve_priority_castes, list(
	// Support
	XENO_CASTE_DRONE, XENO_CASTE_LESSER_DRONE, XENO_CASTE_HIVELORD, XENO_CASTE_CARRIER,
	// Assault
	XENO_CASTE_WARRIOR, XENO_CASTE_RAVAGER, XENO_CASTE_RUNNER, XENO_CASTE_LURKER,
	XENO_CASTE_DEFENDER, XENO_CASTE_CRUSHER, XENO_CASTE_PRAETORIAN, XENO_CASTE_BURROWER,
))

/**
 * Spawns a real, hive-linked xenomorph of the given caste and immediately attaches
 * AI control to it. Returns the new mob, or null if the spawn was refused (unknown
 * caste, no spawn turf, or the caste's own per-caste cap is full).
 */
/proc/spawn_ai_xeno(caste_type = XENO_CASTE_DRONE, turf/spawn_turf, hivenumber = XENO_HIVE_NORMAL, turf/anchor_override)
	if(!spawn_turf)
		return null

	var/mob_type = GLOB.RoleAuthority.get_caste_by_text(caste_type)
	if(!mob_type)
		return null

	var/mob/living/carbon/xenomorph/new_xeno = new mob_type(spawn_turf, null, hivenumber)
	if(!attach_xeno_ai(new_xeno, anchor_override || spawn_turf))
		new_xeno.free_for_ghosts(TRUE) // Attach refused (almost always a full per-caste cap) - still claimable directly by a ghost.
		return new_xeno // Mob exists but AI attach failed; hand back the plain mob rather than leaking it.

	return new_xeno

/**
 * Composes a fresh AI controller onto an existing, clientless xenomorph and starts
 * its decision loop. Returns FALSE (no-op) if the mob already has a client or an
 * AI controller.
 */
/proc/attach_xeno_ai(mob/living/carbon/xenomorph/xeno, turf/anchor_override)
	if(!xeno || xeno.client || xeno.ai_controller)
		return FALSE

	var/caste_cap = GLOB.ai_xeno_max_per_caste[xeno.caste_type]
	if(caste_cap && count_active_ai_xenos_of_caste(xeno.caste_type) >= caste_cap)
		return FALSE

	var/controller_type = get_ai_controller_type_for_caste(xeno.caste_type)
	xeno.ai_controller = new controller_type(xeno)
	if(anchor_override)
		xeno.ai_controller.anchor_turf = anchor_override
	xeno.is_ai_controlled = TRUE
	xeno.was_ai_spawned = TRUE

	GLOB.ai_xeno_list += xeno
	GLOB.ai_xeno_active_count++

	xeno.ai_controller.start()
	xeno.free_for_ghosts(TRUE) // Lets a ghost claim the mob mid-fight at any time, same mechanism as an unclaimed King hatch.

	return TRUE

/**
 * Tears down AI control on a xenomorph, either because a client just attached
 * (ghost takeover - see login.dm's Login() hook) or because it's dying/being
 * deleted. Leaves the mob itself untouched.
 */
/proc/detach_xeno_ai(mob/living/carbon/xenomorph/xeno)
	if(!xeno || !xeno.ai_controller)
		return FALSE

	xeno.ai_controller.stop()
	QDEL_NULL(xeno.ai_controller)
	xeno.is_ai_controlled = FALSE

	GLOB.ai_xeno_list -= xeno
	GLOB.ai_xeno_active_count = max(0, GLOB.ai_xeno_active_count - 1)

	return TRUE

/**
 * Re-attaches AI control after a player who was piloting a formerly-AI-spawned
 * xeno disconnects, so waves/objectives don't go permanently quiet just because a
 * ghost left. Anchors to the mob's current position, not its original spawn point,
 * so it doesn't unrealistically walk back across the map. Only fires for mobs that
 * were originally AI-spawned (was_ai_spawned) - ordinary players disconnecting
 * behave exactly as today.
 */
/proc/reattach_xeno_ai_on_disconnect(mob/living/carbon/xenomorph/xeno)
	if(!xeno || !xeno.was_ai_spawned || xeno.client || xeno.stat == DEAD)
		return FALSE

	return attach_xeno_ai(xeno, get_turf(xeno))

/**
 * AI-safe evolution - mirrors do_evolve()'s actual mob-creation mechanics
 * (Evolution.dm) but skips every usr/client-dependent step (the radial/
 * tgui caste picker, do_after windup, chat messages) since an AI-piloted
 * xeno has neither. Reuses the real evolve_checks()/can_evolve() gates
 * so an AI xeno is bound by exactly the same full-health/restrained/
 * hardcore/hive-slot-capacity/minimum_evolve_time rules a player would be -
 * this only replaces the player-input layer, not the actual eligibility
 * rules. Returns the new mob on success (with a fresh AI controller
 * already attached) or null if nothing was eligible yet - the old mob is
 * left completely untouched on failure.
 *
 * Never offers Queen (she's singular and already AI-controlled by the
 * time this economy is running at all), Predalien, or Hellhound - those
 * are excluded explicitly even though in practice the normal evolves_to
 * chain can't reach the latter two anyway (see the caste audit).
 */
/proc/ai_evolve_xeno(mob/living/carbon/xenomorph/xeno)
	if(!xeno || QDELETED(xeno) || xeno.client || !xeno.hive || !xeno.caste)
		return null
	if(!length(xeno.caste.evolves_to))
		return null
	if(!xeno.evolve_checks())
		return null

	var/list/castes_available = xeno.caste.evolves_to.Copy()
	for(var/caste_option in castes_available.Copy())
		if(caste_option == XENO_CASTE_QUEEN || caste_option == XENO_CASTE_PREDALIEN || caste_option == XENO_CASTE_HELLHOUND)
			castes_available -= caste_option
			continue
		var/datum/caste_datum/option_caste = GLOB.xeno_datum_list[caste_option]
		if(!option_caste || option_caste.minimum_evolve_time > ROUND_TIME)
			castes_available -= caste_option

	if(!length(castes_available))
		return null

	// "They should try to fill in most slots support and assault" - prefer
	// whichever eligible options are support/assault roles (see
	// GLOB.ai_evolve_priority_castes) over ranged/other options, and try
	// every option in that preferred order rather than a single random pick
	// that gives up outright if it happens to land on a caste the hive's
	// tier slots are currently full for (can_evolve() already checks that -
	// previously a bad roll just meant no evolution at all this cycle,
	// waiting AI_EVOLVE_CHECK_INTERVAL to try again from scratch).
	var/list/ordered_castes = list()
	var/list/priority_options = castes_available & GLOB.ai_evolve_priority_castes
	var/list/other_options = castes_available - GLOB.ai_evolve_priority_castes
	while(length(priority_options))
		ordered_castes += pick_n_take(priority_options)
	while(length(other_options))
		ordered_castes += pick_n_take(other_options)

	var/castepick
	for(var/caste_option in ordered_castes)
		if(xeno.can_evolve(caste_option, 0)) // potential_queens=0: the only branch that reads it requires !hive.living_xeno_queen, moot here since a living AI Queen is what's driving this economy in the first place.
			castepick = caste_option
			break
	if(!castepick)
		return null

	var/mob_type = GLOB.RoleAuthority.get_caste_by_text(castepick)
	if(!mob_type)
		return null

	xeno.evolution_stored -= xeno.evolution_threshold
	var/obj/item/organ/xeno/organ = locate() in xeno
	if(!isnull(organ))
		qdel(organ)

	return replace_ai_xeno_mob(xeno, mob_type)

/**
 * Shared mob-replacement mechanics for turning one AI-piloted xenomorph into another
 * caste in place - qdels the old mob, constructs the new one, carries over tier
 * bookkeeping/health-fraction/plasma-fraction/built structures, and re-attaches AI
 * control.
 */
/proc/replace_ai_xeno_mob(mob/living/carbon/xenomorph/old_xeno, mob_type)
	var/mob/living/carbon/xenomorph/new_xeno = new mob_type(get_turf(old_xeno), old_xeno)
	if(!istype(new_xeno))
		if(new_xeno)
			qdel(new_xeno)
		return null

	new_xeno.creation_time = old_xeno.creation_time

	var/area/xeno_area = get_area(new_xeno)
	if(!should_block_game_interaction(new_xeno) || (xeno_area.flags_atom & AREA_ALLOW_XENO_JOIN))
		switch(new_xeno.tier)
			if(2)
				old_xeno.hive.tier_2_xenos |= new_xeno
			if(3)
				old_xeno.hive.tier_3_xenos |= new_xeno

	new_xeno.generate_name()
	if(new_xeno.health - old_xeno.getBruteLoss() - old_xeno.getFireLoss() > 0)
		new_xeno.bruteloss = old_xeno.bruteloss
		new_xeno.fireloss = old_xeno.fireloss
		new_xeno.updatehealth()

	if(old_xeno.plasma_max == 0)
		new_xeno.plasma_stored = new_xeno.plasma_max
	else
		new_xeno.plasma_stored = new_xeno.plasma_max * (old_xeno.plasma_stored / old_xeno.plasma_max)

	new_xeno.built_structures = old_xeno.built_structures?.Copy()

	log_game("EVOLVE: [key_name(old_xeno)] (AI) evolved into [new_xeno].")
	SEND_SIGNAL(old_xeno, COMSIG_XENO_EVOLVE_TO_NEW_CASTE, new_xeno)

	var/turf/new_turf = get_turf(new_xeno)
	qdel(old_xeno) // Destroy() already detaches the old AI controller (see Xenomorph.dm) before this proc returns.
	attach_xeno_ai(new_xeno, new_turf)

	return new_xeno

/// Count of currently AI-piloted xenos of one specific caste - backs the optional per-caste caps in GLOB.ai_xeno_max_per_caste. A plain scan is fine here rather than maintaining a second set of per-caste counters.
/proc/count_active_ai_xenos_of_caste(caste_type)
	var/count = 0
	for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
		if(xeno.caste_type == caste_type)
			count++
	return count

/**
 * Per-caste controller dispatch table (see code/modules/mob/living/carbon/xenomorph/ai/castes/
 * for the concrete subtypes). Every caste not listed here still gets a
 * fully-functional xeno, just with the generic Stage 1 melee/patrol
 * controller rather than a specialized one - this list only needs entries
 * for castes whose behavior genuinely differs, not every caste in the game.
 */
/proc/get_ai_controller_type_for_caste(caste_type)
	switch(caste_type)
		if(XENO_CASTE_QUEEN)
			return /datum/xeno_ai_controller/queen
		if(XENO_CASTE_KING)
			return /datum/xeno_ai_controller/king
		if(XENO_CASTE_DRONE, XENO_CASTE_LESSER_DRONE)
			return /datum/xeno_ai_controller/drone_worker
		if(XENO_CASTE_HIVELORD)
			return /datum/xeno_ai_controller/hivelord
		if(XENO_CASTE_BURROWER)
			return /datum/xeno_ai_controller/burrower
		if(XENO_CASTE_CARRIER)
			return /datum/xeno_ai_controller/carrier
		if(XENO_CASTE_SPITTER)
			return /datum/xeno_ai_controller/ranged/spitter
		if(XENO_CASTE_SENTINEL)
			return /datum/xeno_ai_controller/ranged/sentinel
		if(XENO_CASTE_BOILER)
			return /datum/xeno_ai_controller/ranged/boiler
		if(XENO_CASTE_CRUSHER)
			return /datum/xeno_ai_controller/crusher
		if(XENO_CASTE_RAVAGER)
			return /datum/xeno_ai_controller/ravager
		if(XENO_CASTE_RUNNER)
			return /datum/xeno_ai_controller/runner
		if(XENO_CASTE_WARRIOR)
			return /datum/xeno_ai_controller/warrior
		if(XENO_CASTE_DEFENDER)
			return /datum/xeno_ai_controller/defender
		if(XENO_CASTE_LURKER)
			return /datum/xeno_ai_controller/lurker
		if(XENO_CASTE_PRAETORIAN)
			return /datum/xeno_ai_controller/praetorian
		if(XENO_CASTE_PREDALIEN)
			return /datum/xeno_ai_controller/predalien
		if(XENO_CASTE_FACEHUGGER)
			return /datum/xeno_ai_controller/facehugger
		if(XENO_CASTE_LARVA)
			return /datum/xeno_ai_controller/larva
	return /datum/xeno_ai_controller
