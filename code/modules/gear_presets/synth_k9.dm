/datum/equipment_preset/synth_k9
	name = "K9 Synthetic"
	uses_special_name = TRUE
	languages = ALL_SYNTH_LANGUAGES
	skills = /datum/skills/synth_k9
	minimap_icon = "synth_k9"
	flags = EQUIPMENT_PRESET_START_OF_ROUND|EQUIPMENT_PRESET_MARINE
	faction = FACTION_MARINE
	idtype = /obj/item/card/id/gold/synth_k9
	assignment = JOB_SYNTH_K9
	rank = "Synthetic K9"
	paygrades = list(PAY_SHORT_SYN_K9 = JOB_PLAYTIME_TIER_0)
	role_comm_title = "K9"

/datum/equipment_preset/synth_k9/New()
	. = ..()
	access = get_access(ACCESS_LIST_GLOBAL)

/datum/equipment_preset/synth_k9/load_race(mob/living/carbon/human/new_human)
	. = ..()
	new_human.h_style = "Bald"
	new_human.f_style = "Shaved"
	new_human.set_species(SYNTH_K9)

/datum/equipment_preset/synth_k9/load_name(mob/living/carbon/human/new_human, randomise)
	var/final_name = "Rex"
	if(new_human.client?.prefs?.k9_name)
		final_name = new_human.client.prefs.k9_name
		if(!final_name || final_name == "Undefined")
			final_name = "Rex"
	new_human.change_real_name(new_human, final_name)

/datum/equipment_preset/synth_k9/load_gear(mob/living/carbon/human/new_human)
	. = ..()
	// The K9's "serial identification collar" (marine_uniform.dm) is typed as
	// a /obj/item/clothing/under (uniform slot) so its worn-collar sprite
	// renders correctly, but nothing ever actually equipped it - it was only
	// ever referenced by its own definition and by the k9_synth backpacks'
	// uniform_restricted requirement (backpack.dm), which could therefore
	// never be satisfied. flags_item = NODROP already keeps it on for good.
	new_human.equip_to_slot_or_del(new /obj/item/clothing/under/rank/synthetic/synth_k9(new_human), WEAR_BODY)
	new_human.equip_to_slot_or_del(new /obj/item/storage/backpack/marine/k9_synth/cargopack(new_human), WEAR_BACK)
	new_human.equip_to_slot_or_del(new /obj/item/device/radio/headset/almayer/mcom/synth/k9(new_human), WEAR_L_EAR)

/datum/equipment_preset/synth_k9/load_skills(mob/living/carbon/human/new_human)
	. = ..()
	new_human.allow_gun_usage = FALSE
