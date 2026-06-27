// ---- TGUI Admin Sound Panel ----

/datum/admin_sound_panel
	var/client/owner
	var/resolved_url = ""
	var/resolved_title = ""
	var/last_error = ""
	var/last_status = ""
	var/is_playing = FALSE
	var/pending_asset_name = ""
	var/pending_asset_url = ""

/datum/admin_sound_panel/New(client/C)
	. = ..()
	owner = C

/datum/admin_sound_panel/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/admin_sound_panel/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "AdminSoundPanel", "Admin Sound Panel")
		ui.open()

/datum/admin_sound_panel/ui_state(mob/user)
	return GLOB.admin_state

/datum/admin_sound_panel/ui_data(mob/user)
	. = list()
	var/list/cliented = list()
	for (var/mob/M in sortmobs())
		if (!M.client)
			continue
		cliented += list(list(
			"name" = M.name,
			"key" = M.key,
			"ref" = "\ref[M]",
		))
	.["cliented_mobs"] = cliented
	.["resolved_title"] = resolved_title
	.["last_error"] = last_error
	.["last_status"] = last_status
	.["is_playing"] = is_playing

/datum/admin_sound_panel/proc/resolve_and_play(url, audience, target_ref, sound_type_flag, show_title)
	last_error = ""
	var/list/data = list()

	var/list/datum/internet_media/media_players = list()
	if (CONFIG_GET(string/invoke_youtubedl))
		media_players += new /datum/internet_media/yt_dlp
	if (CONFIG_GET(string/cobalt_base_api))
		media_players += new /datum/internet_media/cobalt

	if (!length(media_players))
		last_error = "No web media players configured on this server."
		SStgui.update_uis(src)
		return

	var/datum/media_response/response
	for (var/datum/internet_media/player as anything in media_players)
		response = player.get_media(url)
		if (istype(response))
			break

	if (!istype(response))
		var/errors = ""
		for (var/datum/internet_media/player as anything in media_players)
			errors += "\n  [player.type]: [player.error]"
		last_error = "All media players failed:[errors]"
		SStgui.update_uis(src)
		return

	data = response.get_list()
	if (!data["url"])
		last_error = "Media provider returned no usable URL."
		SStgui.update_uis(src)
		return

	if (!findtext(data["url"], GLOB.is_http_protocol))
		last_error = "BLOCKED: Content URL not using http(s) protocol."
		SStgui.update_uis(src)
		return

	resolved_url = data["url"]
	resolved_title = data["title"] || "Admin sound"

	var/list/music_extra_data = list(
		"link" = data["url"],
		"start" = data["start_time"],
		"end" = data["end_time"],
		"title" = show_title ? resolved_title : "Admin sound",
	)

	broadcast_sound(audience, target_ref, music_extra_data, resolved_url, sound_type_flag, show_title, pending_asset_name)
	is_playing = TRUE
	last_status = "Playing: [resolved_title]"
	SStgui.update_uis(src)

/datum/admin_sound_panel/proc/broadcast_sound(audience, target_ref, list/music_extra_data, web_url, sound_type_flag, show_title, asset_name)
	var/list/targets = list()
	switch (audience)
		if ("Globally")
			targets = GLOB.mob_list
		if ("Xenos")
			targets = GLOB.xeno_mob_list + GLOB.dead_mob_list
		if ("Marines")
			targets = GLOB.human_mob_list + GLOB.dead_mob_list
		if ("Ghosts")
			targets = GLOB.observer_list + GLOB.dead_mob_list
		if ("All In View Range")
			var/list/atom/ranged_atoms = long_range(owner.view, get_turf(owner.mob))
			for (var/mob/receiver in ranged_atoms)
				targets += receiver
		if ("Single Mob")
			var/mob/M = locate(target_ref)
			if (!QDELETED(M))
				targets.Add(M)
		else
			return

	for (var/mob/mob as anything in targets)
		var/client/C = mob?.client
		if (!C)
			continue
		if (C.prefs?.toggles_sound & sound_type_flag)
			if (asset_name && SSassets.transport.send_assets(C, asset_name))
				// send_assets() only fire-and-forgets a browse_rsc() push - the client's own asset
				// registry doesn't actually have the file until asset_cache_update_json() runs, which
				// the transport itself schedules 1 second later (asset_transport.dm). Calling
				// play_music() on the same tick as send_assets() races that: the client's embedded
				// player gets told to fetch a local asset URL before the browser has finished
				// receiving it, which is why "Upload File" could silently play for nobody - worse the
				// slower the client's connection. Wait for the same window before actually starting playback.
				addtimer(CALLBACK(src, PROC_REF(start_playback), C, web_url, music_extra_data, show_title), 1.5 SECONDS)
			else
				start_playback(C, web_url, music_extra_data, show_title)
		else
			C.tgui_panel?.stop_music()

