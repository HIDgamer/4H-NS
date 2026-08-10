// /client is not a /datum subtype in BYOND and can't host a tgui interface directly
// (no other /client/tgui_interact exists anywhere in this codebase either), so the
// clan menu is hosted on this singleton, matching the established GLOB.hive_leaders_tgui
// pattern (code/modules/mob/new_player/new_player.dm). viewing_clan_by_ref is keyed per
// viewer ref since multiple admins can view different clans through the same singleton
// at once (same class of bug as the shared-state issue fixed in health_scan.dm earlier
// in this migration pass — a single shared "currently viewed clan" var would leak
// between simultaneous viewers).
GLOBAL_DATUM_INIT(clan_menu, /datum/clan_menu, new)

/datum/clan_menu
	var/list/viewing_clan_by_ref = list()

/datum/clan_menu/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ClanMenu", "Clan Menu")
		ui.open()

/datum/clan_menu/ui_state(mob/user)
	return GLOB.always_state

/datum/clan_menu/ui_data(mob/user)
	var/client/C = user.client
	if(!C)
		return list()
	return build_clan_data(C, viewing_clan_by_ref[REF(user)])

/client/proc/usr_create_new_clan()
	set name = "Create New Clan"
	set category = "Debug"

	if(!clan_info)
		return

	if(!(clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER))
		return

	var/input = input(src, "Name the clan:", "Create a Clan") as text|null

	if(!input)
		return

	to_chat(src, SPAN_NOTICE("Made a new clan called: [input]"))

	create_new_clan(input)

/client/verb/view_clan_info()
	set name = "View Clan Info"
	set category = "OOC.Records"

	INVOKE_ASYNC(src, PROC_REF(usr_view_clan_info))

/client/proc/usr_view_clan_info(clan_id, force_clan_id = FALSE)
	var/clan_to_get

	if(!has_clan_permission(CLAN_PERMISSION_VIEW))
		return

	if(!clan_id && !force_clan_id)
		if(!clan_info)
			to_chat(src, SPAN_WARNING("You don't have a yautja whitelist!"))
			return

		if(clan_info.permissions & CLAN_PERMISSION_ADMIN_VIEW)
			var/list/datum/view_record/clan_view/CPV = DB_VIEW(/datum/view_record/clan_view/)

			var/clans = list()
			for(var/datum/view_record/clan_view/CV in CPV)
				clans += list("[CV.name]" = CV.clan_id)

			clans += list("People without clans" = null)

			var/input = tgui_input_list(src, "Choose the clan to view", "View clan", clans)

			if(!input)
				to_chat(src, SPAN_WARNING("Couldn't find any clans for you to view!"))
				return

			clan_to_get = clans[input]
		else if(clan_info.clan_id)

			var/options = list(
				"Your clan" = clan_info.clan_id,
				"People without clans" = null
			)

			var/input = tgui_input_list(src, "Choose the clan to view", "View clan", options)

			if(!input)
				return

			clan_to_get = options[input]
		else
			clan_to_get = null
	else
		clan_to_get = clan_id

	GLOB.clan_menu.viewing_clan_by_ref[REF(mob)] = clan_to_get
	GLOB.clan_menu.tgui_interact(mob)

