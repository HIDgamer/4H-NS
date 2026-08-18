/*

TODO:
give money an actual use (QM stuff, vending machines)
send money to people (might be worth attaching money to custom database thing for this, instead of being in the ID)
log transactions

*/

#define NO_SCREEN 0
#define CHANGE_SECURITY_LEVEL 1
#define TRANSFER_FUNDS 2
#define VIEW_TRANSACTION_LOGS 3

/obj/item/card/id/var/money = 2000

/obj/structure/machinery/atm
	name = "Wey-Yu Automatic Teller Machine"
	desc = "For all your monetary needs!"
	icon = 'icons/obj/structures/machinery/terminals.dmi'
	icon_state = "atm"
	anchored = TRUE
	use_power = USE_POWER_IDLE
	idle_power_usage = 10
	var/datum/money_account/authenticated_account
	var/number_incorrect_tries = 0
	var/previous_account_number = 0
	var/max_pin_attempts = 3
	var/ticks_left_locked_down = 0
	var/ticks_left_timeout = 0
	var/machine_id = ""
	var/obj/item/card/held_card
	var/editing_security_level = 0
	var/view_screen = NO_SCREEN
	var/datum/effect_system/spark_spread/spark_system
	var/withdrawal_timer = 0

/obj/structure/machinery/atm/New()
	..()
	machine_id = "[MAIN_SHIP_NAME] RT #[GLOB.num_financial_terminals++]"
	spark_system = new /datum/effect_system/spark_spread
	spark_system.set_up(5, 0, src)
	spark_system.attach(src)

/obj/structure/machinery/atm/Destroy()
	QDEL_NULL(spark_system)
	return ..()

/obj/structure/machinery/atm/attackby(obj/item/I as obj, mob/user as mob)
	if(inoperable())
		to_chat(user, SPAN_NOTICE("You try to use it ,but it appears to be unpowered!"))
		return //so it doesnt brazil IDs when unpowered
	if(istype(I, /obj/item/card))
		var/obj/item/card/id/idcard = I
		if(!held_card)
			usr.drop_held_item()
			idcard.forceMove(src)
			held_card = idcard
			if(authenticated_account && held_card.associated_account_number != authenticated_account.account_number)
				authenticated_account = null
	else if(authenticated_account)
		if(istype(I,/obj/item/spacecash))
			var/obj/item/spacecash/spacecash = I
			//consume the money
			if(spacecash.counterfeit)
				authenticated_account.money += floor(spacecash.worth * 0.25)
				visible_message(SPAN_DANGER("[src] starts sparking and making error noises as you load [I] into it!"))
				spark_system.start()
			else
				authenticated_account.money += spacecash.worth
			if(prob(50))
				playsound(loc, 'sound/items/polaroid1.ogg', 15, 1)
			else
				playsound(loc, 'sound/items/polaroid2.ogg', 15, 1)

			//create a transaction log entry
			var/datum/transaction/T = new()
			T.target_name = authenticated_account.owner_name
			T.purpose = "Credit deposit"
			T.amount = I:worth
			T.source_terminal = machine_id
			T.date = GLOB.current_date_string
			T.time = worldtime2text()
			authenticated_account.transaction_log.Add(T)

			to_chat(user, SPAN_INFO("You insert [I] into [src]."))
			src.attack_hand(user)
			qdel(I)
	else
		. = ..()

/obj/structure/machinery/atm/proc/drop_money(turf)
		playsound(turf, "sound/machines/ping.ogg", 15)
		new /obj/item/spacecash/c100(turf)

/obj/structure/machinery/atm/attack_hand(mob/user as mob)
	if(isRemoteControlling(user))
		to_chat(user, SPAN_DANGER("[icon2html(src, usr)] Artificial unit recognized. Artificial units do not currently receive monetary compensation, as per Weyland-Yutani regulation #1005."))
		return
	if(get_dist(src, user) <= 1)
		if(ishuman(user))
			scan_user(user)
		tgui_interact(user)
		return

/obj/structure/machinery/atm/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ATM", "Weyland-Yutani ATM")
		ui.open()

/obj/structure/machinery/atm/ui_state(mob/user)
	return GLOB.always_state

/obj/structure/machinery/atm/ui_data(mob/user)
	var/list/data = list()
	data["machine_id"] = machine_id
	data["locked_down"] = ticks_left_locked_down > 0
	data["has_card"] = !!held_card
	data["card_name"] = held_card?.name || ""
	data["withdrawal_cooldown"] = max(0, round((withdrawal_timer - world.time) / 10))
	if(authenticated_account)
		data["authenticated"] = TRUE
		data["suspended"] = authenticated_account.suspended
		data["owner"] = authenticated_account.owner_name
		data["balance"] = authenticated_account.money
		data["account_number"] = authenticated_account.account_number
		data["security_level"] = authenticated_account.security_level
		data["screen"] = view_screen
		var/list/logs = list()
		for(var/datum/transaction/T in authenticated_account.transaction_log)
			logs += list(list(
				"date"     = T.date,
				"time"     = T.time,
				"target"   = T.target_name,
				"purpose"  = T.purpose,
				"amount"   = T.amount,
				"terminal" = T.source_terminal,
			))
		data["transaction_log"] = logs
	else
		data["authenticated"] = FALSE
	return data

