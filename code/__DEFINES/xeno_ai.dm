// Defines for the NPC Xenomorph AI foundation (xeno_ai_controller and friends).
// See code/modules/mob/living/carbon/xenomorph/ai/ for the implementation.

/// Idle, no target, scanning at the slow idle heartbeat.
#define AI_STATE_IDLE 1
/// Named sub-states of AI_STATE_IDLE - "Idle" alone used to cover wandering, building, following, hiding, and patrolling all as one flat label with no memory between ticks. See patrol()/xeno_ai_controller.dm's idle_activity var.
#define IDLE_ACTIVITY_NONE "Idle"
#define IDLE_ACTIVITY_ALERT "Responding to alert"
#define IDLE_ACTIVITY_ESCORT "Escorting Queen"
#define IDLE_ACTIVITY_PACK "Regrouping"
#define IDLE_ACTIVITY_AMBUSH "Ambush hiding"
#define IDLE_ACTIVITY_LONG_PATROL "Long patrol"
#define IDLE_ACTIVITY_WANDER "Wandering"
#define IDLE_ACTIVITY_BUILD "Building"
#define IDLE_ACTIVITY_COMMANDING "Commanding"
#define IDLE_ACTIVITY_SABOTAGE "Sabotaging power"
#define IDLE_ACTIVITY_SOCIAL "Socializing"
#define IDLE_ACTIVITY_REST "Resting"
#define IDLE_ACTIVITY_ORDERED "Under orders"
/// Target acquired, closing distance.
#define AI_STATE_APPROACHING 2
/// Adjacent to target, actively attacking.
#define AI_STATE_ATTACKING 3
/// Disengaging, walking back to anchor_turf.
#define AI_STATE_RETURNING 4
/// Chasing down the last known position of a target that escaped rather than died (may involve a ladder to cross z-levels).
#define AI_STATE_SEARCHING 5

