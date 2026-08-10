/**
 * # Job Slot Assignment
 *
 * tgui replacement for the legacy `/datum/preferences/proc/set_job_slots()` HTML grid
 * (code/modules/client/preferences.dm:828). The slot-listing + tgui_input_list() picker itself
 * is the same flow `assign_job_slot()` already used (that proc IS already tgui-based under the
 * hood) — not reused directly here only because it ends by rebuilding the legacy HTML window
 * (`set_job_slots(user)`), which this replaces; `reset_job_slots()` is still called as-is since
 * it's pure data mutation with no such side effect.
 */
/datum/job_slots_setup
	var/client/owner

/datum/job_slots_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/job_slots_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/job_slots_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "JobSlots", "Job Slot Assignment")
		ui.open()

/datum/job_slots_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/job_slots_setup/ui_data(mob/user)
	. = list()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs || !GLOB.RoleAuthority)
		return

	var/list/active_role_names = GLOB.gamemode_roles[GLOB.master_mode]
	if(!active_role_names)
		active_role_names = GLOB.ROLES_DISTRESS_SIGNAL

	var/list/jobs = list()
	for(var/role_name as anything in active_role_names)
		var/datum/job/job = GLOB.RoleAuthority.roles_by_name[role_name]
		if(!job)
			continue

		var/list/entry = list("title" = job.title, "disp_title" = job.disp_title, "department" = get_job_department(role_name))
		if(jobban_isbanned(user, job.title))
			entry["status"] = "banned"
		else if(!job.check_whitelist_status(user))
			entry["status"] = "whitelisted"
		else if(!job.can_play_role(user.client))
			entry["status"] = "timelocked"
		else
			entry["status"] = "available"
			entry["slot_name"] = prefs.get_job_slot_name(job.title)

		jobs += list(entry)

	.["jobs"] = jobs
	.["ignore_on_start_join"] = !!(prefs.toggle_prefs & TOGGLE_START_JOIN_CURRENT_SLOT)
	.["ignore_on_late_join"] = !!(prefs.toggle_prefs & TOGGLE_LATE_JOIN_CURRENT_SLOT)

/datum/job_slots_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return TRUE
	switch(action)
		if("assign")
			var/target_job = params["title"]
			if(!target_job)
				return TRUE
			var/list/slot_options = list(JOB_SLOT_RANDOMISED_TEXT = JOB_SLOT_RANDOMISED_SLOT, JOB_SLOT_CURRENT_TEXT = JOB_SLOT_CURRENT_SLOT)
			var/savefile/S = new /savefile(prefs.path)
			var/slot_name
			for(var/slot in 1 to MAX_SAVE_SLOTS)
				S.cd = "/character[slot]"
				S["real_name"] >> slot_name
				if(slot_name)
					slot_options["[slot_name] (slot #[slot])"] = slot
			var/chosen_slot = tgui_input_list(ui.user, "Assign character for [target_job] job", "Slot assignment", slot_options)
			if(chosen_slot)
				prefs.pref_job_slots[target_job] = slot_options[chosen_slot]
			return TRUE

		if("toggle_start_join")
			prefs.toggle_prefs ^= TOGGLE_START_JOIN_CURRENT_SLOT
			return TRUE

		if("toggle_late_join")
			prefs.toggle_prefs ^= TOGGLE_LATE_JOIN_CURRENT_SLOT
			return TRUE

		if("reset")
			prefs.reset_job_slots()
			return TRUE
