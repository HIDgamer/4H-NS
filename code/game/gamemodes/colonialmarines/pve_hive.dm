/**
 * PVE Hive - the standard Distress Signal marine-vs-hive fight, but the only gamemode where the
 * AI Xeno Spawner (SSxeno_spawner, code/controllers/subsystem/xeno_spawner.dm) runs
 * automatically. Subclasses colonialmarines.dm wholesale rather than duplicating any of its
 * marine setup/spawn/win-condition logic - the only thing PVE Hive changes is forcing the AI
 * hive economy on, since the AI system already supports live xeno players freely coexisting
 * with (and taking over) AI-piloted xenos via the existing ghost-claim mechanism
 * (attach_xeno_ai()'s free_for_ghosts() call, xeno_ai_lifecycle.dm) - nothing about the roles
 * list or role gating needs to differ from the base mode.
 *
 * Every other gamemode keeps the Spawner off by default (game_mode.dm's base pre_setup() resets
 * GLOB.xeno_spawner_enabled to FALSE before any mode's own setup runs) - this file only owns
 * turning it back on for itself.
 */
/datum/game_mode/colonialmarines/pve_hive
	name = GAMEMODE_PVE_HIVE
	config_tag = GAMEMODE_PVE_HIVE
	// The AI Spawner bootstraps its own Queen and population from nothing (spawner_ensure_queen(),
	// xeno_spawner.dm) - a round shouldn't fail to start just because no player wants the Xeno
	// role this round, that's the entire point of this mode existing.
	xeno_required_num = 0

/datum/game_mode/colonialmarines/pve_hive/pre_setup()
	. = ..()
	GLOB.xeno_spawner_enabled = TRUE
	GLOB.xeno_spawner_hive = XENO_HIVE_NORMAL
