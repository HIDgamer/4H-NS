/**
 * # Late Join
 *
 * tgui replacement for the legacy late_choices()/late_choices_upp() HTML popup
 * (code/modules/mob/new_player/new_player.dm), matching the visual style of the
 * modern Job Preferences screen (job_preferences.dm/JobPreferences.tsx). Reuses
 * AttemptLateSpawn(), check_role_entry() and get_job_department() rather than
 * duplicating their logic - one interface handles both the normal and UPP variants
 * via the faction var, replacing what used to be two near-duplicate procs.
 */
/datum/late_join_setup
	var/mob/new_player/owner
	var/faction

/datum/late_join_setup/New(mob/new_player/holder, faction_value)
	. = ..()
	owner = holder
	faction = faction_value

/datum/late_join_setup/Destroy(force, ...)
	owner = null
	SStgui.close_uis(src)
	return ..()

/datum/late_join_setup/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "LateJoin", "Late Join")
		ui.open()

/datum/late_join_setup/ui_state(mob/user)
	return GLOB.always_state

/datum/late_join_setup/ui_data(mob/user)
	. = list()
	if(!owner || !GLOB.RoleAuthority)
		return

	var/mins = (world.time % 36000) / 600
	var/hours = world.time / 36000
	.["round_duration"] = "[floor(hours)]h [floor(mins)]m"
	.["evacuating"] = SShijack && SShijack.evac_status == EVACUATION_STATUS_INITIATED

	var/list/jobs = list()
	for(var/i in GLOB.RoleAuthority.roles_for_mode)
		var/datum/job/J = GLOB.RoleAuthority.roles_for_mode[i]
		if(!GLOB.RoleAuthority.check_role_entry(owner, J, latejoin = TRUE, faction = faction))
			continue

		var/active = 0
		for(var/mob/M in GLOB.player_list)
			if(M.client && M.job == J.title)
				active++

		jobs += list(list(
			"title" = J.title,
			"disp_title" = J.disp_title,
			"department" = get_job_department(J.title),
			"current_positions" = J.current_positions,
			"active" = active,
		))

	.["jobs"] = jobs

/datum/late_join_setup/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!owner)
		return TRUE
	switch(action)
		if("select_job")
			owner.AttemptLateSpawn(params["title"])
			return TRUE
