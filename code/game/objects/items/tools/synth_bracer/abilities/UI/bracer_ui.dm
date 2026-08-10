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

/// Trimmed action allow-list for the bracer's embedded Apollo tab — see the comment at the
/// forwarding call site in /obj/item/clothing/gloves/synth/ui_act() for why this is an explicit
/// allow-list rather than a blanket forward like the camera/dropship/phone tabs use. Does NOT
/// include login/logout/go_back/home — those collide with the bracer's OWN top-level actions of
/// the same name (see APOLLO_ACTION_TRANSLATION below).
GLOBAL_LIST_INIT(ALLOWED_APOLLO_ACTIONS, list(
	"toggle_sound",
	"page_logins", "page_apollo", "page_request", "page_report", "page_maintenance",
	"new_report", "claim_ticket", "cancel_ticket", "mark_ticket", "new_access", "return_access",
))

/// login/logout/go_back/home are ambiguous action names: the bracer's own switch(action) in
/// ui_act() already has top-level cases for all four (its own biometric login, its own menu nav),
/// and DM's switch() matches by name only — it has no idea which tab is showing. Since those
/// top-level cases come first in the switch, they'd silently swallow Apollo's identically-named
/// actions whenever the Apollo tab is active (this is exactly what broke Apollo login — clicking
/// "Login" inside the Apollo tab hit the bracer's OWN login case, which no-ops because the wearer
/// is already logged into the bracer). Fix: give Apollo's frontend distinct action names
/// (apollo_login etc.), translated back to the real name only when forwarding to temp_ami_pda.
GLOBAL_LIST_INIT(APOLLO_ACTION_TRANSLATION, list(
	"apollo_login" = "login",
	"apollo_logout" = "logout",
	"apollo_go_back" = "go_back",
	"apollo_home" = "home",
))

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
	if(current_menu == "cameras")
		leave_camera_tab(user)
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

