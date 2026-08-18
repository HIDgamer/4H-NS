/*
	Gear built specifically for the K9 chassis. Ground/inventory sprites reuse the existing human item art
	(scarves.dmi/berets.dmi/goggles.dmi) instead of new placeholder art; only the on-mob worn look uses the
	K9-specific overlay sheet (icons/mob/humans/species/synth_k9/onmob/synth_k9_overlays.dmi), since that's
	art drawn to fit the K9 body and doesn't exist for humans.

	Every item here is flagged k9_exclusive_wear = TRUE (see the restrict_to_k9_clothing check in
	/obj/item/proc/mob_can_equip() in code/game/objects/items.dm) - no ordinary human can wear these, and
	the K9 species can't wear ordinary human clothing in return.

	item_state_slots forces the on-mob sprite name to the K9-specific state regardless of slot (see
	/obj/item/proc/get_icon_state() in items.dm - by default several slots just fall back to icon_state,
	which here is the human item's ground-sprite name, not the K9 one). Squad color naming
	(alpha/bravo/charlie/delta = red/yellow/purple/blue) matches the existing scarf/beret art.
*/
#define K9_OVERLAY_ICON 'icons/mob/humans/species/synth_k9/onmob/synth_k9_overlays.dmi'
#define K9_SCARF_ICON 'icons/obj/items/clothing/masks/scarves.dmi'
#define K9_BERET_ICON 'icons/obj/items/clothing/hats/berets.dmi'
#define K9_GOGGLES_ICON 'icons/obj/items/clothing/glasses/goggles.dmi'

/obj/item/clothing/mask/k9_bandana
	name = "K9 bandana"
	desc = "A rugged bandana, sized to fit a K9 Rescue Unit."
	icon = K9_SCARF_ICON
	icon_state = "scarf_tan"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_FACE = "bandana_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_FACE

/obj/item/clothing/mask/k9_bandana/red
	name = "red K9 bandana"
	icon_state = "scarf_red"
	item_state_slots = list(WEAR_FACE = "bandana_k9_r")

/obj/item/clothing/mask/k9_bandana/yellow
	name = "yellow K9 bandana"
	icon_state = "scarf_bravo"
	item_state_slots = list(WEAR_FACE = "bandana_k9_y")

/obj/item/clothing/mask/k9_bandana/purple
	name = "purple K9 bandana"
	icon_state = "scarf_charlie"
	item_state_slots = list(WEAR_FACE = "bandana_k9_p")

/obj/item/clothing/mask/k9_bandana/blue
	name = "blue K9 bandana"
	icon_state = "scarf_delta"
	item_state_slots = list(WEAR_FACE = "bandana_k9_b")

/obj/item/clothing/mask/k9_bandana/green
	name = "green K9 bandana"
	icon_state = "scarf_green"
	item_state_slots = list(WEAR_FACE = "bandana_k9_g")

/obj/item/clothing/mask/k9_bandana/black
	name = "black K9 bandana"
	icon_state = "scarf_black"
	item_state_slots = list(WEAR_FACE = "bandana_k9_bl")

//------------------------------------------------------------------------------
// Vests - a lighter alternative to a full pack, worn in the same suit slot.
// No standalone human vest item exists to borrow ground art from, so these keep the K9 overlay as their own icon too.

/obj/item/clothing/suit/k9_vest
	name = "K9 safety vest"
	desc = "A hi-visibility safety vest, resized to fit a K9 Rescue Unit."
	icon = K9_OVERLAY_ICON
	icon_state = "safetyvest_k9"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_JACKET = "safetyvest_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_OCLOTHING

/obj/item/clothing/suit/k9_vest/medical
	name = "K9 medical vest"
	desc = "A medical corps vest, resized to fit a K9 Rescue Unit."
	icon_state = "medicalvest_k9"
	item_state_slots = list(WEAR_JACKET = "medicalvest_k9")

/obj/item/clothing/suit/k9_vest/tactical
	name = "K9 tactical vest"
	desc = "A reinforced tactical vest, resized to fit a K9 Rescue Unit."
	icon_state = "safetyvest_b_k9"
	item_state_slots = list(WEAR_JACKET = "safetyvest_b_k9")

//------------------------------------------------------------------------------

/obj/item/clothing/head/k9_drillhat
	name = "K9 drill instructor's hat"
	desc = "A stiff-brimmed hat, resized to fit a K9 Rescue Unit."
	icon = 'icons/obj/items/clothing/hats/hats_by_faction/UA.dmi'
	icon_state = "drillhat"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_HEAD = "drillhat_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_HEAD

/obj/item/clothing/head/k9_mpberet
	name = "K9 military police beret"
	desc = "A military police beret, resized to fit a K9 Rescue Unit."
	icon = K9_BERET_ICON
	icon_state = "beretred"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_HEAD = "mpberet_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_HEAD

/obj/item/clothing/head/k9_engiberet
	name = "K9 engineering beret"
	desc = "An engineering corps beret, resized to fit a K9 Rescue Unit."
	icon = K9_BERET_ICON
	icon_state = "e_beret_badge"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_HEAD = "engiberet_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_HEAD

/obj/item/clothing/head/k9_purpleberet
	name = "K9 purple beret"
	desc = "A purple beret, resized to fit a K9 Rescue Unit."
	icon = K9_BERET_ICON
	icon_state = "purpleberet"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_HEAD = "purpleberet_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_HEAD

//------------------------------------------------------------------------------

/obj/item/clothing/glasses/k9_goggles
	name = "K9 marine goggles"
	desc = "A pair of rugged marine goggles, strapped to fit a K9 Rescue Unit."
	icon = K9_GOGGLES_ICON
	icon_state = "mgoggles"
	icon_override = K9_OVERLAY_ICON
	item_state_slots = list(WEAR_EYES = "mgoggles_k9")
	k9_exclusive_wear = TRUE
	force_overlays_on = TRUE
	w_class = SIZE_SMALL
	flags_equip_slot = SLOT_EYES

/obj/item/clothing/glasses/k9_goggles/v2
	name = "K9 marine goggles (mk 2)"
	desc = "A newer pair of rugged marine goggles, strapped to fit a K9 Rescue Unit."
	icon_state = "mgoggles2"
	item_state_slots = list(WEAR_EYES = "mgoggles2_k9")

//------------------------------------------------------------------------------
// Ears - same headset as human synths, just re-flagged so it fits the K9's ear slot.

/obj/item/device/radio/headset/almayer/mcom/synth/k9
	k9_exclusive_wear = TRUE

//------------------------------------------------------------------------------
// ID - a physical badge like other synthetics carry (/obj/item/card/id/gold), not a dogtag.

/obj/item/card/id/gold/synth_k9
	name = "identification holo-badge"
	desc = "A gold plated holo-badge belonging to a Weyland-Yutani K9 Rescue Unit."
	assignment = JOB_SYNTH_K9
	paygrade = PAY_SHORT_SYN_K9

/obj/item/card/id/gold/synth_k9/New()
	. = ..()
	access = get_access()

#undef K9_OVERLAY_ICON
#undef K9_SCARF_ICON
#undef K9_BERET_ICON
#undef K9_GOGGLES_ICON
