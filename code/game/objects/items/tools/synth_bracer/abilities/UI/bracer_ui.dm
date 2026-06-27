/**
 * Embedded Apollo interface subtype used exclusively inside the synth bracer.
 * - req_one_access cleared: the bracer biometric login gates access; the
 *   Apollo interface still enforces ARES access via get_ares_access() at login time.
 * - ui_state -> always_state: the device lives two levels deep in the user's
 *   inventory (inside the bracer), so inventory_state fails its direct-contents
 *   check. always_state is safe here because the bracer is the security boundary.
 */
/obj/item/device/working_joe_pda/bracer_link
	req_one_access = null

/obj/item/device/working_joe_pda/bracer_link/ui_state(mob/user)
	return GLOB.always_state

// Per-instance UI state — declared here as extensions to the gloves type.
// These MUST NOT be globals; each bracer tracks its own session independently.
/obj/item/clothing/gloves/synth
	var/current_menu = "login"
	var/last_menu = "main"
	var/authentication = 0
	var/last_login = null
	/// Temporary Apollo interface — kept alive while the UI is open
	var/obj/item/device/working_joe_pda/bracer_link/temp_ami_pda
	/// Temporary bracer_remote dropship console — kept alive while the UI is open
	var/obj/structure/machinery/computer/shuttle/dropship/flight/bracer_remote/temp_dropship_console
	/// GID of the synthetic unit this device is biometrically registered to; null until first scan
	var/owner_gid = null
	/// Display name of the registered owner
	var/owner_name = null

// ─── TGUI ────────────────────────────────────────────────────────────────────

/obj/item/clothing/gloves/synth/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		if(battery_charge <= 0)
			to_chat(user, SPAN_WARNING("\The [src] has no power."))
			return
		drain_charge(user, 1, report_charge = FALSE)
		ui_displaying = TRUE
		START_PROCESSING(SSobj, src)
		ui = new(user, src, "SynthBracer", name)
		ui.open()

/obj/item/clothing/gloves/synth/ui_close(mob/user)
	. = ..()
	QDEL_NULL(temp_ami_pda)
	QDEL_NULL(temp_dropship_console)
	// Keep authentication across opens so the player doesn't re-login every time.
	// Set menu back to main if authenticated, login otherwise.
	if(authentication)
		current_menu = "main"
	else
		current_menu = "login"
		last_menu = "main"
	ui_displaying = FALSE
	ui_display_tick = 0
	ui_drain_tick = 0
	if(!motion_detector_active)
		STOP_PROCESSING(SSobj, src)

/obj/item/clothing/gloves/synth/ui_data(mob/user)
	var/list/data = list()

	data["current_menu"] = current_menu
	data["logged_in"] = last_login
	data["access_text"] = "Access Level [authentication] — [bracer_auth_to_text(authentication)]"
	data["access_level"] = authentication
	data["battery_charge"] = battery_charge
	data["battery_charge_max"] = battery_charge_max
	data["phone_ringing"] = (internal_transmitter && internal_transmitter.inbound_call)

	var/mob/living/carbon/human/wearer = loc
	data["is_on_ship"] = (wearer && is_mainship_level(wearer.z))
	data["is_on_colony"] = (wearer && is_ground_level(wearer.z))
	data["has_tactical_map"] = !!(locate(/obj/item/device/simi_chip/tactical_map) in ability_chips)
	data["owner_name"] = owner_name

	return data

/obj/item/clothing/gloves/synth/ui_status(mob/user, datum/ui_state/state)
	. = ..()
	if(!ishuman(user))
		return UI_CLOSE
	var/mob/living/carbon/human/human_user = user
	if(human_user.gloves != src && (!underglove || human_user.gloves != underglove))
		return UI_CLOSE
	return ..()

