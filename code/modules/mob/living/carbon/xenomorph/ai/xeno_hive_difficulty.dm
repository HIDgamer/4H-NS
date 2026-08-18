/**
 * Global mutators for the hive-wide AI difficulty/spawner knobs - split out
 * of what used to be event_tab.dm's standalone /datum/admin_ai_difficulty
 * panel's ui_act() bodies (now merged into xeno_command_console.dm as an
 * admin-only section of the single Hive Command Console) so the exact same
 * logic is callable directly from code, not just through tgui. Every proc
 * here does the actual GLOB/subsystem mutation only - the caller (tgui
 * ui_act() or otherwise) is responsible for its own permission check and
 * any message_admins()/to_chat() feedback.
 */
/proc/xeno_hive_set_spawner_enabled(enabled)
	GLOB.xeno_spawner_enabled = !!enabled

/proc/xeno_hive_set_spawner_hive(hivenumber)
	GLOB.xeno_spawner_hive = hivenumber

/proc/xeno_hive_force_phase(new_phase)
	SSxeno_spawner.force_hive_phase(new_phase)

/// Difficulty is purely the Spawner's population/spawn-rate knob (spawner_target_population()/spawner_maintain_population()'s max_per_fire scaling, xeno_spawner.dm); AI Behavior's own presets/sliders (below) are the sole, independent control for aggression/awareness.
/proc/xeno_hive_set_difficulty_multiplier(new_value)
	GLOB.ai_difficulty_multiplier = clamp(new_value, 0.25, 4)

/// Also immediately refreshes every active AI controller's debug path markers (xeno_ai_movement.dm's update_debug_path_visual()) rather than waiting for each one's next heartbeat - turning the toggle on shows every currently-active route right away, turning it off clears them all right away, instead of a staggered fade-in/out as controllers happen to tick.
/proc/xeno_hive_set_debug_pathing(enabled)
	GLOB.ai_debug_pathing = !!enabled
	for(var/mob/living/carbon/xenomorph/xeno as anything in GLOB.ai_xeno_list)
		xeno.ai_controller?.update_debug_path_visual()

/proc/xeno_hive_set_caste_cap(caste, new_cap)
	if(!(caste in ALL_XENO_CASTES))
		return
	new_cap = clamp(new_cap, 0, 100)
	if(new_cap <= 0)
		GLOB.ai_xeno_max_per_caste -= caste
	else
		GLOB.ai_xeno_max_per_caste[caste] = new_cap

/proc/xeno_hive_set_flee_multiplier(new_value)
	GLOB.ai_flee_multiplier = clamp(new_value, 0.1, 3)

/proc/xeno_hive_set_distance_multiplier(new_value)
	GLOB.ai_distance_multiplier = clamp(new_value, 0.25, 3)

/// Returns TRUE if preset was recognized and applied, FALSE otherwise - lets a caller distinguish "did nothing" from "did something" without duplicating the switch.
/proc/xeno_hive_set_behavior_preset(preset)
	switch(preset)
		if("passive")
			GLOB.ai_flee_multiplier = 1.5
			GLOB.ai_distance_multiplier = 0.7
		if("balanced")
			GLOB.ai_flee_multiplier = 1
			GLOB.ai_distance_multiplier = 1
		if("aggressive")
			GLOB.ai_flee_multiplier = 0.6
			GLOB.ai_distance_multiplier = 1.3
		if("ruthless")
			GLOB.ai_flee_multiplier = 0.25
			GLOB.ai_distance_multiplier = 1.5
		else
			return FALSE
	return TRUE
