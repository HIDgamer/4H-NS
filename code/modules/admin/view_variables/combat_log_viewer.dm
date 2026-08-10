/**
 * Small read-only tgui popup for a mob's attack_log, replacing the old ad hoc show_browser()
 * page opened from the VV window's "View Combat Logs" link. No session caching needed —
 * each open is a fresh read-only snapshot, same as the old popup.
 */
/datum/combat_log_viewer
	var/mob/target
	var/list/log_lines

/datum/combat_log_viewer/New(mob/target)
	. = ..()
	src.target = target
	log_lines = target?.attack_log?.Copy() || list()

/datum/combat_log_viewer/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CombatLogViewer", "Combat Logs: [target]")
		ui.open()

// Same fix as view_variables_session.dm — a bare /datum has no loc, so the default tgui state's
// physical distance check can never resolve, and the UI closes itself right after ui.open() fires.
/datum/combat_log_viewer/ui_state(mob/user)
	return GLOB.always_state

/datum/combat_log_viewer/ui_status(mob/user, datum/ui_state/state)
	if(!user.client?.admin_holder || !(user.client.admin_holder.rights & R_MOD))
		return UI_CLOSE
	return ..()

/datum/combat_log_viewer/ui_static_data(mob/user)
	var/list/data = list()
	data["target_name"] = "[target]"
	data["logs"] = log_lines
	return data
