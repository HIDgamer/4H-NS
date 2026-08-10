/// Admin-tool sound polish — real sampled cues for infrequent, meaningful moments
/// (successful spawn confirmations), as opposed to the synthesized Web Audio blips
/// (common/audio.ts) used for frequent low-stakes clicks. Sent only to admin tools that need it
/// via ui_assets(), not on login, since non-admins never open these interfaces.
/datum/asset/simple/admin_ui_sounds
	keep_local_name = TRUE
	assets = list(
		"admin_spawn_confirm.ogg" = 'sound/machines/terminal_prompt_confirm.ogg',
	)
