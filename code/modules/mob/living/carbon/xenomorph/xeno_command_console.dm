/**
 * RTS-style hive command console - lets a Hive Leader (in-character) or an
 * admin-ghost (out-of-character, GM/testing) select AI-piloted xenos and
 * issue them direct move/attack orders, plus a set of canned orders. Orders
 * only ever affect AI-piloted (clientless) xenos - never player-controlled
 * ones, enforced both at selection time (xeno_command_selection.dm) and
 * again here at issuance time as defense in depth.
 *
 * One console instance per commander. Selecting units (any of the three
 * input methods - see xeno_command_selection.dm, xeno.dm's shift-click hook,
 * xeno_command_marquee.dm) is itself the "arm" step: client.click_intercept
 * is kept in sync with whether the selection is non-empty, rather than
 * requiring a separate arm button per order the way admin_spawn_terminal does -
 * right-clicking a destination or target is always available the moment
 * something is selected, matching real RTS UX.
 *
 * Also carries the AI Difficulty controls (formerly a separate standalone
 * /datum/admin_ai_difficulty panel) - "merge the AI difficulty panel with
 * the command one, and make it an admin and AI only panel." Admin-only in
 * this UI: a Hive Leader session (is_admin_session FALSE) never sees or can
 * act on any of it, gated in both ui_data()/ui_static_data() and every
 * relevant ui_act() case. The mutating logic itself lives in standalone
 * global procs (xeno_hive_difficulty.dm) rather than inline here, so it's
 * callable directly from code and not just through this tgui - though the
 * "AI leaders like an AI queen" half of the request is actually satisfied
 * separately, by queen.dm's own should_reinforce_frontline() decision
 * logic, not by the Queen driving this panel's procs herself.
 */
/datum/xeno_command_console
	var/mob/owner
	var/datum/hive_status/hive
	/// TRUE for the admin-ghost entry point (permission-checked via R_SPAWN instead of IS_XENO_LEADER, hive picked manually instead of read off the owner).
	var/is_admin_session = FALSE
	var/datum/xeno_command_selection/selection
	/// While TRUE, a plain click (not shift-click) on a same-hive AI xeno in-world selects it (clearing any prior selection) instead of behaving as a normal click - toggled from the panel so ordinary play is never affected when the console isn't in active use.
	var/selecting_mode = FALSE
	/// Canned order awaiting a destination click ("go_to_area") - consumed by the very next InterceptClickOn regardless of button, then cleared.
	var/armed_order_type
	/// TRUE while marquee mode is registered/listening for a drag - see xeno_command_marquee.dm.
	var/marquee_active = FALSE
	/// Marquee drag-select state - see xeno_command_marquee.dm.
	var/turf/marquee_start_turf
	/// Turfs currently under a live marquee drag's highlight - cleared and reset every mousedrag event.
	var/list/turf/marquee_highlighted_turfs

/datum/xeno_command_console/New(mob/user, datum/hive_status/target_hive, admin_session = FALSE)
	owner = user
	hive = target_hive
	is_admin_session = admin_session
	selection = new

/datum/xeno_command_console/Destroy()
	if(owner?.client?.click_intercept == src)
		owner.client.click_intercept = null
	SStgui.close_uis(src)
	owner = null
	hive = null
	selection = null
	return ..()

/datum/xeno_command_console/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "XenoCommandConsole", "Hive Command")
		ui.open()

/// Closing the window (not just losing leader status) left an armed intercept forever since nothing else cleared it - same discipline admin_spawn_terminal already needs for the same reason.
/datum/xeno_command_console/ui_close(mob/user)
	. = ..()
	if(user?.client?.click_intercept == src)
		user.client.click_intercept = null
	armed_order_type = null

/datum/xeno_command_console/ui_state(mob/user)
	return GLOB.always_state

