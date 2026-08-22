GLOBAL_LIST_EMPTY_TYPED(cm_vending_vendors, /obj/structure/machinery/cm_vending/sorted) //Used by our gamemode code

GLOBAL_LIST_EMPTY_TYPED(gun_list, /obj/item/weapon/gun)
GLOBAL_LIST_EMPTY_TYPED(ammo_magazine_list, /obj/item/ammo_magazine)

GLOBAL_LIST_EMPTY_TYPED(radio_beacon_list, /obj/item/device/radio/beacon)
GLOBAL_LIST_EMPTY_TYPED(tracking_implant_list, /obj/item/implant/tracking)
GLOBAL_LIST_EMPTY_TYPED(chem_implant_list, /obj/item/implant/chem)

GLOBAL_LIST_EMPTY_TYPED(seed_list, /obj/item/seeds)
GLOBAL_LIST_EMPTY_TYPED(grown_snacks_list, /obj/item/reagent_container/food/snacks/grown)
GLOBAL_LIST_EMPTY_TYPED(head_limb_list, /obj/item/limb/head)

GLOBAL_LIST_EMPTY_TYPED(portal_list, /obj/effect/portal)

GLOBAL_LIST_EMPTY_TYPED(supply_drop_list, /obj/structure/supply_drop)
GLOBAL_LIST_EMPTY_TYPED(brig_locker_list, /obj/structure/closet/secure_closet/brig)
GLOBAL_LIST_EMPTY_TYPED(ladder_list, /obj/structure/ladder)
/// Every /obj/structure/stairs/multiz on the map - unlike ladders, stairs have no interaction to bypass (they teleport any mob that steps through them in the right direction automatically, misc.dm), but the AI still needs a registry to find one connecting toward a given z-level - see find_stairs_towards() (xeno_ai_controller.dm).
GLOBAL_LIST_EMPTY_TYPED(multiz_stairs_list, /obj/structure/stairs/multiz)
/// Every /obj/structure/pipes/vents on the map - no equivalent registry exists for the pipe network otherwise (unlike GLOB.ladder_list), needed so AI code can find a usable entry/exit vent - see ai_ventcrawl_find_entry()/ai_ventcrawl_find_exit() (xeno_ai_ventcrawl.dm).
GLOBAL_LIST_EMPTY_TYPED(vent_list, /obj/structure/pipes/vents)
GLOBAL_LIST_EMPTY_TYPED(cable_list, /obj/structure/cable)
GLOBAL_LIST_EMPTY_TYPED(closet_list, /obj/structure/closet)

GLOBAL_LIST_EMPTY_TYPED(disposal_retrieval_list, /obj/structure/disposaloutlet/retrieval)
GLOBAL_LIST_EMPTY_TYPED(disposalpipe_up_list, /obj/structure/disposalpipe/up/almayer)
GLOBAL_LIST_EMPTY_TYPED(disposalpipe_down_list, /obj/structure/disposalpipe/down/almayer)

GLOBAL_LIST_EMPTY_TYPED(all_multi_vehicles, /obj/vehicle/multitile)

GLOBAL_LIST_EMPTY_TYPED(lifeboat_almayer_docks, /obj/docking_port/stationary/lifeboat_dock)
GLOBAL_LIST_EMPTY_TYPED(lifeboat_doors, /obj/structure/machinery/door/airlock/multi_tile/almayer/dropshiprear/lifeboat/blastdoor)

GLOBAL_LIST_EMPTY_TYPED(teleporters, /datum/teleporter)
GLOBAL_LIST_EMPTY(teleporters_by_id)
