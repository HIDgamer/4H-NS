/**
 * # Whitelist Role Settings
 *
 * tgui replacement for the legacy MENU_XENOMORPH/MENU_CO/MENU_SYNTHETIC panels
 * (code/modules/client/preferences.dm:480-549). Combined into one window with gated sections
 * instead of three separate top-level legacy menus — each section only renders if the player
 * actually holds that whitelist, same gating check the legacy menu used
 * (owner.check_whitelist_status()). Yautja/Predator isn't here — see PredPicker.tsx, which
 * already covers most of MENU_YAUTJA; the handful of fields it was missing were added directly
 * to it instead of duplicating a second Predator UI.
 *
 * Xeno prefix/postfix validation (playtime gates, character-count/format rules) is transcribed
 * from the legacy handlers as-is, not simplified — this is the one part of this phase with real
 * business logic worth getting exactly right rather than reimplementing from scratch.
 */
/datum/whitelist_roles_setup
	var/client/owner

/datum/whitelist_roles_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/whitelist_roles_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/whitelist_roles_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "WhitelistRoles", "Whitelist Role Settings")
		ui.open()

/datum/whitelist_roles_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/whitelist_roles_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return

	.["has_co"] = !!owner.check_whitelist_status(WHITELIST_COMMANDER)
	.["has_synth"] = !!owner.check_whitelist_status(WHITELIST_SYNTHETIC)

	.["xeno_prefix"] = prefs.xeno_prefix
	.["xeno_postfix"] = prefs.xeno_postfix
	.["playtime_perks"] = prefs.playtime_perks
	.["xeno_vision_level_pref"] = prefs.xeno_vision_level_pref
	.["be_xeno_after_death"] = !!(prefs.be_special & (1<<1))
	.["be_agent"] = !!(prefs.be_special & (1<<0))

	.["commander_status"] = prefs.commander_status
	.["commander_sidearm"] = prefs.commander_sidearm
	.["affiliation"] = prefs.affiliation

	.["synthetic_name"] = prefs.synthetic_name
	.["synthetic_type"] = prefs.synthetic_type
	.["synth_status"] = prefs.synth_status