/datum/xeno_command_console/ui_data(mob/user)
	var/list/data = list()
	data["is_admin_session"] = is_admin_session
	data["selecting_mode"] = selecting_mode
	data["armed_order_type"] = armed_order_type
	data["hive_name"] = hive?.name
	data["has_rally_point"] = !!hive?.rally_turf

	// AI Difficulty (formerly the standalone /datum/admin_ai_difficulty
	// panel, event_tab.dm) merged in here - "merge the AI difficulty panel
	// with the command one, and make it an admin and AI only panel" -
	// admin-only in the UI (a Hive Leader session never sees or can act on
	// any of this); the "AI leaders like an AI queen" half of that ask is
	// satisfied separately, by queen.dm's own should_reinforce_frontline()
	// decision, not by exposing this UI section to her.
	if(is_admin_session)
		data["ai_xeno_count"] = GLOB.ai_xeno_active_count
		data["ai_flee_multiplier"] = GLOB.ai_flee_multiplier
		data["ai_distance_multiplier"] = GLOB.ai_distance_multiplier
		data["difficulty_multiplier"] = GLOB.ai_difficulty_multiplier
		data["ai_debug_pathing"] = GLOB.ai_debug_pathing

		data["spawner_enabled"] = GLOB.xeno_spawner_enabled
		var/datum/hive_status/spawner_hive = GLOB.xeno_spawner_hive ? GLOB.hive_datum[GLOB.xeno_spawner_hive] : null
		data["spawner_target_population"] = spawner_target_population(spawner_hive)
		data["spawner_hive_name"] = spawner_hive ? spawner_hive.name : "None"
		data["spawner_phase"] = SSxeno_spawner.hive_phase

		var/list/caste_caps = list()
		for(var/c in ALL_XENO_CASTES)
			caste_caps[c] = GLOB.ai_xeno_max_per_caste[c] || 0 // 0 means "uncapped" in the UI, not "cap of zero".
		data["ai_caste_caps"] = caste_caps
		var/list/caste_counts = list()
		for(var/c in ALL_XENO_CASTES)
			caste_counts[c] = count_active_ai_xenos_of_caste(c)
		data["ai_caste_counts"] = caste_counts

	var/list/roster = list()
	if(hive)
		for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
			if(xeno.hivenumber != hive.hivenumber)
				continue
			var/list/entry = list()
			entry["ref"] = REF(xeno)
			entry["name"] = xeno.name
			entry["caste"] = xeno.caste_type
			entry["health"] = xeno.health
			entry["max_health"] = xeno.maxHealth
			entry["ai_state"] = xeno.ai_controller?.ai_state
			entry["idle_activity"] = xeno.ai_controller?.idle_activity
			entry["area"] = get_area_name(xeno)
			entry["selected"] = selection.is_selected(xeno)
			entry["ordered"] = xeno.ai_controller && xeno.ai_controller.player_order_type != PLAYER_ORDER_NONE
			roster += list(entry)
	data["roster"] = roster
	data["selected_count"] = length(selection.get_selected(hive?.hivenumber))
	return data

/datum/xeno_command_console/ui_static_data(mob/user)
	var/list/data = list()
	if(is_admin_session)
		var/list/hives = list()
		for(var/h in GLOB.hive_datum)
			hives += h
		data["available_hives"] = hives

		var/list/castes = list()
		for(var/c in ALL_XENO_CASTES)
			castes += c
		data["ai_castes"] = castes
	return data

