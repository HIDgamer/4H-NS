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

	.["body_sizes"] = list()
	for(var/key in GLOB.body_types_list)
		var/datum/body_type/size = GLOB.body_types_list[key]
		.["body_sizes"] += list(
			list("name" = size.name, "icon" = size.icon_name)
		)

/datum/body_picker/ui_data(mob/user)
	. = ..()

	.["body_type"] = GLOB.body_types_list[user.client.prefs.body_type].icon_name
	.["skin_color"] = GLOB.ethnicities_list[user.client.prefs.skin_color].icon_name
	.["body_size"] = GLOB.body_types_list[user.client.prefs.body_size].icon_name

/datum/body_picker/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()

	var/datum/preferences/prefs = ui.user.client.prefs

	switch(action)
		if("type")
			if(!GLOB.body_types_list[params["name"]])
				return
		if("size")
			if(!GLOB.body_types_list[params["name"]])
				return
		if("color")
			if(!GLOB.ethnicities_list[params["name"]])
				return

			prefs.skin_color = params["name"]

	prefs.ShowChoices(ui.user)
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
