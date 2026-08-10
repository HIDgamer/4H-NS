/**
 * # Settings & Special
 *
 * tgui replacement for the legacy MENU_SETTINGS/MENU_SPECIAL panels
 * (code/modules/client/preferences.dm:593-691). MENU_SETTINGS is almost entirely uniform bitflag
 * toggles across 4 different bitfield vars (toggle_prefs/toggles_chat/toggles_sound/
 * toggles_langchat) — the frontend only ever sends a named field ("ooc_flag", "ert_leader", etc,
 * never a raw bit value), and toggle_bitflag() below resolves that name to the right var + bit
 * internally via .vars[] dynamic access, so the tgui layer never needs to know any DM #define
 * values. The handful of proc-call buttons (set_eye_blur_type() etc, already tgui_alert()-based)
 * are called directly as plain proc calls, same as the legacy "action=proccall" hrefs did.
 * MENU_SPECIAL (ERT toggles) uses the same named-action/toggle_bitflag() pattern against
 * toggles_ert.
 */
/datum/settings_setup
	var/client/owner
	/// Cached per-hub so repeat "saved_messages" clicks reuse the same window instead of
	/// spawning a new one each time — same pattern as character_setup.dm's cached pickers.
	var/datum/saved_messages_setup/saved_messages

/datum/settings_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/settings_setup/Destroy(force, ...)
	owner = null
	QDEL_NULL(saved_messages)
	SStgui.close_uis(src)
	return ..()

/datum/settings_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SettingsSetup", "Settings & Special")
		ui.open()

