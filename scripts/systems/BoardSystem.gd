extends Node
class_name BoardSystem

var battle


var _firing_on_summon: bool = false

func init(_battle) -> void:
	battle = _battle

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false) -> void:
	await summon_minion_return(card_data, is_player, row, insert_index, skip_onplay)

func _has_row_overflow_ally(is_player: bool) -> bool:
	var camp: Array = battle.player_minions if is_player else battle.enemy_minions
	return camp.any(func(m: Minion): return m.card_data != null and m.card_data.allows_row_overflow)

func summon_minion_return(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false, onplay_target: Minion = null) -> Minion:
	if not battle.can_summon_to_row(is_player, row):
		var alt_row: String = "Back" if row == "Front" else "Front"
		if _has_row_overflow_ally(is_player) and battle.can_summon_to_row(is_player, alt_row):
			row = alt_row
		else:
			push_warning("Rangée %s pleine, impossible d'invoquer %s" % [row, card_data.card_name])
			return null
	var minion := Minion.new(card_data, is_player, row)
	battle.net_registry.register(minion)
	battle.combat_log.card_played(card_data, is_player)
	_insert(minion, is_player, row, insert_index)
	var commandement_applied: bool = _apply_commandement_bonus(minion, is_player)
	var chair_adaptative_source: Minion = _apply_chair_adaptative(minion)
	_spawn(minion, is_player)
	AudioManager.play_for_style(AudioManager.SUMMON, card_data.unit_style)
	await battle.get_tree().create_timer(0.2).timeout

	var minion_visual: BoardMinion = battle.board_visual_system.find_visual(minion)
	if commandement_applied:
		battle.animation_system.play_commandement_buff(minion_visual)
	if chair_adaptative_source != null:
		var source_visual: BoardMinion = battle.board_visual_system.find_visual(chair_adaptative_source)
		battle.animation_system.play_chair_adaptative_copy(source_visual, minion_visual)
	if minion.has_keyword(Keyword.Type.CHARGE):
		battle.animation_system.play_charge_ready(minion_visual)


	if not skip_onplay:
		await battle.effect_manager.trigger_effects(battle, minion, "ONPLAY", onplay_target)


	if not _firing_on_summon:
		_firing_on_summon = true
		var allies: Array[Minion] = (battle.player_minions if is_player else battle.enemy_minions).duplicate()
		for ally in allies:
			if ally != minion:
				await battle.effect_manager.trigger_effects(battle, ally, "OnSummon")

		await battle.trigger_system.fire("OnSummon", minion, is_player)
		_firing_on_summon = false
	battle.aura_system.recompute_all()
	await battle.death_system.process_deaths()
	battle.board_visual_system.refresh_board()
	return minion

func _apply_commandement_bonus(minion: Minion, is_player: bool) -> bool:
	if minion.card_data.race != Race.Type.HUMAN:
		return false
	var allies: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	var applied := false
	for ally in allies:
		if ally != minion and ally.has_human_keyword(KeywordHuman.Type.COMMANDEMENT):
			minion.base_attack += 1
			applied = true
	return applied

# CHAIR ADAPTATIVE (Abomination) : Arrivée — copie un mot-clé présent sur un
# serviteur ALLIÉ adjacent, de façon permanente. Simplification par rapport au
# texte (« allié ou ennemi ») : le plateau n'ayant pas de notion de position
# géométrique inter-camp (les rangées adverses ne sont pas indexées en miroir),
# seule l'adjacence alliée est résolue ici. Choix déterministe (premier trouvé),
# faute d'UI de sélection.
func _apply_chair_adaptative(minion: Minion) -> Minion:
	if not minion.has_abomination_keyword(KeywordAbomination.Type.CHAIR_ADAPTATIVE):
		return null
	for adjacent in battle.effect_manager._get_adjacent_minions(battle, minion):
		if not adjacent.keywords.is_empty():
			minion.add_keyword(adjacent.keywords[0])
			return adjacent
		if not adjacent.human_keywords.is_empty():
			minion.add_human_keyword(adjacent.human_keywords[0])
			return adjacent
		if not adjacent.undead_keywords.is_empty():
			minion.undead_keywords.append(adjacent.undead_keywords[0])
			return adjacent
		if not adjacent.demon_keywords.is_empty():
			minion.add_demon_keyword(adjacent.demon_keywords[0])
			return adjacent
		for kw in adjacent.abomination_keywords:
			if kw != KeywordAbomination.Type.CHAIR_ADAPTATIVE:
				minion.add_abomination_keyword(kw)
				return adjacent
	return null

func _insert(minion: Minion, is_player: bool, row: String, insert_index: int) -> void:
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	var row_count: int = _get_row_count(minions, row)
	insert_index = clamp(insert_index, 0, row_count) if insert_index >= 0 else row_count
	var seen_in_row: int = 0
	for i in range(minions.size()):
		if minions[i].board_row != row:
			continue
		if seen_in_row == insert_index:
			minions.insert(i, minion)
			return
		seen_in_row += 1
	minions.append(minion)

func _get_row_count(minions: Array[Minion], row: String) -> int:
	var count: int = 0
	for minion in minions:
		if minion.board_row == row:
			count += 1
	return count

func _spawn(minion: Minion, is_player: bool) -> void:
	battle.board_visual_system.spawn_minion_visual(minion, is_player)
