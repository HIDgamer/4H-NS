/**
 * # Character Setup Hub
 *
 * The tgui entry point for character preferences, replacing
 * `/datum/preferences/proc/ShowChoices()` (the legacy browse() popup, code/modules/client/
 * preferences.dm) as the "Setup Character" destination. Thin router only — reuses the same
 * `/datum/preferences` vars and validation helpers the legacy menu already used
 * (reject_bad_name(), AGE_MIN/AGE_MAX, GLOB.ethnicities_list), and opens each picker/sub-setup
 * datum (hair_picker.dm/color_picker.dm's body_picker/traits_picker.dm/loadout_picker.dm/
 * job_preferences.dm/job_slots_setup.dm/background_setup.dm/whitelist_roles_setup.dm/
 * settings_setup.dm) directly rather than reimplementing their logic.
 *
 * Profile fields (name/age/gender/ethnicity) and a static composited preview
 * (preferences.dm's preview_icon_b64, see preferences_setup.dm's update_preview_icon()) live
 * directly on this hub; everything else is a launcher to its own picker/sub-setup window.
 * ShowChoices() is left in place and still reachable via the "open_legacy" action for anything
 * not yet covered by a tgui equivalent.
 */
/datum/character_setup
	var/client/owner
	// Cached per-hub so repeat "open_X" clicks reuse the same window instead of spawning a new
	// one each time — these 4 picker datums have no persistent owner of their own (confirmed:
	// no New()/stored vars in hair_picker.dm/color_picker.dm/traits_picker.dm/loadout_picker.dm,
	// they're stateless and derive everything from ui.user.client.prefs at call time).
	var/datum/hair_picker/hair_picker
	var/datum/body_picker/body_picker
	var/datum/traits_picker/traits_picker
	var/datum/loadout_picker/loadout_picker
	var/datum/job_preferences_setup/job_prefs
	var/datum/job_slots_setup/job_slots
	var/datum/background_setup/background
	var/datum/whitelist_roles_setup/whitelist_roles
	var/datum/settings_setup/settings

/datum/character_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/character_setup/Destroy(force, ...)
	owner = null
	QDEL_NULL(hair_picker)
	QDEL_NULL(body_picker)
	QDEL_NULL(traits_picker)
	QDEL_NULL(loadout_picker)
	QDEL_NULL(job_prefs)
	QDEL_NULL(job_slots)
	QDEL_NULL(background)
	QDEL_NULL(whitelist_roles)
	QDEL_NULL(settings)
	SStgui.close_uis(src)
	return ..()

/datum/character_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CharacterSetup", "Character Setup")
		ui.open()

/datum/character_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/character_setup/ui_static_data(mob/user)
	. = list()
	// GLOB.ethnicities_list is indexed by name (name -> /datum/ethnicity) — sending it directly
	// serializes to a JSON object, not an array, which crashed the frontend Dropdown component
	// (it calls .findIndex() on `options`, array-only). Flatten to a plain list of names first,
	// same as body_picker.dm/hair_picker.dm already do when exposing their own indexed lists.
	var/list/ethnicities = list()
	for(var/key in GLOB.ethnicities_list)
		ethnicities += key
	.["ethnicities"] = ethnicities
	.["has_predator"] = !!owner.check_whitelist_status(WHITELIST_PREDATOR)

/datum/character_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return
	prefs.update_preview_icon()
	.["real_name"] = prefs.real_name
	.["age"] = prefs.age
	.["gender"] = prefs.gender == MALE ? "Male" : "Female"
	.["ethnicity"] = prefs.ethnicity
	.["preview_icon_b64"] = prefs.preview_icon_b64
	.["default_slot"] = prefs.default_slot
	.["random_name"] = prefs.be_random_name
	.["random_body"] = prefs.be_random_body

