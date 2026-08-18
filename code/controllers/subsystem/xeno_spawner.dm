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
 *
 * "Many xenos start walking back and forth when switching to assault" -
 * live-reported. Root cause was actually twofold. First, and most direct per
 * explicit user correction: this was reading the wrong signal entirely -
 * "assault phase was meant to mark the primary landing zone chosen by the
 * players as the attack marker, not actual humans... the hive begins
 * marching to the fob or primary LZ." The marine-mass computation
 * (spawner_marine_mass_turf()) tracks live human positions, which is
 * exactly what it shouldn't be doing here - get_active_lz_turf() (command's
 * actual designated primary LZ, a real player decision, stable until
 * re-designated) is the correct target and now tried first; the mass-turf
 * fallback only covers the window before any LZ has been designated yet.
 * Second, compounding the wrong-signal problem: spawner_marine_mass_turf()
 * itself picks whichever living marine is currently closest to the group's
 * average position, which is genuinely unstable when two marines sit
 * near-equally close to that average - ordinary movement can flip which one
 * "wins" from one 20-second recheck to the next, jumping the picked turf
 * between two different locations. Every idle xeno hive-wide shares this one
 * queen_alert_turf (respond_to_hive_alert()), so an unconditional overwrite
 * here meant the whole hive reversed direction together on the same rhythm
 * the flip happened on - a correlated, hive-wide oscillation, not the
 * per-mob pathfinding issue fixed earlier. Kept as a genuine improvement
 * even now that it's just the fallback, and applies equally to the LZ (a
 * no-op once it's already correctly set - the drift is 0). queen_alert_time
 * still refreshes every fire regardless (keeps the assault alive for its
 * full duration even while the target genuinely hasn't moved) - only the
 * turf itself is gated behind a real minimum drift.
 */
/datum/controller/subsystem/xeno_spawner/proc/update_hive_phase(datum/hive_status/hive)
	var/pacing_mult = clamp(GLOB.ai_difficulty_multiplier, 0.5, 2)
	if(!phase_ends_at)
		phase_ends_at = world.time + rand(XENO_SPAWNER_BUILDUP_MIN, XENO_SPAWNER_BUILDUP_MAX) / pacing_mult

	if(world.time >= phase_ends_at)
		var/old_phase = hive_phase
		switch(hive_phase)
			if(HIVE_PHASE_BUILDUP)
				hive_phase = HIVE_PHASE_ASSAULT
				phase_ends_at = world.time + rand(XENO_SPAWNER_ASSAULT_MIN, XENO_SPAWNER_ASSAULT_MAX) * pacing_mult
			if(HIVE_PHASE_ASSAULT)
				hive_phase = HIVE_PHASE_LULL
				phase_ends_at = world.time + XENO_SPAWNER_LULL_DURATION / pacing_mult
				attempt_bank_frontier_advance(hive)
			else
				hive_phase = HIVE_PHASE_BUILDUP
				phase_ends_at = world.time + rand(XENO_SPAWNER_BUILDUP_MIN, XENO_SPAWNER_BUILDUP_MAX) / pacing_mult
		if(GLOB.ai_debug_pathing)
			log_debug("XENO SPAWNER PHASE: hive [hive.hivenumber] [old_phase] -> [hive_phase], ends in [(phase_ends_at - world.time) / 10]s")

	if(hive_phase == HIVE_PHASE_ASSAULT)
		var/turf/assault_turf = get_active_lz_turf() || spawner_marine_mass_turf()
		if(assault_turf)
			// assault_alert_turf, not queen_alert_turf - see hive_status.dm's
			// doc comment on why the hive-wide march needs its own field
			// instead of sharing the Queen/King's range-capped personal
			// combat alert.
			if(!hive.assault_alert_turf || get_dist(assault_turf, hive.assault_alert_turf) >= XENO_SPAWNER_ASSAULT_TURF_UPDATE_THRESHOLD)
				if(GLOB.ai_debug_pathing && hive.assault_alert_turf)
					log_debug("XENO SPAWNER ASSAULT TURF MOVED: hive [hive.hivenumber] alert ([hive.assault_alert_turf.x],[hive.assault_alert_turf.y]) -> ([assault_turf.x],[assault_turf.y]), drift=[get_dist(assault_turf, hive.assault_alert_turf)]")
				hive.assault_alert_turf = assault_turf
			hive.assault_alert_time = world.time

/**
 * "The goal is always to take over the colony, and weed it all and secure
 * it, not just staying in their spawn positions waiting" - called exactly
 * once, at the moment an assault phase rolls to LULL. If the hive's LZ push
 * actually held (no living hostile marine still contesting the ground),
 * banks that turf as hive.frontier_turf - a permanent signal, distinct from
 * assault_alert_turf (which goes stale/reverts every phase cycle) - so the
 * hive's footprint genuinely advances over the course of a round instead of
 * fully reverting once the phase timer moves on. If marines are still
 * fighting for it, the push isn't over yet - don't bank a contested tile.
 */
/datum/controller/subsystem/xeno_spawner/proc/attempt_bank_frontier_advance(datum/hive_status/hive)
	var/turf/held_turf = hive.assault_alert_turf
	if(!held_turf)
		return
	for(var/mob/living/carbon/human/marine as anything in GLOB.alive_human_list)
		if(marine.faction != FACTION_MARINE || marine.stat == DEAD)
			continue
		if(get_dist(marine, held_turf) <= XENO_FRONTIER_CONTEST_RADIUS)
			return // Still contested - the push isn't won yet, nothing to bank.
	hive.frontier_turf = held_turf
	hive.frontier_turf_time = world.time
	if(GLOB.ai_debug_pathing)
		log_debug("XENO SPAWNER FRONTIER ADVANCE: hive [hive.hivenumber] banked ([held_turf.x],[held_turf.y]) as new frontier_turf.")

/// Admin override (AdminAIDifficulty UI): jump straight to a phase; the normal rhythm resumes from there.
/datum/controller/subsystem/xeno_spawner/proc/force_hive_phase(new_phase)
	hive_phase = new_phase
	phase_ends_at = 0
	switch(new_phase)
		if(HIVE_PHASE_ASSAULT)
			phase_ends_at = world.time + XENO_SPAWNER_ASSAULT_MAX
		if(HIVE_PHASE_LULL)
			phase_ends_at = world.time + XENO_SPAWNER_LULL_DURATION

/// Turf of the primary LZ command has designated (game_mode.dm's active_lz, set by cm_process.dm's "designated as the primary landing zone" order) - the real, stable "attack marker" update_hive_phase() should march the assault on, not a live read of wherever marines currently happen to be standing. Null before command designates one. Shared with xeno_ai_controller.dm's get_lz_turf() (queen.dm's LZ-siege response, attempt_ambush_hide()) so there's one source of truth for "where's the LZ."
/proc/get_active_lz_turf()
	var/datum/game_mode/mode = SSticker.mode
	if(!mode || !mode.active_lz)
		return null
	return get_turf(mode.active_lz)

/**
 * The turf of the living ground-side marine closest to all living
 * ground-side marines' average position - i.e. where the marine force
 * actually is, snapped to a real reachable marine rather than an arbitrary
 * midpoint that could land inside a wall or between two split squads.
 * update_hive_phase()'s fallback for the (normally brief) window before
 * command has designated a primary LZ at all - get_active_lz_turf() is
 * strongly preferred whenever it's available.
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

	// "The queen has to be alive, and the core has to be built with the queen on ovi, for
	// xenomorphs to keep spawning" - the Core gate above only ever checked the structure, never
	// the Queen herself; a hive could keep reinforcing indefinitely with a dead/missing Queen (the
	// spawner_ensure_queen() call above this proc handles replacing her, but that can take a
	// while - see spawner_ensure_queen()/next_queen_spawn_attempt) or with a live Queen who's
	// simply not on her ovipositor (mirrors the exact ovipositor_check update_progression()
	// already gates real player evolution progress on, life.dm's own Queen-on-ovi read).
	if(!hive.living_xeno_queen || QDELETED(hive.living_xeno_queen) || hive.living_xeno_queen.stat == DEAD || !hive.living_xeno_queen.ovipositor)
		return

	var/target = spawner_target_population(hive)
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
	// Marine positions don't change mid-fire() - build the "which landmark is near which
	// marine" table once for this whole batch (up to max_per_fire spawns) instead of every
	// spawner_pick_spawn_turf() call independently re-scanning every GLOB.xeno_spawns landmark
	// against every GLOB.human_mob_list marine from scratch, up to 6 times back-to-back.
	var/list/spawn_candidates = spawner_build_spawn_candidates()
	while(current < target && spawned_this_fire < max_per_fire)
		var/caste_type = spawner_pick_caste()
		if(!caste_type)
			break
		var/turf/spawn_turf = spawner_pick_spawn_turf(spawn_candidates)
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
 * Bootstraps the very first Queen for a hive that never got a player one (no Core exists yet -
 * round start, or a catastrophic collapse), OR - once the Core already stands - kicks off a slow
 * drone-to-Queen ascension (hive_status.dm's start_queen_evolution()) instead of conjuring a
 * fresh Queen from nothing. "When the queen dies a drone has to evolve to the queen, not just a
 * new queen spawning in - it's a slow process": the instant spawn below is now reserved for the
 * genuine bootstrap/no-Drone-left case; a hive that still has an AI Drone to ascend always takes
 * the slow path instead. Never double-spawns: add_xeno() (hive_status.dm) already guards
 * set_living_xeno_queen() behind if(!living_xeno_queen), and BYOND's single-threaded execution
 * means there's no window for a second call to run before hive.living_xeno_queen is already
 * populated by this same synchronous spawn.
 */
/proc/spawner_ensure_queen(datum/hive_status/hive)
	if(hive.living_xeno_queen && hive.living_xeno_queen.stat != DEAD)
		return
	if(hive.evolving_to_queen && !QDELETED(hive.evolving_to_queen) && hive.evolving_to_queen.stat != DEAD)
		return // Already ascending - the timer already running (start_queen_evolution()) will finish it; don't queue a second attempt on top.
	if(world.time < hive.next_queen_spawn_attempt)
		return
	hive.next_queen_spawn_attempt = world.time + XENO_SPAWNER_QUEEN_RETRY_INTERVAL

	if(hive.has_structure(XENO_STRUCTURE_CORE) && hive.start_queen_evolution())
		return // A candidate Drone is now slowly ascending - see start_queen_evolution()'s doc comment. Falls through to the instant bootstrap spawn below only when the Core doesn't exist yet, or no AI Drone is left to ascend.

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
 *
 * hive is optional (existing callers elsewhere in the codebase may not have one handy) - when
 * passed, adds hive.count_active_human_caps() (hive_status.dm) as a flat bonus on top: "capping
 * a human to a wall increases the hive's total numbers by 1 for as long as that cap lives."
 */
/proc/spawner_target_population(datum/hive_status/hive)
	var/marines_awake = get_active_player_count(TRUE, TRUE, TRUE, FACTION_MARINE)
	var/target = XENO_SPAWNER_BASE_POP + round(marines_awake * XENO_SPAWNER_POP_PER_MARINE * GLOB.ai_difficulty_multiplier)
	if(hive)
		target += hive.count_active_human_caps()
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
 * Builds the "which landmark is near which marine" table spawner_pick_spawn_turf() picks
 * from. Split out from that proc so a batch of several spawns in the same
 * spawner_maintain_population() call can share one scan instead of each repeating the same
 * O(spawns x marines) work - marine positions don't move mid-batch, so nothing after the
 * first scan can change the answer anyway. Returns an assoc list: "all" = every candidate
 * turf, "dists" = assoc turf -> nearest living marine distance (only for turfs past
 * XENO_SPAWNER_PLACEMENT_MIN_MARINE_DIST), "any_marines" = whether a living marine exists at all.
 */
/proc/spawner_build_spawn_candidates()
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

	return list("all" = all_candidates, "dists" = candidate_dists, "any_marines" = any_marines)

/**
 * "Weighted near marines" placement (user decision) - directly addresses "there seems to be
 * a radius to the AI advancing from the hive": spawning far from the actual fight just
 * recreates that problem with more spawn points, since each spawn's own return_distance
 * leash then locks it out of relevance for the rest of the round. Picks randomly among
 * whichever candidates are closest to the nearest marine (same "pick among the near-tied
 * best, not always the single nearest" pattern xeno_ai_movement.dm's find_cover_turf()
 * already uses, so it doesn't always land on the exact same landmark). Falls back to a plain
 * random landmark if no marines are alive anywhere (round hasn't started fighting yet, or all
 * marines are down) - ambient map-wide presence rather than nothing spawning at all.
 *
 * Consumes the picked turf out of spawn_candidates so a caller spawning several xenos off the
 * same table (spawner_maintain_population()) doesn't stack them all on the exact same
 * landmark. Pass no argument (or null) to build and use a fresh one-off table, e.g.
 * spawner_ensure_queen()'s single Queen-placement call.
 */
/proc/spawner_pick_spawn_turf(list/spawn_candidates)
	if(!length(GLOB.xeno_spawns))
		return null
	if(!spawn_candidates)
		spawn_candidates = spawner_build_spawn_candidates()

	var/list/all_candidates = spawn_candidates["all"]
	var/list/candidate_dists = spawn_candidates["dists"]
	var/any_marines = spawn_candidates["any_marines"]

	if(!any_marines || !length(candidate_dists))
		if(!length(all_candidates))
			return null
		var/turf/picked = pick(all_candidates)
		all_candidates -= picked
		return picked

	var/best_dist = INFINITY
	for(var/turf/candidate in candidate_dists)
		if(candidate_dists[candidate] < best_dist)
			best_dist = candidate_dists[candidate]

	var/list/near_best = list()
	for(var/turf/candidate in candidate_dists)
		if(candidate_dists[candidate] <= best_dist + XENO_SPAWNER_PLACEMENT_VARIETY_TOLERANCE)
			near_best += candidate

	var/turf/picked = pick(near_best)
	candidate_dists -= picked
	all_candidates -= picked
	return picked
