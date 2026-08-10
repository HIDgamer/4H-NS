/// Cache of open VV sessions for this client, keyed by REF(target), so re-opening the same
/// target (including vv_do_topic()'s internal "datumrefresh" self-call) updates the existing
/// window instead of spawning a new one.
/client/var/list/vv_sessions

/**
 * # View Variables Session
 *
 * One instance per (admin, target) VV window. `/client` can't host tgui directly, so
 * `/client/proc/debug_variables()` creates/reuses one of these and opens tgui on it instead
 * of building a browse() HTML page. Sessions are cached per-client so that vv_do_topic()'s
 * internal "datumrefresh" self-call (fired after almost every edit) updates the same window
 * instead of spawning a new one each time.
 */
/datum/view_variables_session
	/// The datum or raw /list being inspected. Deliberately untyped — VV can target lists too,
	/// which aren't /datum subtypes, so a typed var would reject them.
	var/target
	var/client/owner

/datum/view_variables_session/New(target, client/owner)
	. = ..()
	src.target = target
	src.owner = owner

/datum/view_variables_session/Destroy()
	if(owner?.vv_sessions?[REF(target)] == src)
		owner.vv_sessions -= REF(target)
	target = null
	owner = null
	return ..()

/datum/view_variables_session/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ViewVariables", "View Variables")
		ui.open()

// A bare /datum has no loc — the default tgui state (GLOB.default_state) does a physical distance
// check between the user and src_object via shared_living_ui_distance(), which can never resolve
// a turf for a location-less session datum. Without this override the UI was closing itself right
// after ui.open() fired (server logs showed "new ViewVariables" every time — the window really did
// open — but tgui immediately closed it again before anything rendered client-side, which is
// indistinguishable from "never opened" to the player). Same fix pattern as admin_help/clan_menu/
// the bracer's internal sub-consoles: admin-rights-only tools with no real physical target don't
// belong on a proximity-based state at all.
/datum/view_variables_session/ui_state(mob/user)
	return GLOB.always_state

/datum/view_variables_session/ui_status(mob/user, datum/ui_state/state)
	if(!user.client?.admin_holder || !(user.client.admin_holder.rights & R_MOD))
		return UI_CLOSE
	return ..()

/datum/view_variables_session/ui_data(mob/user)
	var/list/data = list()
	var/islist = islist(target)
	var/refid = REF(target)

	data["ref"] = refid
	data["is_list"] = islist
	data["type"] = islist ? "/list" : "[target:type]"
	// Just the name here — ref and type are already shown in the body (ref_short/type fields), where
	// there's room. The old "[target] ([refid]) = [target:type]" was long enough to truncate mid-word
	// in the OS window titlebar for anything with a non-trivial type path.
	data["title"] = islist ? "/list" : "[target]"
	data["ref_short"] = "@[copytext(refid, 2, -1)]" // strip brackets, @-prefix for copy-pasting into asay

	if(islist)
		var/list/L = target
		data["dropdown"] = list(
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_LIST_ADD), "label" = "Add Item"),
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_LIST_ERASE_NULLS), "label" = "Remove Nulls"),
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_LIST_ERASE_DUPES), "label" = "Remove Dupes"),
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_LIST_SET_LENGTH), "label" = "Set len"),
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_LIST_SHUFFLE), "label" = "Shuffle"),
			list("href" = VV_HREF_TARGETREF_INTERNAL(refid, VV_HK_EXPOSE), "label" = "Show VV To Player"),
		)
		var/list/rows = list()
		for(var/i in 1 to length(L))
			var/key = L[i]
			var/value
			if(IS_NORMAL_LIST(L) && IS_VALID_ASSOC_KEY(key))
				value = L[key]
			rows += list(debug_variable(i, value, 0, L))
		data["rows"] = rows
	else
		var/datum/D = target
		var/datum/admins/AH = owner?.admin_holder
		data["marked"] = AH && AH.marked_datum == D
		data["tag_index"] = AH ? LAZYFIND(AH.tagged_datums, D) : 0
		data["var_edited"] = !!(D.datum_flags & DF_VAR_EDITED)
		data["deleted"] = !!D.gc_destroyed
		var/list/header_lines = D.vv_get_header()
		data["header_html"] = header_lines.Join()
		data["dropdown"] = D.vv_get_dropdown_data()

		if(istype(D, /atom))
			var/icon/sprite = getFlatIcon(D)
			if(sprite)
				data["sprite_b64"] = icon2base64(sprite)

		var/list/names = list()
		for(var/V in D.vars)
			names += V
		names = sort_list(names)

		var/list/rows = list()
		for(var/V in names)
			if(D.can_vv_get(V))
				rows += list(D.vv_get_var(V))
		data["rows"] = rows

	return data

/datum/view_variables_session/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!owner?.admin_holder || !(owner.admin_holder.rights & R_MOD))
		return TRUE
	if(action == "click_href")
		var/href = params["href"]
		if(!href)
			return TRUE
		if(copytext(href, 1, 9) == "byond://")
			href = copytext(href, 9)
		// Call the shared VV dispatch logic directly instead of replaying the href through
		// /client/Topic() — this is a same-session tgui click we've already gated on R_MOD above,
		// not a real hyperlink click, so there's nothing for Topic()'s own checks (usr/src identity,
		// CheckAdminHref's clickjacking guard) or its unrelated middleware (rate limiter, asset-cache
		// handling) to protect against here. See vv_do_href_list() in topic.dm.
		owner.vv_do_href_list(href, params2list(href))
		SStgui.update_uis(src)
		return TRUE
