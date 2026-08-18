//woof!
/datum/species/synthetic/synth_k9
	name = SPECIES_SYNTHETIC_K9

	slowdown = -1.75 //Faster than Human run, slower than rooney run

	icobase = 'icons/mob/humans/species/synth_k9/r_k9.dmi'
	deform = 'icons/mob/humans/species/synth_k9/r_k9.dmi'
	eyes = "blank_eyes_s"
	blood_mask = 'icons/mob/humans/species/synth_k9/r_k9.dmi'

	//r_k9.dmi only has a single-sprite body (K9_closed/K9_open/dead) - it was never built as a limb-segmented
	//sheet like a normal species needs (torso/head/arms/legs/hands/feet/groin, see r_synthetic.dmi for the
	//full set). body_sprite_icon/body_sprite_prefix make update_body() draw this one sprite instead of
	//trying (and failing) to composite per-limb art that doesn't exist.
	body_sprite_icon = 'icons/mob/humans/species/synth_k9/r_k9.dmi'
	body_sprite_prefix = "K9" //-> "K9_open"/"K9_closed", see get_body_sprite_state()
	unarmed_type = /datum/unarmed_attack/bite/synthetic
	secondary_unarmed_type = /datum/unarmed_attack
	death_message = "lets out a faint whimper as it collapses and stops moving..."
	flags = IS_WHITELISTED|NO_BREATHE|NO_CLONE_LOSS|NO_BLOOD|NO_POISON|IS_SYNTHETIC|NO_CHEM_METABOLIZATION|NO_NEURO|NO_OVERLAYS

	mob_inherent_traits = list(TRAIT_SUPER_STRONG, TRAIT_IRON_TEETH, TRAIT_EMOTE_CD_EXEMPT)

	fire_sprite_prefix = "k9"
	fire_sprite_sheet = 'icons/mob/humans/onmob/OnFire.dmi'

	//Only items flagged k9_exclusive_wear can go in a visible clothing slot - see the check in
	///obj/item/proc/mob_can_equip() in code/game/objects/items.dm. Keeps a K9 out of normal human clothing.
	restrict_to_k9_clothing = TRUE

	inherent_verbs = list(
		/mob/living/carbon/human/synthetic/proc/toggle_HUD,
		/mob/living/carbon/human/proc/toggle_inherent_nightvison,
		/mob/living/carbon/human/synthetic/synth_k9/proc/toggle_scent_tracking,
		/mob/living/carbon/human/synthetic/synth_k9/proc/toggle_binocular_vision,
	)

	//Scent tracking
	var/datum/radar/scenttracker/radar
	var/faction = FACTION_MARINE

//Lets have a place for radar data to live
/datum/species/synthetic/synth_k9/handle_post_spawn(mob/living/carbon/human/spawned_k9)
	. = ..()
	radar = new /datum/radar/scenttracker(spawned_k9, faction)
	//Near-instant climbing - a K9 is far more nimble over obstacles than a human. COMSIG_LIVING_CLIMB_STRUCTURE
	//is a generic /mob/living signal (see code/game/objects/structures.dm do_climb()), no animal mob type needed.
	RegisterSignal(spawned_k9, COMSIG_LIVING_CLIMB_STRUCTURE, PROC_REF(handle_climbing))

/datum/species/synthetic/synth_k9/post_species_loss(mob/living/carbon/human/H)
	UnregisterSignal(H, COMSIG_LIVING_CLIMB_STRUCTURE)
	. = ..()

/datum/species/synthetic/synth_k9/proc/handle_climbing(mob/living/user, list/climbdata)
	SIGNAL_HANDLER
	climbdata["climb_delay"] *= 0.1

/datum/species/synthetic/synth_k9/Destroy()
	. = ..()
	qdel(radar)
	faction = null
