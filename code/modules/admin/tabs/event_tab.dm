/client/proc/cmd_admin_change_custom_event()
	set name = "Setup Event Info"
	set category = "Admin.Events"

	if(!admin_holder)
		to_chat(usr, "Only administrators may use this command.")
		return

	if(!LAZYLEN(GLOB.custom_event_info_list))
		to_chat(usr, "custom_event_info_list is not initialized, tell a dev.")
		return

	var/list/temp_list = list()

	for(var/T in GLOB.custom_event_info_list)
		var/datum/custom_event_info/CEI = GLOB.custom_event_info_list[T]
		temp_list["[CEI.msg ? "(x) [CEI.faction]" : CEI.faction]"] = CEI.faction

	var/faction = tgui_input_list(usr, "Select faction. Ghosts will see only \"Global\" category message. Factions with event message set are marked with (x).", "Faction Choice", temp_list)
	if(!faction)
		return

	faction = temp_list[faction]

	if(!GLOB.custom_event_info_list[faction])
		to_chat(usr, "Error has occurred, [faction] category is not found.")
		return

	var/datum/custom_event_info/CEI = GLOB.custom_event_info_list[faction]

	var/input = input(usr, "Enter the custom event message for \"[faction]\" category. Be descriptive. \nTo remove the event message, remove text and confirm.", "[faction] Event Message", CEI.msg) as message|null
	if(isnull(input))
		return

	if(input == "" || !input)
		CEI.msg = ""
		message_admins("[key_name_admin(usr)] has removed the event message for \"[faction]\" category.")
		return

	CEI.msg = html_encode(input)
	message_admins("[key_name_admin(usr)] has changed the event message for \"[faction]\" category.")

	CEI.handle_event_info_update(faction)

/client/proc/get_whitelisted_clients()
	set name = "Find Whitelisted Players"
	set category = "Admin.Events"
	if(!admin_holder)
		return

	var/flag = tgui_input_list(src, "Which flag?", "Whitelist Flags", GLOB.bitfields["whitelist_status"])

	var/list/ckeys = list()
	for(var/client/test_client in GLOB.clients)
		if(test_client.check_whitelist_status(GLOB.bitfields["whitelist_status"][flag]))
			ckeys += test_client.ckey
	if(!length(ckeys))
		to_chat(src, SPAN_NOTICE("There are no players with that whitelist online"))
		return
	to_chat(src, SPAN_NOTICE("Whitelist holders: [ckeys.Join(", ")]."))

/client/proc/change_security_level()
	if(!check_rights(R_ADMIN))
		return
	var sec_level = input(usr, "It's currently code [get_security_level()].", "Select Security Level")  as null|anything in (list("green","blue","red","delta")-get_security_level())
	if(sec_level && alert("Switch from code [get_security_level()] to code [sec_level]?","Change security level?","Yes","No") == "Yes")
		set_security_level(seclevel2num(sec_level))
		log_admin("[key_name(usr)] changed the security level to code [sec_level].")

/client/proc/toggle_gun_restrictions()
	if(!admin_holder || !config)
		return

	if(CONFIG_GET(flag/remove_gun_restrictions))
		to_chat(src, "<b>Enabled gun restrictions.</b>")
		message_admins("Admin [key_name_admin(usr)] has enabled WY gun restrictions.")
	else
		to_chat(src, "<b>Disabled gun restrictions.</b>")
		message_admins("Admin [key_name_admin(usr)] has disabled WY gun restrictions.")
	CONFIG_SET(flag/remove_gun_restrictions, !CONFIG_GET(flag/remove_gun_restrictions))

/client/proc/togglebuildmodeself()
	set name = "Buildmode"
	set category = "Admin.Events"
	if(!check_rights(R_ADMIN))
		return

	if(src.mob)
		togglebuildmode(src.mob)

/client/proc/drop_bomb()
	set name = "Drop Bomb"
	set desc = "Cause an explosion of varying strength at your location."
	set category = "Admin.Fun"

	var/turf/epicenter = mob.loc
	handle_bomb_drop(epicenter)

/client/proc/handle_bomb_drop(atom/epicenter)
	var/custom_limit = 5000
	var/power_warn_threshold = 500
	var/falloff_warn_threshold = 0.05
	var/list/choices = list("Small Bomb", "Medium Bomb", "Big Bomb", "Custom Bomb")
	var/list/falloff_shape_choices = list("CANCEL", "Linear", "Exponential")
	var/choice = tgui_input_list(usr, "What size explosion would you like to produce?", "Drop Bomb", choices)
	var/datum/cause_data/cause_data = create_cause_data("divine intervention")
	switch(choice)
		if(null)
			return 0
		if("Small Bomb")
			explosion(epicenter, 1, 2, 3, 3, , , , cause_data)
		if("Medium Bomb")
			explosion(epicenter, 2, 3, 4, 4, , , , cause_data)
		if("Big Bomb")
			explosion(epicenter, 3, 5, 7, 5, , , , cause_data)
		if("Custom Bomb")
			var/power = tgui_input_number(src, "Power?", "Power?")
			if(!power)
				return

			var/falloff = tgui_input_number(src, "Falloff?", "Falloff?")
			if(!falloff)
				return

			var/shape_choice = tgui_input_list(src, "Select falloff shape?", "Select falloff shape", falloff_shape_choices)
			var/explosion_shape = EXPLOSION_FALLOFF_SHAPE_LINEAR
			switch(shape_choice)
				if("CANCEL")
					return 0
				if("Exponential")
					explosion_shape = EXPLOSION_FALLOFF_SHAPE_EXPONENTIAL

			if(power > custom_limit)
				return

			if((power >= power_warn_threshold) && ((1 / (power / falloff)) <= falloff_warn_threshold) && (explosion_shape == EXPLOSION_FALLOFF_SHAPE_LINEAR)) // The lag can be a bit situational, but a large-power explosion with minimal (linear) falloff can absolutely bring the server to a halt in certain cases.
				if(tgui_input_list(src, "This bomb has the potential to lag the server. Are you sure you wish to drop it?", "Drop confirm", list("Yes", "No")) != "Yes")
					return

			cell_explosion(epicenter, power, falloff, explosion_shape, null, cause_data)
			message_admins("[key_name(src, TRUE)] dropped a custom cell bomb with power [power], falloff [falloff] and falloff_shape [shape_choice]!")
	message_admins("[ckey] used 'Drop Bomb' at [epicenter.loc].")


/client/proc/cmd_admin_emp(atom/O as obj|mob|turf in world)
	set name = "EM Pulse"
	set category = "Admin.Fun"

	if(!check_rights(R_DEBUG|R_ADMIN))
		return

	var/heavy = input("Range of heavy pulse.", text("Input"))  as num|null
	if(heavy == null)
		return
	var/light = input("Range of light pulse.", text("Input"))  as num|null
	if(light == null)
		return

	if(!heavy && !light)
		return

	empulse(O, heavy, light)
	message_admins("[key_name_admin(usr)] created an EM PUlse ([heavy],[light]) at ([O.x],[O.y],[O.z])")
	return

/datum/admins/proc/admin_force_ERT_shuttle()
	set name = "Force ERT Shuttle"
	set desc = "Force Launch the ERT Shuttle."
	set category = "Admin.Shuttles"

	if (!SSticker.mode)
		return
	if(!check_rights(R_EVENT))
		return

	var/list/shuttle_map = list()
	for(var/obj/docking_port/mobile/emergency_response/ert_shuttles in SSshuttle.mobile)
		shuttle_map[ert_shuttles.name] = ert_shuttles.id
	var/tag = tgui_input_list(usr, "Which ERT shuttle should be force launched?", "Select an ERT Shuttle:", shuttle_map)
	if(!tag)
		return

	var/shuttleId = shuttle_map[tag]
	var/list/docks = SSshuttle.stationary
	var/list/targets = list()
	var/list/target_names = list()
	var/obj/docking_port/mobile/emergency_response/ert = SSshuttle.getShuttle(shuttleId)
	for(var/obj/docking_port/stationary/emergency_response/dock in docks)
		var/can_dock = ert.canDock(dock)
		if(can_dock == SHUTTLE_CAN_DOCK)
			targets += list(dock)
			target_names +=  list(dock.name)
	var/dock_name = tgui_input_list(usr, "Where on the [MAIN_SHIP_NAME] should the shuttle dock?", "Select a docking zone:", target_names)
	var/launched = FALSE
	if(!dock_name)
		return
	for(var/obj/docking_port/stationary/emergency_response/dock as anything in targets)
		if(dock.name == dock_name)
			var/obj/docking_port/stationary/target = SSshuttle.getDock(dock.id)
			ert.request(target)
			launched=TRUE
	if(!launched)
		to_chat(usr, SPAN_WARNING("Unable to launch this Distress shuttle at this moment. Aborting."))
		return

	message_admins("[key_name_admin(usr)] force launched a distress shuttle ([tag])")