/obj/item/clothing/gloves/synth/ui_static_data(mob/user)
	. = ..()
	.["battery_low_ratio"] = SIMI_LOWPOWER_RATIO

	// Cameras and Phone tabs — internal_camera_console and internal_transmitter are both
	// permanent children of the bracer (unlike the lazily-created dropship console), so their
	// static data is always safe to include here.
	var/list/camera_static = internal_camera_console.ui_static_data(user)
	.["mapRef"] = camera_static["mapRef"]
	.["cameras"] = camera_static["cameras"]

	if(internal_transmitter)
		var/list/phone_static = internal_transmitter.ui_static_data(user)
		.["available_transmitters"] = phone_static["available_transmitters"]
		.["transmitters"] = phone_static["transmitters"]

	// Dropship tab — only present once the console has actually been created (lazily, on first
	// "page_dropship"); page_dropship's handler explicitly pushes a static-data refresh after
	// creating it, since this proc won't be called again on its own. Merged at the top level
	// (not nested) so DropshipFlightControl.tsx's existing components can be reused unmodified —
	// they read these fields directly off the window's top-level data via useBackend().
	if(temp_dropship_console)
		var/list/dropship_static = temp_dropship_console.ui_static_data(user)
		for(var/key in dropship_static)
			.[key] = dropship_static[key]

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

	data["active_ability"] = active_ability
	data["active_utility"] = active_utility
	data["motion_detector_active"] = motion_detector_active

	var/list/abilities = list()
	// category/ability_tag/charge_cost are declared separately on the two synth_bracer action
	// base classes (framework.dm), not on their common ancestor /datum/action/human_action, so a
	// typed loop var can't access them via "." (fails static checking) — but an untyped var can't
	// access ANYTHING via "." either (no static type to resolve against, not even inherited members
	// like .name/.cooldown). Fix: keep the typed loop var for the members it does have, and use ":"
	// (BYOND's dynamic/unchecked member access) only for the three leaf-only members.
	for(var/datum/action/human_action/action as anything in actions_list_actions)
		var/is_active = (action:ability_tag != SIMI_ACTIVE_NONE) && \
			(action:ability_tag == (action:category == SIMI_PRIMARY_ACTION ? active_ability : active_utility))
		abilities += list(list(
			"ref" = REF(action),
			"name" = action.name,
			"category" = action:category,
			"charge_cost" = action:charge_cost,
			"cooldown_s" = round(action.cooldown / 10),
			"cooldown_remaining_s" = max(0, round((action.ability_used_time - world.time) / 10)),
			"is_active" = is_active,
			"can_afford" = battery_charge >= action:charge_cost,
		))
	data["abilities"] = abilities

	// Embedded sub-system tabs — only pulled in while that tab is actually active, so idle
	// polling on other pages doesn't pay for camera/dropship data it isn't showing.
	if(current_menu == "cameras")
		var/list/camera_data = internal_camera_console.ui_data(user)
		data["network"] = camera_data["network"]
		data["activeCamera"] = camera_data["activeCamera"]
	else if(current_menu == "dropship" && temp_dropship_console)
		var/list/dropship_data = temp_dropship_console.ui_data(user)
		for(var/key in dropship_data)
			data[key] = dropship_data[key]
	else if(current_menu == "phone" && internal_transmitter)
		var/list/phone_data = internal_transmitter.ui_data(user)
		data["availability"] = phone_data["availability"]
		data["last_caller"] = phone_data["last_caller"]
	else if(current_menu == "ati_maint" && temp_ami_pda)
		// Merged wholesale (unlike the other three tabs' field-by-field picks) since
		// working_joe_pda/ui_data() pulls from the shared ARES datacore (datacore.dm) and doesn't
		// separate "trimmed-relevant" fields out — the extra ship-wide fields (nuke timers, evac
		// status, security/announcement logs) just go unused by the trimmed frontend below rather
		// than being a security concern, since none of them are actions and none are rendered.
		var/list/apollo_data = temp_ami_pda.ui_data(user)
		for(var/key in apollo_data)
			data[key] = apollo_data[key]

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
	var/was_on_cameras = (current_menu == "cameras")

	switch(action)

		if("trigger_ability")
			// Same entry point a hotbar click on the action button uses (code/_onclick/hud/screen_objects.dm) —
			// routes through the ability's own can_use_action()/action_activate(), so all of its existing
			// validation, chat feedback, cooldowns and charge costs apply exactly as they do from the hotbar.
			var/target_ref = params["action_ref"]
			var/datum/action/human_action/target_action
			for(var/datum/action/human_action/bracer_action as anything in actions_list_actions)
				if(REF(bracer_action) == target_ref)
					target_action = bracer_action
					break
			if(!target_action)
				return TRUE
			if(target_action.can_use_action())
				target_action.action_activate()
			return TRUE

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
				// attack_hand() keeps its existing "silently answer an active incoming call and
				// put the handset in the wearer's hand" shortcut — same behavior as before this
				// tab was embedded. Its own fallback (no active call) would open a standalone
				// PhoneMenu window on internal_transmitter itself; close that immediately since
				// the Phone tab now renders inline in this same window instead.
				internal_transmitter.attack_hand(user)
				SStgui.close_uis(internal_transmitter)

		if("page_ati_maint")
			last_menu = current_menu
			current_menu = "ati_maint"
			// Trimmed Apollo interface, embedded — see leave_camera_tab-style comment block
			// near ALLOWED_APOLLO_ACTIONS below for what's deliberately left out and why.
			// Kept alive (not recreated) across re-visits within the same bracer session, same
			// as before, so the wearer doesn't need to re-login to Apollo every time they tab
			// away and back — only torn down in ui_close().
			if(temp_ami_pda && QDELING(temp_ami_pda))
				QDEL_NULL(temp_ami_pda)
			if(!temp_ami_pda)
				temp_ami_pda = new(src)
				temp_ami_pda.link_systems()

		if("page_cameras")
			// Only expose the networks that are reachable from the current location — recomputed
			// fresh on every entry to the tab, same as the old "open_cameras" gate used to do.
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
			last_menu = current_menu
			current_menu = "cameras"

		if("page_tactical")
			last_menu = current_menu
			current_menu = "tactical"

		if("page_abilities")
			last_menu = current_menu
			current_menu = "abilities"

		if("page_dropship")
			last_menu = current_menu
			current_menu = "dropship"
			// Uses the bracer_remote subtype which:
			//   - sets is_remote = TRUE for CIC-style automated controls
			//   - overrides ui_state to always_state (console lives inside the bracer)
			if(temp_dropship_console && QDELING(temp_dropship_console))
				QDEL_NULL(temp_dropship_console)
			if(!temp_dropship_console)
				temp_dropship_console = new(src)
			// ui_static_data() only fires once at window-open, before this console existed —
			// push a fresh static-data update now that it's here, same as change_shuttle does below.
			update_static_data(user)

		else
			// Anything not recognized above gets forwarded to whichever sub-system tab is
			// currently active — CameraConsole.tsx's, DropshipFlightControl.tsx's, and
			// PhoneMenu.tsx's action names are all reused verbatim by the embedded tab
			// components, so no translation needed.
			if(current_menu == "cameras")
				internal_camera_console.ui_act(action, params, ui, state)
				play_sound = FALSE
			else if(current_menu == "dropship" && temp_dropship_console)
				temp_dropship_console.ui_act(action, params, ui, state)
				play_sound = FALSE
				if(action == "change_shuttle")
					update_static_data(user)
			else if(current_menu == "phone" && internal_transmitter)
				internal_transmitter.ui_act(action, params, ui, state)
				play_sound = FALSE
			else if(current_menu == "ati_maint" && temp_ami_pda && GLOB.APOLLO_ACTION_TRANSLATION[action])
				// apollo_login/apollo_logout/apollo_go_back/apollo_home — translated back to their
				// real name before forwarding (see APOLLO_ACTION_TRANSLATION for why these can't
				// use their real names directly).
				temp_ami_pda.ui_act(GLOB.APOLLO_ACTION_TRANSLATION[action], params, ui, state)
				play_sound = FALSE
			else if(current_menu == "ati_maint" && temp_ami_pda && (action in GLOB.ALLOWED_APOLLO_ACTIONS))
				// Unlike the other three tabs, Apollo's action set is NOT blanket-forwarded —
				// working_joe_pda/ui_act() also handles security_lockdown, trigger_vent,
				// page_core_gas, page_tickets, auth_access, and reject_access, none of which the
				// bracer's trimmed frontend renders buttons for. Blanket forwarding would still let
				// a forged act() call reach them regardless of what's rendered, so this is an
				// explicit allow-list, not a "the frontend won't ask for it anyway" assumption.
				temp_ami_pda.ui_act(action, params, ui, state)
				play_sound = FALSE
			else
				return FALSE

	if(was_on_cameras && current_menu != "cameras")
		leave_camera_tab(user)
	else if(!was_on_cameras && current_menu == "cameras")
		enter_camera_tab(user)

	if(play_sound)
		var/snd = pick('sound/machines/pda_button1.ogg', 'sound/machines/pda_button2.ogg')
		playsound(src, snd, 15, TRUE)

	return TRUE

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Registers the camera map screen objects onto the wearer's client — see internal_camera_console
/// (/obj/structure/machinery/computer/cameras/internal), which no longer gets its own tgui_interact()
/// call now that the Cameras tab renders inline, so this replicates the signal side of what that
/// call used to do.
/obj/item/clothing/gloves/synth/proc/enter_camera_tab(mob/user)
	SEND_SIGNAL(internal_camera_console, COMSIG_CAMERA_REFRESH)
	SEND_SIGNAL(internal_camera_console, COMSIG_CAMERA_REGISTER_UI, user)

/// Unregisters the camera map screen objects and clears the active feed — mirrors
/// /obj/structure/machinery/computer/cameras/ui_close(), since this camera console's own
/// ui_close() no longer fires (its window is never independently opened/closed).
/obj/item/clothing/gloves/synth/proc/leave_camera_tab(mob/user)
	SEND_SIGNAL(internal_camera_console, COMSIG_CAMERA_UNREGISTER_UI, user)
	SEND_SIGNAL(internal_camera_console, COMSIG_CAMERA_CLEAR)

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
