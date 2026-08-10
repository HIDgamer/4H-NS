/// Get displayed variable in VV variable list, as structured data for the tgui ViewVariables
/// interface — each row carries its edit/change/mass-edit/remove hrefs as plain data fields
/// (bare href strings via VV_HREF_TARGET_1V_INTERNAL(), NOT the VV_HREF_TARGET_1V() macro — that
/// one wraps its output in a full "<a href='...'>text</a>" tag meant for embedding in real HTML,
/// which is wrong here: storing that whole tag as a data field's value means the row's onClick
/// handler would send the literal string "<a href='...'>E</a>" as the href, and client.Topic()
/// can't parse that as a query string) rather than as clickable HTML, since a tgui window can't
/// resolve byond:// links the way a browse() popup window could. See view_variables_session.dm's
/// "click_href" ui_act for how these get fired.
/// If D is a list, name will be index, and value will be assoc value.
/proc/debug_variable(name, value, level, datum/D, sanitize = TRUE)
	var/list/row = list()
	if(D)
		if(islist(D))
			var/list/var_list = D
			var/index = name
			if(value)
				name = var_list[name] //name is really the index until this line
			else
				value = var_list[name]
			row["edit_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_LIST_EDIT, index)
			row["change_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_LIST_CHANGE, index)
			row["remove_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_LIST_REMOVE, index)
		else
			row["edit_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_BASIC_EDIT, name)
			row["change_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_BASIC_CHANGE, name)
			row["massedit_href"] = VV_HREF_TARGET_1V_INTERNAL(D, VV_HK_BASIC_MASSEDIT, name)

	row["name"] = "[name]"
	if(level > 0 || islist(D)) //handling keys in assoc lists
		if(istype(name, /datum))
			row["name_ref"] = REF(name)
			row["name_href"] = VV_HREF_NAV_INTERNAL(REF(name))
		else if(islist(name))
			var/list/L = name
			row["name_ref"] = REF(name)
			row["name_href"] = VV_HREF_NAV_INTERNAL(REF(name))
			row["name_list_length"] = length(L)

	if(isnull(value))
		row["class"] = "null"

	else if(istext(value))
		row["class"] = "text"
		row["value_text"] = value

	else if(isicon(value))
		row["class"] = "icon"
		row["value_text"] = "[value]"
		#ifdef VARSICON
		row["value_icon_b64"] = icon2base64(icon(value))
		#endif

	else if(isfile(value))
		row["class"] = "file"
		row["value_text"] = "[value]"

	else if(istype(value, /matrix)) // Needs to be before datum
		var/matrix/M = value
		row["class"] = "matrix"
		row["matrix"] = list(M.a, M.d, M.b, M.e, M.c, M.f) //TODO link to modify_transform wrapper for all matrices

	else if(isdatum(value))
		var/datum/DV = value
		row["class"] = "datum"
		row["value_ref"] = REF(value)
		row["value_href"] = VV_HREF_NAV_INTERNAL(REF(value))
		row["value_type"] = "[DV.type]"
		row["value_text"] = ("[DV]" != "[DV.type]") ? "[DV]" : null //if the thing has a name var, lets use it.
		if(istype(value, /datum/weakref))
			var/datum/weakref/weakref = value
			row["weakref_target_ref"] = weakref.reference
			row["weakref_target_href"] = VV_HREF_NAV_INTERNAL(weakref.reference)

	else if(islist(value))
		var/list/L = value
		row["class"] = "list"
		row["value_ref"] = REF(value)
		row["value_href"] = VV_HREF_NAV_INTERNAL(REF(value))
		row["list_length"] = length(L)

		if(length(L) > 0 && !(name == "underlays" || name == "overlays" || length(L) > (IS_NORMAL_LIST(L) ? VV_NORMAL_LIST_NO_EXPAND_THRESHOLD : VV_SPECIAL_LIST_NO_EXPAND_THRESHOLD)))
			var/list/children = list()
			for(var/i in 1 to length(L))
				var/key = L[i]
				var/val
				if(IS_NORMAL_LIST(L) && !isnum(key))
					val = L[key]
				if(isnull(val)) // we still want to display non-null false values, such as 0 or ""
					val = key
					key = i

				children += list(debug_variable(key, val, level + 1, sanitize = sanitize))
			row["children"] = children

	else if(name in GLOB.bitfields)
		var/list/flags = list()
		for(var/i in GLOB.bitfields[name])
			if(value & GLOB.bitfields[name][i])
				flags += i
		row["class"] = "bitfield"
		row["value_text"] = jointext(flags, ", ")

	else
		row["class"] = "value"
		row["value_text"] = "[value]"

	return row
