/obj/item/device/simi_chip
	name = "PK-130 SIMI programmable circuit (NOT FOR USE)"
	desc = "A programmable computer circuit used within the PK-130 SINI wrist-mounted computer to add or unlock various functions."
	icon = 'icons/obj/items/synth/bracer.dmi'
	icon_state = "simi_chip_white"

	/// The action this chip will add to the SIMI
	var/chip_action = /datum/action/human_action
	/// If this chip is 'secret' or not (cannot be removed/one time use)
	var/secret = FALSE

/obj/item/device/simi_chip/repair
	name = "PK-130 SIMI programmable circuit (Self-Repair)"
	chip_action = /datum/action/human_action/synth_bracer/repair_form
	icon_state = "simi_chip_red"

/obj/item/device/simi_chip/protect
	name = "PK-130 SIMI programmable circuit (Damage Bracing)"
	icon_state = "simi_chip_blue"
	chip_action = /datum/action/human_action/synth_bracer/protective_form

/obj/item/device/simi_chip/anchor
	name = "PK-130 SIMI programmable circuit (Anchor)"
	icon_state = "simi_chip_blue"
	chip_action = /datum/action/human_action/synth_bracer/anchor_form

/obj/item/device/simi_chip/rescue_hook
	name = "PK-130 SIMI programmable circuit (Rescue Hook)"
	chip_action = /datum/action/human_action/activable/synth_bracer/rescue_hook

/obj/item/device/simi_chip/motion_detector
	name = "PK-130 SIMI programmable circuit (Motion Detector)"
	chip_action = /datum/action/human_action/synth_bracer/motion_detector
	desc = "A programmable computer circuit used within the PK-130 SIMI wrist-mounted computer to add or unlock various functions. This one activates a motion detector capability, at a running cost of power."

/obj/item/device/simi_chip/tactical_map
	name = "PK-130 SIMI programmable circuit (Tactical Map)"
	chip_action = /datum/action/human_action/synth_bracer/tactical_map

/obj/item/device/simi_chip/live_tactical_map
	name = "PK-130 SIMI programmable circuit (Live Tactical Map)"
	desc = "A programmable circuit that integrates a real-time tactical minimap feed into the SIMI, showing live unit positions. Includes drawing tools for marking positions for your squad."
	chip_action = /datum/action/human_action/synth_bracer/live_tactical_map

/obj/item/device/simi_chip/laser_designator
	name = "PK-130 SIMI programmable circuit (Ocular Upgrade)"
	desc = "A programmable circuit that upgrades the SIMI's integrated binoculars to a laser designator, enabling CAS target marking and rangefinder modes. Adds a mode-toggle action when the designator is deployed."
	chip_action = /datum/action/human_action/synth_bracer/laser_designator

/obj/item/device/simi_chip/battery_upgrade
	name = "PK-130 SIMI programmable circuit (Extended Battery)"
	desc = "A high-density power cell expansion for the PK-130 SIMI computer. Doubles the available battery capacity."
	icon_state = "simi_chip_blue"
	chip_action = /datum/action/human_action/synth_bracer/battery_upgrade

/// Informational action button added by the extended battery chip.
/// Reports current charge/max when clicked; the real effect (doubled capacity) is applied in synth_bracer.dm attackby.
/datum/action/human_action/synth_bracer/battery_upgrade
	name = "Extended Battery Status"
	action_icon_state = "crew_monitor"
	handles_cooldown = TRUE
	handles_charge_cost = TRUE
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/battery_upgrade/form_call(obj/item/clothing/gloves/synth/bracer, mob/user)
	to_chat(user, SPAN_NOTICE("SIMI Extended Battery installed — Charge: <b>[bracer.battery_charge]/[bracer.battery_charge_max]</b>"))
