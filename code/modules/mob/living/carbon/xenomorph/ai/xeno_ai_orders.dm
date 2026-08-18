/**
 * Direct Hive Leader/admin command console orders for xeno_ai_controller -
 * per-mob, unlike the ambient hive-wide broadcasts (queen_alert_turf,
 * assault_alert_turf, queen_escort_turf - hive_status.dm) idle xenos already
 * poll during patrol(). An order is issued to specific, selected xenos (see
 * code/modules/mob/living/carbon/xenomorph/xeno_command_console.dm) and
 * outranks every ambient broadcast and autonomous idle behavior for exactly
 * the mobs it was given to - everyone else keeps behaving exactly as before.
 *
 * PLAYER_ORDER_MOVE/HOLD are polled from tick()'s own patrol() call site
 * (see respond_to_player_order(), and tick()'s doc comment on why it wraps
 * patrol() there instead of being folded into it). PLAYER_ORDER_ATTACK is
 * different in kind, not just in target type - it has to be able to override
 * an already-in-progress autonomous fight, not just idle wandering, so it's
 * applied immediately at issuance via acquire_target() instead of being
 * polled at all.
 */

/**
 * Acts on a live PLAYER_ORDER_MOVE/HOLD - the first check patrol() itself
 * would otherwise run (see tick()'s call site). Returns FALSE (meaning "no
 * order active, fall through to normal patrol()") the moment there's nothing
 * to do, so this is a complete no-op with zero behavior change whenever no
 * order has been issued.
 */
/datum/xeno_ai_controller/proc/respond_to_player_order()
	if(!pilot || player_order_type == PLAYER_ORDER_NONE)
		return FALSE

	if(player_order_type == PLAYER_ORDER_HOLD)
		return TRUE

	if(player_order_type == PLAYER_ORDER_MOVE)
		if(!player_order_turf)
			clear_player_order()
			return FALSE
		if(get_dist(pilot, player_order_turf) <= AI_XENO_PLAYER_ORDER_ARRIVE_RADIUS)
			// Arrived - re-anchor here (a Move order is meant to relocate the
			// unit, not just visit a point and drift back to its old spawn
			// turf the next time it wanders) and hand off to normal patrol()
			// this same tick, same as respond_to_hive_alert()'s own
			// close-enough fallthrough.
			if(GLOB.ai_debug_pathing)
				log_debug("XENO AI ORDER ARRIVED: [pilot] ([pilot.type]) reached move order at ([player_order_turf.x],[player_order_turf.y]), re-anchoring - [get_ai_debug_snapshot()]")
			anchor_turf = get_turf(pilot)
			clear_player_order()
			return FALSE
		travel_to_broadcast_turf(player_order_turf)
		return TRUE

	return FALSE

/// Issues a PLAYER_ORDER_MOVE - walk to destination, then clear and re-anchor there once arrived. Never leashed by return_distance/should_disengage() (that check only ever fires for chase state), matching the existing no-cap precedent for assault_alert_turf - a Hive Leader ordering a unit clear across the map should actually be obeyed.
/datum/xeno_ai_controller/proc/receive_move_order(turf/destination)
	if(!pilot || !destination)
		return FALSE
	if(GLOB.ai_debug_pathing)
		log_debug("XENO AI ORDER RECEIVED: [pilot] ([pilot.type]) ordered to move to ([destination.x],[destination.y]) - [get_ai_debug_snapshot()]")
	player_order_type = PLAYER_ORDER_MOVE
	player_order_turf = destination
	player_order_target = null
	player_order_time = world.time
	return TRUE

/// Issues a PLAYER_ORDER_HOLD at the pilot's current position - suppresses every lower-priority idle behavior (building, wandering, resting, responding to ambient hive alerts) without moving. process_target() still runs every tick unconditionally (tick()'s own dispatch, ahead of patrol()), so a held xeno still fights back if something wanders adjacent - "hold" is not "ignore everything."
/datum/xeno_ai_controller/proc/receive_hold_order()
	if(!pilot)
		return FALSE
	var/turf/hold_turf = get_turf(pilot)
	if(GLOB.ai_debug_pathing)
		log_debug("XENO AI ORDER RECEIVED: [pilot] ([pilot.type]) ordered to hold at [hold_turf] - [get_ai_debug_snapshot()]")
	player_order_type = PLAYER_ORDER_HOLD
	player_order_turf = hold_turf
	player_order_target = null
	player_order_time = world.time
	return TRUE

/**
 * Issues a PLAYER_ORDER_ATTACK - takes effect immediately via acquire_target(),
 * regardless of current ai_state, unlike MOVE/HOLD (which only ever apply
 * from patrol()'s idle-only vantage point). This is deliberate: an explicit
 * "attack THIS" order needs to be able to redirect a xeno already fighting
 * something else, not just an idle one. Reuses 100% of the existing chase/
 * attack state machine (process_attack(), process_movement(), retaliation,
 * priority re-scan, leash disengage) - no new movement or combat code at
 * all, just a new reason an attack starts. See check_nearby_threats()'s
 * AI_XENO_PLAYER_ORDER_COMMIT_WINDOW guard for why a fresh order isn't
 * immediately vulnerable to being silently swapped onto something else.
 */
/datum/xeno_ai_controller/proc/receive_attack_order(atom/movable/target)
	if(!pilot || !target || !is_valid_target(target))
		return FALSE
	if(GLOB.ai_debug_pathing)
		log_debug("XENO AI ORDER RECEIVED: [pilot] ([pilot.type]) ordered to attack [target] - [get_ai_debug_snapshot()]")
	player_order_type = PLAYER_ORDER_ATTACK
	player_order_turf = null
	player_order_target = target
	player_order_time = world.time
	acquire_target(target, "player_order")
	return TRUE

/**
 * Clears any active order. Called both directly (order resolved on arrival,
 * or superseded by a fresh one) and from drop_target() - see drop_target()'s
 * own doc comment for why funneling order cleanup through that single
 * existing choke point (rather than updating every one of its many callers
 * individually) is deliberate.
 */
/datum/xeno_ai_controller/proc/clear_player_order()
	if(player_order_type == PLAYER_ORDER_NONE)
		return
	if(GLOB.ai_debug_pathing)
		log_debug("XENO AI ORDER CLEARED: [pilot] ([pilot?.type]) order [player_order_type] cleared - [get_ai_debug_snapshot()]")
	player_order_type = PLAYER_ORDER_NONE
	player_order_turf = null
	player_order_target = null
