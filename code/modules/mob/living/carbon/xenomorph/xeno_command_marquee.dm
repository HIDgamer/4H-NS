/**
 * True click-and-drag marquee/box selection for the hive command console -
 * the one selection input method with no existing primitive to extend
 * (unlike shift-click, which reuses the normal click pipeline, or the roster
 * panel, which is just tgui buttons). Built on client/MouseDown/MouseDrag/
 * MouseUp's own COMSIG_MOB_MOUSEDOWN/MOUSEDRAG/MOUSEUP signals
 * (code/_onclick/click_hold.dm), which already resolve every event to a real
 * turf for free - only the box-tracking and selection-resolution logic here
 * is new.
 *
 * Visual feedback is a live turf-highlight (a temporary image on every turf
 * currently inside the dragged rectangle) rather than a pixel-precise
 * screen-space box overlay - simpler to get right without live-testing exact
 * screen_loc pixel math, and reads just as clearly as an actual selection
 * box for a tile-based view.
 */

/// Toggles marquee mode on/off - registers or unregisters the mouse-drag signals on the owner's mob. Only one drag is needed per selection (see on_marquee_mouseup()'s auto-exit), but the toggle itself stays a deliberate on/off so accidental drags don't fire while the commander is doing anything else with their mouse.
/datum/xeno_command_console/proc/toggle_marquee_mode(mob/user)
	if(!owner)
		return
	if(marquee_active)
		clear_marquee_signals()
		clear_marquee_highlight()
		to_chat(user, SPAN_NOTICE("Marquee select disabled."))
		return
	RegisterSignal(owner, COMSIG_MOB_MOUSEDOWN, PROC_REF(on_marquee_mousedown))
	RegisterSignal(owner, COMSIG_MOB_MOUSEDRAG, PROC_REF(on_marquee_mousedrag))
	RegisterSignal(owner, COMSIG_MOB_MOUSEUP, PROC_REF(on_marquee_mouseup))
	marquee_active = TRUE
	to_chat(user, SPAN_NOTICE("Marquee select enabled - click and drag across the map to box-select. Disabled automatically after one drag."))

/datum/xeno_command_console/proc/clear_marquee_signals()
	if(owner)
		UnregisterSignal(owner, list(COMSIG_MOB_MOUSEDOWN, COMSIG_MOB_MOUSEDRAG, COMSIG_MOB_MOUSEUP))
	marquee_start_turf = null
	marquee_active = FALSE

/datum/xeno_command_console/proc/clear_marquee_highlight()
	if(!marquee_highlighted_turfs)
		return
	for(var/turf/highlighted as anything in marquee_highlighted_turfs)
		highlighted.color = null
	marquee_highlighted_turfs = null

/datum/xeno_command_console/proc/on_marquee_mousedown(mob/source, atom/A, turf/T, skin_ctl, params)
	SIGNAL_HANDLER
	if(!T)
		return
	marquee_start_turf = T

/datum/xeno_command_console/proc/on_marquee_mousedrag(mob/source, atom/src_obj, atom/over_obj, turf/src_loc, turf/over_loc, src_ctl, over_ctl, params)
	SIGNAL_HANDLER
	if(!marquee_start_turf || !over_loc || marquee_start_turf.z != over_loc.z)
		return
	clear_marquee_highlight()
	marquee_highlighted_turfs = list()
	for(var/turf/candidate in block(marquee_start_turf, over_loc))
		candidate.color = "#66ff6640"
		marquee_highlighted_turfs += candidate

/**
 * Resolves the drag into a selection and auto-exits marquee mode - drag,
 * select, and the very next right-click issuing an order reads as one fluid
 * gesture instead of needing to manually toggle the mode off again first.
 * A zero-area drag (start turf == end turf, i.e. a plain click while
 * marquee mode happened to be on) still resolves fine - block() with equal
 * corners is just that one turf, not an error.
 */
/datum/xeno_command_console/proc/on_marquee_mouseup(mob/source, atom/A, turf/T, skin_ctl, params)
	SIGNAL_HANDLER
	clear_marquee_highlight()
	if(!marquee_start_turf || !T || marquee_start_turf.z != T.z)
		clear_marquee_signals()
		return

	var/list/found = list()
	for(var/turf/candidate in block(marquee_start_turf, T))
		for(var/mob/living/carbon/xenomorph/xeno in candidate)
			found += xeno
	selection.select_list(found, hive?.hivenumber)
	sync_click_intercept()
	if(source.client)
		to_chat(source, SPAN_NOTICE("Selected [length(selection.selected)] xeno\s."))

	clear_marquee_signals()