/// Default scan radius (tiles) used for both target acquisition and re-acquisition.
#define AI_XENO_DEFAULT_ATTACK_DISTANCE 10
/// Default leash radius (tiles) from anchor_turf before an AI xeno disengages and returns.
#define AI_XENO_DEFAULT_RETURN_DISTANCE 15
/// How far the pilot can drift from where process_target()'s scan rectangle was last centered before it's considered stale and recomputed - keeps the scan following her as she patrols/wanders instead of staying pinned to wherever she happened to be during her last unsuccessful scan.
#define AI_XENO_TARGET_SCAN_REFRESH_DISTANCE 3
/// Per-swing cooldown the AI's plain melee is held to (execute_attack()'s plain-melee branch, xeno_ai_attack.dm) - attack_alien() itself never sets this, only click_adjacent()'s own `next_move += 4` does, and only for a real player's click. 4 is the bare code-permitted floor though (2.5 attacks/sec sustained), far faster than a real player's actual click cadence in practice (aiming, reacting, missing a click here and there) - "no click delay... can melt a player to death with just slashing" was this AI attacking at that literal floor nonstop, which no human sustains. Set higher to read as a real melee pace instead of the theoretical maximum.
#define XENO_MELEE_ATTACK_DELAY 8
/// Percent chance a plain melee swing against a human uses INTENT_DISARM (a real tackle attempt, can knock down) instead of INTENT_HARM (plain claw damage).
#define AI_XENO_DISARM_CHANCE 20
/// Ticks slept between ai_loop() iterations while actively engaged with a target. Deliberately as low as
/// BYOND's sleep() grants (1 tick) - actual movement/attack pacing is already gated for free by the pilot's
/// own next_move (same movement_delay()/attack cooldown a real player is bound by via step()/attack_alien()),
/// so there's no reason to lay a second, slower artificial cadence on top of it. At 5 this was the real
/// bottleneck behind "pathfinding far too slow" and "never walks and acts in the same window" - a fast
/// caste's true move_delay could be well under 5 ticks, but tick() (and therefore any new step or attack)
/// couldn't run again until the full 5 had passed regardless.
#define AI_XENO_DEFAULT_HEARTBEAT 1
/// Ticks slept between ai_loop() iterations while idle/no target (cheaper than the engaged heartbeat, but still close enough to actual per-tile movement speed to look like continuous walking rather than "one step every few seconds" - see wander()'s doc comment). Lowering this raises server load roughly linearly with the size of the idle AI population - see AI_XENO_DORMANT_HEARTBEAT/dormant_until for how most of that population avoids paying this cost most of the time.
#define AI_XENO_DEFAULT_IDLE_HEARTBEAT 6
/// Health fraction (0-1) below which an AI xeno even considers disengaging - see should_flee() for the rest of the decision (target's own health, nearby backup). Raised from 0.25 - "normal casts should really use fleeing better" - combined with the old ally threshold of 1, most fights had an excuse not to disengage until nearly dead.
#define AI_XENO_FLEE_HEALTH_PERCENT 0.35
/// Queen-specific flee threshold, higher than the population default - "she is big and slow and easy to kill," a huge investment worth breaking off with sooner rather than overcommitting.
#define AI_QUEEN_FLEE_HEALTH_PERCENT 0.5
/// Tiles within which a living same-hive AI xeno counts as "backup" for should_flee()'s decision.
#define AI_XENO_FLEE_ALLY_RADIUS 7
/// Nearby same-hive allies (see count_nearby_hive_allies()) at/above which a hurt xeno keeps fighting instead of disengaging - not fighting alone, so the hive's numbers carry it instead. Raised from 1 - a single other daughter happening to be nearby isn't real backup, it was just cancelling the flee decision almost every time.
#define AI_XENO_FLEE_ALLY_THRESHOLD 2
/// Health fraction (0-1) below which no amount of nearby/engaged ally backup suppresses should_flee() - "I would engage, but as soon as I got low, I would retreat" even with an escort present. Below this, retreat-and-heal-on-weeds always wins over standing with the group.
#define AI_XENO_FLEE_ALLY_SUPPRESS_FLOOR 0.20
/// Tiles from anchor_turf within which a larva no longer bothers fleeing - see larva.dm's should_flee() doc comment for why "flee home" is a no-op this close to it already.
#define AI_XENO_LARVA_SAFE_HOME_RADIUS 3
/// Health fraction (0-1) below which a fleeing xeno gives up on running and turns to fight instead - "unless they are very desperate and want to live." Well below the flee threshold: by this point a parting hit while her back's turned is just as likely to kill her as standing and swinging, so running only pays off if she can actually reach safety, not just because she's hurt. Only relevant while already fleeing (return_to_anchor()) and only when there's still a real target adjacent to turn on.
#define AI_XENO_DESPERATE_HEALTH_PERCENT 0.12
/// Drone-specific flee threshold, higher than the population default - "many casts like... drones... dive to their deaths." She's a builder pressed into a fight, not a frontline unit, so she should break off sooner than a caste actually built to brawl. Phase 3: was 0.35, identical to AI_XENO_FLEE_HEALTH_PERCENT above - drone_worker.dm's override was a silent no-op despite this doc comment; raised so it actually does what it says.
#define AI_DRONE_FLEE_HEALTH_PERCENT 0.45
/// Hivelord-specific flee threshold - same "builder pressed into combat" reasoning as AI_DRONE_FLEE_HEALTH_PERCENT, she just never got her own override before Phase 3.
#define AI_HIVELORD_FLEE_HEALTH_PERCENT 0.45
/// King-specific flee threshold, mirrors AI_QUEEN_FLEE_HEALTH_PERCENT - exactly as hard to replace as Queen (one-per-round investment), only Queen had a raised threshold before Phase 3.
#define AI_KING_FLEE_HEALTH_PERCENT 0.5
/// Warrior-specific flee threshold, lower than the population default - a heavy brawler in the same "hardened, fights longer" spirit as AI_CRUSHER_FLEE_HEALTH_PERCENT. Starting point for playtesting.
#define AI_WARRIOR_FLEE_HEALTH_PERCENT 0.25
/// Sentinel/Spitter-specific flee threshold, higher than the population default - both are ranged glass cannons with no armor investment, should disengage sooner than a melee caste. Starting point for playtesting.
#define AI_SENTINEL_FLEE_HEALTH_PERCENT 0.45
#define AI_SPITTER_FLEE_HEALTH_PERCENT 0.45
/// Lurker-specific flee threshold, higher than the population default - "fast but low-HP/no-armor, exactly the caste that should never just stand and trade" (lurker.dm's own header). Starting point for playtesting.
#define AI_LURKER_FLEE_HEALTH_PERCENT 0.45
/// Facehugger-specific flee threshold, deliberately much higher than every other caste's - a one-hit-fragile (XENO_HEALTH_LARVA) ambush predator that can't actually fight, so should_flee()'s override treats "took a real hit at all" as the trigger rather than a normal population-scale health fraction. Starting point for playtesting.
#define AI_FACEHUGGER_FLEE_HEALTH_PERCENT 0.8
/// Radius (tiles) find_defensible_turf() searches for a corner/wall position with limited approach angles - "they should also consider corners and walls as defensive positions" for fleeing/kiting castes instead of always retreating across open ground.
#define AI_XENO_DEFENSIBLE_SEARCH_RADIUS 6
/// Cardinally-adjacent dense tiles a candidate turf needs before find_defensible_turf() considers it "defensible" (fewer open approach directions).
#define AI_XENO_DEFENSIBLE_MIN_DENSE_SIDES 2
/// Range within which a "ready" threat (weapon raised/aimed) is close enough that climbing/smashing straight toward them is actually risky - see is_direct_approach_too_risky(). Outside this range they're not an immediate danger yet even if armed.
#define AI_XENO_RISKY_APPROACH_RANGE 5
/// How long an AI xeno will keep investigating a lost target's last known position before giving up.
#define AI_XENO_SEARCH_TIMEOUT 15 SECONDS
/// Largest local grid (width*height tiles) handed to the native pathfinder. Beyond this the old greedy step_towards() chase handles it fine - this is for routing around nearby obstacles, not long-range travel.
#define XENO_PATHFIND_MAX_CELLS 900
/// Floor on compute_path()'s search margin around the direct pilot-goal bounding box.
#define AI_PATHFIND_MIN_MARGIN 2
/// Consecutive compute_path_global()/compute_path() failures against the same goal (path_fail_streak) before compute_path() escalates past its normal AI_PATHFIND_MAX_MARGIN/budget - see that proc's doc comment. "If unable to go where you want, and you keep failing to find a path around, search a wider area for a way around" - the normal margin stays tight since most replans are cheap and frequent; this only kicks in once a goal has genuinely proven hard to reach.
#define AI_PATHFIND_ESCALATION_THRESHOLD 3
/// Escalated margin ceiling compute_path() searches out to once AI_PATHFIND_ESCALATION_THRESHOLD consecutive failures have piled up - wider than AI_PATHFIND_MAX_MARGIN so a genuinely long detour (a door several extra tiles off the direct line) becomes visible to the solver instead of the pilot giving up on the whole target. Paired with AI_PATHFIND_ESCALATED_BUDGET_MULTIPLIER below since a wider margin needs a bigger cell budget to actually be reached, not just a higher cap the width*height check still clamps away.
#define AI_PATHFIND_ESCALATED_MAX_MARGIN 22
/// Multiplier on get_pathfind_cell_budget()'s normal result while escalated (see AI_PATHFIND_ESCALATION_THRESHOLD) - only ever spent after PATH_RETRY_COOLDOWN-throttled repeated failures against the same goal, not a per-tick cost, so a heavier one-off solve here is worth it.
#define AI_PATHFIND_ESCALATED_BUDGET_MULTIPLIER 2
/// Ceiling on compute_path()'s search margin, however much cell budget is left unused - "pathfinding cannot go around walls, only tries to go through them" was a flat margin of 2 regardless of budget, which almost never actually reached far enough sideways to include a real door/entrance for a typical room, so the solver came back "no path" and everything fell to the greedy walk-straight-at-the-wall-and-smash fallback instead. Capped rather than solved exactly for the budget so a close-together pilot/goal pair doesn't scan an enormous area just because the raw budget math would allow it.
#define AI_PATHFIND_MAX_MARGIN 14
/// Tiles a live target can drift from where a cached path was computed for before advance_along_path() throws it out and replans - keeps a moving target from forcing a fresh plan (and a fresh solver tie-break near corners) every single tick.
#define PATH_GOAL_REPLAN_TOLERANCE 2
/// How soon after a step a direction-reversal counts as suspicious enough to log (GLOB.ai_debug_pathing) - see ai_step()'s reversal-detection doc comment. A reversal long after the prior step is just a normal, deliberate direction change, not ping-ponging.
#define AI_DEBUG_REVERSAL_WINDOW 3 SECONDS
/// How long advance_along_path() waits after a failed compute_path() attempt before trying again against essentially the same goal - a doomed hop (bbox too big for the cell budget, e.g. across an open LZ/Thunderdome pad) would otherwise re-run the full grid-build every single tick forever.
#define PATH_RETRY_COOLDOWN 2 SECONDS
/// How long get_blocking_obstacle() stays committed to a specific wall/structure once it starts being smashed, even if a target shifting behind cover would otherwise make a different obstacle line up - "keeps moving between smashing different walls instead of focusing on the original wall." Refreshed on every successful hit (attack_blocking_obstacle()), so continuous smashing never lapses; only actual inactivity lets a stale commitment expire.
#define AI_XENO_OBSTACLE_COMMIT_DURATION 6 SECONDS
/// Minimum time between SUCCESSFUL whole-map replans per mob (advance_along_path()) - a live target drifting past PATH_GOAL_REPLAN_TOLERANCE would otherwise force a native route solve every single tick; within this window the existing route keeps being consumed toward where the goal recently was.
#define PATH_REPLAN_MIN_INTERVAL 1 SECONDS
/// How long an AI-controlled facehugger commits to a downed target before attaching - gives the target's allies a beat to intervene rather than the hug landing the instant it's adjacent.
#define FACEHUGGER_WINDUP_DURATION 1 SECONDS

