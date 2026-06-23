GLOBAL_LIST_INIT_TYPED(underwear_m, /datum/sprite_accessory/underwear, setup_underwear(MALE))
GLOBAL_LIST_INIT_TYPED(underwear_f, /datum/sprite_accessory/underwear, setup_underwear(FEMALE))

/proc/setup_underwear(restricted_gender)
	var/list/underwear_list = list()
	for(var/underwear_type in subtypesof(/datum/sprite_accessory/underwear))
		var/datum/sprite_accessory/underwear/underwear_datum = new underwear_type
		if(restricted_gender && underwear_datum.gender != restricted_gender && (underwear_datum.gender == MALE || underwear_datum.gender == FEMALE))
			continue
		if(underwear_datum.camo_conforming)
			underwear_list["[underwear_datum.name] (Camo Conforming)"] = underwear_datum
			var/datum/sprite_accessory/underwear/classic_datum = new underwear_type
			classic_datum.generate_non_conforming("classic")
			underwear_list[classic_datum.name] = classic_datum
			var/datum/sprite_accessory/underwear/jungle_datum = new underwear_type
			jungle_datum.generate_non_conforming("jungle")
			underwear_list[jungle_datum.name] = jungle_datum
			var/datum/sprite_accessory/underwear/desert_datum = new underwear_type
			desert_datum.generate_non_conforming("desert")
			underwear_list[desert_datum.name] = desert_datum
			var/datum/sprite_accessory/underwear/snow_datum = new underwear_type
			snow_datum.generate_non_conforming("snow")
			underwear_list[snow_datum.name] = snow_datum
			var/datum/sprite_accessory/underwear/urban_datum = new underwear_type
			urban_datum.generate_non_conforming("urban")
			underwear_list[urban_datum.name] = urban_datum
			var/datum/sprite_accessory/underwear/black_datum = new underwear_type
			black_datum.generate_non_conforming("black")
			underwear_list[black_datum.name] = black_datum
		else
			underwear_list[underwear_datum.name] = underwear_datum
	return underwear_list

/datum/sprite_accessory/underwear
	icon = 'icons/mob/humans/underwear.dmi'
	var/camo_conforming = FALSE

/datum/sprite_accessory/underwear/proc/get_image(mob_gender)
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

/datum/sprite_accessory/underwear/proc/generate_non_conforming(camo_key)
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

// Plural
/datum/sprite_accessory/underwear/lowriders
	name = "Lowriders"
	icon_state = "lowriders"
	gender = NEUTER
	camo_conforming = TRUE

/datum/sprite_accessory/underwear/briefs
	name = "Briefs"
	icon_state = "briefs"
	gender = NEUTER
	camo_conforming = TRUE

// Male
/datum/sprite_accessory/underwear/boxers_m
	name = "Boxers"
	icon_state = "boxers_m"
	gender = MALE
	camo_conforming = TRUE

/datum/sprite_accessory/underwear/briefs_c
	name = "Briefs Classic"
	icon_state = "briefs_c"
	gender = MALE

/datum/sprite_accessory/underwear/boxers_f
	name = "Boxers"
	icon_state = "boxers_f"
	gender = FEMALE
	camo_conforming = TRUE

// Female
/datum/sprite_accessory/underwear/panties
	name = "Panties"
	icon_state = "panties"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/underwear/thong
	name = "Thong"
	icon_state = "thong"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/underwear/tanga
	name = "Tanga"
	icon_state = "tanga"
	gender = FEMALE
	camo_conforming = TRUE

/datum/sprite_accessory/underwear/satin
	name = "Satin"
	icon_state = "satin"
	gender = FEMALE
	camo_conforming = TRUE
