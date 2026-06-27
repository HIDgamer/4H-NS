/obj/item/clothing/gloves/synth
	var/obj/item/device/binoculars/binos
	/// TRUE when the laser designator upgrade chip has swapped binos → designator
	var/binos_upgraded = FALSE

/obj/item/clothing/gloves/synth/Initialize(mapload, ...)
	. = ..()
	binos = new(src)
	RegisterSignal(binos, COMSIG_ITEM_DROPPED, PROC_REF(return_binos))

/obj/item/clothing/gloves/synth/attackby(obj/item/I, mob/user)
	if(I == binos)
		return_binos()
		return
	return ..()

/obj/item/clothing/gloves/synth/dropped(mob/user)
	. = ..()
	return_binos()

/obj/item/clothing/gloves/synth/Destroy()
	QDEL_NULL(binos)
	return ..()

/obj/item/clothing/gloves/synth/proc/deploy_binos(mob/M)
	if(!M.put_in_active_hand(binos))
		M.put_in_inactive_hand(binos)

/obj/item/clothing/gloves/synth/proc/return_binos()
	if(QDELETED(binos))
		binos = null
		return

	if(ismob(binos.loc))
		var/mob/M = binos.loc
		M.drop_inv_item_to_loc(binos, src)
	else
		binos.forceMove(src)

/// Swaps the integrated binoculars for a laser designator. Called when the ocular upgrade chip is slotted.
/obj/item/clothing/gloves/synth/proc/upgrade_binos()
	if(binos_upgraded)
		return
	if(!QDELETED(binos))
		UnregisterSignal(binos, COMSIG_ITEM_DROPPED)
		if(ismob(binos.loc))
			var/mob/M = binos.loc
			M.drop_inv_item_to_loc(binos, src)
		qdel(binos)
	binos = new /obj/item/device/binoculars/range/designator(src)
	RegisterSignal(binos, COMSIG_ITEM_DROPPED, PROC_REF(return_binos))
	binos_upgraded = TRUE

/// Reverts the laser designator back to standard binoculars. Called when the ocular upgrade chip is removed.
/obj/item/clothing/gloves/synth/proc/downgrade_binos()
	if(!binos_upgraded)
		return
	if(!QDELETED(binos))
		UnregisterSignal(binos, COMSIG_ITEM_DROPPED)
		if(ismob(binos.loc))
			var/mob/M = binos.loc
			M.drop_inv_item_to_loc(binos, src)
		qdel(binos)
	binos = new /obj/item/device/binoculars(src)
	RegisterSignal(binos, COMSIG_ITEM_DROPPED, PROC_REF(return_binos))
	binos_upgraded = FALSE


/datum/action/human_action/synth_bracer/deploy_binoculars
	name = "Deploy Binoculars"
	action_icon_state = "far_sight"
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/deploy_ocular_binos/can_use_action()
	if(QDELETED(synth_bracer.binos) || synth_bracer.binos.loc != synth_bracer)
		to_chat(synth, SPAN_WARNING("The ocular device isn't inside the SIMI anymore."))
		return FALSE
	if(synth.l_hand && synth.r_hand)
		to_chat(synth, SPAN_WARNING("You need at least one free hand."))
		return FALSE
	return ..()

/datum/action/human_action/synth_bracer/deploy_binoculars/action_activate()
	..()
	if(COOLDOWN_FINISHED(synth_bracer, sound_cooldown))
		COOLDOWN_START(synth_bracer, sound_cooldown, 5 SECONDS)
		playsound(synth_bracer.loc,'sound/machines/click.ogg', 25, TRUE)
	if(synth_bracer.binos.loc == synth_bracer)
		to_chat(synth, SPAN_NOTICE("You deploy your [synth_bracer.binos_upgraded ? "laser designator" : "binoculars"]."))
		synth_bracer.deploy_binos(synth)
	else
		to_chat(synth, SPAN_NOTICE("You return your [synth_bracer.binos_upgraded ? "laser designator" : "binoculars"]."))
		synth_bracer.return_binos(synth)


/// Chip action: added when the ocular upgrade chip is slotted.
/// Toggles the deployed laser designator between CAS-lasing and rangefinder modes.
/datum/action/human_action/synth_bracer/laser_designator
	name = "Toggle Designator Mode"
	action_icon_state = "far_sight"
	handles_cooldown = TRUE
	handles_charge_cost = TRUE
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/laser_designator/can_use_action()
	var/obj/item/device/binoculars/range/designator/des = synth_bracer.binos
	if(!istype(des))
		to_chat(synth, SPAN_WARNING("No laser designator upgrade is installed."))
		return FALSE
	if(!ismob(des.loc))
		to_chat(synth, SPAN_WARNING("Deploy the laser designator first."))
		return FALSE
	if(des.laser || des.coord)
		to_chat(synth, SPAN_WARNING("Cannot switch modes while actively lasing a target."))
		return FALSE
	return ..()

/datum/action/human_action/synth_bracer/laser_designator/form_call(obj/item/clothing/gloves/synth/bracer, mob/user)
	var/obj/item/device/binoculars/range/designator/des = bracer.binos
	if(!istype(des))
		return
	des.toggle_bino_mode(user)