/// Builds the clan-menu payload for whichever clan `clan_to_get` names (or the "no clan" bucket if null).
/// Split out of usr_view_clan_info() so ui_data() can rebuild this on every refresh without re-running
/// the clan-picker prompts above, which only make sense when the menu is first opened via the verb.
/datum/clan_menu/proc/build_clan_data(client/C, clan_to_get)
	var/datum/entity/clan/target_clan
	var/list/datum/view_record/clan_playerbase_view/CPV

	if(clan_to_get)
		target_clan = GET_CLAN(clan_to_get)
		target_clan.sync()
		CPV = DB_VIEW(/datum/view_record/clan_playerbase_view, DB_COMP("clan_id", DB_EQUALS, clan_to_get))
	else
		CPV = DB_VIEW(/datum/view_record/clan_playerbase_view, DB_COMP("clan_id", DB_IS, clan_to_get))

	var/list/data

	var/player_rank = C.clan_info.clan_rank

	if(C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER)
		player_rank = 999 // Target anyone except other managers

	if(target_clan)
		data = list(
			clan_id = target_clan.id,
			clan_name = html_encode(target_clan.name),
			clan_description = html_encode(target_clan.description),
			clan_honor = target_clan.honor,
			clan_keys = list(),

			player_rank_pos = player_rank,

			player_delete_clan = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER),
			player_sethonor_clan = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER),
			player_setcolor_clan = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MODIFY),

			player_rename_clan = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MODIFY),
			player_setdesc_clan = (C.clan_info.permissions & CLAN_PERMISSION_MODIFY),
			player_modify_ranks = (C.clan_info.permissions & CLAN_PERMISSION_MODIFY),

			player_purge = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER),
			player_move_clans = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MOVE)
		)
	else
		data = list(
			clan_id = null,
			clan_name = "Players without a clan",
			clan_description = "This is a list of players without a clan",
			clan_honor = null,
			clan_keys = list(),

			player_rank_pos = player_rank,

			player_delete_clan = FALSE,
			player_sethonor_clan = FALSE,
			player_rename_clan = FALSE,
			player_setdesc_clan = FALSE,
			player_modify_ranks = FALSE,

			player_purge = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MANAGER),
			player_move_clans = (C.clan_info.permissions & CLAN_PERMISSION_ADMIN_MOVE)
		)

	var/list/clan_members[length(CPV)]

	var/index = 1
	for(var/datum/view_record/clan_playerbase_view/CP in CPV)
		var/rank_to_give = CP.clan_rank

		if(CP.permissions & CLAN_PERMISSION_ADMIN_MANAGER)
			rank_to_give = 999

		var/list/player = list(
			player_id = CP.player_id,
			name = CP.ckey,
			rank = GLOB.clan_ranks[CP.clan_rank], // rank_to_give not used here, because we need to get their visual rank, not their position
			rank_pos = rank_to_give,
			honor = (CP.honor? CP.honor : 0)
		)

		clan_members[index++] = player

	data["clan_keys"] = clan_members
	data["can_change_view"] = !!(C.clan_info.permissions & CLAN_PERMISSION_ADMIN_VIEW)

	return data

/client/proc/has_clan_permission(permission_flag, clan_id, warn)
	if(!clan_info)
		if(warn)
			to_chat(src, "You do not have a yautja whitelist!")
		return FALSE

	if(clan_id)
		if(clan_id != clan_info.clan_id)
			if(warn)
				to_chat(src, "You do not have permission to perform actions on this clan!")
			return FALSE


	if(!(clan_info.permissions & permission_flag))
		if(warn)
			to_chat(src, "You do not have the necessary permissions to perform this action!")
		return FALSE

	return TRUE

/client/proc/add_honor(number)
	if(!clan_info)
		return FALSE
	clan_info.sync()

	clan_info.honor = max(number + clan_info.honor, 0)
	clan_info.save()

	if(clan_info.clan_id)
		var/datum/entity/clan/target_clan = GET_CLAN(clan_info.clan_id)
		target_clan.sync()

		target_clan.honor = max(number + target_clan.honor, 0)

		target_clan.save()

	return TRUE