/datum/xeno_command_console/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!can_command(user))
		return

	switch(action)
		if("toggle_select")
			var/mob/living/carbon/xenomorph/xeno = locate(params["ref"]) in GLOB.ai_xeno_list
			if(xeno)
				selection.toggle(xeno, hive?.hivenumber)
			sync_click_intercept()
			return TRUE
		if("select_all")
			var/list/all_ai = list()
			for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
				if(xeno.hivenumber == hive?.hivenumber)
					all_ai += xeno
			selection.select_list(all_ai, hive?.hivenumber)
			sync_click_intercept()
			return TRUE
		if("select_none")
			selection.clear()
			sync_click_intercept()
			return TRUE
		if("toggle_selecting_mode")
			selecting_mode = !selecting_mode
			return TRUE
		if("toggle_marquee_mode")
			toggle_marquee_mode(user)
			return TRUE
		if("cancel_all_orders")
			for(var/mob/living/carbon/xenomorph/xeno as anything in selection.get_selected(hive?.hivenumber))
				xeno.ai_controller?.clear_player_order()
				xeno.ai_controller?.drop_target()
			return TRUE
		if("order_hold")
			for(var/mob/living/carbon/xenomorph/xeno as anything in selection.get_selected(hive?.hivenumber))
				xeno.ai_controller?.receive_hold_order()
			return TRUE
		if("order_gather_here")
			var/turf/gather_turf = get_turf(user)
			if(gather_turf)
				issue_move_order(selection.get_selected(hive?.hivenumber), gather_turf)
			return TRUE
		if("order_form_on_queen")
			var/turf/queen_turf = hive?.living_xeno_queen ? get_turf(hive.living_xeno_queen) : null
			if(queen_turf)
				issue_move_order(selection.get_selected(hive?.hivenumber), queen_turf)
			else
				to_chat(user, SPAN_WARNING("The hive has no living Queen to form on."))
			return TRUE
		if("order_attack_lz")
			var/turf/lz_turf = get_active_lz_turf()
			if(!lz_turf)
				to_chat(user, SPAN_WARNING("No primary LZ has been designated yet."))
				return TRUE
			var/list/selected_xenos = selection.get_selected(hive?.hivenumber)
			var/atom/movable/lz_target = locate(/mob/living/carbon/human) in lz_turf
			if(lz_target)
				issue_attack_order(selected_xenos, lz_target)
			else
				issue_move_order(selected_xenos, lz_turf)
			return TRUE
		if("order_set_rally")
			if(hive)
				hive.rally_turf = get_turf(user)
				to_chat(user, SPAN_NOTICE("Rally point set - fresh reinforcements will anchor here."))
			return TRUE
		if("order_clear_rally")
			if(hive)
				hive.rally_turf = null
				to_chat(user, SPAN_NOTICE("Rally point cleared."))
			return TRUE
		if("order_retreat")
			for(var/mob/living/carbon/xenomorph/xeno as anything in selection.get_selected(hive?.hivenumber))
				if(xeno.ai_controller?.anchor_turf)
					xeno.ai_controller.receive_move_order(xeno.ai_controller.anchor_turf)
			return TRUE
		if("arm_go_to_area")
			armed_order_type = "go_to_area"
			sync_click_intercept()
			to_chat(user, SPAN_NOTICE("Click a destination for the selected xenos - right-click to cancel."))
			return TRUE
		if("arm_focus_fire")
			armed_order_type = "focus_fire"
			sync_click_intercept()
			to_chat(user, SPAN_NOTICE("Click a target for the selected xenos to focus fire - right-click to cancel."))
			return TRUE
		if("order_delayed")
			var/delay_seconds = clamp(text2num(params["delay"]) || 0, 1, 60)
			var/list/xeno_refs = list()
			for(var/mob/living/carbon/xenomorph/xeno as anything in selection.get_selected(hive?.hivenumber))
				xeno_refs += xeno
			var/turf/gather_turf = get_turf(user)
			if(length(xeno_refs) && gather_turf)
				addtimer(CALLBACK(src, PROC_REF(issue_move_order), xeno_refs, gather_turf), delay_seconds SECONDS)
				to_chat(user, SPAN_NOTICE("Order staged - firing in [delay_seconds] second\s."))
			return TRUE

		// ─── AI Difficulty (admin-only - see ui_data()'s doc comment) ────────
		if("set_spawner_enabled")
			if(!is_admin_session)
				return TRUE
			xeno_hive_set_spawner_enabled(params["enabled"])
			message_admins("[key_name_admin(user)] [GLOB.xeno_spawner_enabled ? "enabled" : "disabled"] the Xeno Spawner.")
			return TRUE

		if("set_spawner_hive")
			if(!is_admin_session)
				return TRUE
			var/list/hive_options = list("None (spawner disabled)" = null)
			for(var/hivenumber in GLOB.hive_datum)
				var/datum/hive_status/hive_option = GLOB.hive_datum[hivenumber]
				hive_options["[hive_option.name]"] = hivenumber
			var/choice = tgui_input_list(user, "Which hive should the Xeno Spawner reinforce?", "Xeno Spawner Hive", hive_options)
			if(isnull(choice))
				return TRUE // Cancelled - distinct from actually picking "None", which is a null *value*, not a null *key*.
			xeno_hive_set_spawner_hive(hive_options[choice])
			message_admins("[key_name_admin(user)] set the Xeno Spawner's target hive to [choice].")
			return TRUE

		if("set_spawner_phase")
			if(!is_admin_session)
				return TRUE
			var/list/phase_options = list(HIVE_PHASE_BUILDUP, HIVE_PHASE_ASSAULT, HIVE_PHASE_LULL)
			var/choice = tgui_input_list(user, "Force the hive's pressure phase (the normal rhythm resumes from it):", "Hive Phase", phase_options)
			if(isnull(choice))
				return TRUE
			xeno_hive_force_phase(choice)
			message_admins("[key_name_admin(user)] forced the Xeno Spawner's hive phase to [choice].")
			return TRUE

		if("set_spawner_difficulty")
			if(!is_admin_session)
				return TRUE
			var/new_difficulty = text2num(params["value"])
			xeno_hive_set_difficulty_multiplier(new_difficulty)
			message_admins("[key_name_admin(user)] set the Xeno Spawner difficulty multiplier to [GLOB.ai_difficulty_multiplier].")
			return TRUE

		if("set_ai_debug_pathing")
			if(!is_admin_session)
				return TRUE
			xeno_hive_set_debug_pathing(params["enabled"])
			message_admins("[key_name_admin(user)] [GLOB.ai_debug_pathing ? "enabled" : "disabled"] xeno AI pathing/broadcast debug logging.")
			return TRUE

		if("set_caste_cap")
			if(!is_admin_session)
				return TRUE
			var/caste = params["caste"]
			if(!(caste in ALL_XENO_CASTES))
				return TRUE
			var/new_cap = text2num(params["value"])
			xeno_hive_set_caste_cap(caste, new_cap)
			if(GLOB.ai_xeno_max_per_caste[caste])
				message_admins("[key_name_admin(user)] capped [caste] to [GLOB.ai_xeno_max_per_caste[caste]] active AI xenos.")
			else
				message_admins("[key_name_admin(user)] removed the per-caste cap on [caste].")
			return TRUE

		if("set_flee_multiplier")
			if(!is_admin_session)
				return TRUE
			xeno_hive_set_flee_multiplier(text2num(params["value"]))
			message_admins("[key_name_admin(user)] set the AI flee multiplier to [GLOB.ai_flee_multiplier].")
			return TRUE

		if("set_distance_multiplier")
			if(!is_admin_session)
				return TRUE
			xeno_hive_set_distance_multiplier(text2num(params["value"]))
			message_admins("[key_name_admin(user)] set the AI awareness/leash distance multiplier to [GLOB.ai_distance_multiplier].")
			return TRUE

		if("set_behavior_preset")
			if(!is_admin_session)
				return TRUE
			if(xeno_hive_set_behavior_preset(params["preset"]))
				message_admins("[key_name_admin(user)] set the AI behavior preset to [params["preset"]].")
			return TRUE

