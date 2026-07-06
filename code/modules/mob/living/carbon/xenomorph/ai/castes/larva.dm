/**
 * Larva AI - "larva needs to hide, and just in general be scared since they
 * are fragile." Unlike every other caste's controller, spotting a living
 * hostile at all is the flee trigger here, not taking damage - a larva has
 * no attack worth using and dies in one or two hits, so the generic
 * approach-and-attack default (inherited from the base controller before
 * this file existed) was actively suicidal. should_flee() is completely
 * overridden rather than just tuning get_flee_threshold() higher, since the
 * base version's health/ally-count/target-condition reasoning ("finish it
 * off," "not fighting alone") all assume a xeno that can actually win a
 * fight - none of that applies to her. She never enters AI_STATE_ATTACKING
 * at all: the base tick()'s flee-check runs before movement/attack logic
 * every tick, so an unconditional should_flee() intercepts her before she'd
 * ever close distance on a target.
 */
/datum/xeno_ai_controller/larva

/**
 * Spotting any valid living hostile is reason enough to run - no health/
 * ally/target-condition exceptions, she can't win a fight regardless of the
 * numbers.
 *
 * "The larva returns into the core as soon as they spawn" - an organic-
 * growth larva's anchor_turf IS the Hive Core (spawn_organic() spawns her
 * there with no anchor_override), so return_to_anchor()'s destination is
 * that same tile - fleeing "home" while already standing on it just reads
 * as never having left at all. She's not in any more danger standing still
 * there than she would be after "fleeing" a single tile back to the exact
 * spot she's already on, so skip the whole flee cycle while already this
 * close to anchor instead of visibly panicking in place.
 */
/datum/xeno_ai_controller/larva/should_flee()
	if(!pilot || !current_target || !is_valid_target(current_target))
		return FALSE
	if(anchor_turf && get_dist(pilot, anchor_turf) <= AI_XENO_LARVA_SAFE_HOME_RADIUS)
		return FALSE
	return TRUE

/// Never - she has no attack worth turning around for, cornered or not. Always keep running/hiding instead of return_to_anchor()'s generic desperate-stand fallback.
/datum/xeno_ai_controller/larva/get_desperate_threshold()
	return 0

/**
 * "They need to stay on weeds" - a larva's whole job is sitting on hive
 * weeds (that's where she matures and heals), so instead of the generic
 * anchor-radius wander, her idle destination IS the nearest own-hive weed
 * tile. Once on weeds she stays put; the base wander()'s rest logic handles
 * the rest.
 */
/datum/xeno_ai_controller/larva/patrol()
	if(!pilot)
		return
	var/turf/pilot_turf = get_turf(pilot)
	if(pilot_turf)
		var/obj/effect/alien/weeds/own_weeds = locate(/obj/effect/alien/weeds) in pilot_turf
		if(own_weeds && own_weeds.linked_hive.hivenumber == pilot.hivenumber)
			idle_activity = IDLE_ACTIVITY_NONE
			return // Settled on weeds - exactly where a larva belongs.
	var/turf/nearest_weed = find_nearest_hive_weed_turf()
	if(nearest_weed)
		idle_activity = IDLE_ACTIVITY_WANDER
		travel_to(nearest_weed, TRAVEL_FLAG_FORCE_OBSTACLES|TRAVEL_FLAG_AVOID_MOBS)
		return
	return ..()
