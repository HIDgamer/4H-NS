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
	body_sprite_prefix = "K9" //-> "K9_open"/"K9_closed"/"K9_open_rest"/"K9_closed_rest", see get_body_sprite_state()
	//k9_dam_l/m/h (+ resting "r_"/dead "d_" variants) already existed in this sheet but were never drawn - see update_body_sprite_damage_overlay()
	body_sprite_damage_icon = 'icons/mob/humans/species/synth_k9/onmob/synth_k9_overlays.dmi'
	body_sprite_damage_prefix = "k9_dam"
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
	//Normal humans show "lying down" by rotating their standing sprite (see set_lying_angle()); K9 has a
	//dedicated K9_*_rest body art instead, so redraw on every stand/lie transition rather than rotate.
	RegisterSignal(spawned_k9, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(handle_body_position_change))
	give_action(spawned_k9, /datum/action/human_action/activable/k9_lunge)

/datum/species/synthetic/synth_k9/post_species_loss(mob/living/carbon/human/H)
	UnregisterSignal(H, list(COMSIG_LIVING_CLIMB_STRUCTURE, COMSIG_LIVING_SET_BODY_POSITION))
	remove_action(H, /datum/action/human_action/activable/k9_lunge)
	. = ..()

/datum/species/synthetic/synth_k9/proc/handle_climbing(mob/living/user, list/climbdata)
	SIGNAL_HANDLER
	climbdata["climb_delay"] *= 0.1

/datum/species/synthetic/synth_k9/proc/handle_body_position_change(mob/living/carbon/human/user, new_value, old_value)
	SIGNAL_HANDLER
	user.update_body()

/datum/species/synthetic/synth_k9/Destroy()
	. = ..()
	qdel(radar)
	faction = null

/*
	K9 Lunge - a toggle action: click the HUD button to arm/disarm (matching every other /activable ability,
	see action_activate() on the parent /datum/action/human_action/activable), then while armed, clicking a
	nearby floor tile with the player's configured ability mouse button (middle-click by default - see
	get_ability_mouse_key()) throws the K9 straight to it, the same way the Xenomorph Runner's Pounce covers
	ground. Reuses the same self-throw plumbing marines' hoverpack backpack uses (/atom/movable/proc/throw_atom())
	rather than xeno-only pounce code. Left as NORMAL_LAUNCH (no PASS_HIGH_OVER) on purpose - it's a fast dash
	across open floor, not a way to skip over obstacles; a blocked path just stops the throw early like a
	normal blocked move would.
*/
/datum/action/human_action/activable/k9_lunge
	name = "Lunge"
	action_icon_state = "pounce"
	///Furthest the K9 can lunge in one go, in tiles.
	var/max_distance = 3
	///Throw speed of the lunge - see /atom/movable/proc/throw_atom().
	var/lunge_speed = 3
	///How long after a lunge before the next one is allowed.
	var/lunge_cooldown = 3 SECONDS
	///world.time this comes off cooldown. Tracked separately from the base /datum/action/cooldown var,
	///since that one's enter_cooldown() fires from action_activate() (arming/disarming the toggle) rather
	///than from an actual lunge - see use_ability().
	var/next_lunge = 0

/datum/action/human_action/activable/k9_lunge/can_use_action()
	var/mob/living/carbon/human/H = owner
	if(!isk9synth(H))
		return FALSE
	if(H.is_mob_incapacitated() || H.buckled || H.body_position != STANDING_UP)
		return FALSE
	return TRUE

/datum/action/human_action/activable/k9_lunge/update_button_icon()
	if(!button)
		return
	button.color = (next_lunge <= world.time) ? rgb(255,255,255,255) : rgb(120,120,120,200)

/datum/action/human_action/activable/k9_lunge/use_ability(atom/A)
	if(!can_use_action())
		return
	var/mob/living/carbon/human/H = owner
	if(next_lunge > world.time)
		to_chat(H, SPAN_WARNING("We need a moment before we can lunge again!"))
		return

	var/turf/target_turf = get_turf(A)
	if(!target_turf || target_turf == get_turf(H))
		return

	next_lunge = world.time + lunge_cooldown
	update_button_icon()
	addtimer(CALLBACK(src, PROC_REF(update_button_icon)), lunge_cooldown)

	H.visible_message(SPAN_NOTICE("[H] lunges forward!"), SPAN_NOTICE("We lunge forward!"))
	H.throw_atom(target_turf, max_distance, lunge_speed)