/// Shared permission gate for every ui_act branch - a Hive Leader session requires actually still being one (can be demoted mid-session); an admin session requires the R_SPAWN right, same as the existing Xeno Spawner/AI Difficulty admin panels that also directly manipulate the AI hive.
/datum/xeno_command_console/proc/can_command(mob/user)
	if(is_admin_session)
		return check_client_rights(user.client, R_SPAWN)
	if(!isxeno(user))
		return FALSE
	var/mob/living/carbon/xenomorph/xeno_user = user
	return IS_XENO_LEADER(xeno_user) && xeno_user == owner

/// Keeps client.click_intercept in sync with "is there anything to give an order to right now" - selecting a unit is itself the arm step (see this file's own doc comment), rather than a separate button press per order.
/datum/xeno_command_console/proc/sync_click_intercept()
	if(!owner?.client)
		return
	if(length(selection.selected) || armed_order_type)
		owner.client.click_intercept = src
	else if(owner.client.click_intercept == src)
		owner.client.click_intercept = null

/**
 * Right-click order issuance. LEFT_CLICK always returns FALSE (un-
 * intercepted) - normal gameplay clicking for the commander's own mob is
 * completely untouched, the intercept only ever adds behavior on right-click.
 * A canned order awaiting a destination (armed_order_type) consumes the very
 * next click regardless of button, then falls back to the ambient
 * right-click-always-available mode.
 */
