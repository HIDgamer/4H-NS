// ---- TGUI Admin Spawner ----

/datum/admin_spawner
	var/datum/admins/admin_holder

/datum/admin_spawner/New(datum/admins/holder)
	. = ..()
	admin_holder = holder

/datum/admin_spawner/Destroy(force, ...)
	admin_holder = null
	SStgui.close_uis(src)
	return ..()

/datum/admin_spawner/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "AdminSpawner", "Admin Spawner")
		ui.open()

/datum/admin_spawner/ui_state(mob/user)
	return GLOB.admin_state

/datum/admin_spawner/ui_static_data(mob/user)
	. = list()
	.["types"] = typesof(/mob)
	.["ui_effects_enabled"] = admin_ui_effects_enabled(user)

/datum/admin_spawner/ui_assets(mob/user)
	. = ..()
	. += get_asset_datum(/datum/asset/simple/admin_ui_sounds)

/datum/admin_spawner/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if (.)
		return
	if (action == "spawn")
		if (!check_client_rights(ui.user.client, R_MOD))
			return
		var/mob_type = text2path(params["type"])
		if (!mob_type || !(mob_type == /mob || ispath(mob_type, /mob)))
			return
		var/turf/target_turf = get_turf(ui.user)
		if (params["offset_type"] == "absolute")
			target_turf = locate(params["offset_x"], params["offset_y"], params["offset_z"])
		else
			target_turf = locate(
				target_turf.x + params["offset_x"],
				target_turf.y + params["offset_y"],
				target_turf.z + params["offset_z"]
			)
		if (!target_turf)
			return
		var/spawn_count = max(1, min(50, params["count"]))
		var/spawn_dir = params["dir"] || SOUTH
		var/spawn_name = params["name"]
		var/spawn_where = params["where"]
		for (var/i in 1 to spawn_count)
			var/mob/spawned = new mob_type(target_turf)
			if (spawn_name)
				spawned.name = spawn_name
			spawned.setDir(spawn_dir)
			if (spawn_where == "inmarked" && ui.user.client?.admin_holder?.marked_datum)
				var/obj/container = ui.user.client.admin_holder.marked_datum
				if (istype(container))
					spawned.forceMove(container)
		message_admins("[key_name_admin(ui.user)] spawned [spawn_count]x [params["type"]] at ([target_turf.x],[target_turf.y],[target_turf.z]).")
		log_admin("[key_name(ui.user)] spawned [spawn_count]x [params["type"]] at ([target_turf.x],[target_turf.y],[target_turf.z]).")
		return TRUE

/datum/admins/proc/create_mob(mob/user)
	if (!check_rights(R_MOD, 0))
		return
	var/datum/admin_spawner/spawner = new(src)
	spawner.tgui_interact(user || usr)