// travel_to() behavior flags (see xeno_ai_movement.dm) - the unified
// route-first navigation primitive every AI movement flow goes through.
/// Claw through doors/walls/structures blocking the route (combat/urgent flows). Without it a blocked route just replans around.
#define TRAVEL_FLAG_FORCE_OBSTACLES (1<<0)
/// Before committing to smash an obstacle toward current_target, weigh whether stepping to real cover is smarter (is_direct_approach_too_risky()) - chase flows only.
#define TRAVEL_FLAG_COVER_CHECK (1<<1)
/// Don't step onto tiles occupied by other living mobs - idle drift/cohesion flows, so idlers stop shuffling through each other.
#define TRAVEL_FLAG_AVOID_MOBS (1<<2)
/// Skip the short-range direct-step shortcut (AI_TRAVEL_DIRECT_RANGE) and always route, even at close range - for a STATIC goal (a fixed build-site tile, never a moving chase target) where that shortcut's whole rationale ("goal might have moved, don't trust a stale route") doesn't apply. A build site a couple of tiles away but genuinely walled off (own fort-line corner, a dead-end alcove) needs a real route around, which raw cardinal-step-plus-sidestep fundamentally can't solve - see attempt_build_fort_line()/attempt_build_defense()'s travel_to() calls.
#define TRAVEL_FLAG_STATIC_GOAL (1<<3)
/// Distance at or under which travel_to() steps directly at the goal instead of routing - routing to a moving nearby goal walks stale paths the wrong way and reads as pacing back and forth.
#define AI_TRAVEL_DIRECT_RANGE 3
/// How long navigate_around()'s last-resort direction commitment lasts once real A* routing has failed - long enough to actually clear a building corner instead of re-aiming at the goal (and walking straight back into the same wall) every tick.
#define AI_XENO_FALLBACK_WALK_DURATION 8 SECONDS
/// Pending native-grid deltas that force an immediate flush instead of waiting for SSxeno_pathfinding's next fire() - keeps a big simultaneous change (an explosion leveling walls) from leaving routes stale for several seconds.
#define XENO_PATHFIND_DELTA_FLUSH_AT 64
/// SSxeno_pathfinding fire()s (5s apart) between threat-decay calls - 3 = decay every ~15s, so a kill zone stays meaningfully hot for a couple of minutes.
#define XENO_PATHFIND_DECAY_EVERY_FIRES 3
/// Threat cost added at a hive member's death tile (radius-2 falloff, native side) - each point is worth 1/10th of an open tile's step cost, so 24 makes the epicenter ~3.4x as expensive to route through until it decays. Starting point for playtesting, not final balance.
#define AI_THREAT_DEATH_AMOUNT 24
/// Distance from the target at which an approaching pilot considers a pack-staging hold (see check_pack_staging()). Starting point for playtesting.
#define AI_XENO_STAGE_RANGE 6
/// Hard cap on how long a staging hold lasts before the pilot rushes alone anyway - never passive for long. Starting point for playtesting.
#define AI_XENO_STAGE_MAX_WAIT 4 SECONDS
/// Cooldown after a stage commit before the same pilot may stage again, so a running chase never turns into repeated stop-and-go.
#define AI_XENO_STAGE_COOLDOWN 10 SECONDS
/// How long after arriving at (or giving up on) a flee destination before the flee transition can re-latch - the window in which a still-hurt xeno rests/heals/fights back instead of re-entering the flee state machine every tick.
#define AI_XENO_FLEE_REARM_DELAY 15 SECONDS
/// Net tiles of drag progress after which a dragged marine counts as isolated and gets released (see process_drag()) if no wall cap was reachable in time - the old isolation-only fallback. Starting point for playtesting.
#define AI_DRAG_MAX_DIST 10
/// Chance per idle tick a Drone/Hivelord attempts to build a new hive wall cap (attempt_build_human_cap(), human_cap.dm) - deliberately much rarer than a fort-line wall/door tile, this is a standing capture slot, not routine perimeter upkeep.
#define AI_HUMAN_CAP_BUILD_CHANCE 3
/// Hard ceiling on how many hive wall caps a single hive is allowed to have built at once (hive.human_cap_structures) - keeps the AI from spamming an unbounded number of capture slots regardless of build-chance rolls.
#define AI_XENO_MAX_HUMAN_CAPS 4
/// Search radius attempt_cap_drag_victim() scans for the nearest empty hive wall cap once a drag has reached the hive's own weeds.
#define AI_HUMAN_CAP_SEARCH_RADIUS 12
/// Health fraction below which an idle xeno seeks out a planted resin fruit to eat (attempt_eat_fruit()). Starting point for playtesting.
#define AI_XENO_EAT_FRUIT_HEALTH_PERCENT 0.6
/// How far an idle hurt xeno scans for an edible planted fruit.
#define AI_XENO_FRUIT_SEARCH_RADIUS 12
/// Ally health fraction below which an idle emitter switches to recovery pheromones (select_pheromone_aura()).
#define AI_XENO_RECOVERY_PHERO_HEALTH_PERCENT 0.75
/// Minimum direct-walk distance before a hive tunnel is even considered as a shortcut (attempt_tunnel_shortcut()).
#define AI_TUNNEL_MIN_TRIP 25
/// Tiles of advantage a tunnel route must have over the direct walk to be worth the crawl-in/transit windups.
#define AI_TUNNEL_TRIP_OVERHEAD 10
/// Chance per attack tick that a Runner drags a marine she's downed out of their squad's cover fire (attempt_start_drag()). Starting point for playtesting.
#define AI_RUNNER_DRAG_CHANCE 40
/// Same as AI_RUNNER_DRAG_CHANCE, but for a Burrower - "slashing and hacking or even kidnapping a human... before burrowing back to safety" is an occasional, not constant, play pattern for her (she's a build/ambush hybrid, not a harasser), so this starts lower than Runner's. Starting point for playtesting.
#define AI_BURROWER_DRAG_CHANCE 25
/// get_drag_chance() (xeno_ai_controller.dm) for every melee caste that isn't a dedicated isolation specialist (Runner/Burrower, above) but can plausibly end up standing over a target she just downed - a side hustle for a caste whose real job is fighting, not a Runner-tier dedicated kit, so this is well below both dedicated drag chances.
#define AI_XENO_OPPORTUNISTIC_DRAG_CHANCE 10
/// Radius pick_burrower_flank_turf() (burrower.dm) scans around the target for allies already fighting them, to score which flank side is still unclaimed - deliberately small and separate from AI_XENO_FLEE_ALLY_RADIUS (a different, unrelated tuning knob) since this only cares about immediate melee-range crowding around one specific target, not general nearby backup.
#define AI_BURROWER_FLANK_ALLY_SCAN_RADIUS 5
/// Percent chance per idle tick that a Burrower attempts attempt_build_hive_tunnel() (burrower.dm) - a low-priority infrastructure roll, checked last among her own build options, similar rarity band to AI_HUMAN_CAP_BUILD_CHANCE.
#define AI_BURROWER_TUNNEL_BUILD_CHANCE 4
/// Minimum distance (tiles) a new autonomous tunnel site must be from every existing hive.tunnels node - see is_hive_tunnel_network_sparse_near() (burrower.dm). Keeps the AI from spamming redundant entrances close together instead of genuinely extending the network's reach.
#define AI_BURROWER_TUNNEL_MIN_SPACING 20
/// Acid fraction (of max) at which an Acider counts as charged and switches to the deliberate detonation-run pattern.
#define AI_ACIDER_CHARGED_PERCENT 0.8
/// Distance band at which a charged Acider holds before committing her detonation run.
#define AI_ACIDER_HOLD_RANGE 5
/// Hard cap on the pre-detonation hold before she commits anyway.
#define AI_ACIDER_HOLD_MAX_WAIT 5 SECONDS
/// Health fraction at which a recovered Ravager heads back to the fight she fled from (patrol() re-engage loop). Starting point for playtesting.
#define AI_RAVAGER_REENGAGE_HEALTH_PERCENT 0.8
/// Shard fraction (of max) below which a Hedgehog holds ground instead of rolling a tactical retreat - standing in fire is how she charges.
#define AI_HEDGEHOG_SHARD_HOLD_PERCENT 0.5
/// Longest lane a Charger scans for a momentum pass (find_charge_lane()).
#define AI_CHARGER_LANE_MAX_LENGTH 14
/// Minimum open lane length for a charge pass to be worth lining up - less than this means cramped ground, fight like a base Crusher instead.
#define AI_CHARGER_LANE_MIN_LENGTH 5
/// Tiles of overrun past the target's row/column a pass carries through - momentum doesn't stop ON them, it goes THROUGH them.
#define AI_CHARGER_LANE_OVERRUN 4
/// Distance beyond which a target counts as an optional expedition for King - closer than this he always fights (never stands there eating hits).
#define AI_KING_COMMIT_RANGE 4
/// Radius King checks for a bodyguard before committing to a distant fight.
#define AI_KING_ESCORT_RADIUS 7
/// Sisters required at King's side before he marches on a distant target.
#define AI_KING_ESCORT_MIN 2
/// Distance within which the Queen always defends herself regardless of hive strength.
#define AI_QUEEN_SELF_DEFENSE_RANGE 8
/// Radius the Queen checks for an escort before marching to a distant fight.
#define AI_QUEEN_ATTACK_ESCORT_RADIUS 7
/// Daughters required at the Queen's side before she leaves the hive to attack.
#define AI_QUEEN_ATTACK_MIN_ESCORT 2
/// Fraction of the Spawner's target population the hive must hold before the Queen considers an optional attack - below this she stays on the economy/ovi loop. Starting point for playtesting.
#define AI_QUEEN_ATTACK_STRENGTH_PERCENT 0.7
/// How far an idle Facehugger looks for a table/rack to tuck under before flattening (attempt_cover_tuck()).
#define AI_HUGGER_COVER_SEARCH_RADIUS 8
/// How often check_movement_progress() samples distance to the approach goal.
#define AI_XENO_STUCK_CHECK_INTERVAL 6 SECONDS
/// How long hive_status's get_cached_ai_roster() reuses its last GLOB.ai_xeno_list snapshot before rebuilding - see that proc's doc comment. Every same-hive AI controller shares one rebuild per this window instead of each independently re-scanning the whole list every heartbeat, which is what actually scales with population size as a round goes on (not any single mob's own age).
#define AI_HIVE_SCAN_CACHE_INTERVAL (0.5 SECONDS) // Short enough that pack/social/escort decisions never read meaningfully stale, long enough to actually amortize the scan cost across a hive's whole population.
/// Consecutive no-improvement samples (see AI_XENO_STUCK_CHECK_INTERVAL) before check_movement_progress() gives up on the current target - real net progress resets this even while blocked_attempts itself keeps getting reset by successful smash-attacks that never actually close the distance.
#define AI_XENO_STUCK_GIVEUP_TICKS 4
/// How far an idle xeno will wander from its anchor while patrolling.
#define AI_XENO_PATROL_RADIUS 10
/// Percent chance per idle tick that a hurt xeno standing on healing-eligible weeds opportunistically rests to heal up, rather than only ever resting once critically hurt and already back at anchor_turf.
#define AI_XENO_OPPORTUNISTIC_REST_CHANCE 8
/// Hard cap on how long wander() lets her rest before standing back up regardless of health - see rest_timeout.
#define AI_XENO_MAX_REST_DURATION 1 MINUTES
/// Percent chance per idle tick that a resting-eligible xeno off her own hive's weeds bothers seeking one out (find_nearest_hive_weed_turf()) instead of just staying put - no longer gates plain wander() movement itself (see wander()'s doc comment).
#define AI_XENO_PATROL_CHANCE 33
/// How long wander() commits to a single heading before picking a new one - see wander()'s doc comment for why this exists.
#define AI_XENO_WANDER_COMMIT_TIME 6 SECONDS
/// Percent chance, each time a committed heading expires, that a wandering xeno goes dormant for a while instead of picking a new one - "lag is an issue, moving as a player is painfully slow" plus "they need to stop at some point and rest or stay dormant if they have nothing to do" are the same fix: continuous per-tile stepping (wander()'s doc comment above) is only cheap in aggregate if a good chunk of the idle population isn't doing it at any given moment. A dormant xeno skips movement/pathing entirely (wander()'s own early return) but keeps scanning for targets at the normal idle rate - "completely idle, not attacking" was this cutting target-scan frequency too, not just movement, on top of an initial chance/duration tuned too high (they read as dead, not resting).
#define AI_XENO_DORMANT_CHANCE 20
/// Shortest a dormant phase lasts.
#define AI_XENO_DORMANT_MIN_DURATION 6 SECONDS
/// Longest a dormant phase lasts.
#define AI_XENO_DORMANT_MAX_DURATION 15 SECONDS
/// Percent chance per idle tick (once no higher-priority order applies) that a xeno starts a long patrol leg instead of short-range wander() - see start_long_patrol().
#define AI_XENO_LONG_PATROL_CHANCE 10
/// Percent chance a long patrol leg specifically targets the marine LZ (once one's been chosen) instead of a random distant point.
#define AI_XENO_LONG_PATROL_LZ_CHANCE 40
/// How many tiles current_patrol_radius() grows per minute of round time.
#define AI_XENO_LONG_PATROL_RADIUS_GROWTH_PER_MINUTE 2
/// Cap on how far current_patrol_radius() can grow.
#define AI_XENO_LONG_PATROL_RADIUS_MAX 60
/// Percent chance per idle tick that an AI Drone attempts a build action (plant weeds) instead of wandering. Kept low - every Drone in the hive rolls this independently on its own idle heartbeat, so even a modest chance adds up fast across a full population ("weeding everywhere").
#define AI_DRONE_BUILD_CHANCE 8
/// Percent chance per idle tick, for ANY caste with no current_target (truly free, not mid-fight), that a xeno detours to dig blocking snow instead of its normal idle behavior - checked once at the single shared tick()/patrol() dispatch point (xeno_ai_controller.dm) rather than per-caste, so every caste opportunistically clears a path for the hive's weeds/structures, not just the dedicated builders. Kept low for the same "adds up fast across a full population" reasoning as AI_DRONE_BUILD_CHANCE.
#define AI_SNOW_CLEAR_CHANCE 5
/// Percent chance per idle tick that an eligible builder caste (Drone/Hivelord/Burrower) attempts a defensive resin wall at the hive perimeter instead of just weeding - see attempt_build_defense().
#define AI_DEFENSE_BUILD_CHANCE 6
/// Nearest a defensive perimeter wall is allowed to anchor_turf - keeps walls from boxing in the hive core itself.
#define AI_XENO_DEFENSE_PERIMETER_MIN_RADIUS 4
/// Farthest a defensive perimeter wall is allowed from anchor_turf.
#define AI_XENO_DEFENSE_PERIMETER_MAX_RADIUS 8
/// Tiles of resin wall built in a row before attempt_build_fort_line() switches to a paired-door gate - matches the real player convention ("2x2 or 4 resin wall") of a solid run rather than one tile at a time. Playtesting starting point.
#define AI_FORT_WALL_SEGMENT_LENGTH 4
/// Resin doors built side-by-side per gate - real doors require an adjacent dense tile (wall or another door) to even be buildable, so a lone door was never a real option; two together is the actual minimum viable gate. Playtesting starting point.
#define AI_FORT_GATE_WIDTH 2
/// Total tiles (wall+door combined) attempt_build_fort_line() will place before ending the current line and letting a fresh one start elsewhere - a safety cap so one builder doesn't wall off half the map solo over a long round. Playtesting starting point.
#define AI_FORT_MAX_LINE_LENGTH 24
/// How far find_cover_turf()/find_defensible_turf() look for an already-built fort gate (hive_status.dm's fort_gates) before falling back to their generic cover/defensible-tile scans.
#define AI_FORT_GATE_SEARCH_RADIUS 12
/// Percent chance per idle tick a dedicated builder caste (Drone/Hivelord) starts a FRESH fort line, once no line is currently in progress - "castle after castle," deliberately much higher than the shared AI_DEFENSE_BUILD_CHANCE default other/future callers of the fort-line system keep. Playtesting starting point.
#define AI_BUILDER_FORT_LINE_START_CHANCE 60
/// Minimum distance (tiles) a fresh fort line's start turf must keep from any existing hive.fort_gates entry - "defenses all over the hive," not restacking the same spot. Playtesting starting point.
#define AI_FORT_ANTI_CLUSTER_RADIUS 10
/// How close (tiles) to the single farthest-from-anchor candidate a fresh fort line's start-turf pick still counts as "frontier" - same near-tied-pick variety pattern AI_XENO_COVER_VARIETY_TOLERANCE already uses elsewhere, applied to outward spread instead of cover. Playtesting starting point.
#define AI_FORT_FRONTIER_TOLERANCE 3
/// Bounded search radius for would_block_passage()'s chokepoint check - "hivelords and drones would block doors... and block whole roads." Large enough to catch a real corridor/route, small enough to stay cheap per build attempt. Playtesting starting point.
#define AI_FORT_PASSAGE_CHECK_RADIUS 20
/// attempt_build_fort_line() is laying a solid wall run.
#define FORT_LINE_PHASE_WALL "wall"
/// attempt_build_fort_line() is laying a paired-door gate.
#define FORT_LINE_PHASE_GATE "gate"
/// How far an egg-carrying caste (Drone/Hivelord/Carrier) looks for a loose /obj/item/xeno_egg to pick up - see attempt_carry_egg().
#define AI_XENO_EGG_SEARCH_RADIUS 9
/// Percent chance per idle tick that a Drone/Hivelord bothers going to fetch a fresh egg, once nothing higher-priority (helping build the core, building defenses, weeding) rolled true first - "all they do is plant eggs, never building the hive" was attempt_carry_egg() being checked unconditionally ahead of every build/weed roll. Only gates picking a NEW egg up - once actually carrying one, she always finishes the delivery regardless of this roll (see is_carrying_egg()).
#define AI_XENO_EGG_CARRY_CHANCE 10
/// How far any idle xeno looks for a slashable light or APC to darken/depower - see attempt_slash_infrastructure().
#define AI_XENO_INFRASTRUCTURE_SEARCH_RADIUS 7
/// Percent chance per idle tick that an idle xeno bothers detouring to slash a nearby light/APC instead of continuing whatever else it was about to do - kept low so this reads as an opportunistic side action, not the whole hive making a beeline for the nearest light fixture.
#define AI_XENO_INFRASTRUCTURE_SLASH_CHANCE 10
/// Percent chance per idle tick (once truly nothing else to do) that an idle xeno strikes up a purely cosmetic vignette with a nearby idle ally - see attempt_social_interaction().
#define AI_XENO_SOCIAL_CHANCE 12
/// How close another idle same-hive xeno needs to be to be picked as a social vignette partner - deliberately much tighter than pack cohesion's hold distance, since "bumped into each other" only reads right at point-blank range.
#define AI_XENO_SOCIAL_RANGE 2
/// world.time both participants in a social vignette wait before either can roll into another one - keeps the same two xenos from looping the same flavor text back to back.
#define AI_XENO_SOCIAL_COOLDOWN 20 SECONDS
/// Of the social vignettes attempt_social_interaction() rolls, percent chance it's the real headbutt/tail-clash handshake (attempt_headbutt()/attempt_tailswipe(), XenoAttacks.dm) instead of the scripted roar/roughhouse flavor text.
#define AI_XENO_PLAYFUL_EMOTE_CHANCE 40
/// Percent chance per idle tick that a Burrower actually burrows to ambush instead of wandering - kept low, same reasoning as AI_VENT_AMBUSH_CHANCE.
#define AI_BURROWER_AMBUSH_CHANCE 5
/// Percent chance per movement tick, while chasing a target still out of melee range, that a Burrower burrows in place to set up a tunnel-ambush instead of just walking the rest of the way over.
#define AI_BURROWER_AMBUSH_ENGAGE_CHANCE 35
/// Health fraction below which a Burrower starts actually weighing whether to retreat mid-fight, once the target's back up and still a real threat - "they should consider slashing until the enemy is up, and then they get to decide to flee or keep fighting," not a flat dice roll after every swing regardless of how the fight's going.
#define AI_BURROWER_CAUTIOUS_HEALTH_PERCENT 0.6
/// How long a Burrower's tactical retreat lasts once triggered - long enough to actually put distance on the target before reconsidering.
#define AI_BURROWER_RETREAT_DURATION 6 SECONDS
/// Distance from the target a retreating Burrower wants before she ducks back underground to wait out the rest of the retreat safely, rather than just standing in the open.
#define AI_BURROWER_RETREAT_SAFE_DISTANCE 4
/// Percent chance per idle tick that the Queen attempts a build action - she's a single unit, not a population, so this can run a bit higher than a Drone's without the same compounding effect.
#define AI_QUEEN_BUILD_CHANCE 12
/// Percent chance per movement tick, while actively fighting, that Queen/Drone/Hivelord lay a weed patch mid-combat instead of just idle economy - "weeds heal, slow enemies, speed up xenos... a real tactical move mid-fight." Low - must never meaningfully compete with actually fighting. Shared across all three castes since the behavior and reasoning are identical.
#define AI_XENO_COMBAT_WEED_CHANCE 8
/// Queen-only override of AI_XENO_COMBAT_WEED_CHANCE (get_combat_weed_chance()) - "weeding is important overall, you rest on it to heal" was reported specifically about her marching behavior. Higher than the shared population-scale value since she's a single unit, same reasoning as AI_QUEEN_BUILD_CHANCE above being raised past a Drone's own build chance.
#define AI_QUEEN_COMBAT_WEED_CHANCE 18
/// Tiles an AI ranged xeno tries to stay from its target - closer than this and it backs off instead of closing to melee.
#define AI_XENO_RANGED_PREFERRED_DISTANCE 5
/// If the target closes to within this distance, a ranged xeno actively backs away instead of just holding position.
#define AI_XENO_RANGED_MIN_DISTANCE 2
/// Width of maintain_kiting_distance()'s neutral "hold and fire" band above preferred_distance - see its own doc comment for why this needs real slack (a single ai_step() against a target that's also moving can swing distance by more than 1 tile) rather than the bare minimum. Playtesting starting point.
#define AI_KITING_HOLD_BAND 2
/// Distance a ranged xeno retreats to and holds at whenever every ranged ability it has is on cooldown - matches Boiler's own AI_BOILER_HIDE_DISTANCE reasoning ("attack ranged, hide, come back out") instead of holding the normal, much closer preferred band and getting walked down while it has nothing to fire.
#define AI_XENO_RANGED_HIDE_DISTANCE 8
/// How many tiles wider than the single closest option find_cover_turf() will still consider "tied" and pick randomly among - "too predictable, walking in the same 3 tiles over and over" was a deterministic nearest-cover pick with no variety; this keeps the choice genuinely close without it always resolving to the exact same tile.
#define AI_XENO_COVER_VARIETY_TOLERANCE 2
/// How long get_or_pick_cover_turf()/get_or_pick_flank_turf() (xeno_ai_movement.dm) stay committed to whatever cover/flank tile they last picked before allowing a fresh re-roll - find_cover_turf()'s own near-tied randomization (AI_XENO_COVER_VARIETY_TOLERANCE, above) re-picking every single uncached tick read as visibly oscillating in place. Shorter than AI_XENO_OBSTACLE_COMMIT_DURATION since a retreat/flank position should still adapt reasonably quickly to a real fight shifting, just not every tick.
#define AI_XENO_COVER_COMMIT_DURATION 3 SECONDS
/// How long get_or_pick_z_transition() (xeno_ai_controller.dm) stays committed to whatever stairs/ladder it last picked before allowing a fresh re-scan of GLOB.multiz_stairs_list/GLOB.ladder_list - longer than AI_XENO_COVER_COMMIT_DURATION since reaching a chosen transition point (unlike a nearby cover/flank tile) can genuinely take a while to walk to across a whole deck, and re-scanning every few seconds mid-walk would just find the same nearest transition again anyway.
#define AI_XENO_Z_TRANSITION_COMMIT_DURATION 15 SECONDS
/// How long other hive members will respond to the Queen's last hive-alert broadcast before it goes stale (see hive_status.dm's queen_alert_turf).
#define AI_XENO_HIVE_ALERT_WINDOW 30 SECONDS
/// How far away a hive-alert will actually pull an idle builder off what she's doing - a fight on the far side of the map shouldn't empty out every drone's weeding queue.
#define AI_XENO_HIVE_ALERT_RESPONSE_RANGE 25
/// Radius around a live hive-alert used to gauge how many same-hive xenos are already converging - see AI_XENO_HIVE_ALERT_MAX_RESPONDERS.
#define AI_XENO_HIVE_ALERT_RESPONDER_RADIUS 10
/// Once this many same-hive xenos are already near a live hive-alert, further idle xenos hold back and stay on their own business instead of also converging - "the queen ordering the other aliens shouldn't be the only way they behave, ultimately they'd scout, weed, take over sections of the map on their own." Unbounded participation also meant a Queen stuck on one bad/unreachable target (the "stall" report) could in principle pull the entire hive toward the same dead end - this caps the blast radius of that too.
#define AI_XENO_HIVE_ALERT_MAX_RESPONDERS 8

