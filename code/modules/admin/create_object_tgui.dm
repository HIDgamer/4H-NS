// ---- TGUI Create Object (replaces the legacy show_browser() popup in create_object.dm) ----

/// Same rough grouping the old "Quick Create Object" pre-filter dialog offered
/// (create_object.dm's quick_paths), now exposed as an in-window category filter instead of a
/// separate tgui_input_list prompt before the popup even opens.
GLOBAL_LIST_INIT(admin_create_object_categories, list(
	"/obj",
	"/obj/effect",
	"/obj/item",
	"/obj/item/ammo_box",
	"/obj/item/ammo_magazine",
	"/obj/item/clothing",
	"/obj/item/device",
	"/obj/item/hardpoint",
	"/obj/item/reagent_container",
	"/obj/item/stack",
	"/obj/item/storage",
	"/obj/item/explosive",
	"/obj/item/weapon",
	"/obj/item/weapon/gun",
	"/obj/structure",
	"/obj/structure/machinery",
	"/obj/vehicle",
))

/datum/admin_create_object
	var/datum/admins/admin_holder

/datum/admin_create_object/New(datum/admins/holder)
	. = ..()
	admin_holder = holder

/datum/admin_create_object/Destroy(force, ...)
	admin_holder = null
	SStgui.close_uis(src)
	return ..()

/datum/admin_create_object/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AdminCreateObject", "Create Object")
		ui.open()

/datum/admin_create_object/ui_state(mob/user)
	return GLOB.admin_state

/datum/admin_create_object/ui_static_data(mob/user)
	. = list()
	.["types"] = typesof(/obj)
	.["categories"] = GLOB.admin_create_object_categories
	.["ui_effects_enabled"] = admin_ui_effects_enabled(user)

/datum/admin_create_object/ui_assets(mob/user)
	. = ..()
	. += get_asset_datum(/datum/asset/simple/admin_ui_sounds)

/datum/admin_create_object/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(!admin_holder || !check_client_rights(ui.user.client, R_SPAWN))
		return TRUE
	if(action == "spawn")
		// Reuses the exact same validated dispatch the legacy create_object.html popup drove
		// (see spawn_from_object_list() in code/modules/admin/topic/topic.dm) by building an
		// equivalent href_list instead of duplicating its offset/direction/target-resolution
		// logic here.
		var/list/href_list = list(
			"object_list" = params["types"],
			"offset" = "[params["offset_x"]],[params["offset_y"]],[params["offset_z"]]",
			"offset_type" = params["offset_type"],
			"object_count" = "[params["count"]]",
			"object_dir" = "[params["dir"]]",
			"object_name" = params["name"],
			"object_where" = params["where"],
		)
		admin_holder.spawn_from_object_list(href_list)
		return TRUE