/datum/xeno_command_console/proc/InterceptClickOn(mob/user, params, atom/A)
	var/list/modifiers = params2list(params)
	var/is_right_click = LAZYACCESS(modifiers, RIGHT_CLICK)

	if(is_right_click && !armed_order_type)
		// A bare right-click with nothing armed cancels the ambient order
		// mode entirely (clears the selection) - the same "right-click to
		// cancel" convention admin_spawn_terminal's own InterceptClickOn uses.
		if(length(selection.selected))
			selection.clear()
			SStgui.update_uis(src)
			return TRUE
		return FALSE

	if(armed_order_type)
		var/order = armed_order_type
		armed_order_type = null
		var/list/selected_xenos = selection.get_selected(hive?.hivenumber)
		if(is_right_click)
			sync_click_intercept()
			return TRUE // Right-click while armed just cancels the armed order, same as admin_spawn_terminal.
		if(order == "go_to_area")
			issue_move_order(selected_xenos, get_turf(A))
		else if(order == "focus_fire")
			issue_attack_order(selected_xenos, A)
		sync_click_intercept()
		return TRUE

	if(!is_right_click)
		return FALSE

	var/list/selected_xenos = selection.get_selected(hive?.hivenumber)
	if(!length(selected_xenos))
		return FALSE

	// Right-click on a valid target issues ATTACK to whichever selected
	// members can validly target it and MOVE (to that turf) to the rest, so
	// a mixed-tier selection (e.g. a Runner alongside a Crusher right-
	// clicking a vehicle only the Crusher can fight) never leaves anyone
	// standing idle.
	var/list/attackers = list()
	var/list/movers = list()
	for(var/mob/living/carbon/xenomorph/xeno as anything in selected_xenos)
		if(xeno.ai_controller?.is_valid_target(A))
			attackers += xeno
		else
			movers += xeno
	if(length(attackers))
		issue_attack_order(attackers, A)
	if(length(movers))
		issue_move_order(movers, get_turf(A))
	return TRUE

/**
 * Sole entry point for a MOVE order - every canned order and the ambient
 * right-click flow funnel through this, never setting controller vars
 * directly. Re-checks AI-piloted/no-client as defense in depth on top of
 * xeno_command_selection.dm's own filtering - QDELETED is checked first and
 * separately since the delayed-order QoL feature (order_delayed) holds these
 * refs in a closure for up to 60 seconds, a real window for a selected xeno
 * to have died in the meantime.
 */
/datum/xeno_command_console/proc/issue_move_order(list/mob/living/carbon/xenomorph/xenos, turf/destination)
	if(!destination)
		return
	for(var/mob/living/carbon/xenomorph/xeno as anything in xenos)
		if(QDELETED(xeno) || !xeno.is_ai_controlled || xeno.client || !xeno.ai_controller)
			continue
		xeno.ai_controller.receive_move_order(destination)

