/**
 * Fires a Saved Messages slot (code/modules/client/
 * saved_messages_setup.dm) directly from a bound key, without opening the panel — unbound by
 * default, same as most non-movement keybindings; players bind these themselves via Settings &
 * Special > View Keybinds.
 */
/datum/keybinding/client/communication/saved_message_1
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_1"
	full_name = "Send Saved Message 1"
	description = "Instantly sends Saved Message slot 1."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE1_DOWN

/datum/keybinding/client/communication/saved_message_1/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(1)
	return TRUE

/datum/keybinding/client/communication/saved_message_2
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_2"
	full_name = "Send Saved Message 2"
	description = "Instantly sends Saved Message slot 2."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE2_DOWN

/datum/keybinding/client/communication/saved_message_2/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(2)
	return TRUE

/datum/keybinding/client/communication/saved_message_3
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_3"
	full_name = "Send Saved Message 3"
	description = "Instantly sends Saved Message slot 3."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE3_DOWN

/datum/keybinding/client/communication/saved_message_3/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(3)
	return TRUE

/datum/keybinding/client/communication/saved_message_4
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_4"
	full_name = "Send Saved Message 4"
	description = "Instantly sends Saved Message slot 4."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE4_DOWN

/datum/keybinding/client/communication/saved_message_4/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(4)
	return TRUE

/datum/keybinding/client/communication/saved_message_5
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_5"
	full_name = "Send Saved Message 5"
	description = "Instantly sends Saved Message slot 5."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE5_DOWN

/datum/keybinding/client/communication/saved_message_5/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(5)
	return TRUE

/datum/keybinding/client/communication/saved_message_6
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_6"
	full_name = "Send Saved Message 6"
	description = "Instantly sends Saved Message slot 6."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE6_DOWN

/datum/keybinding/client/communication/saved_message_6/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(6)
	return TRUE

/datum/keybinding/client/communication/saved_message_7
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_7"
	full_name = "Send Saved Message 7"
	description = "Instantly sends Saved Message slot 7."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE7_DOWN

/datum/keybinding/client/communication/saved_message_7/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(7)
	return TRUE

/datum/keybinding/client/communication/saved_message_8
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_8"
	full_name = "Send Saved Message 8"
	description = "Instantly sends Saved Message slot 8."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE8_DOWN

/datum/keybinding/client/communication/saved_message_8/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(8)
	return TRUE

/datum/keybinding/client/communication/saved_message_9
	hotkey_keys = list("Unbound")
	classic_keys = list("Unbound")
	name = "saved_message_9"
	full_name = "Send Saved Message 9"
	description = "Instantly sends Saved Message slot 9."
	keybind_signal = COMSIG_KB_CLIENT_SAVEDMESSAGE9_DOWN

/datum/keybinding/client/communication/saved_message_9/down(client/user)
	. = ..()
	if(.)
		return
	user.send_saved_message(9)
	return TRUE
