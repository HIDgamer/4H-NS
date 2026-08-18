/**
 * Shared selection state for the RTS-style hive command console
 * (xeno_command_console.dm). One instance per commander - a Hive Leader's
 * own console, or an admin's console for a picked hive. All three selection
 * input methods (in-world shift-click, roster panel checkboxes, marquee
 * drag-box) write through this single datum, and the console's right-click
 * order issuance reads from it - there is exactly one source of truth for
 * "who is currently selected," regardless of how they got selected.
 */
/datum/xeno_command_selection
	/// Selected AI-piloted xenos. Purged of dead/QDELETED/wrong-hive/no-longer-AI entries on every read - never trust this list raw, always go through get_selected().
	var/list/mob/living/carbon/xenomorph/selected = list()

/**
 * The only proc anything outside this datum should ever read `selected`
 * through - defensively drops anything that stopped being a valid
 * selectable unit since it was added (died, was evolved into a fresh mob
 * instance, lost AI control to a ghost claiming it, changed hive), the same
 * tolerant-of-staleness discipline this codebase already applies to
 * fort_gates/committed_cover_turf rather than needing every death/detach
 * path to remember to clean this list too.
 */
/datum/xeno_command_selection/proc/get_selected(hivenumber)
	for(var/mob/living/carbon/xenomorph/xeno as anything in selected)
		if(QDELETED(xeno) || xeno.stat == DEAD || !xeno.is_ai_controlled || !xeno.ai_controller || xeno.client)
			selected -= xeno
			continue
		if(hivenumber && xeno.hivenumber != hivenumber)
			selected -= xeno
	return selected.Copy()

/// Adds a single xeno to the selection if it's actually a valid selectable unit (same-hive AI-piloted, no client). Silently no-ops on an invalid candidate rather than erroring - mirrors how attempt_plant_weeds()/can_build_here() elsewhere in the xeno codebase treat a bad target as a no-op, not an exception.
/datum/xeno_command_selection/proc/select(mob/living/carbon/xenomorph/xeno, hivenumber)
	if(!istype(xeno) || QDELETED(xeno) || xeno.stat == DEAD || !xeno.is_ai_controlled || !xeno.ai_controller || xeno.client)
		return FALSE
	if(hivenumber && xeno.hivenumber != hivenumber)
		return FALSE
	selected |= xeno
	return TRUE

/// Adds every valid xeno in the list - used by the roster's "select all" and the marquee box's rectangle scan.
/datum/xeno_command_selection/proc/select_list(list/mob/living/carbon/xenomorph/xenos, hivenumber)
	for(var/mob/living/carbon/xenomorph/xeno as anything in xenos)
		select(xeno, hivenumber)

/datum/xeno_command_selection/proc/deselect(mob/living/carbon/xenomorph/xeno)
	selected -= xeno

/datum/xeno_command_selection/proc/toggle(mob/living/carbon/xenomorph/xeno, hivenumber)
	if(xeno in selected)
		deselect(xeno)
		return FALSE
	return select(xeno, hivenumber)

/datum/xeno_command_selection/proc/clear()
	selected = list()

/datum/xeno_command_selection/proc/is_selected(mob/living/carbon/xenomorph/xeno)
	return (xeno in selected)