/datum/clan_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	set waitfor = FALSE
	. = ..()
	if(.)
		return

	var/mob/user = ui.user
	var/client/C = user.client
	if(!C || !C.clan_info)
		return TRUE

	C.clan_info.sync() // Make sure permissions/clan is accurate

	if(action == "choose_clan")
		if(!(C.clan_info.permissions & CLAN_PERMISSION_ADMIN_VIEW))
			return TRUE
		var/list/datum/view_record/clan_view/CPV = DB_VIEW(/datum/view_record/clan_view/)
		var/clans = list()
		for(var/datum/view_record/clan_view/CV in CPV)
			clans += list("[CV.name]" = CV.clan_id)
		clans += list("People without clans" = null)
		var/input = tgui_input_list(user, "Choose the clan to view", "View clan", clans)
		if(isnull(input))
			return TRUE
		viewing_clan_by_ref[REF(user)] = clans[input]
		return TRUE

	if(action in list(CLAN_ACTION_CLAN_RENAME, CLAN_ACTION_CLAN_SETDESC, CLAN_ACTION_CLAN_SETCOLOR, CLAN_ACTION_CLAN_SETHONOR, CLAN_ACTION_CLAN_DELETE))
		var/datum/entity/clan/target_clan = GET_CLAN(params["clan_id"])
		target_clan.sync()

		switch(action)
			if(CLAN_ACTION_CLAN_RENAME)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MODIFY))
					return TRUE

				var/input = tgui_input_text(user, "Input the new name", "Set Name", target_clan.name)

				if(!input || input == target_clan.name)
					return TRUE

				message_admins("[key_name_admin(C)] has set the name of [target_clan.name] to [input].")
				to_chat(user, SPAN_NOTICE("Set the name of [target_clan.name] to [input]."))
				target_clan.name = trim(input)

			if(CLAN_ACTION_CLAN_SETDESC)
				if(!C.has_clan_permission(CLAN_PERMISSION_USER_MODIFY))
					return TRUE

				var/input = tgui_input_text(user, "Input a new description", "Set Description", target_clan.description, multiline = TRUE)

				if(!input || input == target_clan.description)
					return TRUE

				message_admins("[key_name_admin(C)] has set the description of [target_clan.name].")
				to_chat(user, SPAN_NOTICE("Set the description of [target_clan.name]."))
				target_clan.description = trim(input)

			if(CLAN_ACTION_CLAN_SETCOLOR)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MODIFY))
					return TRUE

				// No tgui-native color picker exists in this codebase (only text/number/list inputs) —
				// keeping the native color-picker dialog here is a deliberate exception, not a missed
				// conversion; a text-entry hex-code substitute would be a worse experience for this
				// specific widget type.
				var/color = input(user, "Input a new color", "Set Color", target_clan.color) as color|null

				if(!color)
					return TRUE

				target_clan.color = color
				message_admins("[key_name_admin(C)] has set the color of [target_clan.name] to [color].")
				to_chat(user, SPAN_NOTICE("Set the name of [target_clan.name] to [color]."))

			if(CLAN_ACTION_CLAN_SETHONOR)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MANAGER))
					return TRUE

				var/input = tgui_input_number(user, "Input the new honor", "Set Honor", target_clan.honor)

				if((!input && input != 0) || input == target_clan.honor)
					return TRUE

				message_admins("[key_name_admin(C)] has set the honor of clan [target_clan.name] from [target_clan.honor] to [input].")
				to_chat(user, SPAN_NOTICE("Set the honor of [target_clan.name] from [target_clan.honor] to [input]."))
				target_clan.honor = input

			if(CLAN_ACTION_CLAN_DELETE)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MANAGER))
					return TRUE

				var/input = tgui_input_text(user, "Please input the name of the clan to proceed.", "Delete Clan")

				if(input != target_clan.name)
					to_chat(user, "You have decided not to delete [target_clan.name].")
					return TRUE

				message_admins("[key_name_admin(C)] has deleted the clan [target_clan.name].")
				to_chat(user, SPAN_NOTICE("You have deleted [target_clan.name]."))
				var/list/datum/view_record/clan_playerbase_view/CPV = DB_VIEW(/datum/view_record/clan_playerbase_view, DB_COMP("clan_id", DB_EQUALS, target_clan.id))

				for(var/datum/view_record/clan_playerbase_view/CP in CPV)
					var/datum/entity/clan_player/pl = DB_EKEY(/datum/entity/clan_player/, CP.player_id)
					pl.sync()

					pl.clan_id = null
					pl.permissions = GLOB.clan_ranks[CLAN_RANK_UNBLOODED].permissions
					pl.clan_rank = GLOB.clan_ranks_ordered[CLAN_RANK_UNBLOODED]

					pl.save()

				target_clan.delete()
				viewing_clan_by_ref[REF(user)] = null
				return TRUE // We delete here. We don't need to save the clan after it deletes

		target_clan.save()
		target_clan.sync()

		if(target_clan.id)
			viewing_clan_by_ref[REF(user)] = target_clan.id
		return TRUE

	if(action in list(CLAN_ACTION_PLAYER_PURGE, CLAN_ACTION_PLAYER_MOVECLAN, CLAN_ACTION_PLAYER_MODIFYRANK))
		var/datum/entity/clan_player/target = GET_CLAN_PLAYER(params["target_ref"])
		target.sync()

		var/datum/entity/player/P = DB_ENTITY(/datum/entity/player, target.player_id)
		P.sync()

		var/player_name = P.ckey

		var/player_rank = C.clan_info.clan_rank

		if(C.has_clan_permission(CLAN_PERMISSION_ADMIN_MANAGER, warn = FALSE))
			player_rank = 999

		if((target.permissions & CLAN_PERMISSION_ADMIN_MANAGER) || player_rank <= target.clan_rank)
			to_chat(user, SPAN_DANGER("You can't target this person!"))
			return TRUE

		switch(action)
			if(CLAN_ACTION_PLAYER_PURGE)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MANAGER))
					return TRUE

				var/input = tgui_input_text(user, "Are you sure you want to purge this person? Type '[player_name]' to purge", "Confirm Purge")

				if(!input || input != player_name)
					return TRUE

				var/target_clan_id = target.clan_id
				message_admins("[key_name_admin(C)] has purged [player_name]'s clan profile.")
				to_chat(user, SPAN_NOTICE("You have purged [player_name]'s clan profile."))

				target.delete()

				if(P.owning_client)
					P.owning_client.clan_info = null

				viewing_clan_by_ref[REF(user)] = target_clan_id
				return TRUE // Return because we don't want to save them. They've been deleted

			if(CLAN_ACTION_PLAYER_MOVECLAN)
				if(!C.has_clan_permission(CLAN_PERMISSION_ADMIN_MOVE))
					return TRUE

				var/is_clan_manager = C.has_clan_permission(CLAN_PERMISSION_ADMIN_MANAGER, warn = FALSE)
				var/list/datum/view_record/clan_view/CPV = DB_VIEW(/datum/view_record/clan_view/)

				var/list/clans = list()
				for(var/datum/view_record/clan_view/CV in CPV)
					clans += list("[CV.name]" = CV.clan_id)

				if(is_clan_manager && length(clans) >= 1)
					if(target.permissions & CLAN_PERMISSION_ADMIN_ANCIENT)
						clans += list("Remove from Ancient")
					else
						clans += list("Make Ancient")

				if(target.clan_id)
					clans += list("Remove from clan")

				var/input = tgui_input_list(user, "Choose the clan to put them in", "Change player's clan", clans)

				if(!input)
					return TRUE

				if(input == "Remove from clan" && target.clan_id)
					target.clan_id = null
					target.clan_rank = GLOB.clan_ranks_ordered[CLAN_RANK_BLOODED]
					to_chat(user, SPAN_NOTICE("Removed [player_name] from their clan."))
					message_admins("[key_name_admin(C)] has removed [player_name] from their current clan.")
				else if(input == "Remove from Ancient")
					target.clan_rank = GLOB.clan_ranks_ordered[CLAN_RANK_BLOODED]
					target.permissions = GLOB.clan_ranks[CLAN_RANK_BLOODED].permissions
					to_chat(user, SPAN_NOTICE("Removed [player_name] from ancient."))
					message_admins("[key_name_admin(C)] has removed [player_name] from ancient.")
				else if(input == "Make Ancient" && is_clan_manager)
					target.clan_rank = GLOB.clan_ranks_ordered[CLAN_RANK_ADMIN]
					target.permissions = CLAN_PERMISSION_ADMIN_ANCIENT
					to_chat(user, SPAN_NOTICE("Made [player_name] an ancient."))
					message_admins("[key_name_admin(C)] has made [player_name] an ancient.")
				else
					to_chat(user, SPAN_NOTICE("Moved [player_name] to [input]."))
					message_admins("[key_name_admin(C)] has moved [player_name] to clan [input].")

					target.clan_id = clans[input]

					if(!(target.permissions & CLAN_PERMISSION_ADMIN_ANCIENT))
						target.permissions = GLOB.clan_ranks[CLAN_RANK_BLOODED].permissions
						target.clan_rank = GLOB.clan_ranks_ordered[CLAN_RANK_BLOODED]

			if(CLAN_ACTION_PLAYER_MODIFYRANK)
				if(!target.clan_id)
					to_chat(user, SPAN_WARNING("This player doesn't belong to a clan!"))
					return TRUE

				var/list/datum/yautja_rank/ranks = GLOB.clan_ranks.Copy()
				ranks -= list(CLAN_RANK_ADMIN, CLAN_RANK_YOUNG)// Admin rank should not and cannot be obtained from here, Youngblood should only be used for non-WL players

				var/datum/yautja_rank/chosen_rank
				if(C.has_clan_permission(CLAN_PERMISSION_ADMIN_MODIFY, warn = FALSE))
					var/input = tgui_input_list(user, "Select the rank to change this user to.", "Select Rank", ranks)

					if(!input)
						return TRUE

					chosen_rank = ranks[input]

				else if(C.has_clan_permission(CLAN_PERMISSION_USER_MODIFY, target.clan_id))
					for(var/rank in ranks)
						if(!C.has_clan_permission(ranks[rank].permission_required, warn = FALSE))
							ranks -= rank

					var/input = tgui_input_list(user, "Select the rank to change this user to.", "Select Rank", ranks)

					if(!input)
						return TRUE

					chosen_rank = ranks[input]

					if(chosen_rank.limit_type)
						var/list/datum/view_record/clan_playerbase_view/CPV = DB_VIEW(/datum/view_record/clan_playerbase_view/, DB_AND(DB_COMP("clan_id", DB_EQUALS, target.clan_id), DB_COMP("rank", DB_EQUALS, GLOB.clan_ranks_ordered[input])))
						var/players_in_rank = length(CPV)

						switch(chosen_rank.limit_type)
							if(CLAN_LIMIT_NUMBER)
								if(players_in_rank >= chosen_rank.limit)
									to_chat(user, SPAN_DANGER("This slot is full! (Maximum of [chosen_rank.limit] slots)"))
									return TRUE
							if(CLAN_LIMIT_SIZE)
								var/list/datum/view_record/clan_playerbase_view/clan_players = DB_VIEW(/datum/view_record/clan_playerbase_view/, DB_COMP("clan_id", DB_EQUALS, target.clan_id))
								var/available_slots = ceil(length(clan_players) / chosen_rank.limit)

								if(players_in_rank >= available_slots)
									to_chat(user, SPAN_DANGER("This slot is full! (Maximum of [chosen_rank.limit] per player in the clan, currently [available_slots])"))
									return TRUE

				else
					return TRUE // Doesn't have permission to do this

				if(!C.has_clan_permission(chosen_rank.permission_required)) // Double check
					return TRUE

				target.clan_rank = GLOB.clan_ranks_ordered[chosen_rank.name]
				target.permissions = chosen_rank.permissions
				message_admins("[key_name_admin(C)] has set the rank of [player_name] to [chosen_rank.name] for their clan.")
				to_chat(user, SPAN_NOTICE("Set [player_name]'s rank to [chosen_rank.name]"))

		target.save()
		target.sync()
		viewing_clan_by_ref[REF(user)] = target.clan_id
		return TRUE
