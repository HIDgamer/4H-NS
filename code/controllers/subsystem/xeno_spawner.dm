/**
 * "I want all commanding and spawning features removed and replaced with a simple Spawner.
 * It spawns AI all over the map based on the amount of players awake and parameters given
 * like difficulty, and so on." Replaces the old Hive Population Director (per-hive economy
 * datum, instant/organic spawn styles, a persistent threat-score/siege-escalation system,
 * admin-issued manual hive commands) entirely - this is a flat, stateless subsystem with no
 * per-hive datum, since none of that economy/threat state exists to own any more.
 *
 * "Keep the queen's hive building like core and ovi, allowing there to be an objective, if
 * the hive core and the queen die, the xenos stop spawning" - the Hive Core (built by the
 * Queen's own AI, queen.dm) is the objective this Spawner respects: no Core, no
 * reinforcement, full stop (see spawner_maintain_population()'s Core gate). A hive that's
 * lost its Core can still fight with whatever xenos already exist, it just never gets
 * backfilled again. spawner_ensure_queen() (reusing the exact reasoning the old Director's
 * ensure_queen() used) handles two distinct cases with the same call: bootstrapping the very
 * first Queen for a hive that never got a player one (round start has no guarantee a player
 * picks the Queen role, especially on a PvE-focused server), and auto-replacing a Queen who
 * died after the Core was already built - so losing just the Queen is never a permanent loss,
 * only losing the Core too actually ends reinforcement for good.
 */
SUBSYSTEM_DEF(xeno_spawner)
	name = "Xeno Spawner"
	wait = XENO_SPAWNER_CHECK_INTERVAL
	flags = SS_NO_INIT | SS_KEEP_TIMING
	priority = SS_PRIORITY_XENO_SPAWNER

	/// Current pressure-rhythm phase (HIVE_PHASE_BUILDUP/ASSAULT/LULL) - buildup fills population normally, assault broadcasts a hive-wide push at the marines and spawns faster, lull pauses reinforcement entirely. See update_hive_phase().
	var/hive_phase = HIVE_PHASE_BUILDUP
	/// world.time the current phase rolls over into the next one.
	var/phase_ends_at = 0

/**
 * Targets exactly one hive, GLOB.xeno_spawner_hive (admin-selectable, see
 * event_tab.dm's set_spawner_hive) rather than every entry in GLOB.hive_datum
 * (13 hive numbers, mobs.dm's XENO_HIVE_* list, ALL unconditionally
 * instantiated at global-var init regardless of whether they're actually in
 * play a given round - global_lists.dm) - null means no hive selected, spawn
 * nothing.
 */
/datum/controller/subsystem/xeno_spawner/fire(resumed = FALSE)
	if(!GLOB.xeno_spawner_enabled || !GLOB.xeno_spawner_hive || SSticker?.current_state < GAME_STATE_PLAYING)
		return
	var/datum/hive_status/hive = GLOB.hive_datum[GLOB.xeno_spawner_hive]
	if(!hive)
		return
	update_hive_phase(hive)
	if(hive_phase == HIVE_PHASE_LULL)
		spawner_ensure_queen(hive) // A Queen loss is never gated behind pacing - only regular reinforcement pauses.
		return
	spawner_maintain_population(hive, hive_phase == HIVE_PHASE_ASSAULT)

/**
 * Advances the buildup -> assault -> lull rhythm and, while assaulting,
 * keeps the hive-wide attack broadcast fresh. The assault reuses the
 * existing queen_alert_turf/respond_to_hive_alert() infrastructure - idle
 * xenos already know how to converge on a hive alert, this just points one
 * at the marines' center of mass on a rhythm instead of only when the AI
 * Queen personally spots a target. Durations scale with the difficulty
 * multiplier: harder = shorter buildups/lulls, longer assaults.
 */
/datum/controller/subsystem/xeno_spawner/proc/update_hive_phase(datum/hive_status/hive)
	var/pacing_mult = clamp(GLOB.ai_difficulty_multiplier, 0.5, 2)
	if(!phase_ends_at)
		phase_ends_at = world.time + rand(XENO_SPAWNER_BUILDUP_MIN, XENO_SPAWNER_BUILDUP_MAX) / pacing_mult

	if(world.time >= phase_ends_at)
		switch(hive_phase)
			if(HIVE_PHASE_BUILDUP)
				hive_phase = HIVE_PHASE_ASSAULT
				phase_ends_at = world.time + rand(XENO_SPAWNER_ASSAULT_MIN, XENO_SPAWNER_ASSAULT_MAX) * pacing_mult
			if(HIVE_PHASE_ASSAULT)
				hive_phase = HIVE_PHASE_LULL
				phase_ends_at = world.time + XENO_SPAWNER_LULL_DURATION / pacing_mult
			else
				hive_phase = HIVE_PHASE_BUILDUP
				phase_ends_at = world.time + rand(XENO_SPAWNER_BUILDUP_MIN, XENO_SPAWNER_BUILDUP_MAX) / pacing_mult

	if(hive_phase == HIVE_PHASE_ASSAULT)
		var/turf/assault_turf = spawner_marine_mass_turf()
		if(assault_turf)
			hive.queen_alert_turf = assault_turf
			hive.queen_alert_time = world.time

