GLOBAL_LIST_INIT_TYPED(undershirt_m, /datum/sprite_accessory/undershirt, setup_undershirt(MALE))
GLOBAL_LIST_INIT_TYPED(undershirt_f, /datum/sprite_accessory/undershirt, setup_undershirt(FEMALE))

/proc/setup_undershirt(restricted_gender)
	var/list/undershirt_list = list()
	for(var/undershirt_type in subtypesof(/datum/sprite_accessory/undershirt))
		var/datum/sprite_accessory/undershirt/undershirt_datum = new undershirt_type
		if(restricted_gender && undershirt_datum.gender != restricted_gender && (undershirt_datum.gender == MALE || undershirt_datum.gender == FEMALE))
			continue
		if(undershirt_datum.camo_conforming)
			undershirt_list["[undershirt_datum.name] (Camo Conforming)"] = undershirt_datum
			var/datum/sprite_accessory/undershirt/classic_datum = new undershirt_type
			classic_datum.generate_non_conforming("classic")
			undershirt_list[classic_datum.name] = classic_datum
			var/datum/sprite_accessory/undershirt/jungle_datum = new undershirt_type
			jungle_datum.generate_non_conforming("jungle")
			undershirt_list[jungle_datum.name] = jungle_datum
			var/datum/sprite_accessory/undershirt/desert_datum = new undershirt_type
			desert_datum.generate_non_conforming("desert")
			undershirt_list[desert_datum.name] = desert_datum
			var/datum/sprite_accessory/undershirt/snow_datum = new undershirt_type
			snow_datum.generate_non_conforming("snow")
			undershirt_list[snow_datum.name] = snow_datum
			var/datum/sprite_accessory/undershirt/urban_datum = new undershirt_type
			urban_datum.generate_non_conforming("urban")
			undershirt_list[urban_datum.name] = urban_datum
			var/datum/sprite_accessory/undershirt/black_datum = new undershirt_type
			black_datum.generate_non_conforming("black")
			undershirt_list[black_datum.name] = black_datum
		else
			undershirt_list[undershirt_datum.name] = undershirt_datum
	return undershirt_list

/datum/sprite_accessory/undershirt
	icon = 'icons/mob/humans/undershirt.dmi'
	var/camo_conforming = FALSE

/datum/sprite_accessory/undershirt/proc/get_image(mob_gender)
	var/selected_icon_state = icon_state
	if(camo_conforming)
		switch(SSmapping.configs[GROUND_MAP].camouflage_type)
			if("classic")
				selected_icon_state = "c_" + selected_icon_state
			if("jungle")
				selected_icon_state = "j_" + selected_icon_state
			if("desert")
				selected_icon_state = "d_" + selected_icon_state
			if("snow")
				selected_icon_state = "s_" + selected_icon_state
			if("urban")
				selected_icon_state = "u_" + selected_icon_state
			if("black")
				selected_icon_state = "b_" + selected_icon_state

	if(gender == PLURAL)
		selected_icon_state += mob_gender == MALE ? "_m" : "_f"
	return image(icon, selected_icon_state)

/datum/sprite_accessory/undershirt/proc/generate_non_conforming(camo_key)
	camo_conforming = FALSE
	var/camo_prefix
	switch(camo_key)
		if("classic")
			camo_prefix = "c_"
			name += " (Classic)"
		if("jungle")
			camo_prefix = "j_"
			name += " (Jungle)"
		if("desert")
			camo_prefix = "d_"
			name += " (Desert)"
		if("snow")
			camo_prefix = "s_"
			name += " (Snow)"
		if("urban")
			camo_prefix = "u_"
			name += " (Urban)"
		if("black")
			camo_prefix = "b_"
			name += " (Black)"
	icon_state = "[camo_prefix][icon_state]"

// Plural - Non-Camo-Conforming (classic) variants
/datum/sprite_accessory/undershirt/t_undershirt
	name = "Undershirt"
	icon_state = "t_undershirt"
	gender = NEUTER

/datum/sprite_accessory/undershirt/t_undershirt_sleeveless
	name = "Undershirt Sleeveless"
	icon_state = "t_undershirt_sleeveless"
	gender = NEUTER

/datum/sprite_accessory/undershirt/t_rolled_undershirt
	name = "Undershirt Rolled"
	icon_state = "t_rolled_undershirt"
	gender = NEUTER

/datum/sprite_accessory/undershirt/t_rolled_undershirt_sleeveless
	name = "Undershirt Rolled Sleeveless"
	icon_state = "t_rolled_undershirt_sleeveless"
	gender = NEUTER

/datum/sprite_accessory/undershirt/t_long_undershirt
	name = "Undershirt Long"
	icon_state = "t_long_undershirt"
	gender = NEUTER

// Male
/datum/sprite_accessory/undershirt/none
	name = "None"
	icon_state = "none"
	gender = MALE

// Female
/datum/sprite_accessory/undershirt/bra
	name = "Bra"
	icon_state = "bra"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/undershirt/sports_c
	name = "Sports Bra Classic"
	icon_state = "sports_c"
	gender = FEMALE

/datum/sprite_accessory/undershirt/sports
	name = "Sports Bra"
	icon_state = "sports"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/undershirt/halter
	name = "Haltertop"
	icon_state = "halter"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/undershirt/strapless_c
	name = "Strapless Bra Classic"
	icon_state = "strapless_c"
	gender = FEMALE

/datum/sprite_accessory/undershirt/strapless
	name = "Strapless Bra"
	icon_state = "strapless"
	gender = FEMALE
	camo_conforming = TRUE
