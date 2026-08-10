/**
 * # Saved Messages
 *
 * tgui_say (code/modules/tgui/tgui-say/) is built around a single hidden native window per
 * client with one active channel at a time — true "multiple simultaneous say windows" isn't
 * achievable without rewriting that architecture. This panel gets the same practical benefit a
 * different way: pre-compose several messages (each remembering its own channel) ahead of time,
 * then fire any one instantly, without losing the others — a queue of ready-to-send lines
 * instead of literal extra windows. Sends reuse tgui_say's own delegate_speech() proc
 * (code/modules/tgui/tgui-say/speech.dm) rather than duplicating its channel-routing switch.
 */
/// Channels a saved message can target — mirrors delegate_speech()'s real switch, minus
/// ADMIN_CHANNEL/MENTOR_CHANNEL which aren't appropriate for a player-facing quick-send list.
GLOBAL_LIST_INIT(saved_message_channels, list(SAY_CHANNEL, ME_CHANNEL, OOC_CHANNEL, LOOC_CHANNEL, COMMS_CHANNEL))

/datum/saved_messages_setup
	var/client/owner

/datum/saved_messages_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/saved_messages_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/saved_messages_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SavedMessages", "Saved Messages")
		ui.open()

/datum/saved_messages_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/saved_messages_setup/ui_static_data(mob/user)
	. = list()
	.["channels"] = GLOB.saved_message_channels
	.["max_slots"] = MAX_SAVED_MESSAGES

/datum/saved_messages_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return

	var/list/slots = list()
	for(var/i in 1 to MAX_SAVED_MESSAGES)
		// String-keyed (not a positional numeric index) — DM can't tell a numeric-index
		// assignment on an otherwise-empty list apart from a positional one, so slot lookups
		// stay unambiguous by keying on "1".."9" instead of the bare numbers.
		var/list/entry = prefs.saved_messages["[i]"]
		slots += list(list(
			"channel" = entry?["channel"] || SAY_CHANNEL,
			"text" = entry?["text"] || "",
		))
	.["slots"] = slots

/datum/saved_messages_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return TRUE

	var/slot = text2num(params["slot"])
	if(!slot || slot < 1 || slot > MAX_SAVED_MESSAGES)
		return TRUE
	var/slot_key = "[slot]"

	switch(action)
		if("save")
			var/channel = params["channel"]
			if(!(channel in GLOB.saved_message_channels))
				return TRUE
			var/text = sanitize_text(params["text"], "")
			if(!length(text))
				prefs.saved_messages -= slot_key
				return TRUE
			prefs.saved_messages[slot_key] = list("channel" = channel, "text" = text)
			return TRUE

		if("clear")
			prefs.saved_messages -= slot_key
			return TRUE

		if("send")
			var/list/entry = prefs.saved_messages[slot_key]
			if(!entry?["text"])
				return TRUE
			owner.tgui_say?.delegate_speech(entry["text"], entry["channel"])
			return TRUE

/// Fires a saved message slot directly, without opening the panel — bound to a key via
/// the /datum/keybinding/client/communication/saved_message_N datums (code/datums/keybinding/
/// saved_messages.dm), same as IC Say/OOC/Me already are.
/client/proc/send_saved_message(slot)
	if(!prefs || slot < 1 || slot > MAX_SAVED_MESSAGES)
		return
	var/list/entry = prefs.saved_messages["[slot]"]
	if(!entry?["text"])
		return
	tgui_say?.delegate_speech(entry["text"], entry["channel"])
