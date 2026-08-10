/**
 * # Job Preferences
 *
 * tgui replacement for the legacy `/datum/preferences/proc/SetChoices()` HTML priority grid
 * (code/modules/client/preferences.dm:710). Reuses the same underlying procs the legacy menu
 * already calls for mutation (SetJobDepartment(), ResetJobs(), job.filter_job_option() +
 * tgui_input_list() for the per-job variant picker) rather than duplicating their logic —
 * SetJob()/SetChoices() themselves aren't reused since they end by rebuilding the legacy HTML
 * window, which this replaces.
 */
/datum/job_preferences_setup
	var/client/owner

/datum/job_preferences_setup/New(client/holder)
	. = ..()
	owner = holder

/datum/job_preferences_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/job_preferences_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "JobPreferences", "Job Preferences")
		ui.open()

/datum/job_preferences_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/job_preferences_setup/ui_data(mob/user)
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

		var/list/entry = list(
			"title" = job.title,
			"disp_title" = job.disp_title,
			"department" = get_job_department(role_name),
		)

		if(jobban_isbanned(user, job.title))
			entry["status"] = "banned"
		else if(!job.check_whitelist_status(user))
			entry["status"] = "whitelisted"
		else if(!job.can_play_role(user.client))
			entry["status"] = "timelocked"
		else
			entry["status"] = "available"
			entry["priority"] = prefs.get_job_priority(job.title)
			if(job.job_options)
				prefs.pref_special_job_options[role_name] = sanitize_inlist(prefs.pref_special_job_options[role_name], job.job_options, job.job_options[1])
				entry["special_option"] = prefs.pref_special_job_options[role_name]

		jobs += list(entry)

	.["jobs"] = jobs
	.["alternate_option"] = prefs.alternate_option

/datum/job_preferences_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return TRUE
	switch(action)
		if("set_priority")
			var/datum/job/job = GLOB.RoleAuthority.roles_by_name[params["title"]]
			var/priority = text2num(params["priority"])
			if(job && !isnull(priority))
				prefs.SetJobDepartment(job, priority)
			return TRUE

		if("special_option")
			var/datum/job/job = GLOB.RoleAuthority.roles_by_name[params["title"]]
			if(!job)
				return TRUE
			var/list/filtered_options = job.filter_job_option(ui.user)
			var/new_variant = tgui_input_list(ui.user, "Choose your preferred job variant:", "Preferred Job Variant", filtered_options)
			if(new_variant)
				prefs.pref_special_job_options[job.title] = new_variant
			return TRUE

		if("alternate_option")
			var/new_alt = text2num(params["value"])
			if(new_alt in list(GET_RANDOM_JOB, BE_MARINE, RETURN_TO_LOBBY, BE_XENOMORPH))
				prefs.alternate_option = new_alt
			return TRUE

		if("reset")
			prefs.ResetJobs()
			return TRUE