/obj/structure/machinery/atm/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	switch(action)
		if("eject_card")
			if(held_card)
				release_held_id(user)
				SStgui.update_uis(src)
			return TRUE
		if("attempt_auth")
			if(ticks_left_locked_down)
				return TRUE
			if(ishuman(user))
				scan_user(user)
			if(!authenticated_account)
				var/tried_acc = text2num(params["account_num"])
				if(!tried_acc && held_card)
					tried_acc = held_card.associated_account_number
				var/tried_pin = text2num(params["pin"])
				authenticated_account = attempt_account_access(tried_acc, tried_pin, held_card && held_card.associated_account_number == tried_acc ? 2 : 1)
				if(!authenticated_account)
					number_incorrect_tries++
					if(previous_account_number == tried_acc)
						if(number_incorrect_tries > max_pin_attempts)
							ticks_left_locked_down = 30
							playsound(src, 'sound/machines/buzz-two.ogg', 25, 1)
						else
							to_chat(user, SPAN_DANGER("[icon2html(src, usr)] Incorrect PIN. [max_pin_attempts - number_incorrect_tries] attempt\s remaining."))
							previous_account_number = tried_acc
							playsound(src, 'sound/machines/buzz-sigh.ogg', 25, 1)
					else
						to_chat(user, SPAN_DANGER("[icon2html(src, usr)] Incorrect account/PIN combination."))
						number_incorrect_tries = 0
					previous_account_number = tried_acc
				else
					playsound(src, 'sound/machines/twobeep.ogg', 25, 1)
					ticks_left_timeout = 120
					view_screen = NO_SCREEN
					number_incorrect_tries = 0
					var/datum/transaction/T = new()
					T.target_name = authenticated_account.owner_name
					T.purpose    = "Remote terminal access"
					T.source_terminal = machine_id
					T.date       = GLOB.current_date_string
					T.time       = worldtime2text()
					authenticated_account.transaction_log.Add(T)
					to_chat(user, SPAN_NOTICE("[icon2html(src, usr)] Access granted. Welcome, [authenticated_account.owner_name]."))
			SStgui.update_uis(src)
			return TRUE
		if("logout")
			authenticated_account = null
			view_screen = NO_SCREEN
			SStgui.update_uis(src)
			return TRUE
		if("set_screen")
			view_screen = text2num(params["screen"])
			SStgui.update_uis(src)
			return TRUE
		if("withdraw")
			if(!authenticated_account || authenticated_account.suspended)
				return TRUE
			if(withdrawal_timer > world.time)
				to_chat(user, SPAN_WARNING("[icon2html(src, usr)] Please wait before making another withdrawal."))
				return TRUE
			var/amount = max(round(text2num(params["amount"]), 0.01), 0)
			if(amount <= 0 || amount > authenticated_account.money)
				return TRUE
			authenticated_account.money -= amount
			if(params["type"] == "ewallet")
				spawn_ewallet(amount, src.loc, user)
			else
				spawn_money(amount, src.loc, user)
			playsound(src, 'sound/machines/chime.ogg', 25, 1)
			var/datum/transaction/T = new()
			T.target_name = authenticated_account.owner_name
			T.purpose     = "Credit withdrawal"
			T.amount      = "([amount])"
			T.source_terminal = machine_id
			T.date        = GLOB.current_date_string
			T.time        = worldtime2text()
			authenticated_account.transaction_log.Add(T)
			withdrawal_timer = world.time + 20
			SStgui.update_uis(src)
			return TRUE
		if("transfer")
			if(!authenticated_account || authenticated_account.suspended)
				return TRUE
			var/amount = max(round(text2num(params["amount"]), 0.01), 0)
			if(amount <= 0 || amount > authenticated_account.money)
				return TRUE
			var/target_acc = text2num(params["target_acc"])
			var/purpose    = params["purpose"] || "Funds transfer"
			if(charge_to_account(target_acc, authenticated_account.owner_name, purpose, machine_id, amount))
				authenticated_account.money -= amount
				var/datum/transaction/T = new()
				T.target_name = "Account #[target_acc]"
				T.purpose     = purpose
				T.amount      = "([amount])"
				T.source_terminal = machine_id
				T.date        = GLOB.current_date_string
				T.time        = worldtime2text()
				authenticated_account.transaction_log.Add(T)
				to_chat(user, SPAN_NOTICE("[icon2html(src, usr)] Transfer successful."))
			else
				to_chat(user, SPAN_WARNING("[icon2html(src, usr)] Transfer failed."))
			SStgui.update_uis(src)
			return TRUE
		if("change_security")
			if(!authenticated_account)
				return TRUE
			authenticated_account.security_level = clamp(text2num(params["level"]), 0, 2)
			SStgui.update_uis(src)
			return TRUE
		if("print_statement")
			if(!authenticated_account)
				return TRUE
			var/obj/item/paper/R = new(src.loc)
			R.name = "Account Statement: [authenticated_account.owner_name]"
			R.info = "<b>WY Automated Teller Account Statement</b><br><br>"
			R.info += "<i>Account holder:</i> [authenticated_account.owner_name]<br>"
			R.info += "<i>Account number:</i> [authenticated_account.account_number]<br>"
			R.info += "<i>Balance:</i> $[authenticated_account.money]<br>"
			R.info += "<i>Date and time:</i> [worldtime2text()], [GLOB.current_date_string]<br>"
			R.info += "<i>Service terminal ID:</i> [machine_id]<br>"
			var/image/stamp = image('icons/obj/items/paper.dmi')
			stamp.icon_state = "paper_stamp-weyyu"
			if(!R.stamped) R.stamped = new
			R.stamped += /obj/item/tool/stamp
			R.overlays += stamp
			R.stamps += "<HR><i>Stamped by WY Automatic Teller Machine.</i>"
			playsound(loc, prob(50) ? 'sound/items/polaroid1.ogg' : 'sound/items/polaroid2.ogg', 15, 1)
			return TRUE
		if("print_log")
			if(!authenticated_account)
				return TRUE
			var/obj/item/paper/R = new(src.loc)
			R.name = "Transaction Log: [authenticated_account.owner_name]"
			R.info = "<b>Transaction Log</b><br>"
			R.info += "<i>Account holder:</i> [authenticated_account.owner_name]<br>"
			R.info += "<i>Service terminal ID:</i> [machine_id]<br><br>"
			for(var/datum/transaction/T in authenticated_account.transaction_log)
				R.info += "[T.date] [T.time] | [T.target_name] | [T.purpose] | $[T.amount]<br>"
			var/image/stamp = image('icons/obj/items/paper.dmi')
			stamp.icon_state = "paper_stamp-weyyu"
			if(!R.stamped) R.stamped = new
			R.stamped += /obj/item/tool/stamp
			R.overlays += stamp
			R.stamps += "<HR><i>Stamped by WY Automatic Teller Machine.</i>"
			playsound(loc, prob(50) ? 'sound/items/polaroid1.ogg' : 'sound/items/polaroid2.ogg', 15, 1)
			return TRUE