/datum/admins/proc/admin_force_distress()
	set name = "Distress Beacon"
	set desc = "Call a distress beacon. This should not be done if the shuttle's already been called."
	set category = "Admin.Shuttles"

	if (!SSticker.mode)
		return

	if(!check_rights(R_EVENT)) // Seems more like an event thing than an admin thing
		return

	var/list/list_of_calls = list()
	var/list/assoc_list = list()

	for(var/datum/emergency_call/L in SSticker.mode.all_calls)
		if(L && L.name != "name")
			list_of_calls += L.name
			assoc_list += list(L.name = L)
	list_of_calls = sortList(list_of_calls)

	list_of_calls += "Randomize"

	var/choice = tgui_input_list(usr, "Which distress call?", "Distress Signal", list_of_calls)

	if(!choice)
		return

	var/datum/emergency_call/chosen_ert
	if(choice == "Randomize")
		chosen_ert = SSticker.mode.get_random_call()
	else
		var/datum/emergency_call/em_call = assoc_list[choice]
		chosen_ert = new em_call.type()

	if(!istype(chosen_ert))
		return
	var/quiet_launch = TRUE
	var/ql_prompt = tgui_alert(usr, "Would you like to broadcast the beacon launch? This will reveal the distress beacon to all players.", "Announce distress beacon?", list("Yes", "No"), 20 SECONDS)
	if(ql_prompt == "Yes")
		quiet_launch = FALSE

	var/announce_receipt = FALSE
	var/ar_prompt = tgui_alert(usr, "Would you like to announce the beacon received message? This will reveal the distress beacon to all players.", "Announce beacon received?", list("Yes", "No"), 20 SECONDS)
	if(ar_prompt == "Yes")
		announce_receipt = TRUE

	var/turf/override_spawn_loc
	var/prompt = tgui_alert(usr, "Spawn at their assigned spawn, or at your location?", "Spawnpoint Selection", list("Spawn", "Current Location"), 0)
	if(!prompt)
		qdel(chosen_ert)
		return
	if(prompt == "Current Location")
		override_spawn_loc = get_turf(usr)

	chosen_ert.activate(quiet_launch, announce_receipt, override_spawn_loc)

	message_admins("[key_name_admin(usr)] admin-called a [choice == "Randomize" ? "randomized ":""]distress beacon: [chosen_ert.name]")

/datum/admins/proc/admin_force_evacuation()
	set name = "Trigger Evacuation"
	set desc = "Triggers emergency evacuation."
	set category = "Admin.Events"

	if(!SSticker.mode || !check_rights(R_ADMIN))
		return
	set_security_level(SEC_LEVEL_RED)
	SShijack.initiate_evacuation()

	message_admins("[key_name_admin(usr)] forced an emergency evacuation.")

/datum/admins/proc/admin_cancel_evacuation()
	set name = "Cancel Evacuation"
	set desc = "Cancels emergency evacuation."
	set category = "Admin.Events"

	if(!SSticker.mode || !check_rights(R_ADMIN))
		return
	SShijack.cancel_evacuation()

	message_admins("[key_name_admin(usr)] canceled an emergency evacuation.")

/datum/admins/proc/add_req_points()
	set name = "Add Requisitions Points"
	set desc = "Add points to the ship requisitions department."
	set category = "Admin.Events"
	if(!SSticker.mode || !check_rights(R_ADMIN))
		return

	var/points_to_add = tgui_input_real_number(usr, "Enter the amount of points to give, or a negative number to subtract. 1 point = $100.", "Points", 0)
	if(!points_to_add)
		return
	else if((GLOB.supply_controller.points + points_to_add) < 0)
		GLOB.supply_controller.points = 0
	else if((GLOB.supply_controller.points + points_to_add) > 99999)
		GLOB.supply_controller.points = 99999
	else
		GLOB.supply_controller.points += points_to_add


	message_admins("[key_name_admin(usr)] granted requisitions [points_to_add] points.")
	if(points_to_add >= 0)
		shipwide_ai_announcement("Additional Supply Budget has been authorised for this operation.")
	message_admins("[key_name_admin(usr)] granted UPP requisitions [points_to_add] points.")

/datum/admins/proc/add_upp_req_points()
	set name = "Add UPP Requisitions Points"
	set desc = "Add points to the UPP ship requisitions department."
	set category = "Admin.Events"
	if(!SSticker.mode || !check_rights(R_ADMIN))
		return

	var/points_to_add = tgui_input_real_number(usr, "Enter the amount of points to give, or a negative number to subtract. 1 point = $100.", "Points", 0)
	if(!points_to_add)
		return
	else if((GLOB.supply_controller_upp.points + points_to_add) < 0)
		GLOB.supply_controller_upp.points = 0
	else if((GLOB.supply_controller_upp.points + points_to_add) > 99999)
		GLOB.supply_controller_upp.points = 99999
	else
		GLOB.supply_controller.points += points_to_add
	message_admins("[key_name_admin(usr)] granted UPP requisitions [points_to_add] points.")


/datum/admins/proc/check_req_heat()
	set name = "Check Requisitions Heat"
	set desc = "Check how close the CMB is to arriving to search Requisitions."
	set category = "Admin.Events"
	if(!SSticker.mode || !check_rights(R_ADMIN))
		return

	var/req_heat_change = tgui_input_real_number(usr, "Set the new requisitions black market heat. ERT is called at 100, disabled at -1. Current Heat: [GLOB.supply_controller.black_market_heat]", "Modify Req Heat", 0, 100, -1)
	if(!req_heat_change)
		return

	GLOB.supply_controller.black_market_heat = req_heat_change
	message_admins("[key_name_admin(usr)] set requisitions heat to [req_heat_change].")


/datum/admins/proc/admin_force_selfdestruct()
	set name = "Self-Destruct"
	set desc = "Trigger self-destruct countdown. This should not be done if the self-destruct has already been called."
	set category = "Admin.Events"

	if(!SSticker.mode || !check_rights(R_ADMIN) || get_security_level() == "delta")
		return

	if(alert(src, "Are you sure you want to do this?", "Confirmation", "Yes", "No") != "Yes")
		return

	set_security_level(SEC_LEVEL_DELTA)

	message_admins("[key_name_admin(usr)] admin-started self-destruct system.")

