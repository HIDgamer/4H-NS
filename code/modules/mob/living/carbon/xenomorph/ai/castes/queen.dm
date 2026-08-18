/**
 * Queen AI - fundamentally different from every other caste's controller:
 * her default loop is hive economy (build the hive, sit her throne), not
 * chase-and-attack. She only drops into the shared combat loop (via ..() ->
 * the base tick()'s normal state machine) when a threat is actually visible,
 * matching the user's design: "if the hive is under heavy attack she would
 * assist if all other conditions such as the hive not needing eggs or
 * anything else check out."
 *
 * There is only ever one living Queen per hive at a time, so unlike every
 * other controller in this file, her AI is deliberately NOT budgeted for
 * population scale - she gets a wider awareness radius
 * (AI_QUEEN_ATTACK_DISTANCE/RETURN_DISTANCE).
 *
 * Capabilities:
 * - Throne + Hive Core: this is the hive's actual objective, not "commanding"
 *   flavor - "keep the hive core and ovipositor, allowing there to be an
 *   objective, if the hive core and the queen die, the xenos stop spawning."
 *   Builds the Hive Core on the ground before she's earned her throne, then
 *   once it's up and nothing's actively threatening her, mounts the
 *   ovipositor for real - "she can ovi for roleplay." Staying mounted keeps
 *   laying eggs (Life()'s own passive accumulation, unchanged) and, since
 *   Screech/the spit macro/shift_spits get force-granted to her the instant
 *   she mounts regardless of maturity (mount_ovipositor(), Queen.dm), she's
 *   never actually defenseless while sitting there even if she hasn't aged up
 *   naturally. She isn't idle on the throne either: she periodically uses
 *   expand_weeds (an ovi-exclusive remote-targeted ability) to grow the
 *   hive's territory without needing to physically move. Dismounting is
 *   always instant and unthrottled - a real threat is a reflex, not a
 *   decision - but re-mounting afterward waits out AI_QUEEN_REMOUNT_COOLDOWN
 *   so a borderline threat-check can't thrash her in and out of ovi tick
 *   after tick.
 * - Command: broadcasts a hive-wide alert (hive_status.dm's
 *   queen_alert_turf/queen_alert_time) whenever she has a live target -
 *   every other same-hive AI xeno checks this during idle patrol
 *   (xeno_ai_controller.dm's respond_to_hive_alert()) and heads there
 *   instead of wandering. This is how she "commands" the hive without a
 *   hard command hierarchy - deliberately the ONLY commanding behavior she
 *   has left; scout orders and threat-tier-driven LZ-siege-joining were
 *   removed as part of ripping out the Hive Population Director system
 *   (both were tied to it, and "the queen ordering the other aliens
 *   shouldn't be the only way they behave" - the rest of the hive scouts/
 *   weeds/patrols on its own initiative via the base controller's own
 *   long-patrol/wander machinery).
 * - Screech: "Screech is her most powerful ability" - opens any real
 *   engagement the moment it's off cooldown, not saved for a crowd.
 * - Confident melee/ranged hybrid: "the smartest AI, and the most dangerous
 *   only beaten by the king" - she closes and finishes a lone or already-
 *   weakened target in melee (should_close_to_melee()) instead of only ever
 *   fighting at range, but still kites and spits down a real cluster
 *   (AI_QUEEN_GROUP_SCREECH_THRESHOLD+ hostiles within
 *   AI_QUEEN_GROUP_SCREECH_RADIUS) rather than wading into all of them at
 *   once.
 * - Last stand: overrides should_flee() so that when the base logic says
 *   she'd retreat (critically wounded/on fire) but she's the hive's only
 *   living member (or already backed by enough escorting daughters), she
 *   stands and fights instead - retreating would only delay the inevitable
 *   while abandoning the fight for nothing.
 */
/datum/xeno_ai_controller/queen
	/// Successful plant_weeds actions committed since spawning - see AI_QUEEN_MIN_INITIAL_BUILDS/tick()'s build-before-ovi gate.
	var/initial_builds_done = 0
	/// world.time she's next willing to mount the ovipositor - set on dismount, see AI_QUEEN_REMOUNT_COOLDOWN.
	var/next_mount_attempt = 0
	/// world.time she can next use expand_weeds from the throne - throttles attempt_expand_weeds().
	var/next_expand_weeds_attempt = 0

