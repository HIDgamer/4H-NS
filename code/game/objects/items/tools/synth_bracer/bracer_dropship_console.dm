/**
 * Internal remote dropship console spawned inside the synth bracer.
 *
 * Differences from the base flight console:
 * - is_remote = TRUE  → unlocks automated-control and shuttle-select UI (CIC-style)
 * - can_change_shuttle = TRUE → lets the user pick which shuttle to control
 * - needs_power = FALSE → it is tucked inside an item; no APC needed
 * - ui_state → inventory_state instead of the default strict-adjacency check,
 *   because the object lives inside the bracer which is on the wearer's hand
 */
/obj/structure/machinery/computer/shuttle/dropship/flight/bracer_remote
	name = "SIMI dropship remote link"
	is_remote = TRUE
	can_change_shuttle = TRUE
	needs_power = FALSE

/obj/structure/machinery/computer/shuttle/dropship/flight/bracer_remote/ui_state(mob/user)
	var/obj/docking_port/mobile/marine_dropship/shuttle = SSshuttle.getShuttle(shuttleId)
	if(shuttle?.is_hijacked)
		return GLOB.never_state
	return GLOB.always_state
