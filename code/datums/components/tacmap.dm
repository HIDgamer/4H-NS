/**
	Tacmap component

	Adds a tacmap with defined z level and flags to an object and allows it to open and close it
 */
/datum/component/tacmap
	var/minimap_flag = MINIMAP_FLAG_USCM
	///by default Zlevel 2, groundside is targetted
	var/targetted_zlevel = 2
	///minimap obj ref that we will display to users
	var/atom/movable/screen/minimap/map
	///List of currently interacting mobs
	var/list/mob/interactees = list()
	///Map holder
	var/datum/tacmap_holder/map_holder


/datum/component/tacmap/Initialize(has_drawing_tools, minimap_flag, has_update, drawing)
	if(!isatom(parent))
		return COMPONENT_INCOMPATIBLE
	src.minimap_flag = minimap_flag

/datum/component/tacmap/proc/popout()
	tgui_interact(usr)

/datum/component/tacmap/proc/on_unset_interaction(mob/user)
	interactees -= user

	if(!user.client)
		return

	user.client.remove_from_screen(map)
	user.client.mouse_pointer_icon = null

/datum/component/tacmap/proc/show_tacmap(mob/user)
	if(!map)
		map = SSminimaps.fetch_minimap_object(targetted_zlevel, minimap_flag)
		map_holder = new(null, targetted_zlevel, minimap_flag)

	user.client.add_to_screen(map)
	interactees += user


/datum/component/tacmap/ui_status(mob/user, datum/ui_state/state)
	if(get_dist(parent, user) > 1)
		ui_close(user)
		return UI_CLOSE

	return UI_INTERACTIVE

/datum/component/tacmap/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		user.client.register_map_obj(map_holder.map)
		ui = new(user, src, "TacticalMap")
		ui.open()

/datum/component/tacmap/ui_data(mob/user)
	. = ..()

	.["mapRef"] = map_holder?.map_ref

/datum/component/tacmap/ui_close(mob/user)
	. = ..()

	if(!user.client)
		return

	user.client.remove_from_screen(map_holder.map)
