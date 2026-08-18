/**
 * "Capturing of humans, dragged to the hive and captured to a wall as a cap
 * for the hive which should increase the hive's total numbers by 1 for as
 * long as that cap lives." Subclasses the existing Predator-nest structure
 * pair (pred_nest.dm) wholesale rather than writing new capture/buckle logic
 * - /obj/effect/alien/resin/special/nest already spawns a companion
 * /obj/structure/bed/nest/structure at the same tile to do the actual
 * buckling (buckle_mob()/do_buckle()/TRAIT_NESTED/COMSIG_MOB_NESTED,
 * xeno_nest.dm), and already handles every release path (welder/sharp-item
 * cutting, structure destruction, victim death) - none of that needed to be
 * reinvented, just retargeted at humans instead of Predators.
 *
 * Built by Drone/Hivelord (attempt_build_human_cap(), xeno_ai_controller.dm)
 * as an occasional idle build action, then filled by whichever AI xeno drags
 * a downed human home (attempt_cap_drag_victim(), same file) - a downed
 * marine isolated by a Runner/Burrower now ends in a real capture instead of
 * just being released once towed far enough.
 */
/obj/effect/alien/resin/special/nest/human_cap
	name = "hive wall cap"
	desc = "A captive pinned to the hive wall, their strength feeding the hive for as long as they live."
	icon_state = "reinforced_nest"
	health = 200

/obj/effect/alien/resin/special/nest/human_cap/get_examine_text(mob/user)
	. = ..()
	if((isxeno(user) || isobserver(user)) && linked_hive)
		. += "A captive pinned here bolsters the hive's numbers for as long as they live."

/**
 * Registers into hive.human_cap_structures (hive_status.dm) so
 * attempt_cap_drag_victim() can find an existing empty cap to deliver a
 * victim to, and count_active_human_caps() can tell whether one currently
 * holds a live captive - see that proc's doc comment for why the population
 * bonus is read live off this list rather than a separately maintained
 * counter (avoids drift against every existing release path, several of
 * which have nothing to do with AI code at all - a marine cutting a
 * captive free, a welder burn, the structure itself being destroyed).
 */
/obj/effect/alien/resin/special/nest/human_cap/Initialize(mapload, datum/hive_status/hive_ref)
	. = ..()
	if(hive_ref)
		hive_ref.human_cap_structures += src

/obj/effect/alien/resin/special/nest/human_cap/Destroy()
	if(linked_hive)
		linked_hive.human_cap_structures -= src
	return ..()