/// Sole entry point for an ATTACK order - see issue_move_order()'s doc comment, same discipline.
/datum/xeno_command_console/proc/issue_attack_order(list/mob/living/carbon/xenomorph/xenos, atom/movable/target)
	if(QDELETED(target))
		return
	for(var/mob/living/carbon/xenomorph/xeno as anything in xenos)
		if(QDELETED(xeno) || !xeno.is_ai_controlled || xeno.client || !xeno.ai_controller)
			continue
		xeno.ai_controller.receive_attack_order(target)

/**
 * Hive Leader action - granted/revoked in hive_status.dm's add_hive_leader()/
 * remove_hive_leader()/replace_hive_leader() alongside info_marker, the exact
 * same mechanism, not a new one. onclick (not activable) since this should
 * open the console immediately on click, not arm for a follow-up click the
 * way info_marker/abilities generally do.
 */
/datum/action/xeno_action/onclick/command_console
	name = "Hive Command"
	action_icon_state = "mark" // Placeholder - reuses info_marker's known-good icon_state (actions_xeno.dmi) pending a dedicated sprite.
	ability_primacy = XENO_NOT_PRIMARY_ACTION
	no_cooldown_msg = TRUE

/datum/action/xeno_action/onclick/command_console/use_ability(atom/Atom)
	. = ..() // SHOULD_CALL_PARENT (xeno_action.dm) - ability-usage stats tracking and the action-button icon refresh, same as every other onclick action here.
	var/mob/living/carbon/xenomorph/xeno = owner
	if(!istype(xeno) || !IS_XENO_LEADER(xeno) || !xeno.hive)
		return
	if(!xeno.hive_command_console)
		xeno.hive_command_console = new(xeno, xeno.hive, FALSE)
	xeno.hive_command_console.tgui_interact(xeno)

/**
 * Admin-ghost entry point - out-of-character GM/testing access to the same
 * console, permission-gated by R_SPAWN (checked in ui_act()'s can_command(),
 * same double-gate pattern admin_spawn_terminal/admin_ai_difficulty already use)
 * rather than IS_XENO_LEADER, since an admin-ghost has no hive membership of
 * its own to check - the hive is picked manually instead, same as the
 * existing Xeno Spawner hive picker (event_tab.dm's "set_spawner_hive").
 * Deliberately no rights check at the verb level itself, matching
 * create_xenos()/ai_difficulty()'s own pattern - any admin can open the
 * picker, but every actual action inside is individually gated.
 */
/datum/admins/proc/xeno_command_console(mob/user)
	var/list/hive_options = list()
	for(var/hivenumber in GLOB.hive_datum)
		var/datum/hive_status/hive_option = GLOB.hive_datum[hivenumber]
		hive_options["[hive_option.name]"] = hivenumber
	var/choice = tgui_input_list(user, "Which hive do you want to command?", "Hive Command Console", hive_options)
	if(isnull(choice))
		return
	// tgui_input_list() returns the selected KEY (the display name string),
	// not the associated value - hive_options[choice] looks the hivenumber
	// back up, the same two-step resolution set_spawner_hive() (event_tab.dm)
	// already uses for this exact list shape. Indexing GLOB.hive_datum with
	// the raw string choice directly (the original bug here) silently found
	// nothing and returned early with no feedback - "clicking a hive does
	// nothing, menu closes."
	var/hivenumber = hive_options[choice]
	var/datum/hive_status/target_hive = GLOB.hive_datum[hivenumber]
	if(!target_hive)
		return
	var/datum/xeno_command_console/console = new(user, target_hive, TRUE)
	console.tgui_interact(user)

/client/proc/xeno_command_console()
	set name = "Hive Command Console"
	set category = "Admin.Events"
	if(admin_holder)
		admin_holder.xeno_command_console(usr)
