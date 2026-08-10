/datum/body_picker/ui_static_data(mob/user)
	. = ..()

	.["icon"] = /datum/species::icobase

	.["body_types"] = list()
	for(var/key in GLOB.body_types_list)
		var/datum/body_type/type = GLOB.body_types_list[key]
		.["body_types"] += list(
			list("name" = type.name, "icon" = type.icon_name)
		)

	.["skin_colors"] = list()
	for(var/key in GLOB.ethnicities_list)
		var/datum/ethnicity/color = GLOB.ethnicities_list[key]
		.["skin_colors"] += list(
			list("name" = color.name, "icon" = color.icon_name)
		)

/datum/body_picker/ui_data(mob/user)
	. = ..()

	var/datum/preferences/prefs = user.client.prefs

	// Self-healing fallback: existing saved prefs can still have ethnicity/body_type persisted as
	// null or a since-removed key — the class defaults alone only cover brand-new prefs, not
	// already-saved ones. Falls back to the first valid list entry and writes it back so this
	// only needs to self-heal once.
	if(!GLOB.body_types_list[prefs.body_type])
		prefs.body_type = GLOB.body_types_list[1] // list[1] on an assoc list returns the first KEY, not the value — this is the string body_type wants, not the datum
	if(!GLOB.ethnicities_list[prefs.ethnicity])
		prefs.ethnicity = GLOB.ethnicities_list[1]

	.["body_type"] = GLOB.body_types_list[prefs.body_type].icon_name
	// `ethnicity` is the real, live var driving skin appearance — copy_appearance_to()/
	// set_limb_icons() both key off it, not a separate skin-color value. CharacterSetup.tsx's
	// compact dropdown and this visual swatch grid both read/write the same var.
	.["skin_color"] = GLOB.ethnicities_list[prefs.ethnicity].icon_name
	// The real torso sprite format is "[ethnicity]_torso_[body_type]_[gender]" (confirmed in
	// code/modules/mob/living/carbon/human/human_helpers.dm's get_limb_icon_name()) — there is no
	// "body size" axis in the actual rendering system at all; gender is the correct 4th token.
	.["gender"] = get_gender_name(prefs.gender)

	.["eye_color"] = rgb(prefs.r_eyes, prefs.g_eyes, prefs.b_eyes)

/datum/body_picker/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()

	var/datum/preferences/prefs = ui.user.client.prefs

	switch(action)
		if("type")
			if(!GLOB.body_types_list[params["name"]])
				return
			prefs.body_type = params["name"]
		if("gender")
			prefs.gender = (prefs.gender == MALE) ? FEMALE : MALE
		if("color")
			if(!GLOB.ethnicities_list[params["name"]])
				return

			prefs.ethnicity = params["name"]

		if("eye_color")
			var/param_color = params["color"]
			if(!param_color)
				return

			var/r = hex2num(copytext(param_color, 2, 4))
			var/g = hex2num(copytext(param_color, 4, 6))
			var/b = hex2num(copytext(param_color, 6, 8))

			if(!isnum(r) || !isnum(g) || !isnum(b))
				return

			prefs.r_eyes = clamp(r, 0, 255)
			prefs.g_eyes = clamp(g, 0, 255)
			prefs.b_eyes = clamp(b, 0, 255)

	prefs.update_preview_icon()
	return TRUE

/datum/body_picker/tgui_interact(mob/user, datum/tgui/ui)
	. = ..()

	ui = SStgui.try_update_ui(user, src, ui)

	if(!ui)
		ui = new(user, src, "BodyPicker", "Body Picker")
		ui.open()
		ui.set_autoupdate(FALSE)

	winset(user, ui.window.id, "focus=true")

/datum/body_picker/ui_state(mob/user)
	return GLOB.always_state