/datum/admin_sound_panel/proc/start_playback(client/C, web_url, list/music_extra_data, show_title)
	if (QDELETED(C))
		return
	C.tgui_panel?.play_music(web_url, music_extra_data)
	if (show_title)
		to_chat(C, SPAN_BOLDANNOUNCE("An admin played: [music_extra_data["title"]]"), confidential = TRUE)

/datum/admin_sound_panel/proc/upload_and_play(audience, target_ref, sound_type, show_title)
	var/soundfile = input(owner?.mob, "Choose a sound file to play", "Upload Sound") as null|file
	if (!soundfile)
		return
	var/static/regex/only_extension = regex(@{"^.*\.([a-z0-9]{1,5})$"}, "gi")
	var/extension = only_extension.Replace("[soundfile]", "$1")
	if (!length(extension))
		last_error = "Invalid filename extension."
		SStgui.update_uis(src)
		return
	var/current_transport = CONFIG_GET(string/asset_transport)
	var/must_send = (!current_transport || current_transport == "simple")
	var/static/playsound_notch = 1
	pending_asset_name = "admin_sound_[playsound_notch++].[extension]"
	SSassets.transport.register_asset(pending_asset_name, soundfile)
	pending_asset_url = SSassets.transport.get_asset_url(pending_asset_name)
	var/static/regex/remove_extension = regex(@{"\.[a-z0-9]+$"}, "gi")
	resolved_title = remove_extension.Replace("[soundfile]", "")
	var/sound_type_flag = (sound_type == "Atmospheric") ? SOUND_ADMIN_ATMOSPHERIC : SOUND_ADMIN_MEME
	var/show_title_bool = !!show_title
	var/list/music_extra_data = list(
		"link" = pending_asset_url,
		"title" = show_title_bool ? resolved_title : "Admin sound",
	)
	broadcast_sound(audience || "Globally", target_ref || "", music_extra_data, pending_asset_url, sound_type_flag, show_title_bool, must_send ? pending_asset_name : "")
	is_playing = TRUE
	last_status = "Playing uploaded: [resolved_title]"
	message_admins("[key_name_admin(owner?.mob)] uploaded and played admin sound '[soundfile]' to [audience || "Globally"].")
	log_admin("[key_name(owner?.mob)] uploaded admin sound '[soundfile]' to [audience || "Globally"].")
	SStgui.update_uis(src)

