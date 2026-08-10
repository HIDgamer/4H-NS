// Both entry points open the same tgui interface (code/modules/admin/create_object_tgui.dm) —
// "Quick Create Object" used to pre-prompt a category via a separate tgui_input_list popup
// before showing the same HTML form scoped to that subtree; the category filter is now just an
// in-window control there instead of a second dialog, so there's nothing left to differentiate
// the two entry points on other than the label admin.dm's Game Panel links already show.
/datum/admins/proc/create_object(mob/user)
	var/datum/admin_create_object/spawner = new(src)
	spawner.tgui_interact(user || usr)

/datum/admins/proc/quick_create_object(mob/user)
	var/datum/admin_create_object/spawner = new(src)
	spawner.tgui_interact(user || usr)