/// Admin override (AdminAIDifficulty UI): jump straight to a phase; the normal rhythm resumes from there.
/datum/controller/subsystem/xeno_spawner/proc/force_hive_phase(new_phase)
	hive_phase = new_phase
	phase_ends_at = 0
	switch(new_phase)
		if(HIVE_PHASE_ASSAULT)
			phase_ends_at = world.time + XENO_SPAWNER_ASSAULT_MAX
		if(HIVE_PHASE_LULL)
			phase_ends_at = world.time + XENO_SPAWNER_LULL_DURATION

/**
 * The turf of the living ground-side marine closest to all living
 * ground-side marines' average position - i.e. where the marine force
 * actually is, snapped to a real reachable marine rather than an arbitrary
 * midpoint that could land inside a wall or between two split squads.
 */
/proc/spawner_marine_mass_turf()
	var/list/ground_levels = SSmapping.levels_by_trait(ZTRAIT_GROUND)
	var/total_x = 0
	var/total_y = 0
	var/list/mob/living/carbon/human/ground_marines = list()
	for(var/mob/living/carbon/human/marine as anything in GLOB.alive_human_list)
		if(marine.faction != FACTION_MARINE || !(marine.z in ground_levels))
			continue
		ground_marines += marine
		total_x += marine.x
		total_y += marine.y
	if(!length(ground_marines))
		return null
	var/avg_x = total_x / length(ground_marines)
	var/avg_y = total_y / length(ground_marines)
	var/mob/living/carbon/human/closest
	var/closest_dist_sq = INFINITY
	for(var/mob/living/carbon/human/marine as anything in ground_marines)
		var/dist_sq = (marine.x - avg_x) ** 2 + (marine.y - avg_y) ** 2
		if(dist_sq < closest_dist_sq)
			closest_dist_sq = dist_sq
			closest = marine
	return get_turf(closest)

/// Target population share (out of 100) each caste holds once a hive reaches its target population - a flat weighted-random table, deliberately NOT tier-slot/hive-economy accounting like the old Director's version. Data, not code - tune here, not in procs.
GLOBAL_LIST_INIT(xeno_spawner_caste_weights, list(
	XENO_CASTE_DRONE     = 14, XENO_CASTE_RUNNER     = 10, XENO_CASTE_SENTINEL = 6, XENO_CASTE_DEFENDER = 6,
	XENO_CASTE_HIVELORD  = 4,  XENO_CASTE_CARRIER    = 2,  XENO_CASTE_BURROWER = 3,
	XENO_CASTE_WARRIOR   = 10, XENO_CASTE_LURKER     = 5,  XENO_CASTE_SPITTER  = 5,
	XENO_CASTE_CRUSHER   = 3,  XENO_CASTE_PRAETORIAN = 3,  XENO_CASTE_RAVAGER  = 3, XENO_CASTE_BOILER = 2,
))

/**
 * Core per-hive maintenance pass. No per-hive datum, no per-hive state beyond what
 * hive_status already tracks (has_structure(), living_xeno_queen, next_queen_spawn_attempt) -
 * everything else is computed fresh every call.
 *
 * spawner_ensure_queen() runs unconditionally, BEFORE the Core gate below - a hive with no
 * Queen also has no Core yet (the Queen builds it herself, queen.dm), so gating the Queen
 * spawn on the Core existing was circular: no Queen meant no Core, no Core meant the gate
 * blocked the only thing that could ever create a Queen, so a hive that never got a player
 * Queen (normal round start, cm_initialize.dm's pick_queen_spawn() - a PvE-focused server can
 * easily have zero players wanting that role) simply never bootstrapped at all. The Core gate
 * still applies to the regular population backfill loop below - it's the reinforcement
 * objective, not the Queen-bootstrap step.
 */