/datum/whitelist_roles_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	var/mob/user = ui.user
	if(!prefs)
		return TRUE

	var/datum/entity/player/player = get_player_from_key(user.ckey)
	var/whitelist_flags = player?.whitelist_flags

	switch(action)
		if("xeno_prefix")
			if(prefs.xeno_name_ban)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You are banned from xeno name picking.")))
				prefs.xeno_prefix = ""
				return TRUE
			var/new_xeno_prefix = tgui_input_text(user, "Choose your xenomorph prefix. One or two letters capitalized. Leave empty to default to 'XX'", "Xenomorph Prefix")
			if(isnull(new_xeno_prefix))
				return TRUE
			new_xeno_prefix = uppertext(new_xeno_prefix)
			var/prefix_length = length(new_xeno_prefix)
			if(prefix_length > 3)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("Invalid Xeno Prefix. Your Prefix can only be up to 3 letters long.")))
				return TRUE
			if(prefix_length == 3)
				var/playtime = user.client.get_total_xeno_playtime()
				if(playtime < 124 HOURS)
					to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You need to play [time_left_until(124 HOURS, playtime, 1 HOURS)] more hours to unlock xeno three letter prefix.")))
					return TRUE
				if(prefs.xeno_postfix)
					to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You can't use three letter prefix with any postfix.")))
					return TRUE
			if(length(new_xeno_prefix) == 0)
				prefs.xeno_prefix = "XX"
				owner.load_xeno_name()
			else
				var/all_ok = TRUE
				for(var/i = 1, i <= length(new_xeno_prefix), i++)
					var/ascii_char = text2ascii(new_xeno_prefix, i)
					if(ascii_char < 65 || ascii_char > 90)
						all_ok = FALSE
				if(all_ok)
					prefs.xeno_prefix = new_xeno_prefix
					owner.load_xeno_name()
				else
					to_chat(user, SPAN_WARNING("Invalid Xeno Prefix. Your Prefix can contain either single letter or two letters."))
			return TRUE

		if("xeno_postfix")
			if(prefs.xeno_name_ban)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You are banned from xeno name picking.")))
				prefs.xeno_postfix = ""
				return TRUE
			var/playtime = user.client.get_total_xeno_playtime()
			if(playtime < 24 HOURS)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You need to play [time_left_until(24 HOURS, playtime, 1 HOURS)] more hours to unlock xeno postfix.")))
				return TRUE
			if(length(prefs.xeno_prefix) == 3)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You can't use three letter prefix with any postfix.")))
				return TRUE
			var/new_xeno_postfix = tgui_input_text(user, "Choose your xenomorph postfix. One capital letter with or without a digit at the end. Leave empty to remove postfix", "Xenomorph Postfix")
			if(isnull(new_xeno_postfix))
				return TRUE
			new_xeno_postfix = uppertext(new_xeno_postfix)
			if(length(new_xeno_postfix) > 2)
				to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("Invalid Xeno Postfix. Your Postfix can only be up to 2 letters long.")))
				return TRUE
			if(length(new_xeno_postfix) == 0)
				prefs.xeno_postfix = ""
				owner.load_xeno_name()
			else
				var/all_ok = TRUE
				var/first_char = TRUE
				for(var/i = 1, i <= length(new_xeno_postfix), i++)
					var/ascii_char = text2ascii(new_xeno_postfix, i)
					switch(ascii_char)
						if(65 to 90)
							if(length(prefs.xeno_prefix) != 2)
								to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You can't use three letter prefix with any postfix.")))
								return TRUE
							if(!first_char && playtime < 300 HOURS)
								to_chat(user, SPAN_WARNING(FONT_SIZE_BIG("You need to play [time_left_until(300 HOURS, playtime, 1 HOURS)] more hours to unlock double letter xeno postfix.")))
								all_ok = FALSE
						if(48 to 57)
							if(first_char)
								all_ok = FALSE
						else
							all_ok = FALSE
					first_char = FALSE
				if(all_ok)
					prefs.xeno_postfix = new_xeno_postfix
					owner.load_xeno_name()
				else
					to_chat(user, SPAN_WARNING("Invalid Xeno Postfix. Your Postfix can contain single letter and an optional digit after it."))
			return TRUE

		if("playtime_perks")
			prefs.playtime_perks = !prefs.playtime_perks
			return TRUE

		if("xeno_vision_level_pref")
			var/static/list/vision_level_choices = list(XENO_VISION_LEVEL_NO_NVG, XENO_VISION_LEVEL_MID_NVG, XENO_VISION_LEVEL_FULL_NVG)
			var/choice = tgui_input_list(user, "Choose your default xeno vision level", "Vision level", vision_level_choices, theme = "hive_status")
			if(choice)
				prefs.xeno_vision_level_pref = choice
			return TRUE

		if("be_special")
			var/num = text2num(params["num"])
			var/ban_check_name = (num == 1) ? JOB_XENOMORPH : "Agent"
			if(jobban_isbanned(user, ban_check_name))
				return TRUE
			if(!can_play_special_job(user.client, ban_check_name))
				return TRUE
			prefs.be_special ^= (1<<num)
			return TRUE

		if("commander_status")
			var/list/options = list("Normal" = WHITELIST_NORMAL)
			if(whitelist_flags & (WHITELIST_COMMANDER_COUNCIL|WHITELIST_COMMANDER_COUNCIL_LEGACY))
				options += list("Council" = WHITELIST_COUNCIL)
			if(whitelist_flags & (WHITELIST_COMMANDER_LEADER|WHITELIST_COMMANDER_COLONEL))
				options += list("Leader" = WHITELIST_LEADER)
			var/new_status = tgui_input_list(user, "Choose your new Commander Whitelist Status.", "Commander Status", options)
			if(new_status)
				prefs.commander_status = options[new_status]
			return TRUE

		if("co_sidearm")
			// CO_GUNS/COUNCIL_CO_GUNS are #define macros expanding to list(...) literals — each
			// use already creates a fresh, independent list, no .Copy() needed.
			var/list/options = CO_GUNS
			if(whitelist_flags & (WHITELIST_COMMANDER_COUNCIL|WHITELIST_COMMANDER_COUNCIL_LEGACY))
				options += COUNCIL_CO_GUNS
			var/new_sidearm = tgui_input_list(user, "Choose your preferred sidearm.", "Commanding Officer's Sidearm", options)
			if(new_sidearm)
				prefs.commander_sidearm = new_sidearm
			return TRUE

		if("co_affiliation")
			var/new_affiliation = tgui_input_list(user, "Choose your faction affiliation.", "Commanding Officer's Affiliation", FACTION_ALLEGIANCE_USCM_COMMANDER)
			if(new_affiliation)
				prefs.affiliation = new_affiliation
			return TRUE

		if("synth_name")
			var/raw_name = tgui_input_text(user, "Choose your Synthetic's name:", "Character Preference")
			if(raw_name)
				var/new_name = reject_bad_name(raw_name)
				if(new_name)
					prefs.synthetic_name = new_name
				else
					to_chat(user, SPAN_WARNING("Invalid name. Your name should be at least 2 and at most [MAX_NAME_LEN] characters long. It may only contain the characters A-Z, a-z, -, ' and ."))
			return TRUE

		if("synth_type")
			var/new_type = tgui_input_list(user, "Choose your model of synthetic:", "Make and Model", PLAYER_SYNTHS)
			if(new_type)
				prefs.synthetic_type = new_type
			return TRUE

		if("synth_status")
			var/list/options = list("Normal" = WHITELIST_NORMAL)
			if(whitelist_flags & (WHITELIST_SYNTHETIC_COUNCIL|WHITELIST_SYNTHETIC_COUNCIL_LEGACY))
				options += list("Council" = WHITELIST_COUNCIL)
			if(whitelist_flags & WHITELIST_SYNTHETIC_LEADER)
				options += list("Leader" = WHITELIST_LEADER)
			var/new_status = tgui_input_list(user, "Choose your new Synthetic Whitelist Status.", "Synthetic Status", options)
			if(new_status)
				prefs.synth_status = options[new_status]
			return TRUE
