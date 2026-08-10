GLOBAL_LIST_EMPTY(clients) //all clients
GLOBAL_LIST_EMPTY(admins) //all clients whom are admins
GLOBAL_PROTECT(admins)

GLOBAL_LIST_EMPTY(directory) //all ckeys with associated client

GLOBAL_LIST_EMPTY(player_list) //all mobs **with clients attached**.

GLOBAL_LIST_EMPTY(observer_list) //all /mob/dead/observer

GLOBAL_LIST_EMPTY(new_player_list) //all /mob/dead/new_player, in theory all should have clients and those that don't are in the process of spawning and get deleted when done.

GLOBAL_LIST_EMPTY_TYPED(mob_list, /mob)

GLOBAL_LIST_EMPTY_TYPED(living_mob_list, /mob/living)
GLOBAL_LIST_EMPTY_TYPED(alive_mob_list, /mob)

GLOBAL_LIST_EMPTY_TYPED(dead_mob_list, /mob) // excludes /mob/new_player

GLOBAL_LIST_EMPTY_TYPED(human_mob_list, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(alive_human_list, /mob/living/carbon/human) // list of alive marines

GLOBAL_LIST_EMPTY_TYPED(xeno_mob_list, /mob/living/carbon/xenomorph)
GLOBAL_LIST_EMPTY_TYPED(living_xeno_list, /mob/living/carbon/xenomorph)
GLOBAL_LIST_EMPTY_TYPED(xeno_cultists, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(player_embryo_list, /obj/item/alien_embryo)

GLOBAL_LIST_EMPTY_TYPED(hellhound_list, /mob/living/carbon/xenomorph/hellhound)
GLOBAL_LIST_EMPTY_TYPED(zombie_list, /mob/living/carbon/human)
GLOBAL_LIST_EMPTY_TYPED(yautja_mob_list, /mob/living/carbon/human)

/// All xenomorphs currently piloted by a xeno_ai_controller (no client). Maintained by the AI lifecycle procs, not derived on demand.
GLOBAL_LIST_EMPTY_TYPED(ai_xeno_list, /mob/living/carbon/xenomorph)
/// Count of currently active AI-piloted xenos - purely observational (admin panel roster/stats) now that the hard population cap is gone; nothing gates spawning on it any more.
GLOBAL_VAR_INIT(ai_xeno_active_count, 0)
/// Optional per-caste caps (caste_type text -> max count), enforced in attach_xeno_ai(). A caste absent from this list has no cap. Set live from the admin mission control panel. "The AI cap, which I want removed" was the old GLOBAL_VAR_INIT(ai_xeno_max_active) hard total cap - removed outright (and with it the backlog it fed - a Director-grown hive that outpaced it just sat there with clientless, uncontrolled, "stale" mobs stacking up forever waiting for a slot); this per-caste knob is a different, deliberately-opt-in balance tool and stays.
GLOBAL_LIST_EMPTY(ai_xeno_max_per_caste)
/// Live-adjustable multiplier on every AI xeno's flee-health-fraction threshold, applied at should_flee() check time (see xeno_ai_controller.dm/crusher.dm) - below 1 makes xenos fight longer before disengaging, above 1 makes them flee earlier. Set from the admin mission control panel's behavior preset. Defaults below 1 - xenomorphs are meant to be ruthless, not skittish, so out of the box they fight well past the point a squishier AI would peel off.
GLOBAL_VAR_INIT(ai_flee_multiplier, 0.6)
/// Live-adjustable multiplier on attack_distance/return_distance, applied once at controller creation (xeno_ai_controller.dm's New()) - only affects xenos spawned after the change.
GLOBAL_VAR_INIT(ai_distance_multiplier, 1.0)
/// Live-adjustable overall AI difficulty knob (Xeno Spawner admin section) - scales the Spawner's population target and spawn-per-fire rate (xeno_spawner.dm's spawner_target_population()/spawner_maintain_population()). No longer tied to ai_flee_multiplier/ai_distance_multiplier - those are purely the independent AI Behavior presets/sliders now.
GLOBAL_VAR_INIT(ai_difficulty_multiplier, 1.0)
/// Master on/off switch for SSxeno_spawner (code/controllers/subsystem/xeno_spawner.dm) - "a simple Spawner... spawns AI all over the map based on the amount of players awake and parameters given like difficulty." Replaces the old per-hive Hive Population Director toggle with one global switch, since the new Spawner has no per-hive economy state worth toggling independently. This TRUE default only matters before the first round's pre_setup() runs (e.g. a debug/admin-triggered spawn attempt in the lobby) - every real round resets this to FALSE at the top of game_mode.dm's base pre_setup(), with only the PVE Hive gamemode (pve_hive.dm) turning it back on, so the AI hive economy no longer silently runs in every gamemode by default.
GLOBAL_VAR_INIT(xeno_spawner_enabled, TRUE)
/// Which single hive (an XENO_HIVE_* key, mobs.dm) SSxeno_spawner reinforces - null means "spawn nothing, no hive selected." "The spawner spawns all different hives at once, placing the whole operation into chaos... I want to be able to select which hive is auto spawned on round start if any at all" - the Spawner used to loop every GLOB.hive_datum entry every fire, reinforcing every hive in existence (13 of them, mobs.dm's XENO_HIVE_* list) simultaneously, most of which aren't even in play a given round. Defaults to the main PvE hive, matching the old (if accidentally-multi-hive) behavior for anyone not touching the new admin control.
GLOBAL_VAR_INIT(xeno_spawner_hive, XENO_HIVE_NORMAL)

