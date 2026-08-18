/*
	Synthetic K9 - a Weyland-Yutani rescue synthetic, whitelisted the same way Working Joe is. This is a
	normal human species job (see /datum/species/synthetic/synth_k9 in
	code/modules/mob/living/carbon/human/species/synth_k9.dm) - it goes through the standard
	create_character()/equip_role() pipeline like every other job, just like Working Joe does.
*/
/datum/job/civilian/synth_k9
	title = JOB_SYNTH_K9
	total_positions = 1
	spawn_positions = 1
	allow_additional = TRUE
	scaled = TRUE
	supervisors = "your assigned squad"
	selection_class = "job_synth_k9"
	flags_startup_parameters = ROLE_ADD_TO_DEFAULT|ROLE_WHITELISTED|ROLE_CUSTOM_SPAWN
	flags_whitelist = WHITELIST_SYNTHETIC
	gear_preset = /datum/equipment_preset/synth_k9
	gets_emergency_kit = FALSE

/datum/job/civilian/synth_k9/generate_entry_message(mob/living/carbon/human/H)
	. = "You are a Weyland-Yutani K9 Rescue Unit. You are held to a higher standard and are required to obey not only the Server Rules but Marine Law and Synthetic Rules. Failure to do so may result in your White-list Removal. Your primary job is to assist your assigned squad with search, rescue and support duties in the field."

/obj/effect/landmark/start/synth_k9
	name = JOB_SYNTH_K9
	icon_state = "syn_spawn"
	job = /datum/job/civilian/synth_k9