// player_order_type (xeno_ai_orders.dm) - a Hive Leader/admin command console
// order issued directly to a selected xeno, distinct from the ambient
// hive-wide broadcasts above. See respond_to_player_order().
/// No active order - normal autonomous behavior (hive alerts, patrol, combat) applies unchanged.
#define PLAYER_ORDER_NONE 0
/// Walk to player_order_turf, then clear and re-anchor there.
#define PLAYER_ORDER_MOVE 1
/// Fight player_order_target - issued via a direct acquire_target() call, not patrol()-level polling.
#define PLAYER_ORDER_ATTACK 2
/// Hold the current tile - suppresses every lower-priority patrol() behavior (building, wandering, resting) without moving; process_target() still runs every tick regardless, so a held xeno still fights back if something wanders adjacent.
#define PLAYER_ORDER_HOLD 3

/// Distance at which an ordered xeno counts as "arrived" for a MOVE order and re-anchors there - matches AI_TRAVEL_DIRECT_RANGE's own short-range tolerance rather than requiring an exact tile match.
#define AI_XENO_PLAYER_ORDER_ARRIVE_RADIUS 3
/// How long a fresh PLAYER_ORDER_ATTACK is protected from check_nearby_threats()'s periodic re-scan stealing focus onto something else - an explicit "attack THIS" order should stick for a few seconds, not get silently swapped the moment a marginally higher-priority target wanders into view. A genuine DELTA-tier threat (an actively-firing turret) still overrides regardless - see check_nearby_threats().
#define AI_XENO_PLAYER_ORDER_COMMIT_WINDOW 5 SECONDS