/datum/xeno_ai_controller/queen/New(mob/living/carbon/xenomorph/new_pilot)
	. = ..()
	attack_distance = AI_QUEEN_ATTACK_DISTANCE
	return_distance = AI_QUEEN_RETURN_DISTANCE

// No /proc/ keyword - overriding the base tick(), which itself overrides
// /datum/proc/process(delta_time) (see xeno_ai_controller.dm's own note on
// this). Deliberately does not call ..() at the top the way a normal
// override might - the Queen's decision loop replaces the base one, only
// falling through to it (via explicit ..() calls below) once she's
// committed to fighting.
/datum/xeno_ai_controller/queen/tick()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return

	// Keep scanning for danger even while mounted (immobilized) - the one
	// exception to the base tick()'s "incapacitated means do nothing"
	// shortcut, since a mounted Queen still needs to notice a threat in
	// order to decide to dismount.
	if(!current_target)
		process_target()

	if(current_target)
		broadcast_hive_alert(queen_pilot)
	broadcast_escort_call(queen_pilot, FALSE)

	if(queen_pilot.ovipositor)
		if(current_target)
			queen_pilot.dismount_ovipositor(TRUE) // TRUE = instant, no confirmation dialog, no player-facing channel - she needs to react immediately, not wait through the flavor animation a player would.
			next_mount_attempt = world.time + AI_QUEEN_REMOUNT_COOLDOWN
			return
		if(should_reinforce_frontline(queen_pilot))
			queen_pilot.dismount_ovipositor() // Graceful, not instant - a considered strategic choice, not a reflex, so the normal dismount animation/hive-wide announcement plays.
			next_mount_attempt = world.time + AI_QUEEN_REMOUNT_COOLDOWN
			if(GLOB.ai_debug_pathing)
				log_debug("XENO AI QUEEN REINFORCING: [queen_pilot] left the ovipositor to reinforce a struggling frontline - [get_ai_debug_snapshot()]")
			return // patrol()'s respond_to_hive_alert() (reached next tick, now that she's off ovi) carries her the rest of the way there - no new movement code needed.
		// Still active from the throne, not just laying eggs and waiting -
		// keeps growing its territory (expand_weeds, an ovi-exclusive remote
		// ability) instead of going fully dormant the moment she sits down.
		attempt_expand_weeds(queen_pilot)
		// "When the Queen is on ovi it should say Queen is either commanding
		// or idle" - AI_STATE_IDLE alone doesn't distinguish "mounted and
		// actively directing the hive via an alert/escort broadcast this
		// tick" from "mounted with nothing going on."
		var/broadcasting = queen_pilot.hive && (world.time - queen_pilot.hive.queen_alert_time <= AI_XENO_HIVE_ALERT_WINDOW || world.time - queen_pilot.hive.queen_escort_time <= AI_XENO_HIVE_ALERT_WINDOW)
		idle_activity = broadcasting ? IDLE_ACTIVITY_COMMANDING : IDLE_ACTIVITY_BUILD
		return // Otherwise stay mounted - TRAIT_IMMOBILIZED already prevents movement/melee, and everything above is remote/passive.

	if(queen_pilot.is_mob_incapacitated() || HAS_TRAIT(queen_pilot, TRAIT_IMMOBILIZED))
		return

	if(current_target)
		// "Stays in the hive unless needed for an attack and the hive is
		// strong enough" / "should rely on her subjects but not be scared to
		// approach a group she can win against" - a DISTANT fight is optional
		// for the hive's mother. She only marches out when the hive can spare
		// her (population near the Spawner's target) and daughters are
		// actually at her side. NEVER gated: a threat already close, or
		// anything once she's taken damage at all - a Queen being shot from
		// beyond the self-defense ring must fight back, not stand there
		// tanking rounds while "on economy."
		var/being_hurt = queen_pilot.maxHealth && queen_pilot.health < queen_pilot.maxHealth * 0.95
		if(!being_hurt && get_dist(queen_pilot, current_target) > AI_QUEEN_SELF_DEFENSE_RANGE && !hive_strong_enough_to_attack())
			drop_target()
		else
			return ..() // Hand off to the shared approach/attack/leash state machine - she defends herself and the hive normally once committed.

	if(should_flee())
		return ..() // Critically wounded/on fire and not the hive's last defender - let the base flee-and-resist logic run even though she's not mounted.

	// "Build her hive before going to ovi" - she still won't mount at all
	// until the Hive Core actually exists (should_mount_ovipositor() below
	// checks this too), so the throne is something she's earned, not an
	// escape hatch from an unfinished hive. This is the objective: no core,
	// no throne, and the new Spawner (xeno_spawner.dm) refuses to reinforce
	// the hive at all until this exists. No time cap on these build gates
	// either - "does not wait for [plasma] to regenerate to continue
	// building" was the previous cap giving up and abandoning the attempt;
	// now she just keeps building for as long as it takes, checking plasma
	// properly each time instead of giving up on it.
	if(queen_pilot.hive && !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		idle_activity = IDLE_ACTIVITY_BUILD
		// "Queen needs to weed, she is trying to build without weeds" - weed
		// her own tile first if it isn't hers yet, only attempt the actual
		// core once she's standing on real hive weeds.
		var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
		if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
			attempt_plant_weeds()
			return
		// "She is unable to finish building the hive core once its
		// construction node is built" - once the node exists, it needs
		// feeding in small amounts as plasma regenerates (attempt_build_
		// hive_core()'s own internal check), not the full 400 up front -
		// gating the call itself on the full placement cost meant she'd
		// never even attempt a feed until she'd banked 400 again. Both the
		// placement path (place_construction's own use_ability()) and the
		// feed path check their own plasma sufficiency internally, so this
		// is safe to call every tick regardless of her current plasma.
		attempt_build_hive_core(queen_pilot)
		return

	if(initial_builds_done < AI_QUEEN_MIN_INITIAL_BUILDS)
		if(attempt_plant_weeds())
			initial_builds_done++
		patrol()
		return

	// "She can ovi for roleplay" - the hive's actually built and there's
	// nothing pressing to do on foot, so she settles onto her throne. Still
	// productive once there (see the ovipositor branch above), and instant
	// to snap out of the moment that stops being true.
	if(should_mount_ovipositor(queen_pilot))
		var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
		mount_ability?.use_ability(queen_pilot)
		return

	patrol()

/**
 * Gates mounting the ovipositor: the hive needs its Core already (the
 * throne is earned, not a shortcut around unfinished building), she needs
 * to actually be standing on her own hive's weeds (mount_ovipositor() has no
 * location requirement of its own, but a Queen anchoring herself in a
 * random hallway would be a strange place to hold court), the remount
 * cooldown from her last dismount needs to have passed, and grow_ovipositor
 * needs to still be off cooldown (it's the same action a player mounts
 * with, and use_ability() already no-ops safely if it isn't ready).
 */
/// Whether the hive can afford its mother marching to a distant, optional fight: population near the Spawner's live target AND an actual escort of daughters nearby. See tick()'s economy gate.
/datum/xeno_ai_controller/queen/proc/hive_strong_enough_to_attack()
	if(count_nearby_hive_allies(AI_QUEEN_ATTACK_ESCORT_RADIUS) < AI_QUEEN_ATTACK_MIN_ESCORT)
		return FALSE
	var/target_pop = spawner_target_population(pilot?.hive)
	if(target_pop <= 0)
		return TRUE
	var/current = 0
	for(var/mob/living/carbon/xenomorph/hive_member as anything in GLOB.ai_xeno_list)
		if(hive_member.hivenumber == pilot.hivenumber && hive_member.counts_for_slots)
			current++
	return current >= target_pop * AI_QUEEN_ATTACK_STRENGTH_PERCENT

/datum/xeno_ai_controller/queen/proc/should_mount_ovipositor(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(queen_pilot.ovipositor || world.time < next_mount_attempt)
		return FALSE
	if(!queen_pilot.hive || !queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return FALSE
	var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in get_turf(queen_pilot)
	if(!own_weeds || own_weeds.linked_hive.hivenumber != queen_pilot.hivenumber)
		return FALSE
	var/datum/action/xeno_action/onclick/grow_ovipositor/mount_ability = get_ability(/datum/action/xeno_action/onclick/grow_ovipositor)
	return mount_ability && mount_ability.action_cooldown_check()

/**
 * "The queen should be able to deovi and go to the frontline to help if
 * possible" - distinct from tick()'s existing reactive dismount (a direct
 * personal threat, instant, no judgment needed): this is a proactive
 * strategic call, checked only while she's mounted with nothing already
 * attacking her. Two things both have to be true - a real hive-wide crisis
 * actually exists (reuses assault_alert_turf, the same "the hive begins
 * marching to the fob/LZ" signal respond_to_hive_alert() already answers
 * for every other idle xeno - not a new pressure metric), and there aren't
 * already enough daughters there without her. Leaving the ovipositor to
 * join a fight that's already well-staffed would just be gambling the
 * hive's only queen for nothing, so both conditions have to hold, not just
 * one.
 */
/datum/xeno_ai_controller/queen/proc/should_reinforce_frontline(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	if(!queen_pilot.hive.assault_alert_turf || world.time - queen_pilot.hive.assault_alert_time > AI_XENO_HIVE_ALERT_WINDOW)
		return FALSE // No live hive-wide push happening - nothing to reinforce.
	if(queen_pilot.hive.stored_larva < AI_QUEEN_DEOVI_MIN_LARVA)
		return FALSE // Economy's too fragile to spare her right now - stay and keep laying.
	return count_nearby_hive_members(queen_pilot.hive.assault_alert_turf, AI_XENO_HIVE_ALERT_RESPONDER_RADIUS) < AI_QUEEN_DEOVI_RESPONDER_THRESHOLD

/**
 * Ovi-exclusive remote-targeted build ability (mount_ovipositor()'s
 * immobile_abilities list, Queen.dm) - lets her keep growing the hive's
 * weed footprint from the throne instead of that work stopping dead the
 * moment she mounts. Picks a plain nearby candidate rather than a careful
 * frontier search - expand_weeds' own use_ability() already validates
 * weedability/area eligibility and just silently no-ops on a bad tile, so a
 * wasted attempt here and there costs nothing.
 */
/datum/xeno_ai_controller/queen/proc/attempt_expand_weeds(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(world.time < next_expand_weeds_attempt)
		return
	var/datum/action/xeno_action/activable/expand_weeds/expand_ability = get_ability(/datum/action/xeno_action/activable/expand_weeds)
	if(!expand_ability || !expand_ability.action_cooldown_check())
		return
	next_expand_weeds_attempt = world.time + AI_QUEEN_EXPAND_WEEDS_INTERVAL

	var/list/candidates = list()
	for(var/turf/candidate in range(AI_QUEEN_EXPAND_WEEDS_RADIUS, queen_pilot))
		if(candidate.density || candidate.is_weedable() < FULLY_WEEDABLE)
			continue
		if(locate(/obj/effect/alien/weeds) in candidate)
			continue // Already weeded - nothing to expand there.
		candidates += candidate
	if(!length(candidates))
		return
	expand_ability.use_ability(pick(candidates))

/**
 * "She is unable to finish building the hive core once its construction
 * node is built (you have to keep filling it with plasma as you regenerate
 * plasma, don't spam it either just wait long enough)" - place_construction
 * can never re-place the Hive Core once the empty node exists
 * (check_alien_construction(), XenoProcs.dm, treats the node itself as an
 * obstacle and refuses), so retrying it forever was a dead end: the plasma
 * cost she was banking for a re-placement was never the real requirement.
 * The node's actual 1000-plasma build cost (construction_template_xenomorph.dm -
 * a completely separate number from the 400-plasma placement fee below) is
 * meant to be fed
 * incrementally by attacking the standing node with something other than
 * harm intent (construction_node.dm's attack_alien() -> add_crystal(),
 * which drains her current plasma into it and makes her stand still for
 * its own 4-second windup) - exactly the real "wait for plasma, feed again,
 * don't spam" mechanic. Locates the node once it exists and feeds it
 * instead of endlessly retrying the placement ability against it.
 */
/datum/xeno_ai_controller/queen/proc/attempt_build_hive_core(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive || queen_pilot.hive.has_structure(XENO_STRUCTURE_CORE))
		return

	var/obj/effect/alien/resin/construction/node = locate(/obj/effect/alien/resin/construction) in get_turf(queen_pilot)
	if(!node)
		for(var/obj/effect/alien/resin/construction/nearby_node in range(3, queen_pilot))
			if(nearby_node.linked_hive == queen_pilot.hive)
				node = nearby_node
				break

	if(node && node.linked_hive == queen_pilot.hive)
		if(!queen_pilot.Adjacent(node))
			travel_to(node, 0)
			return
		if(queen_pilot.plasma_stored <= 0)
			return // "Don't spam it either, just wait long enough" - nothing to contribute yet, don't burn the feed windup for free.
		queen_pilot.a_intent = INTENT_HELP // attack_alien() destroys the node under INTENT_HARM instead of feeding it.
		node.attack_alien(queen_pilot)
		return

	if(queen_pilot.hive.hivecore_cooldown)
		return
	var/datum/action/xeno_action/activable/place_construction/action = get_ability(/datum/action/xeno_action/activable/place_construction)
	if(!action)
		return
	action.use_ability(get_turf(queen_pilot)) // Safe to call speculatively even without enough plasma yet - use_ability() checks check_plasma(400) itself before deducting anything.

/**
 * She has plant_weeds in her own base_actions same as a Drone (see
 * Queen.dm) but the base controller never called it for her - same
 * build-duty pattern as drone_worker.dm, just her own (higher, since
 * she's one unit rather than a population) chance.
 */
/datum/xeno_ai_controller/queen/patrol()
	if(respond_to_hive_alert())
		idle_activity = IDLE_ACTIVITY_ALERT
		return
	if(prob(AI_QUEEN_BUILD_CHANCE) && attempt_plant_weeds())
		idle_activity = IDLE_ACTIVITY_BUILD
		return
	// "Queen should weed like drones" - attempt_plant_weeds() only ever
	// weeds whatever tile she's already standing on, same as a Drone, but
	// falling straight to wander() (rather than the base patrol()'s full
	// idle state machine - long patrols, pack cohesion) kept her drifting
	// over the same small patch near anchor_turf instead of covering ground
	// the way a Drone's own patrol() fallthrough does.
	return ..()

/// Higher than the population default - "she is big and slow and easy to kill," a huge investment that's hard to save if she overcommits, so she breaks off earlier than a disposable population-scale caste would.
/datum/xeno_ai_controller/queen/get_flee_threshold()
	return AI_QUEEN_FLEE_HEALTH_PERCENT

/**
 * Only flees if the base logic would AND she isn't the hive's last living
 * member AND she isn't already backed up - if she's alone, retreating
 * accomplishes nothing but delaying the inevitable, so she makes her stand
 * instead; "she can easily attack with her escort instead of retreating" is
 * the same reasoning extended to any fight where enough daughters
 * (broadcast_escort_call() already rallies them to her every tick she has a
 * target) are actually fighting alongside her against the exact same
 * target, not only the single all-alone edge case.
 */
/datum/xeno_ai_controller/queen/should_flee()
	if(!..())
		return FALSE
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return TRUE
	if(is_last_defender(queen_pilot))
		return FALSE
	if((queen_pilot.health / queen_pilot.maxHealth) > AI_XENO_FLEE_ALLY_SUPPRESS_FLOOR && current_target && count_engaged_allies(current_target) >= AI_QUEEN_ESCORT_STAND_THRESHOLD)
		return FALSE
	return TRUE

/datum/xeno_ai_controller/queen/get_combat_weed_chance()
	return AI_QUEEN_COMBAT_WEED_CHANCE

/datum/xeno_ai_controller/queen/proc/is_last_defender(mob/living/carbon/xenomorph/queen/queen_pilot)
	if(!queen_pilot.hive)
		return FALSE
	for(var/mob/living/carbon/xenomorph/hive_member as anything in queen_pilot.hive.totalXenos)
		if(hive_member == queen_pilot || hive_member.stat == DEAD)
			continue
		return FALSE
	return TRUE

/**
 * Confident hybrid, not purely reactive-melee: she's "the smartest AI, and
 * the most dangerous only beaten by the king," so a lone or already-weakened
 * target just gets closed on and finished, not peppered with spit from a
 * safe distance forever - should_close_to_melee() makes that call. Only a
 * real cluster (the case a spit-and-kite policy actually earns its keep
 * against) keeps her at range softening things up first, same as
 * Boiler/Sentinel's own kiting behavior. Screech opens any real engagement
 * now, not only group ones - "her most powerful ability" is worth using
 * whenever it's up, not saved for a crowd.
 */
/datum/xeno_ai_controller/queen/process_attack()
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !current_target)
		ai_state = AI_STATE_IDLE
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	attempt_screech() // No-ops silently off cooldown - safe to call every tick she's committed to a fight.

	if(pilot.Adjacent(current_target)) // Cornered, or she's chosen to close - fight back.
		execute_attack(current_target)
		if(stale_attack_ticks >= AI_PRIORITY_STALE_ATTACK_GIVEUP) // This override replaces the base process_attack() entirely instead of calling ..() - without this she'd claw an undamageable target forever instead of giving up like every other caste does.
			drop_target()
		return

	if(should_close_to_melee(current_target))
		ai_state = AI_STATE_APPROACHING // process_movement() closes the gap instead of kiting - see should_close_to_melee().
		return

	attempt_ranged_spit(current_target) // No-ops silently if it's on cooldown - safe to call speculatively.
	ai_state = AI_STATE_APPROACHING // Always re-decide positioning next tick.

/**
 * The melee-vs-ranged decision itself: closes in against anything she can
 * confidently just win against outright - already weakened past
 * AI_QUEEN_MELEE_TARGET_HEALTH_PERCENT, or genuinely alone (fewer than
 * AI_QUEEN_GROUP_SCREECH_THRESHOLD other hostiles clustered within
 * AI_QUEEN_GROUP_SCREECH_RADIUS of it). A real cluster is the one case
 * spit-and-kite still earns its keep - softening several targets from range
 * beats wading into all of them at once, even for her.
 */
/datum/xeno_ai_controller/queen/proc/should_close_to_melee(mob/living/target)
	if(!istype(target))
		return FALSE
	if(target.maxHealth && target.health <= target.maxHealth * AI_QUEEN_MELEE_TARGET_HEALTH_PERCENT)
		return TRUE
	var/nearby_hostiles = 0
	for(var/mob/living/nearby in orange(AI_QUEEN_GROUP_SCREECH_RADIUS, target))
		if(nearby == target || !is_valid_target(nearby))
			continue
		nearby_hostiles++
		if(nearby_hostiles >= AI_QUEEN_GROUP_SCREECH_THRESHOLD)
			return FALSE // A real group - stay ranged and soften them up instead.
	return TRUE

/**
 * "Weeds heal, slow enemies, speed up xenos" - a real tactical move
 * mid-fight, not just idle economy. Reuses the same attempt_plant_weeds()
 * idle callers already use (xeno_ai_controller.dm) - its own internal
 * checks (weedable ground, hive ownership) already handle a bad tile
 * silently, so this is safe to roll speculatively without breaking stride.
 */
/datum/xeno_ai_controller/queen/process_movement()
	if(!pilot || !current_target)
		return
	if(!is_valid_target(current_target))
		drop_target()
		return

	if(prob(get_combat_weed_chance()))
		attempt_plant_weeds()
	attempt_periodic_combat_pheromones()

	last_seen_turf = get_turf(current_target)
	if(should_close_to_melee(current_target))
		travel_to(current_target, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_COVER_CHECK)
	else
		maintain_kiting_distance(current_target, AI_XENO_RANGED_PREFERRED_DISTANCE)

/**
 * "Spitting is her main ability in combat, make sure she switches between
 * neuro spit and acid spit on demand, not at random" - shift_spits is a
 * plain toggle (cycles to whichever ammo type comes next in
 * caste.spit_types), so with exactly two entries "on demand" just means
 * comparing her current ammo against the one the situation calls for and
 * toggling only when they differ, instead of never touching it at all
 * (leaving her stuck on whichever type she happened to spawn with for the
 * whole round). Acid Spatter up close for the bigger single hit, Neurotoxin
 * at range for the harassing DoT/slow while she's still closing or holding
 * distance.
 */
/datum/xeno_ai_controller/queen/proc/select_spit_type(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot) || !queen_pilot.caste)
		return
	var/desired_type = (get_dist(queen_pilot, target) <= AI_XENO_RANGED_MIN_DISTANCE + 1) ? /datum/ammo/xeno/acid/spatter : /datum/ammo/xeno/toxin/queen
	if(queen_pilot.ammo == GLOB.ammo_list[desired_type])
		return
	var/datum/action/xeno_action/onclick/shift_spits/shift = get_ability(/datum/action/xeno_action/onclick/shift_spits)
	shift?.use_ability(queen_pilot)

/datum/xeno_ai_controller/queen/proc/attempt_ranged_spit(mob/living/target)
	var/datum/action/xeno_action/activable/xeno_spit/queen_macro/spit = get_ability(/datum/action/xeno_action/activable/xeno_spit/queen_macro)
	if(!spit || !spit.action_cooldown_check())
		return
	select_spit_type(target)
	pilot.setDir(get_dir(pilot, target))
	spit.use_ability(target)

/// AoE fear/disorient - "she should use her special ability Screech too." Opportunistic, no real downside to firing it the moment it's off cooldown while cornered into melee.
/datum/xeno_ai_controller/queen/proc/attempt_screech()
	var/datum/action/xeno_action/onclick/screech/screech = get_ability(/datum/action/xeno_action/onclick/screech)
	if(!screech || !screech.action_cooldown_check())
		return FALSE
	screech.use_ability(pilot)
	return TRUE

/**
 * Only offensive melee special she has worth reaching for as an AI: an
 * 8-second, fully-interruptible windup that instantly gibs whatever's
 * adjacent when it completes (queen_gut() in Queen.dm). Only used to finish
 * something already down (dead or floored/incapacitated), never as a
 * mid-fight opener against something still fighting back - the windup is far
 * too long to commit against a live, mobile opponent that can just walk or
 * hit her out of it.
 */
/datum/xeno_ai_controller/queen/use_caste_ability(mob/living/target)
	var/mob/living/carbon/xenomorph/queen/queen_pilot = pilot
	if(!istype(queen_pilot))
		return FALSE

	attempt_screech() // Side effect only (own cooldown/plasma cost) - never blocks also gutting/slashing the same tick below.

	var/target_helpless = target.stat == DEAD || HAS_TRAIT(target, TRAIT_FLOORED) || target.is_mob_incapacitated()
	if(target_helpless)
		var/datum/action/xeno_action/activable/gut/gut_ability = get_ability(/datum/action/xeno_action/activable/gut)
		if(gut_ability && gut_ability.action_cooldown_check())
			for(var/mob/living/nearby in orange(3, queen_pilot))
				if(nearby == target)
					continue
				if(is_valid_target(nearby))
					return attempt_tail_stab(target) // Not a clean opportunity - something else could interrupt the windup or jump her while she's committed.
			gut_ability.use_ability(target)
			return TRUE

	return attempt_tail_stab(target)

// broadcast_hive_alert()/count_nearby_escorts()/broadcast_escort_call() now
// live on the base controller (xeno_ai_controller.dm) - promoted there so
// King can share them too ("coordination with other AI xenos is very
// poor" - he never had an equivalent before). Queen inherits the identical
// behavior automatically.
