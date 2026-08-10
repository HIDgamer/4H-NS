/**
 * # Background & Records
 *
 * tgui replacement for the remaining MENU_MARINE legacy fields not covered by a dedicated
 * picker: Origin/Religion/Corporate Relation/Preferred Squad, underwear/undershirt/preferred
 * armor/show-job-gear/background-cycle, and Records (medical/employment/security) + Flavor
 * Text. Each field reuses the exact same tgui_input_list()/tgui_input_text()/tgui_alert() calls
 * the legacy menu already used (these were already tgui-based, just reached through a
 * byond://href click instead of a button) — thin buttons that open the same prompt, not a
 * reimplementation of the underlying choice lists.
 */
/datum/background_setup
	var/client/owner

/datum/background_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/background_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/background_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "BackgroundSetup", "Background & Records")
		ui.open()

/datum/background_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/background_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return
	.["origin"] = prefs.origin
	.["religion"] = prefs.religion
	.["nanotrasen_relation"] = prefs.weyland_yutani_relation
	.["preferred_squad"] = prefs.preferred_squad
	.["underwear"] = prefs.underwear
	.["undershirt"] = prefs.undershirt
	.["backbag"] = GLOB.backbaglist[prefs.backbag]
	.["preferred_armor"] = prefs.preferred_armor
	.["show_job_gear"] = prefs.show_job_gear
	.["bg_state"] = prefs.bg_state
	.["med_record"] = prefs.med_record
	.["gen_record"] = prefs.gen_record
	.["sec_record"] = prefs.sec_record
	.["flavor_text"] = prefs.flavor_texts["general"]

/datum/background_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	var/mob/user = ui.user
	if(!prefs)
		return TRUE
	switch(action)
		if("origin")
			var/choice = tgui_input_list(user, "Please choose your character's origin.", "Origin Selection", GLOB.player_origins)
			var/datum/origin/picked_choice = GLOB.origins[choice]
			if(!picked_choice)
				return TRUE
			if(tgui_alert(user, "You've selected [picked_choice.name]. [picked_choice.desc]", "Selected Origin", list("Confirm", "Cancel")) == "Cancel")
				return TRUE
			prefs.origin = choice
			return TRUE

		if("religion")
			var/choice = tgui_input_list(user, "Please choose a religion.", "Religion choice", GLOB.religion_choices + "Other")
			if(!choice)
				return TRUE
			if(choice == "Other")
				var/raw_choice = tgui_input_text(user, "Please enter a religion.", "Religion")
				if(raw_choice)
					prefs.religion = strip_html(raw_choice)
				return TRUE
			prefs.religion = choice
			return TRUE

		if("nt_relation")
			var/new_relation = tgui_input_list(user, "Choose your relation to the Weyland-Yutani company. Note that this represents what others can find out about your character by researching your background, not what your character actually thinks.", "Character Preference", list("Loyal", "Supportive", "Neutral", "Skeptical", "Opposed"))
			if(new_relation)
				prefs.weyland_yutani_relation = new_relation
			return TRUE

		if("prefsquad")
			var/new_pref_squad = tgui_input_list(user, "Choose your preferred squad.", "Character Preference", list("Alpha", "Bravo", "Charlie", "Delta", "None"))
			if(new_pref_squad)
				prefs.preferred_squad = new_pref_squad
			return TRUE

		if("underwear")
			var/list/underwear_options = prefs.gender == MALE ? GLOB.underwear_m : GLOB.underwear_f
			var/new_underwear = tgui_input_list(user, "Choose your character's underwear:", "Character Preference", underwear_options)
			if(new_underwear)
				prefs.underwear = new_underwear
				prefs.update_preview_icon()
			return TRUE

		if("undershirt")
			var/list/undershirt_options = prefs.gender == MALE ? GLOB.undershirt_m : GLOB.undershirt_f
			var/new_undershirt = tgui_input_list(user, "Choose your character's undershirt:", "Character Preference", undershirt_options)
			if(new_undershirt)
				prefs.undershirt = new_undershirt
				prefs.update_preview_icon()
			return TRUE

		if("bag")
			var/new_backbag = tgui_input_list(user, "Choose your character's style of bag:", "Character Preference", GLOB.backbaglist)
			if(new_backbag)
				prefs.backbag = GLOB.backbaglist.Find(new_backbag)
			return TRUE

		if("prefarmor")
			var/new_pref_armor = tgui_input_list(user, "Choose your character's default style of armor:", "Character Preferences", GLOB.armor_style_list)
			if(new_pref_armor)
				prefs.preferred_armor = new_pref_armor
				prefs.update_preview_icon()
			return TRUE

		if("toggle_job_gear")
			prefs.show_job_gear = !prefs.show_job_gear
			return TRUE

		if("cycle_bg")
			prefs.bg_state = next_in_list(prefs.bg_state, GLOB.bgstate_options)
			prefs.update_preview_icon()
			return TRUE

		if("med_record")
			var/msg = tgui_input_text(user, "Set your medical notes here.", "Medical Records", prefs.med_record, multiline = TRUE, max_length = MAX_PAPER_MESSAGE_LEN)
			if(!isnull(msg))
				prefs.med_record = msg
			return TRUE

		if("gen_record")
			var/msg = tgui_input_text(user, "Set your employment notes here.", "Employment Records", prefs.gen_record, multiline = TRUE, max_length = MAX_PAPER_MESSAGE_LEN)
			if(!isnull(msg))
				prefs.gen_record = msg
			return TRUE

		if("sec_record")
			var/msg = tgui_input_text(user, "Set your security notes here.", "Security Records", prefs.sec_record, multiline = TRUE, max_length = MAX_PAPER_MESSAGE_LEN)
			if(!isnull(msg))
				prefs.sec_record = msg
			return TRUE

		if("flavor_text")
			var/msg = tgui_input_text(user, "Give a physical description of your character. This will be shown regardless of clothing.", "Flavor Text", prefs.flavor_texts["general"], multiline = TRUE, max_length = MAX_MESSAGE_LEN)
			if(!isnull(msg))
				prefs.flavor_texts["general"] = msg
			return TRUE
