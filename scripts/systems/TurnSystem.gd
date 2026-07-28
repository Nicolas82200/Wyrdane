extends Node
class_name TurnSystem

var battle

func init(_battle) -> void:
	battle = _battle

func end_turn() -> void:
	# Capture les ids des serviteurs créés par les déclencheurs de fin de tour
	# (ex. Dernier Souffle), pour que le pair les rejoue avec les mêmes ids.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	await run_turn_end_triggers()
	await battle.temp_effect_system.expire_end_of_player_turn()
	battle.cost_system.expire_end_of_player_turn()  # remises "ce tour"
	battle.counter_offensive[true] = false  # "ce tour" : la Contre-Offensive expire
	battle.hero_system.self_damage_blocked[true] = false  # Absolution Écarlate expire
	# Émission réseau : dernière commande du tour local (porte les ids de triggers).
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.end_turn(ids)
	await battle.opponent.take_turn()
	if battle.game_over:
		return
	await battle.temp_effect_system.expire_end_of_enemy_turn()
	battle.counter_offensive[false] = false  # "ce tour" : la Contre-Offensive expire
	battle.hero_system.self_damage_blocked[false] = false
	await _begin_player_turn()

# Phase de fin de tour (Infection). is_local_turn : true si c'est le tour du
# joueur local. Le déclencheur "fin de tour" côté cartes est porté par Déclin
# (OnDecline, déclenché juste après pour le camp dont le tour vient de finir).
func run_turn_end_triggers(is_local_turn: bool = true) -> void:
	# Blocage de soin (Rituel de la Terreur) : expire à la fin du tour du héros
	# dont c'est le tour ("jusqu'à la fin de son prochain tour").
	var turn_hero: Hero = battle.player_hero if is_local_turn else battle.enemy_hero
	turn_hero.heal_block_turns = max(turn_hero.heal_block_turns - 1, 0)

	await _apply_infection_damage()

func _begin_player_turn() -> void:
	# Capture les ids des serviteurs créés par les déclencheurs de début de tour.
	if battle.net_emitter != null:
		battle.net_registry.begin_capture()
	await run_turn_start_triggers(true)
	# Émission réseau : le pair rejoue la même phase pour le tour qui commence.
	if battle.net_emitter != null:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.turn_start(ids)
	_finish_turn_start()
	battle.deck_system.draw_card()
	if battle.tutorial_active:
		if battle.tutorial_manager:
			await battle.tutorial_manager.notify_player_turn_began()
	else:
		battle.turn_timer.start()

# Phase de début de tour. is_local_turn : true si c'est le tour du joueur local.
# OnAwaken vise le camp dont c'est le tour, OnDecline le camp adverse (dont le
# tour vient de finir) — d'où le paramétrage pour le rejeu.
func run_turn_start_triggers(is_local_turn: bool) -> void:
	battle.aura_system.recompute_all()
	await battle.death_system.process_deaths()
	battle.cost_system.on_turn_started(is_local_turn)
	battle.trigger_system.reset_once_per_turn(is_local_turn)
	battle.resource_played_this_turn[is_local_turn] = false
	var turn_minions: Array = battle.player_minions if is_local_turn else battle.enemy_minions
	var other_minions: Array = battle.enemy_minions if is_local_turn else battle.player_minions
	for minion in turn_minions.duplicate():
		minion.refresh_attacks()
	var acted := false
	# Ordre relatif au joueur du tour (identique sur les deux clients) plutôt que
	# player/enemy relatif au client, pour un tirage RNG déterministe.
	acted = await _trigger_minions_paced(turn_minions, "OnAwaken", acted)
	acted = await battle.trigger_system.fire("OnAwaken", null, is_local_turn, {}, true, acted)
	acted = await _trigger_minions_paced(other_minions, "OnDecline", acted)
	acted = await battle.trigger_system.fire("OnDecline", null, not is_local_turn, {}, true, acted)

# Déclenche un trigger sur chaque serviteur de la liste, avec une pause AVANT
# chaque déclenchement sauf le premier de la file. Retourne l'état "acted"
# pour chaîner le pacing sur la suite de la phase.
func _trigger_minions_paced(minions: Array, trigger_name: String, already_acted: bool) -> bool:
	var acted := already_acted
	for minion in minions.duplicate():
		if not battle.effect_manager.has_trigger(minion, trigger_name):
			continue
		if acted:
			await battle.pace_actions()
		await battle.effect_manager.trigger_effects(battle, minion, trigger_name)
		acted = true
	return acted

func _apply_infection_damage() -> void:
	var any_infected := false
	for minion in (battle.player_minions + battle.enemy_minions).duplicate():
		if minion.infected:
			any_infected = true
			var dealt: int = minion.take_damage(1)
			if dealt > 0:
				battle.combat_log.infection_tick(minion)
				var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
				if visual:
					battle.animation_system.play_infection_tick(visual, dealt)
				await battle.effect_manager.notify_damaged(battle, minion)
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	if any_infected:
		await battle.pace_actions()

func _finish_turn_start() -> void:
	battle.refill_mana_pool(true)
	battle.update_mana_ui()
	battle.board_visual_system.refresh_board()
