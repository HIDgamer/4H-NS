/obj/structure/machinery/computer/cameras/internal
	name = "SYN-ITC internal camera link"
	desc = "An internal camera console for accessing organic network cameras."
	icon_state = "cameras"
	density = FALSE
	use_power = USE_POWER_NONE
	idle_power_usage = 0
	active_power_usage = 0
	needs_power = FALSE
	colony_camera_mapload = FALSE
	explo_proof = TRUE
	circuit = null

/obj/structure/machinery/computer/cameras/internal/attack_hand(mob/user)
	return

/obj/structure/machinery/computer/cameras/internal/attack_remote(mob/user)
	return

/obj/structure/machinery/computer/cameras/internal/ui_state(mob/user)
	return GLOB.always_state