/obj/item/clothing/gloves/synth/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	var/mob/living/carbon/human/user = ui.user
	var/play_sound = TRUE

	switch(action)

		if("login")
			if(authentication)
				return FALSE
			var/obj/item/card/id/idcard = user.get_active_hand()
			if(!istype(idcard))
				idcard = user.get_idcard()
			if(!idcard)
				to_chat(user, SPAN_WARNING("BIOMETRIC AUTHENTICATION FAILURE: No identification found."))
				playsound(src, 'sound/machines/buzz-two.ogg', 15, 1)
				return FALSE
			// Device is restricted to synthetic personnel only
			if(!issynth(user))
				to_chat(user, SPAN_WARNING("BIOMETRIC AUTHENTICATION FAILURE: Device restricted to synthetic personnel."))
				playsound(src, 'sound/machines/buzz-two.ogg', 15, 1)
				return FALSE
			if(!idcard.check_biometrics(user))
				to_chat(user, SPAN_WARNING("BIOMETRIC MISMATCH: ID card does not match registered biometrics."))
				playsound(src, 'sound/machines/buzz-two.ogg', 15, 1)
				return FALSE
			// Owner binding: first scan registers this synthetic; subsequent scans verify identity
			if(!owner_gid)
				owner_gid = idcard.registered_gid
				owner_name = idcard.registered_name
				to_chat(user, SPAN_NOTICE("BIOMETRIC REGISTRATION: Device bound to [owner_name]. Serial recorded."))
			else if(idcard.registered_gid != owner_gid)
				to_chat(user, SPAN_WARNING("BIOMETRIC AUTHENTICATION FAILURE: Device is registered to another synthetic unit."))
				playsound(src, 'sound/machines/buzz-two.ogg', 15, 1)
				return FALSE
			authentication = 1
			last_login = idcard.registered_name
			playsound(src, 'sound/machines/pda_ping.ogg', 15, 1)
			play_sound = FALSE
			current_menu = "main"
			last_menu = "main"

		if("logout")
			current_menu = "login"
			last_menu = "main"
			authentication = 0
			last_login = null

		if("go_back")
			if(current_menu == "main")
				return FALSE
			current_menu = "main"
			last_menu = "main"

		if("home")
			if(current_menu == "main")
				return FALSE
			last_menu = current_menu
			current_menu = "main"

		if("page_phone")
			last_menu = current_menu
			current_menu = "phone"
			if(internal_transmitter)
				internal_transmitter.attack_hand(user)

		if("reopen_phone")
			play_sound = FALSE
			if(internal_transmitter)
				internal_transmitter.attack_hand(user)

		if("page_ati_maint")
			last_menu = current_menu
			current_menu = "ati_maint"
			// Open the Apollo interface via a stored Apollo PDA.
			// Keep it alive so its TGUI window persists between interactions.
			if(temp_ami_pda && QDELING(temp_ami_pda))
				QDEL_NULL(temp_ami_pda)
			if(!temp_ami_pda)
				temp_ami_pda = new(src)
				temp_ami_pda.link_systems()
			temp_ami_pda.tgui_interact(user)

		if("reopen_ati")
			play_sound = FALSE
			if(!temp_ami_pda || QDELING(temp_ami_pda))
				return FALSE
			temp_ami_pda.tgui_interact(user)

		if("page_cameras")
			last_menu = current_menu
			current_menu = "cameras"

		if("open_cameras")
			play_sound = FALSE
			// Only expose the networks that are reachable from the current location.
			var/mob/living/carbon/human/wearer = loc
			var/list/active_nets = list()
			if(wearer)
				if(is_mainship_level(wearer.z))
					active_nets = list(CAMERA_NET_ALMAYER, CAMERA_NET_BRIG, CAMERA_NET_ARES, CAMERA_NET_ALAMO)
				else if(is_ground_level(wearer.z))
					active_nets = list(CAMERA_NET_COLONY)
			if(!length(active_nets))
				to_chat(user, SPAN_WARNING("No accessible camera networks at this location."))
				return FALSE
			internal_camera_console.network = active_nets
			internal_camera_console.tgui_interact(user)

		if("page_tactical")
			last_menu = current_menu
			current_menu = "tactical"

		if("page_dropship")
			last_menu = current_menu
			current_menu = "dropship"
			// Open the dropship flight computer via a stored remote console.
			// Uses the bracer_remote subtype which:
			//   - sets is_remote = TRUE for CIC-style automated controls
			//   - overrides ui_state to always_state (console lives inside the bracer)
			if(temp_dropship_console && QDELING(temp_dropship_console))
				QDEL_NULL(temp_dropship_console)
			if(!temp_dropship_console)
				temp_dropship_console = new(src)
			temp_dropship_console.tgui_interact(user)

		if("reopen_dropship")
			play_sound = FALSE
			if(!temp_dropship_console || QDELING(temp_dropship_console))
				return FALSE
			temp_dropship_console.tgui_interact(user)

		else
			return FALSE

	if(play_sound)
		var/snd = pick('sound/machines/pda_button1.ogg', 'sound/machines/pda_button2.ogg')
		playsound(src, snd, 15, TRUE)

	return TRUE

// ─── Helpers ─────────────────────────────────────────────────────────────────

/obj/item/clothing/gloves/synth/proc/get_bracer_access(obj/item/card/id/card, mob/living/carbon/human/user)
	if(!istype(card) || !istype(user))
		return 0
	if(!card.check_biometrics(user))
		to_chat(user, SPAN_WARNING("BIOMETRIC MISMATCH: ID card does not match user."))
		return 0
	if(issynth(user))
		return 1
	if(card.access && (ACCESS_WY_GENERAL in card.access))
		return 2
	if(card.access && (ACCESS_MARINE_COMMAND in card.access))
		return 1
	return 0

/obj/item/clothing/gloves/synth/proc/bracer_auth_to_text(access_level)
	switch(access_level)
		if(0)
			return "Logged Out"
		if(1)
			return "Authorized"
		if(2)
			return "Weyland-Yutani Personnel"
	return "Unknown"
