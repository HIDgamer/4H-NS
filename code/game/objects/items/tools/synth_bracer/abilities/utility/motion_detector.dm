/obj/item/clothing/gloves/synth
	var/obj/item/device/motiondetector/motion_detector
	var/motion_detector_active = FALSE
	var/motion_detector_recycle = 120
	var/motion_detector_cooldown = 10   // scan every 10 ticks (~5 seconds at 0.5s/tick)
	var/motion_detector_cost = 1        // 1 charge per scan; full battery lasts ~16 minutes
	/// TRUE while the TGUI is open — keeps process() running for live battery updates
	var/ui_displaying = FALSE
	var/ui_display_tick = 0
	var/ui_display_interval = 5         // push battery data update every 5 ticks
	var/ui_drain_tick = 0
	var/ui_drain_interval = 40          // drain 1 charge every 40 ticks (~20 seconds) while UI open

/obj/item/clothing/gloves/synth/Initialize(mapload, ...)
	. = ..()
	motion_detector = new /obj/item/device/motiondetector/simi(src)
	motion_detector.iff_signal = faction

/obj/item/clothing/gloves/synth/process()
	if(!ishuman(loc))
		STOP_PROCESSING(SSobj, src)
		motion_detector_active = FALSE
		ui_displaying = FALSE
		return

	// Live battery display and ambient UI drain
	if(ui_displaying)
		ui_display_tick++
		if(ui_display_tick >= ui_display_interval)
			ui_display_tick = 0
			SStgui.update_uis(src)
		if(battery_charge > 0)
			ui_drain_tick++
			if(ui_drain_tick >= ui_drain_interval)
				ui_drain_tick = 0
				drain_charge(loc, 1, FALSE)

	if(!motion_detector_active)
		if(!ui_displaying)
			STOP_PROCESSING(SSobj, src)
		return

	if(battery_charge <= 1)
		motion_detector_active = FALSE
		update_icon()
		var/datum/action/human_action/synth_bracer/motion_detector/TMD = locate(/datum/action/human_action/synth_bracer/motion_detector) in actions_list_actions
		if(TMD)
			TMD.update_icon()
		to_chat(loc, SPAN_WARNING("SIMI: Motion detector offline — insufficient power."))
		if(!ui_displaying)
			STOP_PROCESSING(SSobj, src)
		return

	motion_detector_recycle--
	if(!motion_detector_recycle)
		motion_detector_recycle = initial(motion_detector_recycle)
		motion_detector.refresh_blip_pool()

	motion_detector_cooldown--
	if(motion_detector_cooldown)
		return
	motion_detector_cooldown = initial(motion_detector_cooldown)
	motion_detector.scan()
	drain_charge(loc, motion_detector_cost, FALSE)

/obj/item/clothing/gloves/synth/dropped(mob/user)
	. = ..()
	ui_displaying = FALSE
	ui_display_tick = 0
	ui_drain_tick = 0
	if(motion_detector && motion_detector_active)
		toggle_motion_detector(user)

/obj/item/clothing/gloves/synth/Destroy()
	QDEL_NULL(motion_detector)
	. = ..()

/obj/item/clothing/gloves/synth/proc/toggle_motion_detector(mob/user)
	if(!motion_detector)
		to_chat(user, SPAN_WARNING("No motion detector located!"))
		return FALSE
	to_chat(user, SPAN_NOTICE("You [motion_detector_active? "<B>disable</b>" : "<B>enable</b>"] \the [src]'s motion detector."))
	if(COOLDOWN_FINISHED(src, sound_cooldown))
		playsound(src, 'sound/machines/terminal_prompt_deny.ogg', 35, TRUE)
		COOLDOWN_START(src, sound_cooldown, 5 SECONDS)
	motion_detector_active = !motion_detector_active
	var/datum/action/human_action/synth_bracer/motion_detector/TMD = locate(/datum/action/human_action/synth_bracer/motion_detector) in actions_list_actions
	TMD.update_icon()
	update_icon()

	if(!motion_detector_active)
		if(!ui_displaying)
			STOP_PROCESSING(SSobj, src)
	else
		START_PROCESSING(SSobj, src)
	return TRUE

/datum/action/human_action/synth_bracer/motion_detector
	name = "Toggle Motion Detector"
	action_icon_state = "motion_detector"
	handles_charge_cost = TRUE
	handles_cooldown = TRUE
	charge_cost = 2
	human_adaptable = TRUE

/datum/action/human_action/synth_bracer/motion_detector/action_activate()
	..()
	synth_bracer.toggle_motion_detector(synth)

/datum/action/human_action/synth_bracer/motion_detector/proc/update_icon()
	if(!synth_bracer)
		return

	if(synth_bracer.motion_detector_active)
		button.icon_state = "template_on"
	else
		button.icon_state = "template"

/// Bracer-specific subtype: the detector lives inside the gloves obj, not directly in a human's inventory.
/obj/item/device/motiondetector/simi

/obj/item/device/motiondetector/simi/get_user()
	if(istype(loc, /obj/item/clothing/gloves/synth))
		var/obj/item/clothing/gloves/synth/bracer = loc
		if(ishuman(bracer.loc))
			return bracer.loc
	return null