/datum/settings_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/settings_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return

	.["hotkeys"] = prefs.hotkeys
	.["tgui_say"] = prefs.tgui_say
	.["tgui_say_light_mode"] = prefs.tgui_say_light_mode
	.["ui_style"] = prefs.UI_style
	.["ui_style_color"] = prefs.UI_style_color
	.["ui_style_alpha"] = prefs.UI_style_alpha
	.["stylesheet"] = prefs.stylesheet
	.["hide_statusbar"] = prefs.hide_statusbar
	.["no_radials_preference"] = prefs.no_radials_preference
	.["no_radial_labels_preference"] = prefs.no_radial_labels_preference
	.["custom_cursors"] = prefs.custom_cursors

	.["show_ooc_flag"] = !!CONFIG_GET(flag/ooc_country_flags)
	.["ooc_flag"] = !!(prefs.toggle_prefs & TOGGLE_OOC_FLAG)
	.["show_view_mc"] = !!(owner.admin_holder && (owner.admin_holder.rights & R_DEBUG))
	.["view_mc"] = prefs.View_MC
	.["show_publicity"] = !!prefs.unlock_content
	.["member_public"] = !!(prefs.toggle_prefs & TOGGLE_MEMBER_PUBLIC)
	.["ghost_ears"] = !!(prefs.toggles_chat & CHAT_GHOSTEARS)
	.["ghost_sight"] = !!(prefs.toggles_chat & CHAT_GHOSTSIGHT)
	.["ghost_radio"] = !!(prefs.toggles_chat & CHAT_GHOSTRADIO)
	.["ghost_spyradio"] = !!(prefs.toggles_chat & CHAT_LISTENINGBUG)
	.["ghost_hivemind"] = !!(prefs.toggles_chat & CHAT_GHOSTHIVEMIND)
	.["lang_chat_disabled"] = prefs.lang_chat_disabled
	.["langchat_emotes"] = !!(prefs.toggles_langchat & LANGCHAT_SEE_EMOTES)

	.["ambient_occlusion"] = !!(prefs.toggle_prefs & TOGGLE_AMBIENT_OCCLUSION)
	.["auto_fit_viewport"] = prefs.auto_fit_viewport
	.["adaptive_zoom"] = prefs.adaptive_zoom
	.["tooltips"] = prefs.tooltips
	.["tgui_fancy"] = prefs.tgui_fancy
	.["tgui_lock"] = prefs.tgui_lock
	.["hear_admin_sounds"] = !!(prefs.toggles_sound & SOUND_MIDI)
	.["hear_observer_announcements"] = !!(prefs.toggles_sound & SOUND_OBSERVER_ANNOUNCEMENTS)
	.["lobby_music"] = !!(prefs.toggles_sound & SOUND_LOBBY)
	.["hear_vox"] = prefs.hear_vox
	.["ghost_vision_pref"] = prefs.ghost_vision_pref
	.["show_metadata"] = !!CONFIG_GET(flag/allow_Metadata)

	.["toggle_ignore_self"] = !!(prefs.toggle_prefs & TOGGLE_IGNORE_SELF)
	.["toggle_help_intent_safety"] = !!(prefs.toggle_prefs & TOGGLE_HELP_INTENT_SAFETY)
	.["toggle_middle_mouse_click"] = !!(prefs.toggle_prefs & TOGGLE_MIDDLE_MOUSE_CLICK)
	.["toggle_ability_deactivation_off"] = !!(prefs.toggle_prefs & TOGGLE_ABILITY_DEACTIVATION_OFF)
	.["toggle_directional_attack"] = !!(prefs.toggle_prefs & TOGGLE_DIRECTIONAL_ATTACK)
	.["toggle_auto_eject_magazine_off"] = !!(prefs.toggle_prefs & TOGGLE_AUTO_EJECT_MAGAZINE_OFF)
	.["toggle_auto_eject_magazine_to_hand"] = !!(prefs.toggle_prefs & TOGGLE_AUTO_EJECT_MAGAZINE_TO_HAND)
	.["toggle_eject_magazine_to_hand"] = !!(prefs.toggle_prefs & TOGGLE_EJECT_MAGAZINE_TO_HAND)
	.["toggle_automatic_punctuation"] = !!(prefs.toggle_prefs & TOGGLE_AUTOMATIC_PUNCTUATION)
	.["toggle_combat_clickdrag_override"] = !!(prefs.toggle_prefs & TOGGLE_COMBAT_CLICKDRAG_OVERRIDE)
	.["toggle_middle_mouse_swap_hands"] = !!(prefs.toggle_prefs & TOGGLE_MIDDLE_MOUSE_SWAP_HANDS)
	.["toggle_vend_item_to_hand"] = !!(prefs.toggle_prefs & TOGGLE_VEND_ITEM_TO_HAND)
	.["toggle_ammo_display_type"] = !!(prefs.toggle_prefs & TOGGLE_AMMO_DISPLAY_TYPE)

	.["show_synth_ert"] = !!owner.check_whitelist_status(WHITELIST_SYNTHETIC)
	.["ert_leader"] = !!(prefs.toggles_ert & PLAY_LEADER)
	.["ert_medic"] = !!(prefs.toggles_ert & PLAY_MEDIC)
	.["ert_engineer"] = !!(prefs.toggles_ert & PLAY_ENGINEER)
	.["ert_specialist"] = !!(prefs.toggles_ert & PLAY_HEAVY)
	.["ert_smartgunner"] = !!(prefs.toggles_ert & PLAY_SMARTGUNNER)
	.["ert_synth"] = !!(prefs.toggles_ert & PLAY_SYNTH)
	.["ert_misc"] = !!(prefs.toggles_ert & PLAY_MISC)

/// XORs `bit` on `prefs.vars[varname]`, clearing `undo_bit` if both end up set — same
/// flag/flag_undo mechanic the legacy "toggle_prefs"/"toggles_ert" href handlers used.
/datum/settings_setup/proc/toggle_bitflag(datum/preferences/prefs, varname, bit, undo_bit = 0)
	prefs.vars[varname] ^= bit
	if(undo_bit && (prefs.vars[varname] & bit) && (prefs.vars[varname] & undo_bit))
		prefs.vars[varname] ^= undo_bit