/// Plasma cost for an AI xeno's own opportunistic combat pheromone burst - matches emit_pheromones()'s own default cost (general_powers.dm) rather than inventing a separate balance number.
#define AI_XENO_PHEROMONE_COST 30
/// How often a Queen/King re-evaluates its aura choice mid-engagement (attempt_periodic_combat_pheromones()) - "I used my healing pheromones to heal everyone... as we marched," not just once at the start of a fight. A few seconds, not every tick - a fresh emit_pheromones() call has its own real plasma cost each time it actually switches.
#define AI_XENO_COMBAT_PHERO_RECHECK_INTERVAL 6 SECONDS
/// There's only ever one Queen at a time, so she can afford a much wider awareness radius than population-scale castes.
#define AI_QUEEN_ATTACK_DISTANCE 18
#define AI_QUEEN_RETURN_DISTANCE 28
/// King is the same kind of solo boss unit as Queen (one per round, not a population-budgeted caste) - "should be as deadly if not more deadly than the Queen," but had no override at all and was stuck on the flat population-default radius, noticing threats far later and giving up chases far sooner than she does.
#define AI_KING_ATTACK_DISTANCE 18
#define AI_KING_RETURN_DISTANCE 28
/// Radius around the Queen used to count how many same-hive daughters already count as her escort.
#define AI_QUEEN_ESCORT_RADIUS 7
/// Stops calling for more escorts once this many are already nearby - "up to 10 daughters."
#define AI_QUEEN_ESCORT_MAX 10
/// Tiles from the Queen an escorting daughter holds at instead of stacking directly on her tile.
#define AI_QUEEN_ESCORT_HOLD_DISTANCE 2
/// Same-hive allies actually fighting alongside her against her own current target (count_engaged_allies()) needed before should_flee() treats her as backed up rather than exposed - "she can easily attack with her escort instead of retreating" instead of only ever standing firm when literally the hive's last living member.
#define AI_QUEEN_ESCORT_STAND_THRESHOLD 2
/// Successful plant_weeds actions the Queen commits to before considering her build duties satisfied - "build her hive" as a real, ongoing priority.
#define AI_QUEEN_MIN_INITIAL_BUILDS 3
/// Minimum time the Queen waits after dismounting before she's willing to mount the ovipositor again - dismounting itself is always instant/unthrottled (a threat is a reflex), only settling back down is a considered decision worth a cooldown so a borderline threat-check doesn't thrash her in and out of ovi every tick.
#define AI_QUEEN_REMOUNT_COOLDOWN 20 SECONDS
/// How often a mounted Queen uses expand_weeds to grow the hive's territory from her throne - "build... in weeded areas" while staying productive on ovi instead of only ever laying eggs.
#define AI_QUEEN_EXPAND_WEEDS_INTERVAL 45 SECONDS
/// Minimum banked stored_larva (hive_status.dm) the Queen requires before she'll voluntarily leave the ovipositor to reinforce a struggling frontline - "deovi and go to the frontline to help if possible" needs enough larvae already saved that leaving doesn't stall the hive's growth while she's away. Playtesting starting point.
#define AI_QUEEN_DEOVI_MIN_LARVA 3
/// Same-hive members already near a live hive-wide push (assault_alert_turf) below which the Queen judges it under-defended enough to personally reinforce - joining a fight that's already well-staffed would just be gambling her for nothing. Playtesting starting point.
#define AI_QUEEN_DEOVI_RESPONDER_THRESHOLD 4
/// Radius expand_weeds' frontier-tile search covers from the Queen's own position.
#define AI_QUEEN_EXPAND_WEEDS_RADIUS 6
/// Living hostiles clustered within this radius of a target before should_close_to_melee() treats it as a real group worth kiting/softening from range instead of just closing in - a confident, dangerous Queen still doesn't walk into a crowd she should spit down first.
#define AI_QUEEN_GROUP_SCREECH_RADIUS 3
/// Minimum clustered hostiles (the primary target plus this many more) before a target counts as "a group" for should_close_to_melee() - a single marine isn't a crowd worth kiting around.
#define AI_QUEEN_GROUP_SCREECH_THRESHOLD 2
/// Target health fraction (0-1) at or below which the Queen closes to finish it in melee instead of continuing to peck at it from range - she's dangerous enough to just win that fight outright once it's this far gone.
#define AI_QUEEN_MELEE_TARGET_HEALTH_PERCENT 0.5