/proc/spawner_maintain_population(datum/hive_status/hive, assaulting = FALSE)
	spawner_ensure_queen(hive)

	// The objective gate - see this file's doc comment. Checked first, before the actual
	// reinforcement loop: no Hive Core, no reinforcement, full stop.
	if(!hive.has_structure(XENO_STRUCTURE_CORE))
		return

	var/target = spawner_target_population()
	var/current = 0
	for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
		if(xeno.hivenumber == hive.hivenumber && xeno.counts_for_slots)
			current++
	if(current >= target)
		return // Never touches an existing xeno - this early-return, plus the Core gate above, are the only population ceiling.

	// "Hook the spawn rate to the difficulty" - GLOB.ai_difficulty_multiplier already scales
	// the eventual population target (spawner_target_population()); scaling how many spawn
	// per fire too means difficulty also controls how fast the hive actually ramps up toward
	// that target, not just where it tops out. Floored at 1 so a low difficulty never fully
	// stalls reinforcement, just slows it. An active assault phase doubles the rate - the
	// push should feel like a wave, not the same background trickle.
	var/max_per_fire = max(1, round(XENO_SPAWNER_MAX_PER_FIRE * GLOB.ai_difficulty_multiplier)) * (assaulting ? 2 : 1)
	var/spawned_this_fire = 0
	while(current < target && spawned_this_fire < max_per_fire)
		var/caste_type = spawner_pick_caste()
		if(!caste_type)
			break
		var/turf/spawn_turf = spawner_pick_spawn_turf()
		if(!spawn_turf)
			break
		var/mob/living/carbon/xenomorph/new_xeno = spawn_ai_xeno(caste_type, spawn_turf, hive.hivenumber)
		if(istype(new_xeno))
			spawner_maybe_assign_strain(new_xeno)
			spawner_max_out_carrier_eggs(new_xeno)
		current++
		spawned_this_fire++

/**
 * "Carrier should spawn with eggs maxed out for AI only" - a player Carrier earns her egg
 * stockpile over the round (attempt_carry_egg()'s idle restocking, carrier.dm), which makes
 * sense for a piloted mob but would leave an AI-spawned one with nothing to actually throw for
 * a long stretch after spawning. AI-only and deliberately placed after
 * spawner_maybe_assign_strain() above, not in attach_xeno_ai() (xeno_ai_lifecycle.dm) - so if
 * she rolled the Eggsac strain (which raises eggs_max from 8 to 12, strains/castes/carrier/
 * eggsac.dm), eggs_cur gets maxed against the already-updated cap, not the pre-strain one.
 */
/proc/spawner_max_out_carrier_eggs(mob/living/carbon/xenomorph/xeno)
	var/mob/living/carbon/xenomorph/carrier/carrier_xeno = xeno
	if(!istype(carrier_xeno))
		return
	carrier_xeno.eggs_cur = carrier_xeno.eggs_max

/**
 * "Special AI per strains for each alien" (Phase 2) needs some AI-spawned xenos to actually
 * carry a strain first - xeno.strain (Xenomorph.dm) is otherwise only ever set by the
 * player-facing purchase_strain() verb, so an AI-spawned xeno never got one before this.
 * Calls /datum/xeno_strain/proc/_add_to_xeno() directly - the same plain callable proc the
 * player verb uses after its own UI/confirmation steps, none of which apply to a xeno the
 * instant it's spawned at full health with no strain yet.
 */
/proc/spawner_maybe_assign_strain(mob/living/carbon/xenomorph/xeno)
	if(!length(xeno.caste.available_strains))
		return
	if(!prob(XENO_SPAWNER_STRAIN_CHANCE))
		return
	var/strain_type = pick(xeno.caste.available_strains)
	var/datum/xeno_strain/strain_instance = new strain_type()
	strain_instance._add_to_xeno(xeno)

/**
 * Auto-replaces a dead Queen whenever the Core still stands, so losing just the Queen isn't
 * a permanent loss for the hive - reuses the old Director's ensure_queen() logic and
 * reasoning essentially unchanged. Never double-spawns: add_xeno() (hive_status.dm) already
 * guards set_living_xeno_queen() behind if(!living_xeno_queen), and BYOND's single-threaded
 * execution means there's no window for a second call to run before hive.living_xeno_queen
 * is already populated by this same synchronous spawn.
 */
