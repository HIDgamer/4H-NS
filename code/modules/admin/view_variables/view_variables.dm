/client/proc/debug_variables(datum/D in world)
	set category = "Debug"
	set name = "View Variables"
	//set src in world

	if(!(usr.client) || !(usr.client.admin_holder) || !(usr.client.admin_holder.rights & R_MOD))
		to_chat(usr, SPAN_DANGER("You need to be an administrator to access this."), confidential = TRUE)
		return

	if(!D)
		return

	var/islist = islist(D)
	if(!islist && !istype(D))
		return

	var/refid = REF(D)
	LAZYINITLIST(vv_sessions)
	var/datum/view_variables_session/session = vv_sessions[refid]
	if(!session)
		session = new(D, src)
		vv_sessions[refid] = session
	session.tgui_interact(usr)

/// Compat shim for the old partial-DOM-patch mechanism (span/content, unused now — tgui just
/// recomputes ui_data() fresh). Kept so topic.dm/topic_basic.dm/modify_variables.dm/
/// mark_datum.dm/admin_delete.dm don't need to change any of their vv_update_display() calls.
/client/proc/vv_update_display(datum/D, span, content)
	var/datum/view_variables_session/session = vv_sessions?[REF(D)]
	if(session)
		SStgui.update_uis(session)