// --- Ranged caste cover discipline (shared by ranged.dm/boiler.dm/sentinel.dm) ---
// A ranged caste's actual priority is knowing when cover is worth it, not being melee-happy
// like Queen - should_hold_and_fight() only ever decides "is retreating to cover still worth
// it right now," never "should I close to melee instead of shooting."
/// Target health fraction (0-1) at or below which a ranged caste holds ground and closes in instead of retreating to cover on ability cooldown - it's already lost, not worth spending the hide-and-wait cycle on.
#define AI_RANGED_HOLD_TARGET_HEALTH_PERCENT 0.5
/// Living hostiles clustered within this radius of a target before should_hold_and_fight() treats it as a real group still worth retreating from - same reasoning as AI_QUEEN_GROUP_SCREECH_RADIUS.
#define AI_RANGED_HOLD_GROUP_RADIUS 3
/// Minimum clustered hostiles (the primary target plus this many more) before a target counts as "a group" for should_hold_and_fight() - a single, nearly-beaten marine doesn't justify hiding from.
#define AI_RANGED_HOLD_GROUP_THRESHOLD 2
/// Health fraction below which a Crusher disengages - lower than the population-wide default since it's meant to be the hive's tank, not a caste that breaks off early, but not so low she has no margin left to actually reach safety - "crusher... dive to their deaths."
#define AI_CRUSHER_FLEE_HEALTH_PERCENT 0.18
/// Percent chance after a Ravager's attack that it sidesteps to a flanking tile instead of standing still - the behavioral stand-in for its "nimble/evasive" identity (there's no actual dodge/evasion stat on the caste).
#define AI_RAVAGER_REPOSITION_CHANCE 25
/// Same damage-reactive-plus-baseline-roll reposition pattern as AI_RAVAGER_REPOSITION_CHANCE, applied to Warrior/Burrower/Hivelord/Predalien in Phase 3 - none of them had any post-attack repositioning at all before this. Starting point for playtesting.
#define AI_WARRIOR_REPOSITION_CHANCE 25
/// Living hostiles within melee range at/above which a Predalien's Frenzy (Eviscerate/Devastate) is considered too risky to use - it roots her in place (TRAIT_IMMOBILIZED) for the full windup, so firing it into a clustered group self-traps her instead of the intended lone-target execute.
#define AI_PREDALIEN_FRENZY_MAX_TARGETS 1
/// Minimum nearby hostiles before a Ravager uses Scissor Cut instead of a plain melee swing.
#define AI_RAVAGER_SCISSOR_MIN_TARGETS 2
/// Minimum nearby hostiles before a Ravager arms Empower - matches the ability's own super-empower payoff threshold, so it's only used in a real group fight where the buff is worth it.
#define AI_RAVAGER_EMPOWER_MIN_TARGETS 3
/// How long a Praetorian/Ravager's tactical retreat lasts once triggered (see start_tactical_retreat()) - "hop into action, slash marines, and hop back into safety, and repeat."
#define AI_PRAETORIAN_RETREAT_DURATION 4 SECONDS
/// Percent chance per plain melee swing (Acid Ball not currently up) that a Praetorian decides she's landed enough hits and retreats anyway.
#define AI_PRAETORIAN_RETREAT_CHANCE 15
/// Same shape as AI_PRAETORIAN_RETREAT_DURATION - Ravager is meant to behave the same way once she's landed a hit.
#define AI_RAVAGER_RETREAT_DURATION 4 SECONDS
/// Percent chance per plain melee swing (Scissor Cut not currently up) that a Ravager retreats anyway, same reasoning as AI_PRAETORIAN_RETREAT_CHANCE.
#define AI_RAVAGER_RETREAT_CHANCE 15
/// How long a Lurker's tactical retreat lasts once triggered - "make retreating a strategic part of their attack plan too, as they attack and die."
#define AI_LURKER_RETREAT_DURATION 5 SECONDS
/// Percent chance per plain melee swing (Assassinate not currently up) that a Lurker retreats to re-cloak instead of continuing to trade blows in the open.
#define AI_LURKER_RETREAT_CHANCE 20
/// Health fraction below which a Runner flees - higher than the population default since she's the hive's glass cannon (lowest HP, no armor), meant to hit and run rather than trade hits.
#define AI_RUNNER_FLEE_HEALTH_PERCENT 0.4
/// "Runners are way too difficult, able to attack 2 people alone and win the fight... calmer to give players a chance." Baseline chance (outside a damage-reactive dodge, same pattern as Ravager's AI_RAVAGER_REPOSITION_CHANCE) that she sidesteps after landing an attack - higher than Ravager's 25 since constant motion is core to her identity, just no longer guaranteed every single tick. Starting point for playtesting.
#define AI_RUNNER_REPOSITION_CHANCE 40
/// Chance Runner actually commits to her Pounce opener once it's off cooldown/in range, instead of just walking in via the normal approach chain - was firing unconditionally the instant it was available, landing a free knockdown every ~3s with no counterplay window. Starting point for playtesting.
#define AI_RUNNER_POUNCE_CHANCE 60
/// Minimum valid targets already adjacent before a Defender uses Tail Sweep instead of a plain melee swing.
#define AI_DEFENDER_SWEEP_MIN_TARGETS 2
/// Boiler's own scan/leash radius - wider than the population default so she notices and starts bombarding from well outside melee range instead of needing a target to wander close first.
#define AI_BOILER_ATTACK_DISTANCE 14
/// Health fraction below which a Boiler flees - higher than the population default since she's fire-vulnerable and low on melee damage, and getting run down is close to a worst case for this caste.
#define AI_BOILER_FLEE_HEALTH_PERCENT 0.4
/// Distance a Boiler retreats to while both her ranged abilities are on cooldown ("attack ranged, hide, then come out again once recharged") - wider than the plain ranged kiting band so she's actually out of easy melee reach while waiting, not just standing at the edge of it.
#define AI_BOILER_HIDE_DISTANCE 8
/// Tiles Bombard's aim point leads a moving target by, in its direction of recent travel - roughly what a marine covers during the ability's 5-second windup, so the shell has a chance of actually landing on her instead of always hitting exactly where they were standing when she started casting.
#define AI_BOILER_BOMBARD_LEAD_TILES 2
/// Percent chance per idle tick that a Hivelord attempts a build action - higher than a Drone's own AI_DRONE_BUILD_CHANCE since her build_time_mult (0.5x) makes her genuinely more efficient at it, not just eager.
#define AI_HIVELORD_BUILD_CHANCE 12
/// Health fraction below which a Carrier disengages - higher than the population default since she has no offensive tools to actually win a fight she's already losing.
#define AI_CARRIER_FLEE_HEALTH_PERCENT 0.4
/// Percent chance per idle tick that a xeno with no better order gravitates toward a nearby idle ally instead of wandering solo - "stick together sometimes in a group."
#define AI_PACK_COHESION_CHANCE 20
/// How close counts as "already sticking together" for pack cohesion - stops short of stacking exactly on the buddy's tile.
#define AI_PACK_COHESION_HOLD_DISTANCE 3
/// Percent chance per idle tick that a xeno instead treks out toward the marine LZ to hide and wait - "hiding to ambush" instead of only ever patrolling near the hive.
#define AI_XENO_AMBUSH_CHANCE 6
/// Half-width of the area around the LZ attempt_ambush_hide() picks a hiding tile within.
#define AI_XENO_AMBUSH_LZ_RADIUS 10
/// How long an ambush hide holds before giving up and resuming normal patrol if nothing shows up.
#define AI_XENO_AMBUSH_HIDE_DURATION 40 SECONDS