/proc/spawner_ensure_queen(datum/hive_status/hive)
	if(hive.living_xeno_queen && hive.living_xeno_queen.stat != DEAD)
		return
	if(world.time < hive.next_queen_spawn_attempt)
		return
	hive.next_queen_spawn_attempt = world.time + XENO_SPAWNER_QUEEN_RETRY_INTERVAL

	var/turf/spawn_turf = spawner_pick_spawn_turf() || (hive.hive_location ? get_turf(hive.hive_location) : null)
	if(!spawn_turf)
		return

	var/mob/living/carbon/xenomorph/queen/new_queen = spawn_ai_xeno(XENO_CASTE_QUEEN, spawn_turf, hive.hivenumber)
	// The Core already exists at this point (spawner_maintain_population()'s own gate
	// guarantees it) - a hive with an established Core needs her able to lead/fight NOW, not
	// spend her natural immature window defenseless.
	if(istype(new_queen))
		new_queen.make_combat_effective()

/**
 * "Players awake" - GLOB.get_active_player_count() is the existing, idiomatic primitive for
 * this across the codebase; alive + not-afk + marine-faction is "living, non-AFK marines
 * right now." Reuses GLOB.ai_difficulty_multiplier (the existing admin difficulty slider) as
 * the one and only difficulty knob rather than adding a second, competing setting.
 */
/proc/spawner_target_population()
	var/marines_awake = get_active_player_count(TRUE, TRUE, TRUE, FACTION_MARINE)
	var/target = XENO_SPAWNER_BASE_POP + round(marines_awake * XENO_SPAWNER_POP_PER_MARINE * GLOB.ai_difficulty_multiplier)
	return min(target, XENO_SPAWNER_MAX_POP)

/// Flat weighted-random caste pick against GLOB.xeno_spawner_caste_weights, skipping any caste already at its admin-set per-caste cap (GLOB.ai_xeno_max_per_caste, untouched/orthogonal to this Spawner).
/proc/spawner_pick_caste()
	var/list/available = list()
	for(var/caste_type in GLOB.xeno_spawner_caste_weights)
		var/ai_cap = GLOB.ai_xeno_max_per_caste[caste_type]
		if(ai_cap && count_active_ai_xenos_of_caste(caste_type) >= ai_cap)
			continue
		available[caste_type] = GLOB.xeno_spawner_caste_weights[caste_type]
	if(!length(available))
		return null
	return pick_weight(available)

/**
 * "Weighted near marines" placement (user decision) - directly addresses "there seems to be
 * a radius to the AI advancing from the hive": spawning far from the actual fight just
 * recreates that problem with more spawn points, since each spawn's own return_distance
 * leash then locks it out of relevance for the rest of the round. Builds a candidate list
 * from GLOB.xeno_spawns (already scattered map-wide), excludes anything within
 * XENO_SPAWNER_PLACEMENT_MIN_MARINE_DIST of a living marine (no spawn-in-someone's-face),
 * then picks randomly among whichever remaining candidates are closest to the nearest
 * marine (same "pick among the near-tied best, not always the single nearest" pattern
 * xeno_ai_movement.dm's find_cover_turf() already uses, so it doesn't always land on the
 * exact same landmark). Falls back to a plain random landmark if no marines are alive
 * anywhere (round hasn't started fighting yet, or all marines are down) - ambient map-wide
 * presence rather than nothing spawning at all.
 */
/proc/spawner_pick_spawn_turf()
	if(!length(GLOB.xeno_spawns))
		return null

	var/list/all_candidates = list()
	var/list/candidate_dists = list()
	var/any_marines = FALSE

	for(var/obj/effect/landmark/xeno_spawn/spawn_point in GLOB.xeno_spawns)
		var/turf/candidate = get_turf(spawn_point)
		if(!candidate)
			continue
		all_candidates += candidate

		var/nearest_marine_dist = INFINITY
		for(var/mob/living/carbon/human/marine as anything in GLOB.human_mob_list)
			if(marine.stat == DEAD || marine.faction != FACTION_MARINE)
				continue
			any_marines = TRUE
			var/d = get_dist(candidate, marine)
			if(d < nearest_marine_dist)
				nearest_marine_dist = d
		if(nearest_marine_dist == INFINITY || nearest_marine_dist < XENO_SPAWNER_PLACEMENT_MIN_MARINE_DIST)
			continue
		candidate_dists[candidate] = nearest_marine_dist

	if(!any_marines || !length(candidate_dists))
		return length(all_candidates) ? pick(all_candidates) : null

	var/best_dist = INFINITY
	for(var/turf/candidate in candidate_dists)
		if(candidate_dists[candidate] < best_dist)
			best_dist = candidate_dists[candidate]

	var/list/near_best = list()
	for(var/turf/candidate in candidate_dists)
		if(candidate_dists[candidate] <= best_dist + XENO_SPAWNER_PLACEMENT_VARIETY_TOLERANCE)
			near_best += candidate
	return pick(near_best)