/client/proc/view_faxes()
	set name = "Reply to Faxes"
	set desc = "View faxes from this round"
	set category = "Admin.Events"

	if(!admin_holder)
		return

	var/list/options = list(
		"Weyland-Yutani", "High Command", "Provost", "Press",
		"Colonial Marshal Bureau", "Union of Progressive Peoples",
		"Three World Empire", "Colonial Liberation Front",
		"Other", "Cancel")
	var/answer = tgui_input_list(src, "Which kind of faxes would you like to see?", "Faxes", options)
	switch(answer)
		if("Weyland-Yutani")
			var/body = "<body>"

			for(var/text in GLOB.WYFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to Weyland-Yutani", "wyfaxviewer", width = 300, height = 600)

		if("High Command")
			var/body = "<body>"

			for(var/text in GLOB.USCMFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to High Command", "uscmfaxviewer", width = 300, height = 600)

		if("Provost")
			var/body = "<body>"

			for(var/text in GLOB.ProvostFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to the Provost Office", "provostfaxviewer", width = 300, height = 600)

		if("Press")
			var/body = "<body>"

			for(var/text in GLOB.PressFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to Press organizations", "pressfaxviewer", width = 300, height = 600)

		if("Colonial Marshal Bureau")
			var/body = "<body>"

			for(var/text in GLOB.CMBFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to the Colonial Marshal Bureau", "cmbfaxviewer", width = 300, height = 600)

		if("Union of Progressive Peoples")
			var/body = "<body>"

			for(var/text in GLOB.UPPFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to the Union of Progressive Peoples", "uppfaxviewer", width = 300, height = 600)

		if("Three World Empire")
			var/body = "<body>"

			for(var/text in GLOB.TWEFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to the Three World Empire", "twefaxviewer", width = 300, height = 600)

		if("Colonial Liberation Front")
			var/body = "<body>"

			for(var/text in GLOB.CLFFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Faxes to the Colonial Liberation Front", "clffaxviewer", width = 300, height = 600)

		if("Other")
			var/body = "<body>"

			for(var/text in GLOB.GeneralFaxes)
				body += text
				body += "<br><br>"

			body += "<br><br></body>"
			show_browser(src, body, "Inter-machine Faxes", "otherfaxviewer", width = 300, height = 600)
		if("Cancel")
			return

/client/proc/award_medal()
	if(!check_rights(R_ADMIN))
		return

	give_medal_award(as_admin=TRUE)

/client/proc/award_jelly()
	if(!check_rights(R_ADMIN))
		return

	// Mostly replicated code from observer.dm.hive_status()
	var/list/hives = list()
	var/datum/hive_status/last_hive_checked

	var/datum/hive_status/hive
	for(var/hivenumber in GLOB.hive_datum)
		hive = GLOB.hive_datum[hivenumber]
		if(length(hive.totalXenos) > 0 || length(hive.total_dead_xenos) > 0)
			hives += list("[hive.name]" = hive.hivenumber)
			last_hive_checked = hive

	if(!length(hives))
		to_chat(src, SPAN_ALERT("There seem to be no hives at the moment."))
		return
	else if(length(hives) > 1) // More than one hive, display an input menu for that
		var/faction = tgui_input_list(src, "Select which hive to award", "Hive Choice", hives, theme="hive_status")
		if(!faction)
			to_chat(src, SPAN_ALERT("Hive choice error. Aborting."))
			return
		last_hive_checked = GLOB.hive_datum[hives[faction]]

	give_jelly_award(last_hive_checked, as_admin=TRUE)

/client/proc/give_nuke()
	if(!check_rights(R_ADMIN))
		return
	var/nukename = "Decrypted Operational Nuke"
	var/encrypt = tgui_alert(src, "Do you want the nuke to be already decrypted?", "Nuke Type", list("Encrypted", "Decrypted"), 20 SECONDS)
	if(encrypt == "Encrypted")
		nukename = "Encrypted Operational Nuke"
	var/prompt = tgui_alert(src, "THIS CAN BE USED TO END THE ROUND. Are you sure you want to spawn a nuke? The nuke will be put onto the ASRS Lift.", "DEFCON 1", list("No", "Yes"), 30 SECONDS)
	if(prompt != "Yes")
		return

	var/nuketype = GLOB.supply_packs_types[nukename]

	var/datum/supply_order/new_order = new()
	new_order.ordernum = GLOB.supply_controller.ordernum++
	new_order.objects = list(GLOB.supply_packs_datums[nuketype])
	new_order.orderedby = MAIN_AI_SYSTEM
	new_order.approvedby = MAIN_AI_SYSTEM
	GLOB.supply_controller.shoppinglist += new_order

	marine_announcement("A nuclear device has been supplied and will be delivered to requisitions via ASRS.", "NUCLEAR ARSENAL ACQUIRED", 'sound/misc/notice2.ogg')
	message_admins("[key_name_admin(usr)] admin-spawned \a [encrypt] nuke.")
	log_game("[key_name_admin(usr)] admin-spawned \a [encrypt] nuke.")

/client/proc/turn_everyone_into_primitives()
	var/random_names = FALSE
	if (alert(src, "Do you want to give everyone random numbered names?", "Confirmation", "Yes", "No") == "Yes")
		random_names = TRUE
	if (alert(src, "Are you sure you want to do this? It will laaag.", "Confirmation", "Yes", "No") != "Yes")
		return
	for(var/mob/living/carbon/human/H in GLOB.human_mob_list)
		if(ismonkey(H))
			continue
		H.set_species(pick("Monkey", "Yiren", "Stok", "Farwa", "Neaera"))
		H.is_important = TRUE
		if(random_names)
			var/random_name = "[lowertext(H.species.name)] ([rand(1, 999)])"
			H.change_real_name(H, random_name)
			var/obj/item/card/id/card = H.get_idcard()
			if(card)
				card.registered_name = H.real_name
				card.name = "[card.registered_name]'s [card.id_type] ([card.assignment])"

	message_admins("Admin [key_name(usr)] has turned everyone into a primitive")

/client/proc/force_hijack()
	set name = "Force Hijack"
	set desc = "Force a dropship to be hijacked"
	set category = "Admin.Shuttles"

	var/list/shuttles = list(DROPSHIP_ALAMO, DROPSHIP_NORMANDY)
	var/tag = tgui_input_list(usr, "Which dropship should be force hijacked?", "Select a dropship:", shuttles)
	if(!tag)
		return

	var/obj/docking_port/mobile/marine_dropship/dropship = SSshuttle.getShuttle(tag)

	if(!dropship)
		to_chat(src, SPAN_DANGER("Error: Attempted to force a dropship hijack but the shuttle datum was null. Code: MSD_FSV_DIN"))
		log_admin("Error: Attempted to force a dropship hijack but the shuttle datum was null. Code: MSD_FSV_DIN")
		return

	var/confirm = tgui_alert(usr, "Are you sure you want to hijack [dropship]?", "Force hijack", list("Yes", "No")) == "Yes"
	if(!confirm)
		return

	var/obj/structure/machinery/computer/shuttle/dropship/flight/computer = dropship.getControlConsole()
	computer.hijack(usr, force = TRUE)

/client/proc/cmd_admin_create_centcom_report()
	set name = "Report: Faction"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return
	var/faction = tgui_input_list(usr, "Please choose faction your announcement will be shown to.", "Faction Selection", (FACTION_LIST_HUMANOID - list(FACTION_YAUTJA) + list("Everyone (-Yautja)")))
	if(!faction)
		return
	var/input = input(usr, "Please enter announcement text. Be advised, this announcement will be heard both on Almayer and planetside by conscious humans of selected faction.", "What?", "") as message|null
	if(!input)
		return
	var/customname = input(usr, "Pick a title for the announcement. Confirm empty text for \"[faction] Update\" title.", "Title") as text|null
	if(isnull(customname))
		return
	if(!customname)
		customname = "[faction] Update"
	if(faction == FACTION_MARINE)
		for(var/obj/structure/machinery/computer/almayer_control/C in GLOB.machines)
			if(!(C.inoperable()))
				var/obj/item/paper/P = new /obj/item/paper( C.loc )
				P.name = "'[customname].'"
				P.info = input
				P.update_icon()
				C.messagetitle.Add("[customname]")
				C.messagetext.Add(P.info)

		if(alert("Press \"Yes\" if you want to announce it to ship crew and marines. Press \"No\" to keep it only as printed report on communication console.",,"Yes","No") == "Yes")
			if(alert("Do you want PMCs (not Death Squad) to see this announcement?",,"Yes","No") == "Yes")
				marine_announcement(input, customname, 'sound/AI/commandreport.ogg', faction, TRUE)
			else
				marine_announcement(input, customname, 'sound/AI/commandreport.ogg', faction, FALSE)
	else
		marine_announcement(input, customname, 'sound/AI/commandreport.ogg', faction)

	message_admins("[key_name_admin(src)] has created \a [faction] command report")
	log_admin("[key_name_admin(src)] [faction] command report: [input]")

/client/proc/cmd_admin_xeno_report()
	set name = "Report: Queen Mother"
	set desc = "Basically a command announcement, but only for selected Xeno's Hive"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return

	var/list/hives = list()
	for(var/hivenumber in GLOB.hive_datum)
		var/datum/hive_status/hive = GLOB.hive_datum[hivenumber]
		hives += list("[hive.name]" = hive.hivenumber)

	hives += list("All Hives" = "everything")
	var/hive_choice = tgui_input_list(usr, "Please choose the hive you want to see your announcement. Selecting \"All hives\" option will change title to \"Unknown Higher Force\"", "Hive Selection", hives)
	if(!hive_choice)
		return FALSE

	var/hivenumber = hives[hive_choice]


	var/input = input(usr, "This should be a message from the ruler of the Xenomorph race.", "What?", "") as message|null
	if(!input)
		return FALSE

	var/hive_prefix = ""
	if(GLOB.hive_datum[hivenumber])
		var/datum/hive_status/hive = GLOB.hive_datum[hivenumber]
		hive_prefix = "[hive.prefix] "

	if(hivenumber == "everything")
		xeno_announcement(input, hivenumber, HIGHER_FORCE_ANNOUNCE)
	else
		xeno_announcement(input, hivenumber, SPAN_ANNOUNCEMENT_HEADER_BLUE("[hive_prefix][QUEEN_MOTHER_ANNOUNCE]"))

	message_admins("[key_name_admin(src)] has created a [hive_choice] Queen Mother report")
	log_admin("[key_name_admin(src)] Queen Mother ([hive_choice]): [input]")

/client/proc/cmd_admin_create_AI_report()
	set name = "Report: ARES Comms"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return FALSE

	if(!ares_is_active())
		to_chat(usr, SPAN_WARNING("[MAIN_AI_SYSTEM] is destroyed, and cannot talk!"))
		return FALSE

	var/input = input(usr, "This is a standard message from the ship's AI. It uses Almayer General channel and won't be heard by humans without access to Almayer General channel (headset or intercom). Check with online staff before you send this. Do not use html.", "What?", "") as message|null
	if(!input)
		return FALSE

	if(!ares_can_interface())
		var/prompt = tgui_alert(src, "ARES interface processor is offline or destroyed, send the message anyways?", "Choose.", list("Yes", "No"), 20 SECONDS)
		if(prompt == "No")
			to_chat(usr, SPAN_WARNING("[MAIN_AI_SYSTEM] is not responding. It's interface processor may be offline or destroyed."))
			return FALSE

	ai_announcement(input)
	message_admins("[key_name_admin(src)] has created an AI comms report")
	log_admin("AI comms report: [input]")


/client/proc/cmd_admin_create_AI_apollo_report()
	set name = "Report: ARES Apollo"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return FALSE

	if(!ares_is_active())
		to_chat(usr, SPAN_WARNING("[MAIN_AI_SYSTEM] is destroyed, and cannot talk!"))
		return FALSE

	var/input = tgui_input_text(usr, "This is a broadcast from the ship AI to Working Joes and Maintenance Drones. Do not use html.", "What?", "")
	if(!input)
		return FALSE

	if(!ares_can_apollo())
		var/prompt = tgui_alert(src, "ARES APOLLO processor is offline or destroyed, send the message anyways?", "Choose.", list("Yes", "No"), 20 SECONDS)
		if(prompt != "Yes")
			to_chat(usr, SPAN_WARNING("[MAIN_AI_SYSTEM] is not responding. It's APOLLO processor may be offline or destroyed."))
			return FALSE

	ares_apollo_talk(input)
	message_admins("[key_name_admin(src)] has created an AI APOLLO report")
	log_admin("AI APOLLO report: [input]")

/client/proc/cmd_admin_create_AI_shipwide_report()
	set name = "Report: ARES Shipwide"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return
	var/input = input(usr, "This is an announcement type message from the ship's AI. This will be announced to every conscious human on Almayer z-level. Be aware, this will work even if ARES unpowered/destroyed. Check with online staff before you send this.", "What?", "") as message|null
	if(!input)
		return FALSE
	if(!ares_can_interface())
		var/prompt = tgui_alert(src, "ARES interface processor is offline or destroyed, send the message anyways?", "Choose.", list("Yes", "No"), 20 SECONDS)
		if(prompt == "No")
			to_chat(usr, SPAN_WARNING("[MAIN_AI_SYSTEM] is not responding. It's interface processor may be offline or destroyed."))
			return

	shipwide_ai_announcement(input)
	message_admins("[key_name_admin(src)] has created an AI shipwide report")
	log_admin("[key_name_admin(src)] AI shipwide report: [input]")

/client/proc/cmd_admin_create_predator_report()
	set name = "Report: Yautja AI"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return
	var/input = input(usr, "This is a message from the predator ship's AI. Check with online staff before you send this.", "What?", "") as message|null
	if(!input)
		return FALSE
	yautja_announcement(SPAN_YAUTJABOLDBIG(input))
	message_admins("[key_name_admin(src)] has created a predator ship AI report")
	log_admin("[key_name_admin(src)] predator ship AI report: [input]")

/client/proc/cmd_admin_world_narrate() // Allows administrators to fluff events a little easier -- TLE
	set name = "Narrate to Everyone"
	set category = "Admin.Events"

	if (!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return

	var/msg = input("Message:", text("Enter the text you wish to appear to everyone:")) as text

	if(!msg)
		return

	to_chat_spaced(world, html = SPAN_ANNOUNCEMENT_HEADER_BLUE(msg))
	message_admins("\bold GlobalNarrate: [key_name_admin(usr)] : [msg]")


/client
	var/remote_control = FALSE

/client/proc/toogle_door_control()
	set name = "Toggle Remote Control"
	set category = "Admin.Events"

	if(!check_rights(R_MOD|R_DEBUG))
		return

	remote_control = !remote_control
	message_admins("[key_name_admin(src)] has toggled remote control [remote_control? "on" : "off"] for themselves")

/client/proc/enable_event_mob_verbs()
	set name = "Mob Event Verbs - Show"
	set category = "Admin.Events"

	add_verb(src, GLOB.admin_mob_event_verbs_hideable)
	remove_verb(src, /client/proc/enable_event_mob_verbs)

/client/proc/hide_event_mob_verbs()
	set name = "Mob Event Verbs - Hide"
	set category = "Admin.Events"

	remove_verb(src, GLOB.admin_mob_event_verbs_hideable)
	add_verb(src, /client/proc/enable_event_mob_verbs)

// ----------------------------
// PANELS
// ----------------------------

/datum/admins/proc/event_panel()
	if(!check_rights(R_ADMIN,0))
		return

	var/dat = {"
		<B>Ship</B><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=securitylevel'>Set Security Level</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=distress'>Send a Distress Beacon</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=selfdestruct'>Activate Self-Destruct</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=evacuation_start'>Trigger Evacuation</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=evacuation_cancel'>Cancel Evacuation</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=disable_shuttle_console'>Disable Shuttle Control</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=add_req_points'>Add Requisitions Points</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=add_upp_req_points'>Add UPP Requisitions Points</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=check_req_heat'>Modify Requisitions Heat</A><BR>
		<BR>
		<B>Research</B><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=change_clearance'>Change Research Clearance</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=give_research_credits'>Give Research Credits</A><BR>
		<BR>
		<B>Power</B><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=unpower'>Unpower ship SMESs and APCs</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=power'>Power ship SMESs and APCs</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=quickpower'>Power ship SMESs</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=powereverything'>Power ALL SMESs and APCs everywhere</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=powershipreactors'>Repair and power all ship reactors</A><BR>
		<BR>
		<B>Events</B><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=blackout'>Break all lights</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=whiteout'>Repair all lights</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=comms_blackout'>Trigger a Communication Blackout</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=destructible_terrain'>Toggle destructible terrain</A><BR>
		<BR>
		<B>Misc</B><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=medal'>Award a medal</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=jelly'>Award a royal jelly</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=nuke'>Spawn a nuke</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=pmcguns'>Toggle PMC gun restrictions</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=monkify'>Turn everyone into monkies</A><BR>
		<A href='byond://?src=\ref[src];[HrefToken()];events=xenothumbs'>Give or take opposable thumbs and gun permits from xenos</A><BR>
		<BR>
		"}

	show_browser(usr, dat, "Events Panel", "events")
	return

/client/proc/event_panel()
	set name = "Event Panel"
	set category = "Admin.Panels"
	if (admin_holder)
		admin_holder.event_panel()
	return


/datum/admins/proc/chempanel()
	if(!check_rights(R_MOD))
		return

	var/dat
	if(check_rights(R_MOD,0))
		dat += {"<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=view_reagent'>View Reagent</A><br>
				"}
	if(check_rights(R_VAREDIT,0))
		dat += {"<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=view_reaction'>View Reaction</A><br>"}
		dat += {"<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=sync_filter'>Sync Reaction</A><br>
				<br>"}
	if(check_rights(R_SPAWN,0))
		dat += {"<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=spawn_reagent'>Spawn Reagent in Container</A><br>
				<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=make_report'>Make Chem Report</A><br>
				<br>"}
	if(check_rights(R_ADMIN,0))
		dat += {"<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=create_random_reagent'>Generate Reagent</A><br>
				<br>
				<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=create_custom_reagent'>Create Custom Reagent</A><br>
				<A href='byond://?src=\ref[src];[HrefToken()];chem_panel=create_custom_reaction'>Create Custom Reaction</A><br>
				"}

	show_browser(usr, dat, "Chem Panel", "chempanel", width = 210, height = 300)
	return

/client/proc/chem_panel()
	set name = "Chem Panel"
	set category = "Admin.Panels"
	if(admin_holder)
		admin_holder.chempanel()
	return

/// Shared by admin_spawn_humans/admin_spawn_xenos - rejects walls, dense turfs, and dense non-climbable structures (lockers, machines, etc.) so a map click can't spawn something inside a wall or on top of a real obstacle. Climbable structures (tables, racks) are still fine, same reasoning xeno_ai_movement.dm's get_blocking_obstacle() uses for what actually blocks movement.
/proc/is_valid_admin_spawn_turf(turf/T)
	if(!T || istype(T, /turf/closed) || T.density)
		return FALSE
	for(var/obj/structure/blocking_obstacle in T)
		if(blocking_obstacle.density && !blocking_obstacle.climbable)
			return FALSE
	return TRUE

// ─── Admin Spawn Terminal — TGUI datum (Human/Xeno/Job tabs) ────────────────
/**
 * Admin Spawn Terminal - a single tabbed CRT panel replacing the 2 previously-separate,
 * actually-dead tgui datums (admin_spawn_humans/admin_spawn_xenos - defined but never
 * instantiated by any verb, which instead still opened the legacy create_humans.html/
 * create_xenos.html browser popups) with one working panel that's actually wired up.
 * One shared click-intercept/arm-then-click state machine (same pattern the two originals
 * already used independently) drives both tabs.
 */
/datum/admin_spawn_terminal
	var/datum/admins/admin_datum
	/// Spawn/redress params stashed by "spawn"/arm_spawn while armed, consumed by InterceptClickOn() once the admin clicks a tile or mob.
	var/list/pending_params
	/// Which tab was active when the current arm happened - "human"/"xeno"/"job" - determines InterceptClickOn's click semantics (tile vs. victim vs. redress target).
	var/armed_panel
	/// If set (opened via right-click "Select Equipment" on a specific mob, or the player-panel Redress action), the Job tab is pre-locked to this mob - picking a preset applies immediately, no click-to-target step, matching the old single-target menu's behavior.
	var/mob/living/carbon/human/preset_target
	/// Which tab the frontend should open on - set once at construction, matches whichever verb opened the terminal (Create Humans/Create Xenos/Job Terminal all point here now).
	var/default_tab = "human"

/datum/admin_spawn_terminal/New(datum/admins/AD, mob/living/carbon/human/preset_target_mob, starting_tab)
	admin_datum = AD
	preset_target = preset_target_mob
	if(starting_tab)
		default_tab = starting_tab
	else if(preset_target_mob)
		default_tab = "job"

/datum/admin_spawn_terminal/Destroy()
	if(admin_datum?.owner?.click_intercept == src)
		admin_datum.owner.click_intercept = null
	admin_datum = null
	pending_params = null
	preset_target = null
	return ..()

/datum/admin_spawn_terminal/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new /datum/tgui(user, src, "AdminSpawnTerminal", "Admin Spawn Terminal")
		ui.open()

/// Closing the window (not just cancelling) left the spawn armed forever since nothing else cleared click_intercept - clear it here too.
/datum/admin_spawn_terminal/ui_close(mob/user)
	. = ..()
	if(user?.client?.click_intercept == src)
		user.client.click_intercept = null
	pending_params = null

/datum/admin_spawn_terminal/ui_state(mob/user)
	return GLOB.admin_state

/datum/admin_spawn_terminal/ui_static_data(mob/user)
	var/list/data = list()

	var/list/presets = list()
	for(var/p in GLOB.gear_name_presets_list)
		presets += p
	data["presets"] = presets

	var/list/hives = list()
	for(var/h in ALL_XENO_HIVES)
		hives += h
	data["hives"] = hives

	var/list/castes = list()
	for(var/c in ALL_XENO_CASTES)
		castes += c
	data["castes"] = castes

	data["default_tab"] = default_tab
	data["preset_target_name"] = preset_target ? preset_target.name : null
	data["ui_effects_enabled"] = admin_ui_effects_enabled(user)
	return data

/datum/admin_spawn_terminal/ui_assets(mob/user)
	. = ..()
	. += get_asset_datum(/datum/asset/simple/admin_ui_sounds)

/datum/admin_spawn_terminal/ui_data(mob/user)
	var/list/data = list()
	data["picking"] = (user.client?.click_intercept == src)
	return data

/// Pressing Spawn arms this instead of spawning immediately; the admin's next map click (see InterceptClickOn) is where it actually happens.
/datum/admin_spawn_terminal/proc/arm_spawn(mob/user, list/params)
	pending_params = params.Copy()
	armed_panel = params["panel"]
	if(user.client)
		user.client.click_intercept = src
	if(armed_panel == "job")
		to_chat(user, SPAN_NOTICE("Click a human to redress - stays armed until you right-click to cancel."))
	else if(armed_panel == "xeno" && params["mode"] == "burst")
		to_chat(user, SPAN_NOTICE("Click a living human to burst - stays armed until you right-click to cancel."))
	else
		to_chat(user, SPAN_NOTICE("Click tiles to spawn there - stays armed until you right-click to cancel."))
	SStgui.update_uis(src)

/**
 * Stays armed after a spawn instead of consuming pending_params on the first click, so an
 * admin can place a whole squad/hive by clicking tile after tile, or redress several mobs
 * in a row - right-click (matching the same LEFT_CLICK/RIGHT_CLICK modifier check buildmode's
 * own click-intercept modes use) is what actually cancels it.
 */
/datum/admin_spawn_terminal/proc/InterceptClickOn(mob/user, params, atom/A)
	var/list/modifiers = params2list(params)
	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		if(user.client)
			user.client.click_intercept = null
		pending_params = null
		to_chat(user, SPAN_NOTICE("Spawn cancelled."))
		SStgui.update_uis(src)
		return TRUE

	if(!pending_params)
		return TRUE

	if(armed_panel == "job")
		var/mob/living/carbon/human/victim = A
		if(!istype(victim))
			to_chat(user, SPAN_WARNING("Click a human to redress - right-click to cancel."))
			return TRUE
		do_redress(user, victim, pending_params)
		return TRUE

	if(armed_panel == "xeno" && pending_params["mode"] == "burst")
		var/mob/living/carbon/human/victim = A
		if(!istype(victim) || victim.stat == DEAD)
			to_chat(user, SPAN_WARNING("Click a living human to burst - right-click to cancel."))
			return TRUE
		var/burst_timer = clamp(text2num(pending_params["timer"]) || 0, 0, 300)
		if(burst_timer > 0)
			to_chat(user, SPAN_NOTICE("Burst armed on [key_name(victim)] - triggering in [burst_timer] second\s."))
			new /obj/effect/warning/explosive(get_turf(victim), burst_timer SECONDS)
			addtimer(CALLBACK(src, PROC_REF(do_burst), user, victim, pending_params), burst_timer SECONDS)
		else
			do_burst(user, victim, pending_params)
		return TRUE

	var/turf/spawn_turf = get_turf(A)
	if(!is_valid_admin_spawn_turf(spawn_turf))
		to_chat(user, SPAN_WARNING("Can't spawn there - pick an open tile, not a wall or something blocking movement."))
		return TRUE

	if(armed_panel == "human")
		do_spawn_humans(user, spawn_turf, pending_params)
	else if(armed_panel == "xeno")
		do_spawn_xenos(user, spawn_turf, pending_params)
	return TRUE

/datum/admin_spawn_terminal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!check_client_rights(user.client, R_SPAWN))
		return

	if(action == "cancel_spawn")
		if(user.client?.click_intercept == src)
			user.client.click_intercept = null
		pending_params = null
		return TRUE

	// Pre-targeted flow (opened via right-click Select Equipment / player-panel Redress) - apply immediately, no click-to-target needed.
	if(action == "redress_target")
		if(!preset_target || QDELETED(preset_target))
			return TRUE
		var/job_name = params["job"]
		if(!job_name || !(job_name in GLOB.gear_name_presets_list))
			return TRUE
		do_redress(user, preset_target, list("job" = job_name))
		return TRUE

	if(action == "spawn")
		if(SSticker?.current_state < GAME_STATE_PLAYING)
			to_chat(user, SPAN_WARNING("Wait until the game has started."))
			return TRUE
		var/panel = params["panel"]
		if(panel == "job")
			var/job_name = params["job"]
			if(!job_name || !(job_name in GLOB.gear_name_presets_list))
				return TRUE
			arm_spawn(user, params)
			return TRUE
		if(panel == "human")
			var/list/queue = params["queue"]
			if(!islist(queue) || !length(queue))
				return TRUE
			for(var/list/entry in queue)
				var/job_name = entry["job"]
				if(!job_name || !(job_name in GLOB.gear_name_presets_list))
					return TRUE
			arm_spawn(user, params)
			return TRUE
		if(panel == "xeno")
			if(params["mode"] == "burst")
				var/xeno_hive = params["hive"]
				var/burst_type = params["burst_type"]
				if(!xeno_hive || !(burst_type in list("larva", "hugger")))
					return TRUE
				arm_spawn(user, params)
				return TRUE
			var/list/queue = params["queue"]
			if(!islist(queue) || !length(queue))
				return TRUE
			for(var/list/entry in queue)
				if(!entry["hive"] || !entry["caste"])
					return TRUE
			arm_spawn(user, params)
			return TRUE

// ─── Job tab (redress an existing mob) ───────────────────────────────────────

/datum/admin_spawn_terminal/proc/do_redress(mob/user, mob/living/carbon/human/victim, list/params)
	if(!victim || QDELETED(victim))
		return
	var/job_name = params["job"]
	if(!job_name || !(job_name in GLOB.gear_name_presets_list))
		return
	if(!user.client)
		return
	user.client.cmd_admin_dress_human(victim, job_name, no_logs = TRUE)
	message_admins("[key_name_admin(user)] changed the equipment of [key_name_admin(victim)] to [job_name].")

// ─── Human tab (spawn new humans) ────────────────────────────────────────────

/**
 * "the ability to spawn multiple xenos, multiple different types at once" applied the same
 * way to humans - params["queue"] is a list of {job, count} rows built up client-side, all
 * spawned together into the same clicked turf/range in one call.
 */
/datum/admin_spawn_terminal/proc/do_spawn_humans(mob/user, turf/spawn_turf, list/params)
	if(!spawn_turf)
		return

	var/list/queue = params["queue"]
	if(!islist(queue) || !length(queue))
		return
	var/spawn_range = clamp(text2num(params["range"]), 0, 10)
	var/spawn_as = params["spawn_as"] || "npc"
	var/equip_with = params["equip_with"] || "full"

	var/list/turfs = list()
	if(spawn_range)
		for(var/turf/T in range(spawn_range, spawn_turf))
			if(!is_valid_admin_spawn_turf(T))
				continue
			turfs += T
	else if(is_valid_admin_spawn_turf(spawn_turf))
		turfs = list(spawn_turf)

	if(!length(turfs))
		return

	var/list/humans = list()
	var/total_count = 0
	var/list/summary = list()
	for(var/list/entry in queue)
		var/job_name = entry["job"]
		if(!job_name || !(job_name in GLOB.gear_name_presets_list))
			continue
		var/count = clamp(text2num(entry["count"]), 1, 100)

		for(var/i = 1 to count)
			var/turf/T = pick(turfs)
			var/mob/living/carbon/human/H = new(T)
			if(!H.hud_used)
				H.create_hud()
			if(spawn_as == "freed")
				admin_datum.owner.free_for_ghosts(H)
			arm_equipment(H, job_name, TRUE, FALSE)
			humans += H

			if(equip_with == "no_equipment")
				for(var/obj/item/I in H.contents.Copy()) // Copy first - qdel'ing while iterating H's live contents list skips entries.
					if(istype(I, /obj/item/card/id))
						continue
					qdel(I)
			else if(equip_with == "no_weapons")
				for(var/obj/item/I in H.GetAllContents(3).Copy())
					if(istype(I, /obj/item/ammo_magazine) || istype(I, /obj/item/weapon) || istype(I, /obj/item/explosive))
						qdel(I)

		total_count += count
		summary += "[count]x [job_name]"

	if(!length(humans))
		return

	if(spawn_as == "ert")
		var/datum/emergency_call/custom/em_call = new()
		var/name = input(user, "Name your ERT:", "ERT Name", "Admin spawned humans") as text|null
		em_call.name = name || "Admin spawned humans"
		em_call.mob_max = length(humans)
		em_call.players_to_offer = humans
		em_call.owner = admin_datum.owner

		var/ql = tgui_alert(user, "Broadcast the beacon launch to all players?", "Announce?", list("Yes", "No"), 20 SECONDS)
		var/ar = tgui_alert(user, "Announce beacon received message?", "Announce?", list("Yes", "No"), 20 SECONDS)
		em_call.activate(ql != "Yes", ar == "Yes")

	message_admins("[key_name_admin(user)] created [total_count] humans ([summary.Join(", ")]) at [get_area(spawn_turf)]")

// ─── Xeno tab (spawn new xenos / burst larva-hugger) ─────────────────────────

/**
 * "the ability to spawn multiple xenos, multiple different types at once... from different
 * hives on different amounts at the same time" - params["queue"] is a list of
 * {hive, caste, count} rows built up client-side, all spawned together into the same clicked
 * turf/range in one call instead of one caste+hive+count per spawn action.
 */
/datum/admin_spawn_terminal/proc/do_spawn_xenos(mob/user, turf/spawn_turf, list/params)
	if(!spawn_turf)
		return

	var/list/queue = params["queue"]
	if(!islist(queue) || !length(queue))
		return
	var/spawn_range = clamp(text2num(params["range"]), 0, 10)
	var/spawn_as = params["spawn_as"] || "npc"

	var/list/turfs = list()
	if(spawn_range)
		for(var/turf/T in range(spawn_range, spawn_turf))
			if(!is_valid_admin_spawn_turf(T))
				continue
			turfs += T
	else if(is_valid_admin_spawn_turf(spawn_turf))
		turfs = list(spawn_turf)

	if(!length(turfs))
		return

	var/list/xenos = list()
	var/ai_attach_failures = 0
	var/total_count = 0
	var/list/summary = list()
	for(var/list/entry in queue)
		var/xeno_hive = entry["hive"]
		var/xeno_caste = entry["caste"]
		var/count = clamp(text2num(entry["count"]), 1, 100)

		var/caste_type = GLOB.RoleAuthority.get_caste_by_text(xeno_caste)
		if(!caste_type)
			to_chat(user, SPAN_WARNING("Unknown xeno caste: [xeno_caste]"))
			continue

		for(var/i = 1 to count)
			var/turf/T = pick(turfs)
			var/mob/living/carbon/xenomorph/X = new caste_type(T, null, xeno_hive)
			if(!X.hud_used)
				X.create_hud()
			if(entry["immature"] && istype(X, /mob/living/carbon/xenomorph/queen))
				var/mob/living/carbon/xenomorph/queen/new_queen = X
				new_queen.force_immature()
			if(spawn_as == "freed")
				admin_datum.owner.free_for_ghosts(X)
			else if(spawn_as == "ai")
				if(!attach_xeno_ai(X, T))
					ai_attach_failures++
				spawner_maybe_assign_strain(X)
			xenos += X

		total_count += count
		summary += "[count]x [xeno_caste] ([xeno_hive])[(xeno_caste == XENO_CASTE_QUEEN) ? (entry["immature"] ? " (Immature)" : " (Mature)") : ""]"

	if(!length(xenos))
		return

	if(ai_attach_failures)
		to_chat(user, SPAN_WARNING("[ai_attach_failures] xeno\s spawned without AI control - a per-caste AI cap was reached."))

	if(spawn_as == "ert")
		var/datum/emergency_call/custom/em_call = new()
		var/name = input(user, "Name your ERT:", "ERT Name", "Admin spawned xenos") as text|null
		em_call.name = name || "Admin spawned xenos"
		em_call.mob_max = length(xenos)
		em_call.players_to_offer = xenos
		em_call.owner = admin_datum.owner

		var/ql = tgui_alert(user, "Broadcast the beacon launch to all players?", "Announce?", list("Yes", "No"), 20 SECONDS)
		var/ar = tgui_alert(user, "Announce beacon received message?", "Announce?", list("Yes", "No"), 20 SECONDS)
		em_call.activate(ql != "Yes", ar == "Yes")

	message_admins("[key_name_admin(user)] created [total_count] xenos ([summary.Join(", ")]) at [get_area(spawn_turf)]")

/**
 * "add an option to the xeno spawner which is larva and hugger human burst... clicked on a
 * living human mob, it starts a burst and then either a hugger or a larva bursts out." Larva
 * reuses the real embryo pipeline (Embryo.dm's become_larva()/chest_burst()) but skips its own
 * multi-second ghost-candidate-offering and the 20-tick autoburst wait, since this is an
 * instant admin action rather than a natural infection. Hugger has no equivalent "bursts out
 * of a human" mechanic anywhere in the codebase (huggers only ever come from eggs) so it's a
 * parallel burst built the same shape as chest_burst() (scream/shake/kill, then spawn on the
 * turf).
 */
/datum/admin_spawn_terminal/proc/do_burst(mob/user, mob/living/carbon/human/victim, list/params)
	if(!victim || QDELETED(victim) || victim.stat == DEAD)
		to_chat(user, SPAN_WARNING("That target is no longer valid."))
		return
	if(should_block_game_interaction(victim))
		to_chat(user, SPAN_WARNING("Can't burst that target here."))
		return
	if(locate(/obj/item/alien_embryo) in victim)
		to_chat(user, SPAN_WARNING("[victim] is already hosting an embryo."))
		return

	var/xeno_hive = params["hive"]
	var/burst_type = params["burst_type"]
	var/spawn_as = params["spawn_as"] || "npc"

	if(burst_type == "hugger")
		burst_hugger(user, victim, xeno_hive, spawn_as)
		return

	var/obj/item/alien_embryo/embryo = new(victim)
	embryo.hivenumber = xeno_hive

	var/mob/living/carbon/xenomorph/larva/new_xeno = new(victim)
	var/datum/hive_status/hive = GLOB.hive_datum[xeno_hive]
	if(hive)
		hive.add_xeno(new_xeno)
	new_xeno.update_icons()
	new_xeno.cause_unbearable_pain(victim)

	if(spawn_as == "freed")
		admin_datum.owner.free_for_ghosts(new_xeno)
	else if(spawn_as == "ai")
		attach_xeno_ai(new_xeno, get_turf(victim))

	new_xeno.chest_burst(victim) // set waitfor = 0 - kills/gibs victim after its own scream/shake delay, then forceMoves the larva onto victim's turf.

	message_admins("[key_name_admin(user)] burst a larva ([xeno_hive]) out of [key_name(victim)]")

/datum/admin_spawn_terminal/proc/burst_hugger(mob/user, mob/living/carbon/human/victim, xeno_hive, spawn_as)
	victim.visible_message(SPAN_DANGER("\The [victim] starts shaking uncontrollably!"),
		SPAN_DANGER("You feel something ripping up your insides!"))
	victim.apply_effect(20, DAZE)
	victim.make_jittery(300)

	INVOKE_ASYNC(src, PROC_REF(finish_hugger_burst), user, victim, xeno_hive, spawn_as)
	message_admins("[key_name_admin(user)] burst a facehugger ([xeno_hive]) out of [key_name(victim)]")

/// Mirrors chest_burst()'s scream/shake/kill pacing (Embryo.dm) since there's no real hugger-burst proc to reuse, then spawns a facehugger mob on the victim's turf instead of a larva.
/datum/admin_spawn_terminal/proc/finish_hugger_burst(mob/user, mob/living/carbon/human/victim, xeno_hive, spawn_as)
	set waitfor = 0
	sleep(30)
	if(QDELETED(victim) || !victim.loc)
		return
	victim.emote("burstscream")
	sleep(25)
	if(QDELETED(victim) || !victim.loc)
		return
	sleep(10)
	if(QDELETED(victim) || !victim.loc)
		return

	victim.spawn_gibs()
	var/turf/burst_turf = get_turf(victim)

	var/datum/cause_data/cause = create_cause_data("facehugger bursting", src)
	victim.last_damage_data = cause
	for(var/organ_name in list("heart", "lungs"))
		var/datum/internal_organ/removed_organ = victim.internal_organs_by_name[organ_name]
		victim.internal_organs_by_name -= organ_name
		victim.internal_organs -= removed_organ
	victim.undefibbable = TRUE
	victim.death(cause)

	var/mob/living/carbon/xenomorph/facehugger/new_hugger = new(burst_turf, null, xeno_hive)
	if(!new_hugger.hud_used)
		new_hugger.create_hud()
	if(spawn_as == "freed")
		admin_datum.owner.free_for_ghosts(new_hugger)
	else if(spawn_as == "ai")
		attach_xeno_ai(new_hugger, burst_turf)

// ─── Entry points ─────────────────────────────────────────────────────────

/datum/admins/proc/open_spawn_terminal(mob/user, mob/living/carbon/human/preset_target_mob, starting_tab)
	var/datum/admin_spawn_terminal/terminal = new(src, preset_target_mob, starting_tab)
	terminal.tgui_interact(user)

/client/proc/create_humans()
	set name = "Create Humans"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.open_spawn_terminal(usr, null, "human")

/client/proc/create_xenos()
	set name = "Create Xenos"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.open_spawn_terminal(usr, null, "xeno")

/client/proc/open_job_terminal()
	set name = "Job Terminal"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.open_spawn_terminal(usr, null, "job")

// ─── Hive Status — TGUI datum ────────────────────────────────────────────────

/datum/admin_hive_status

/datum/admin_hive_status/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new /datum/tgui(user, src, "AdminHiveStatus", "Hive Status")
		ui.open()

/datum/admin_hive_status/ui_state(mob/user)
	return GLOB.admin_state

/// One row per currently AI-piloted xeno - health, location, how long it's been alive, and cumulative damage dealt (see xeno_ai_attack.dm's record_damage_dealt()). Rebuilt fresh every open/poll rather than cached, same as every other admin monitoring panel.
/datum/admin_hive_status/ui_data(mob/user)
	var/list/data = list()
	var/list/xenos = list()
	for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
		if(!xeno.ai_controller)
			continue
		var/datum/xeno_ai_controller/controller = xeno.ai_controller
		var/list/entry = list()
		entry["name"] = xeno.name
		entry["codename"] = controller.codename
		entry["caste"] = xeno.caste_type
		entry["health"] = round(xeno.health)
		entry["max_health"] = round(xeno.maxHealth)
		entry["area"] = get_area_name(xeno, TRUE)
		entry["time_lived"] = round((world.time - controller.spawned_at) / 10) // deciseconds -> seconds
		entry["damage_dealt"] = round(controller.damage_dealt)
		entry["last_ability_ago"] = controller.last_ability_time ? round((world.time - controller.last_ability_time) / 10) : -1
		entry["ai_state"] = controller.ai_state
		entry["idle_activity"] = (controller.ai_state == AI_STATE_IDLE) ? controller.idle_activity : ""
		entry["ref"] = REF(xeno)
		xenos += list(entry)
	data["xenos"] = xenos
	return data

/datum/admin_hive_status/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!check_client_rights(user.client, R_ADMIN))
		return

	if(action == "jump_to")
		var/mob/living/carbon/xenomorph/xeno = locate(params["ref"]) in GLOB.ai_xeno_list
		if(xeno)
			user.forceMove(get_turf(xeno))
		return TRUE

/datum/admins/proc/hive_status(mob/user)
	var/datum/admin_hive_status/datum = new()
	datum.tgui_interact(user)

/client/proc/hive_status()
	set name = "Hive Status"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.hive_status(usr)

/client/proc/clear_mutineers()
	set name = "Clear All Mutineers"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.clear_mutineers()
	return

/datum/admins/proc/clear_mutineers()
	if(!check_rights(R_MOD))
		return

	if(alert(usr, "Are you sure you want to change all mutineers back to normal?", "Confirmation", "Yes", "No") != "Yes")
		return

	for(var/mob/living/carbon/human/H in GLOB.human_mob_list)
		if(H.mob_flags & MUTINEER)
			H.mob_flags &= ~MUTINEER
			H.hud_set_squad()

			for(var/datum/action/human_action/activable/mutineer/A in H.actions)
				A.remove_from(H)

/client/proc/cmd_fun_fire_ob()
	set category = "Admin.Fun"
	set desc = "Fire an OB warhead at your current location."
	set name = "Fire OB"

	if(!check_rights(R_ADMIN))
		return

	var/list/firemodes = list("Standard Warhead", "Custom HE", "Custom Cluster", "Custom Incendiary")
	var/mode = tgui_input_list(usr, "Select fire mode:", "Fire mode", firemodes)
	// Select the warhead.
	var/obj/structure/ob_ammo/warhead/warhead
	var/statsmessage
	var/custom = TRUE
	switch(mode)
		if("Standard Warhead")
			custom = FALSE
			var/list/warheads = subtypesof(/obj/structure/ob_ammo/warhead/)
			var/choice = tgui_input_list(usr, "Select the warhead:", "Warhead to use", warheads)
			if(!choice)
				return
			warhead = new choice
		if("Custom HE")
			var/obj/structure/ob_ammo/warhead/explosive/OBShell = new
			OBShell.name = input("What name should the warhead have?", "Set name", "HE orbital warhead")
			if(!OBShell.name)
				return//null check to cancel
			OBShell.clear_power = tgui_input_number(src, "How much explosive power should the wall clear blast have?", "Set clear power", 1200, 3000)
			if(isnull(OBShell.clear_power))
				return
			OBShell.clear_falloff = tgui_input_number(src, "How much falloff should the wall clear blast have?", "Set clear falloff", 400)
			if(isnull(OBShell.clear_falloff))
				return
			OBShell.standard_power = tgui_input_number(src, "How much explosive power should the main blasts have?", "Set blast power", 600, 3000)
			if(isnull(OBShell.standard_power))
				return
			OBShell.standard_falloff = tgui_input_number(src, "How much falloff should the main blasts have?", "Set blast falloff", 30)
			if(isnull(OBShell.standard_falloff))
				return
			OBShell.clear_delay = tgui_input_number(src, "How much delay should the clear blast have?", "Set clear delay", 3)
			if(isnull(OBShell.clear_delay))
				return
			OBShell.double_explosion_delay = tgui_input_number(src, "How much delay should the clear blast have?", "Set clear delay", 6)
			if(isnull(OBShell.double_explosion_delay))
				return
			statsmessage = "Custom HE OB ([OBShell.name]) Stats from [key_name(usr)]: Clear Power: [OBShell.clear_power], Clear Falloff: [OBShell.clear_falloff], Clear Delay: [OBShell.clear_delay], Blast Power: [OBShell.standard_power], Blast Falloff: [OBShell.standard_falloff], Blast Delay: [OBShell.double_explosion_delay]."
			warhead = OBShell
		if("Custom Cluster")
			var/obj/structure/ob_ammo/warhead/cluster/OBShell = new
			OBShell.name = input("What name should the warhead have?", "Set name", "Cluster orbital warhead")
			if(!OBShell.name)
				return//null check to cancel
			OBShell.total_amount = tgui_input_number(src, "How many salvos should be fired?", "Set cluster number", 60)
			if(isnull(OBShell.total_amount))
				return
			OBShell.instant_amount = tgui_input_number(src, "How many shots per salvo? (Max 10)", "Set shot count", 3)
			if(isnull(OBShell.instant_amount))
				return
			if(OBShell.instant_amount > 10)
				OBShell.instant_amount = 10
			OBShell.explosion_power = tgui_input_number(src, "How much explosive power should the blasts have?", "Set blast power", 300, 1500)
			if(isnull(OBShell.explosion_power))
				return
			OBShell.explosion_falloff = tgui_input_number(src, "How much falloff should the blasts have?", "Set blast falloff", 150)
			if(isnull(OBShell.explosion_falloff))
				return
			statsmessage = "Custom Cluster OB ([OBShell.name]) Stats from [key_name(usr)]: Salvos: [OBShell.total_amount], Shot per Salvo: [OBShell.instant_amount], Explosion Power: [OBShell.explosion_power], Explosion Falloff: [OBShell.explosion_falloff]."
			warhead = OBShell
		if("Custom Incendiary")
			var/obj/structure/ob_ammo/warhead/incendiary/OBShell = new
			OBShell.name = input("What name should the warhead have?", "Set name", "Incendiary orbital warhead")
			if(!OBShell.name)
				return//null check to cancel
			OBShell.clear_power = tgui_input_number(src, "How much explosive power should the wall clear blast have?", "Set clear power", 1200, 3000)
			if(isnull(OBShell.clear_power))
				return
			OBShell.clear_falloff = tgui_input_number(src, "How much falloff should the wall clear blast have?", "Set clear falloff", 400)
			if(isnull(OBShell.clear_falloff))
				return
			OBShell.clear_delay = tgui_input_number(src, "How much delay should the clear blast have?", "Set clear delay", 3)
			if(isnull(OBShell.clear_delay))
				return
			OBShell.distance = tgui_input_number(src, "How many tiles radius should the fire be? (Max 30)", "Set fire radius", 18, 30)
			if(isnull(OBShell.distance))
				return
			if(OBShell.distance > 30)
				OBShell.distance = 30
			OBShell.fire_level = tgui_input_number(src, "How long should the fire last?", "Set fire duration", 70)
			if(isnull(OBShell.fire_level))
				return
			OBShell.burn_level = tgui_input_number(src, "How damaging should the fire be?", "Set fire strength", 80)
			if(isnull(OBShell.burn_level))
				return
			var/list/firetypes = list("white","blue","red","green","custom")
			OBShell.fire_type = tgui_input_list(usr, "Select the fire color:", "Fire color", firetypes)
			if(isnull(OBShell.fire_type))
				return
			OBShell.fire_color = null
			if(OBShell.fire_type == "custom")
				OBShell.fire_type = "dynamic"
				OBShell.fire_color = input(src, "Please select Fire color.", "Fire color") as color|null
				if(isnull(OBShell.fire_color))
					return
			statsmessage = "Custom Incendiary OB ([OBShell.name]) Stats from [key_name(usr)]: Clear Power: [OBShell.clear_power], Clear Falloff: [OBShell.clear_falloff], Clear Delay: [OBShell.clear_delay], Fire Distance: [OBShell.distance], Fire Duration: [OBShell.fire_level], Fire Strength: [OBShell.burn_level]."
			warhead = OBShell

	if(custom)
		if(!warhead)
			return
		if(alert(usr, statsmessage, "Confirm Stats", "Yes", "No") != "Yes")
			qdel(warhead)
			return
		message_admins(statsmessage)

	var/turf/target = get_turf(usr.loc)

	if(alert(usr, "Fire or Spawn Warhead?", "Mode", "Fire", "Spawn") == "Fire")
		if(alert("Are you SURE you want to do this? It will create an OB explosion!",, "Yes", "No") != "Yes")
			qdel(warhead)
			return

		message_admins("[key_name(usr)] has fired \an [warhead.name] at ([target.x],[target.y],[target.z]).")
		warhead.warhead_impact(target)

	else
		warhead.forceMove(target)

/client/proc/change_taskbar_icon()
	set name = "Set Taskbar Icon"
	set desc = "Change the taskbar icon to a preset list of selectable icons."
	set category = "Admin.Events"

	if(!check_rights(R_ADMIN))
		return

	var/taskbar_icon = tgui_input_list(usr, "Select an icon you want to appear on the player's taskbar.", "Taskbar Icon", GLOB.available_taskbar_icons)
	if(!taskbar_icon)
		return

	SSticker.mode.taskbar_icon = taskbar_icon
	SSticker.set_clients_taskbar_icon(taskbar_icon)
	message_admins("[key_name_admin(usr)] has changed the taskbar icon to [taskbar_icon].")

/client/proc/change_weather()
	set name = "Change Weather"
	set category = "Admin.Events"

	if(!check_rights(R_EVENT))
		return

	if(!SSweather.map_holder)
		to_chat(src, SPAN_WARNING("This map has no weather data."))
		return

	if(SSweather.is_weather_event_starting)
		to_chat(src, SPAN_WARNING("A weather event is already starting. Please wait."))
		return

	if(SSweather.is_weather_event)
		if(tgui_alert(src, "A weather event is already in progress! End it?", "Confirm", list("End", "Continue"), 10 SECONDS) == "Continue")
			return
		if(SSweather.is_weather_event)
			SSweather.end_weather_event()

	var/list/mappings = list()
	for(var/datum/weather_event/typepath as anything in subtypesof(/datum/weather_event))
		mappings[initial(typepath.name)] = typepath
	var/chosen_name = tgui_input_list(src, "Select a weather event to start", "Weather Selector", mappings)
	var/chosen_typepath = mappings[chosen_name]
	if(!chosen_typepath)
		return

	var/retval = SSweather.setup_weather_event(chosen_typepath)
	if(!retval)
		to_chat(src, SPAN_WARNING("Could not start the weather event at present!"))
		return
	to_chat(src, SPAN_BOLDNOTICE("Success! The weather event should start shortly."))


/client/proc/cmd_admin_create_bioscan()
	set name = "Report: Bioscan"
	set category = "Admin.Factions"

	if(!admin_holder || !(admin_holder.rights & R_MOD))
		to_chat(src, "Only administrators may use this command.")
		return

	var/choice = tgui_alert(usr, "Are you sure you want to trigger a bioscan?", "Bioscan?", list("Yes", "No"))
	if(choice != "Yes")
		return
	else
		var/faction = tgui_input_list(usr, "What faction do you wish to provide a bioscan for?", "Bioscan Faction", list("Xeno","Marine","Yautja"), 20 SECONDS)
		var/variance = tgui_input_number(usr, "How variable do you want the scan to be? (+ or - an amount from truth)", "Variance", 2, 10, 0, 20 SECONDS)
		message_admins("BIOSCAN: [key_name(usr)] admin-triggered a bioscan for [faction].")
		GLOB.bioscan_data.get_scan_data()
		switch(faction)
			if("Xeno")
				GLOB.bioscan_data.qm_bioscan(variance)
			if("Marine")
				var/force_status = FALSE
				if(!ares_can_interface()) //proc checks if ARES is dead or if ARES cannot do announcements
					var/force_check = tgui_alert(usr, "ARES is currently unable to properly display and/or perform the Bioscan, do you wish to force ARES to display the bioscan?", "Display force", list("Yes", "No"), 20 SECONDS)
					if(force_check == "Yes")
						force_status = TRUE
				GLOB.bioscan_data.ares_bioscan(force_status, variance)
			if("Yautja")
				GLOB.bioscan_data.yautja_bioscan()

/client/proc/admin_blurb()
	set name = "Global Blurb Message"
	set category = "Admin.Events"

	if(!check_rights(R_ADMIN|R_DEBUG))
		return FALSE
	var/duration = 5 SECONDS
	var/message = "ADMIN TEST"
	var/text_input = tgui_input_text(usr, "Announcement message", "Message Contents", message, timeout = 5 MINUTES)
	if(!text_input)
		return // Early return here so people dont have to go through the whole process just to cancel it.
	message = text_input
	duration = tgui_input_number(usr, "Set the duration of the alert in deci-seconds.", "Duration", 5 SECONDS, 5 MINUTES, 5 SECONDS, 20 SECONDS)
	var/confirm = tgui_alert(usr, "Are you sure you wish to send '[message]' to all players for [(duration / 10)] seconds?", "Confirm", list("Yes", "No"), 20 SECONDS)
	if(confirm != "Yes")
		return FALSE
	show_blurb(GLOB.player_list, duration, message, TRUE, "center", "center", "#bd2020", "ADMIN")
	message_admins("[key_name(usr)] sent an admin blurb alert to all players. Alert reads: '[message]' and lasts [(duration / 10)] seconds.")