//stolen wholesale and then edited a bit from newscasters, which are awesome and by Agouri
/obj/structure/machinery/atm/proc/scan_user(mob/living/carbon/human/human_user as mob)
	if(authenticated_account)
		return
	var/obj/item/card/id/card = human_user.get_idcard()
	if(!card)
		return

	authenticated_account = attempt_account_access(card.associated_account_number)
	if(!authenticated_account)
		return

	to_chat(human_user, SPAN_NOTICE("[icon2html(src, human_user)] Access granted. Welcome user '[authenticated_account.owner_name].'"))

	//create a transaction log entry
	var/datum/transaction/log = new()
	log.target_name = authenticated_account.owner_name
	log.purpose = "Remote terminal access"
	log.source_terminal = machine_id
	log.date = GLOB.current_date_string
	log.time = worldtime2text()
	authenticated_account.transaction_log.Add(log)

	view_screen = NO_SCREEN

// put the currently held id on the ground or in the hand of the user
/obj/structure/machinery/atm/proc/release_held_id(mob/living/carbon/human/human_user as mob)
	if(!held_card)
		return

	held_card.forceMove(src.loc)
	authenticated_account = null

	if(ishuman(human_user) && !human_user.get_active_hand())
		human_user.put_in_hands(held_card)
	held_card = null
/obj/structure/machinery/atm/verb/eject_id()
	set category = "Object"
	set name = "Eject ID Card"
	set src in view(1)

	if(!usr || usr.is_mob_incapacitated())
		return

	if(ishuman(usr) && held_card)
		to_chat(usr, "You remove \the [held_card] from \the [src].")
		held_card.forceMove(get_turf(src))
		if(!usr.get_active_hand() && istype(usr,/mob/living/carbon/human))
			usr.put_in_hands(held_card)
		held_card = null
		authenticated_account = null
	else
		to_chat(usr, "There is nothing to remove from \the [src].")
	return

/obj/structure/machinery/atm/proc/spawn_ewallet(sum, loc, mob/living/carbon/human/human_user as mob)
	var/obj/item/spacecash/ewallet/E = new /obj/item/spacecash/ewallet(loc)
	if(ishuman(human_user) && !human_user.get_active_hand())
		human_user.put_in_hands(E)
	E.worth = sum
	E.owner_name = authenticated_account.owner_name