/// How often SSxeno_spawner re-evaluates each hive's population - see xeno_spawner.dm.
#define XENO_SPAWNER_CHECK_INTERVAL 20 SECONDS
/// Floor population the Spawner tops a hive up to even with 0 marines online, so it stays "permanently playable." Starting point for playtesting, not final balance.
#define XENO_SPAWNER_BASE_POP 6
/// Additional population target per active (alive, non-AFK) marine - the primary balance lever, scaled further by GLOB.ai_difficulty_multiplier. Starting point for playtesting, not final balance.
#define XENO_SPAWNER_POP_PER_MARINE 1.5
/// Safety rail against a pathological formula result (every slider maxed) - several multiples above any realistic target. This is NOT a reintroduction of the old hard population cap; the real ceiling in normal play is the live, marine-count-derived target itself (see spawner_target_population()).
#define XENO_SPAWNER_MAX_POP 50
/// How long the Spawner waits after a failed Queen-respawn attempt (no valid turf) before retrying - avoids hammering a failing spawn every subsystem tick.
#define XENO_SPAWNER_QUEEN_RETRY_INTERVAL 30 SECONDS
/// Most new xenos the Spawner will place in a single pass - a long-downtime gap (e.g. the Director was just re-enabled) shouldn't dump a huge batch on one tick.
#define XENO_SPAWNER_MAX_PER_FIRE 3
/// Delay after round-start's post_setup signal before hive_status/post_setup()'s round-start Queen guarantee fires - long enough for the normal player-candidate Queen-spawn flow (job equip) to have already run.
#define XENO_ROUNDSTART_QUEEN_GUARANTEE_DELAY 30 SECONDS