/datum/settings_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	var/mob/user = ui.user
	if(!prefs)
		return TRUE

	switch(action)
		// Named actions instead of a generic "pass me a bit value" action — the frontend never
		// needs to know DM #define values, it just names the field being toggled; this proc
		// resolves it to the right bitfield var + bit internally, same flag/flag_undo mechanic
		// the legacy "toggle_prefs"/"toggles_ert" href handlers used.
		if("ooc_flag")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_OOC_FLAG)
		if("member_public")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_MEMBER_PUBLIC)
		if("ghost_ears")
			toggle_bitflag(prefs, "toggles_chat", CHAT_GHOSTEARS)
		if("ghost_sight")
			toggle_bitflag(prefs, "toggles_chat", CHAT_GHOSTSIGHT)
		if("ghost_radio")
			toggle_bitflag(prefs, "toggles_chat", CHAT_GHOSTRADIO)
		if("ghost_spyradio")
			toggle_bitflag(prefs, "toggles_chat", CHAT_LISTENINGBUG)
		if("ghost_hivemind")
			toggle_bitflag(prefs, "toggles_chat", CHAT_GHOSTHIVEMIND)
		if("lang_chat_disabled")
			prefs.lang_chat_disabled = !prefs.lang_chat_disabled
		if("langchat_emotes")
			toggle_bitflag(prefs, "toggles_langchat", LANGCHAT_SEE_EMOTES)

		if("ambient_occlusion")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_AMBIENT_OCCLUSION)
		if("auto_fit_viewport")
			prefs.auto_fit_viewport = !prefs.auto_fit_viewport
		if("adaptive_zoom")
			prefs.adaptive_zoom = prefs.adaptive_zoom ? 0 : 1
		if("tooltips")
			prefs.tooltips = !prefs.tooltips
		if("tgui_fancy")
			prefs.tgui_fancy = !prefs.tgui_fancy
		if("tgui_lock")
			prefs.tgui_lock = !prefs.tgui_lock
		if("hear_admin_sounds")
			toggle_bitflag(prefs, "toggles_sound", SOUND_MIDI)
		if("hear_observer_announcements")
			toggle_bitflag(prefs, "toggles_sound", SOUND_OBSERVER_ANNOUNCEMENTS)
		if("lobby_music")
			toggle_bitflag(prefs, "toggles_sound", SOUND_LOBBY)
		if("hear_vox")
			prefs.hear_vox = !prefs.hear_vox

		if("toggle_ignore_self")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_IGNORE_SELF)
		if("toggle_help_intent_safety")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_HELP_INTENT_SAFETY)
		if("toggle_middle_mouse_click")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_MIDDLE_MOUSE_CLICK)
		if("toggle_ability_deactivation_off")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_ABILITY_DEACTIVATION_OFF)
		if("toggle_directional_attack")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_DIRECTIONAL_ATTACK)
		if("toggle_auto_eject_magazine_off")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_AUTO_EJECT_MAGAZINE_OFF, TOGGLE_AUTO_EJECT_MAGAZINE_TO_HAND)
		if("toggle_auto_eject_magazine_to_hand")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_AUTO_EJECT_MAGAZINE_TO_HAND, TOGGLE_AUTO_EJECT_MAGAZINE_OFF)
		if("toggle_eject_magazine_to_hand")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_EJECT_MAGAZINE_TO_HAND)
		if("toggle_automatic_punctuation")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_AUTOMATIC_PUNCTUATION)
		if("toggle_combat_clickdrag_override")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_COMBAT_CLICKDRAG_OVERRIDE)
		if("toggle_middle_mouse_swap_hands")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_MIDDLE_MOUSE_SWAP_HANDS)
		if("toggle_vend_item_to_hand")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_VEND_ITEM_TO_HAND)
		if("toggle_ammo_display_type")
			toggle_bitflag(prefs, "toggle_prefs", TOGGLE_AMMO_DISPLAY_TYPE)

		if("ert_leader")
			toggle_bitflag(prefs, "toggles_ert", PLAY_LEADER)
		if("ert_medic")
			toggle_bitflag(prefs, "toggles_ert", PLAY_MEDIC)
		if("ert_engineer")
			toggle_bitflag(prefs, "toggles_ert", PLAY_ENGINEER)
		if("ert_specialist")
			toggle_bitflag(prefs, "toggles_ert", PLAY_HEAVY)
		if("ert_smartgunner")
			toggle_bitflag(prefs, "toggles_ert", PLAY_SMARTGUNNER)
		if("ert_synth")
			if(!owner.check_whitelist_status(WHITELIST_SYNTHETIC))
				return TRUE
			toggle_bitflag(prefs, "toggles_ert", PLAY_SYNTH)
		if("ert_misc")
			toggle_bitflag(prefs, "toggles_ert", PLAY_MISC)
		if("hotkeys")
			prefs.hotkeys = !prefs.hotkeys
			if(prefs.hotkeys)
				winset(user, null, "input.focus=true")
			else
				winset(user, null, "input.focus=false")

		if("viewmacros")
			prefs.macros.tgui_interact(user)

		if("saved_messages")
			if(!saved_messages)
				saved_messages = new(owner)
			saved_messages.tgui_interact(user)

		if("inputstyle")
			var/result = tgui_alert(user, "Which input style do you want?", "Input Style", list("Modern", "Legacy"))
			if(!result)
				return TRUE
			prefs.tgui_say = (result != "Legacy")

		if("inputcolor")
			var/result = tgui_alert(user, "Which input color do you want?", "Input Style", list("Darkmode", "Lightmode"))
			if(!result)
				return TRUE
			prefs.tgui_say_light_mode = (result == "Lightmode")

		if("ui_style")
			var/choice = tgui_input_list(user, "Choose your UI style", "UI style", GLOB.custom_human_huds)
			if(choice)
				prefs.UI_style = choice

		if("ui_style_color")
			var/new_color = tgui_color_picker(user, "Choose your UI color, dark colors are not recommended!", "UI Color", prefs.UI_style_color)
			if(new_color)
				prefs.UI_style_color = new_color

		if("ui_style_alpha")
			var/new_alpha = tgui_input_number(user, "Select a new alpha (transparency) parameter for your UI, between 50 and 255", "Select alpha", prefs.UI_style_alpha, 255, 50)
			if(new_alpha && new_alpha <= 255 && new_alpha >= 50)
				prefs.UI_style_alpha = new_alpha

		if("stylesheet")
			var/choice = tgui_input_list(user, "Select a stylesheet to use (affects non-NanoUI interfaces)", "Select a stylesheet", GLOB.stylesheets)
			if(choice)
				prefs.stylesheet = choice

		if("hide_statusbar")
			prefs.hide_statusbar = !prefs.hide_statusbar
			if(prefs.hide_statusbar)
				winset(owner, "mapwindow.status_bar", "text=\"\"")
				winset(owner, "mapwindow.status_bar", "is-visible=false")
			else
				winset(owner, "mapwindow.status_bar", "is-visible=true")

		if("no_radials_preference")
			prefs.no_radials_preference = !prefs.no_radials_preference

		if("no_radial_labels_preference")
			prefs.no_radial_labels_preference = !prefs.no_radial_labels_preference

		if("customcursors")
			owner.do_toggle_custom_cursors(owner.mob)

		if("view_mc")
			if(!(owner.admin_holder && (owner.admin_holder.rights & R_DEBUG)))
				return TRUE
			prefs.View_MC = !prefs.View_MC

		if("ghost_vision_pref")
			var/static/list/vision_level_choices = list(GHOST_VISION_LEVEL_NO_NVG, GHOST_VISION_LEVEL_MID_NVG, GHOST_VISION_LEVEL_FULL_NVG)
			var/choice = tgui_input_list(user, "Choose your default ghost vision level", "Vision level", vision_level_choices)
			if(choice)
				prefs.ghost_vision_pref = choice

		if("metadata")
			if(!CONFIG_GET(flag/allow_Metadata))
				return TRUE
			var/new_metadata = tgui_input_text(user, "Enter any information you'd like others to see, such as Roleplay-preferences:", "Game Preference", prefs.metadata)
			if(new_metadata)
				prefs.metadata = strip_html(new_metadata)

		if("toggle_admin_sound_types")
			owner.toggle_admin_sound_types()
		if("set_eye_blur_type")
			owner.set_eye_blur_type()
		if("set_flash_type")
			owner.set_flash_type()
		if("set_crit_type")
			owner.set_crit_type()
		if("receive_random_tip")
			owner.receive_random_tip()
		if("switch_item_animations")
			owner.switch_item_animations()
		if("toggle_dualwield")
			owner.toggle_dualwield()

	return TRUE
