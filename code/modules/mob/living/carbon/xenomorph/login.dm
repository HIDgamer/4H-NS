/mob/living/carbon/xenomorph/Login()
	if(ai_controller)
		detach_xeno_ai(src) // A ghost just claimed this mob (claim_freed/mind.transfer_to already fired) - hand off cleanly before normal player setup runs.
	..()
	if(client)
		set_lighting_alpha_from_prefs(client)
		if(client.player_data)
			generate_name()
	if(SSticker.mode)
		SSticker.mode.xenomorphs |= mind
	if(selected_ability)
		set_selected_ability(null)

/mob/living/carbon/xenomorph/Logout()
	..()
	if(was_ai_spawned && !ai_controller)
		reattach_xeno_ai_on_disconnect(src) // Falls back to AI control so AI-spawned mobs don't go idle just because their ghost pilot disconnected. Ordinary players are unaffected (was_ai_spawned is only ever set by spawn_ai_xeno()).