// Hive pressure rhythm (SSxeno_spawner, L4D-director style): the spawner
// cycles buildup -> assault -> lull instead of applying constant, even
// pressure, so marines get tension cycles and each push lands as an event.
// All durations are playtesting starting points, scaled by the difficulty
// multiplier (higher difficulty = shorter lulls/buildups, longer assaults).
#define HIVE_PHASE_BUILDUP "buildup"
#define HIVE_PHASE_ASSAULT "assault"
#define HIVE_PHASE_LULL "lull"
/// Buildup phase duration bounds - population fills, xenos patrol/build normally.
#define XENO_SPAWNER_BUILDUP_MIN 3 MINUTES
#define XENO_SPAWNER_BUILDUP_MAX 5 MINUTES
/// Assault phase duration bounds - hive-wide attack broadcast toward the marine center of mass, spawn rate doubled.
#define XENO_SPAWNER_ASSAULT_MIN 90 SECONDS
#define XENO_SPAWNER_ASSAULT_MAX 120 SECONDS
/// Minimum drift (tiles) between the currently-broadcast assault turf and a freshly-recomputed one before update_hive_phase() actually moves it - spawner_marine_mass_turf() picks whichever living marine is closest to the group's average position, which flips identity (and therefore turf) between two similarly-placed marines as they move; without this every hive-wide responder reversed direction in lockstep on every 20-second recheck. Playtesting starting point.
#define XENO_SPAWNER_ASSAULT_TURF_UPDATE_THRESHOLD 8
/// Lull phase duration - spawning paused, no broadcasts; the recovery beat that makes the next assault land.
#define XENO_SPAWNER_LULL_DURATION 60 SECONDS
/// Tiles around the assault turf checked for a living, hostile marine before update_hive_phase() banks it as frontier_turf on the ASSAULT -> LULL transition - "the goal is always to take over the colony... not just staying in their spawn positions." Ground still actively contested doesn't get banked as won.
#define XENO_FRONTIER_CONTEST_RADIUS 10
/// A spawn-point landmark closer than this to a living marine is skipped entirely - "weighted near marines" should put new xenos near the action, not directly in someone's face.
#define XENO_SPAWNER_PLACEMENT_MIN_MARINE_DIST 6
/// How many tiles wider than the single nearest-to-a-marine spawn point spawner_pick_spawn_turf() still considers "tied" and picks randomly among - same reasoning as find_cover_turf()'s AI_XENO_COVER_VARIETY_TOLERANCE, avoids every spawn landing on the exact same landmark.
#define XENO_SPAWNER_PLACEMENT_VARIETY_TOLERANCE 8
/// Percent chance the Spawner also assigns a random strain (from the caste's own available_strains) to a freshly-spawned AI xeno, on top of just picking its caste - "special AI per strains for each alien" needs some AI xenos to actually carry a strain first, since nothing ever assigned one before this. Starting point for playtesting, not final balance.
#define XENO_SPAWNER_STRAIN_CHANCE 35

/// Search radius for find_nearby_ally_xeno() - same scale as AI_XENO_DEFENSIBLE_SEARCH_RADIUS. Used by strain abilities that target a friendly xeno instead of a hostile (Healer's Apply Salve, Valkyrie's Rage/Prae Retrieve).
#define AI_XENO_ALLY_SCAN_RADIUS 8
/// Health fraction (0-1, both the Healer AND the target ally) below which a Healer strain Drone will consider Sacrifice - it kills the caster outright, so this is deliberately conservative, not a casual heal substitute. Starting point for playtesting, not final balance.
#define AI_HEALER_SACRIFICE_HEALTH_PERCENT 0.3
/// Health fraction below which an Acider strain Runner will consider For The Hive (self-destruct) as a last resort - deliberately low, same conservative-suicide-ability spirit as AI_HEALER_SACRIFICE_HEALTH_PERCENT. Starting point for playtesting, not final balance.
#define AI_ACIDER_LAST_STAND_HEALTH_PERCENT 0.15

// --- Threat-priority retargeting ---
// get_target_priority() scores every candidate target on a common scale so the controller
// can compare "what I'm currently fighting" against "what just hit me" or "what's nearby"
// instead of the old all-or-nothing rule (never reconsider once current_target is set).
/// Baseline priority for a human target that's stationary, unarmed, and unarmored - present but not worth breaking off an existing fight for.
#define AI_PRIORITY_LOW 2
/// Priority for a human with all threat factors present (moving, weapon drawn, armored), or an active-but-not-currently-firing turret/crewed vehicle - a real, on-its-own-worth-switching-to threat.
#define AI_PRIORITY_HIGH 10
/// Reserved for a threat actively harming the pilot right now (a turret with its barrel on the pilot and cycling) - always wins a retarget comparison, no margin required, and should also weigh into should_flee() same as any other lethal threat.
#define AI_PRIORITY_DELTA 1000
/// Per-factor priority bump for a human target: moving recently, weapon drawn, wearing body armor. Three factors x this = spans LOW to HIGH.
#define AI_PRIORITY_HUMAN_FACTOR_WEIGHT 2.5
/// world.time window since last_move_time within which a human counts as "moving" for priority purposes.
#define AI_PRIORITY_MOVING_WINDOW 2 SECONDS
/// Priority bonus for a candidate at melee range, tapering to 0 by AI_PRIORITY_DISTANCE_TAPER tiles - closer is scarier, same reasoning motion detectors already use distance for.
#define AI_PRIORITY_DISTANCE_BONUS_MAX 2
/// Distance (tiles) at which the closeness bonus above fully tapers to 0.
#define AI_PRIORITY_DISTANCE_TAPER 7
/// Minimum priority margin a new candidate must beat the current target by before check_retaliation()/periodic re-scan will actually switch - keeps a slightly-better nearby target from causing constant flip-flopping instead of finishing a fight.
#define AI_PRIORITY_RETARGET_MARGIN 3
/// How often (world.time) the controller re-scans for a higher-priority target while already engaged, independent of being hit - lets a xeno notice e.g. a turret powering on nearby without needing to be shot first. Not every tick: same performance reasoning as everything else in this controller.
#define AI_PRIORITY_RESCAN_INTERVAL 3 SECONDS
/// Consecutive process_attack() ticks against the same current_target with zero recorded health-delta before the controller gives up and drops it - process_attack() otherwise has no timeout at all, unlike movement (blocked_attempts) and search (AI_XENO_SEARCH_TIMEOUT), so a target the pilot mechanically can't damage was fought forever.
#define AI_PRIORITY_STALE_ATTACK_GIVEUP 4

// Vent-crawling (xeno_ai_ventcrawl.dm) - see attempt_ventcrawl_travel()'s doc comment for the overall shape.
/// Hard cap on nodes visited by find_vent_path()'s BFS - a malformed/huge duct network degrades to "no route" instead of hanging the coroutine, same philosophy as XENO_PATHFIND_MAX_CELLS for the turf-grid solver.
#define AI_VENT_PATHFIND_MAX_NODES 400
/// world.time slept between each forceMove() hop of ai_ventcrawl_traverse() - NOT mimicking relaymove()'s own timing (intermediate pipe-to-pipe movement is instant there, no do_after at all - only entering/exiting a vent has a real channel). This is a deliberate AI-only pacing choice: fast enough to read as a quick crawl rather than a stall, but non-zero so the whole route doesn't resolve in a single tick and the per-hop safety re-checks (segment welded/destroyed mid-transit) are actually meaningful rather than vacuous.
#define AI_VENT_HOP_DELAY 3
/// Minimum direct-walk distance before a vent-crawl route is even considered - same role as AI_TUNNEL_MIN_TRIP for the tunnel network.
#define AI_VENT_MIN_TRIP 20
/// Tiles of advantage a vent route (entry walk + resolved hop count + exit walk) must have over the direct walk distance to be worth it - hop count stands in for pipe-transit cost since duct runs don't follow open terrain, so this needs more slack than a guaranteed-direct tunnel hop.
#define AI_VENT_TRIP_OVERHEAD 15
/// Hard cap on a resolved pipe route's length (hops) - beyond this a "technically shorter than walking" route is almost certainly a pathological duct layout, not a real shortcut worth taking.
#define AI_VENT_MAX_HOPS 60
/// Percent chance per approach tick that an eligible caste already closing on a target instead detours to vent-crawl into ambush range - kept low, same reasoning as AI_XENO_AMBUSH_CHANCE/AI_BURROWER_AMBUSH_CHANCE.
#define AI_VENT_AMBUSH_CHANCE 8