/datum/admin_sound_panel/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if (.)
		return
	if (!check_client_rights(ui.user.client, R_SOUNDS))
		return

	switch (action)
		if ("resolve_url")
			var/url = trim(params["url"] || "")
			if (!istext(url) || !length(url))
				return
			resolved_url = ""
			resolved_title = ""
			last_error = ""

			var/list/datum/internet_media/media_players = list()
			if (CONFIG_GET(string/invoke_youtubedl))
				media_players += new /datum/internet_media/yt_dlp
			if (CONFIG_GET(string/cobalt_base_api))
				media_players += new /datum/internet_media/cobalt

			if (!length(media_players))
				last_error = "No web media players configured on this server."
				SStgui.update_uis(src)
				return TRUE

			var/datum/media_response/response
			for (var/datum/internet_media/player as anything in media_players)
				response = player.get_media(url)
				if (istype(response))
					break

			if (istype(response))
				var/list/data = response.get_list()
				resolved_title = data["title"] || url
				last_status = "Title resolved: [resolved_title]"
			else
				last_error = "Could not resolve URL title."

			SStgui.update_uis(src)
			return TRUE

		if ("play_web")
			var/url = trim(params["url"] || "")
			if (!url)
				return
			var/audience = params["audience"] || "Globally"
			var/target_ref = params["target_ref"] || ""
			var/sound_type_flag = (params["sound_type"] == "Atmospheric") ? SOUND_ADMIN_ATMOSPHERIC : SOUND_ADMIN_MEME
			var/show_title = !!params["show_title"]
			INVOKE_ASYNC(src, .proc/resolve_and_play, url, audience, target_ref, sound_type_flag, show_title)
			log_admin("[key_name(ui.user)] queued admin web sound: [url] to [audience].")
			message_admins("[key_name_admin(ui.user)] queued admin web sound: [url] to [audience].")
			return TRUE

		if ("open_file_picker")
			INVOKE_ASYNC(src, .proc/upload_and_play, params["audience"], params["target_ref"], params["sound_type"], params["show_title"])
			return TRUE

		if ("play_direct")
			var/url = trim(params["url"] || "")
			if (!url)
				return TRUE
			if (!findtext(url, GLOB.is_http_protocol))
				last_error = "BLOCKED: Content URL not using http(s) protocol."
				SStgui.update_uis(src)
				return TRUE

			var/audience = params["audience"] || "Globally"
			var/target_ref = params["target_ref"] || ""
			var/sound_type_flag = (params["sound_type"] == "Atmospheric") ? SOUND_ADMIN_ATMOSPHERIC : SOUND_ADMIN_MEME
			var/show_title = !!params["show_title"]
			var/show_blurb = !!params["show_blurb"]
			var/title = params["title"] || url
			var/artist = params["artist"] || "Unknown Artist"
			var/album = params["album"] || "Unknown Album"

			resolved_url = url
			resolved_title = title

			var/list/music_extra_data = list(
				"link" = url,
				"title" = show_title ? title : "Admin sound",
				"artist" = artist,
				"album" = album,
			)
			broadcast_sound(audience, target_ref, music_extra_data, url, sound_type_flag, show_title, "")
			if (show_blurb)
				show_blurb_song(title = title, additional = "[artist] - [album]")

			is_playing = TRUE
			last_status = "Playing direct link: [title]"
			log_admin("[key_name(ui.user)] played a direct-link admin sound: [url].")
			message_admins("[key_name_admin(ui.user)] played a direct-link admin sound: [url].")
			SStgui.update_uis(src)
			return TRUE

		if ("stop_all")
			for (var/i in GLOB.clients)
				var/client/C = i
				C.tgui_panel.stop_music()
			is_playing = FALSE
			last_status = "All sounds stopped."
			log_admin("[key_name(ui.user)] stopped all admin sounds.")
			message_admins("[key_name_admin(ui.user)] stopped all admin sounds.")
			SStgui.update_uis(src)
			return TRUE

/client/proc/play_admin_sound()
	set category = "Admin.Fun"
	set name = "Play Admin Sound"
	if (!check_rights(R_SOUNDS))
		return
	var/datum/admin_sound_panel/panel = new(src)
	panel.tgui_interact(mob)

/client/proc/stop_admin_sound()
	set category = "Admin.Fun"
	set name = "Stop Admin Sounds"

	if (!check_rights(R_SOUNDS))
		return

	for (var/i in GLOB.clients)
		var/client/C = i
		C.tgui_panel.stop_music()

	log_admin("[key_name(src)] stopped the currently playing web sounds.")
	message_admins("[key_name_admin(src)] stopped the currently playing web sounds.")

/// Shows a two-line song info blurb - title, then "Artist - Album" underneath. Used by the Direct Link source mode's optional on-screen blurb.
/proc/show_blurb_song(title = "Song Name", additional = "Song Artist - Song Album")
	var/message_to_display = "<b>[title]</b>\n[additional]"
	show_blurb(GLOB.player_list, 10 SECONDS, "[message_to_display]", screen_position = "LEFT+0:16,BOTTOM+1:16", text_alignment = "left", text_color = "#FFFFFF", blurb_key = "song[title]", ignore_key = TRUE, speed = 1)