/datum/character_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return TRUE
	switch(action)
		if("name")
			if(prefs.human_name_ban)
				to_chat(ui.user, SPAN_NOTICE("You are banned from custom human names."))
				return TRUE
			var/new_name = reject_bad_name(params["name"])
			if(new_name)
				prefs.real_name = new_name
			return TRUE

		if("age")
			var/new_age = clamp(text2num(params["age"]), AGE_MIN, AGE_MAX)
			if(new_age)
				prefs.age = new_age
			return TRUE

		if("gender")
			prefs.gender = (prefs.gender == MALE) ? FEMALE : MALE
			return TRUE

		if("ethnicity")
			if(params["ethnicity"] in GLOB.ethnicities_list)
				prefs.ethnicity = params["ethnicity"]
			return TRUE

		if("random_name")
			prefs.be_random_name = !prefs.be_random_name
			return TRUE

		if("random_body")
			prefs.be_random_body = !prefs.be_random_body
			return TRUE

		if("rotate_preview")
			prefs.rotate_preview(params["clockwise"] != FALSE)
			return TRUE

		if("save")
			if(prefs.save_cooldown > world.time)
				to_chat(ui.user, SPAN_WARNING("You need to wait [floor((prefs.save_cooldown-world.time)/10)] seconds before you can do that again."))
				return TRUE
			var/datum/origin/character_origin = GLOB.origins[prefs.origin]
			var/name_error = character_origin.validate_name(prefs.real_name)
			if(name_error)
				tgui_alert(ui.user, name_error, "Invalid Name", list("OK"))
				return TRUE
			prefs.save_preferences()
			prefs.save_character()
			prefs.save_cooldown = world.time + 50
			to_chat(ui.user, SPAN_NOTICE("Character saved."))
			return TRUE

		if("reload")
			if(prefs.reload_cooldown > world.time)
				to_chat(ui.user, SPAN_WARNING("You need to wait [floor((prefs.reload_cooldown-world.time)/10)] seconds before you can do that again."))
				return TRUE
			prefs.load_preferences()
			prefs.load_character()
			prefs.reload_cooldown = world.time + 50
			return TRUE

		if("load_slot")
			if(IsGuestKey(ui.user.key))
				return TRUE
			var/list/slot_options = list()
			var/savefile/S = new /savefile(prefs.path)
			var/name
			for(var/i = 1, i <= MAX_SAVE_SLOTS, i++)
				S.cd = "/character[i]"
				S["real_name"] >> name
				if(!name)
					name = "Character[i]"
				if(i == prefs.default_slot)
					name = "[name] (current)"
				slot_options[name] = i
			var/choice = tgui_input_list(ui.user, "Select a character slot to load", "Load Character", slot_options)
			if(choice)
				prefs.load_character(slot_options[choice])
			return TRUE

		if("open_hair")
			if(!hair_picker)
				hair_picker = new()
			hair_picker.tgui_interact(ui.user)
			return TRUE

		if("open_body")
			if(!body_picker)
				body_picker = new()
			body_picker.tgui_interact(ui.user)
			return TRUE

		if("open_traits")
			if(!traits_picker)
				traits_picker = new()
			traits_picker.tgui_interact(ui.user)
			return TRUE

		if("open_loadout")
			if(!loadout_picker)
				loadout_picker = new()
			loadout_picker.tgui_interact(ui.user)
			return TRUE

		if("open_job_prefs")
			if(!job_prefs)
				job_prefs = new(owner)
			job_prefs.tgui_interact(ui.user)
			return TRUE

		if("open_job_slots")
			if(!job_slots)
				job_slots = new(owner)
			job_slots.tgui_interact(ui.user)
			return TRUE

		if("open_whitelist_roles")
			if(!whitelist_roles)
				whitelist_roles = new(owner)
			whitelist_roles.tgui_interact(ui.user)
			return TRUE

		if("open_predator")
			if(!owner.check_whitelist_status(WHITELIST_PREDATOR))
				to_chat(ui.user, SPAN_WARNING("You do not have the whitelist for this role."))
				return TRUE
			var/datum/pred_picker/picker = new()
			picker.tgui_interact(ui.user)
			return TRUE

		if("open_settings")
			if(!settings)
				settings = new(owner)
			settings.tgui_interact(ui.user)
			return TRUE

		if("open_background")
			if(!background)
				background = new(owner)
			background.tgui_interact(ui.user)
			return TRUE

		if("open_legacy")
			prefs.ShowChoices(ui.user)
			return TRUE

/client/proc/character_setup()
	set name = "Character Setup"
	set category = "Preferences"

	var/datum/character_setup/hub = new(src)
	hub.tgui_interact(mob)
