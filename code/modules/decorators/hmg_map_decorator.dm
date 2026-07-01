/datum/decorator/hmg_map_decorator
	var/list/camouflage_type

	var/icon/c_icon

/datum/decorator/hmg_map_decorator/is_active_decor()
	return SSmapping.configs[GROUND_MAP].camouflage_type == camouflage_type

/datum/decorator/hmg_map_decorator/get_decor_types()
	return list(
		/obj/structure/machinery/m56d_hmg,
		/obj/structure/machinery/m56d_hmg/mg_turret,
		/obj/structure/machinery/m56d_hmg/mg_turret/dropship,
		/obj/structure/machinery/m56d_hmg/auto,
		/obj/structure/machinery/m56d_hmg/auto/t37,
		/obj/structure/machinery/m56d_post,
		/obj/item/device/m56d_gun,
		/obj/item/device/m56d_gun/mounted,
		/obj/item/device/m56d_post,
		/obj/item/device/m56d_post_frame,
	)

/datum/decorator/hmg_map_decorator/decorate(atom/object)
	if(!istype(object))
		return

	object.icon = c_icon

/datum/decorator/hmg_map_decorator/classic
	camouflage_type = "classic"
	c_icon = 'icons/obj/items/weapons/guns/guns_by_map/classic/hmg.dmi'

/datum/decorator/hmg_map_decorator/desert
	camouflage_type = "desert"
	c_icon = 'icons/obj/items/weapons/guns/guns_by_map/desert/hmg.dmi'

/datum/decorator/hmg_map_decorator/jungle
	camouflage_type = "jungle"
	c_icon = 'icons/obj/items/weapons/guns/guns_by_map/jungle/hmg.dmi'

/datum/decorator/hmg_map_decorator/snow
	camouflage_type = "snow"
	c_icon = 'icons/obj/items/weapons/guns/guns_by_map/snow/hmg.dmi'

/datum/decorator/hmg_map_decorator/urban
	camouflage_type = "urban"
	c_icon = 'icons/obj/items/weapons/guns/guns_by_map/urban/hmg.dmi'
