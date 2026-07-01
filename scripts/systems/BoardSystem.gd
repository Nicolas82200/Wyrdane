extends Node
class_name BoardSystem

var battle: Node

func init(_battle: Node) -> void:
	battle = _battle

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	await summon_minion_return(card_data, is_player, row, insert_index)

func summon_minion_return(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> Minion:
	if not battle.can_summon_to_row(is_player, row):
		push_warning("Rangée %s pleine, impossible d'invoquer %s" % [row, card_data.card_name])
		return null
	var minion := Minion.new(card_data, is_player, row)
	_insert(minion, is_player, row, insert_index)
	_apply_commandement_bonus(minion, is_player)
	_spawn(minion, is_player)
	AudioManager.play_for_style(AudioManager.SUMMON, card_data.unit_style)
	await battle.get_tree().create_timer(0.2).timeout

	# Effet d'invocation du minion lui-même
	await battle.effect_manager.trigger_effects(battle, minion, "ONPLAY")

	# OnSummon sur les alliés déjà en jeu (pas le minion lui-même)
	var allies: Array[Minion] = (battle.player_minions if is_player else battle.enemy_minions).duplicate()
	for ally in allies:
		if ally != minion:
			await battle.effect_manager.trigger_effects(battle, ally, "OnSummon")

	# Appel — enchantements réagissent à l'invocation
	await battle.trigger_system.fire("OnSummon", minion, is_player)
	battle.aura_system.recompute_all()
	battle.board_visual_system.refresh_board()
	return minion

func _apply_commandement_bonus(minion: Minion, is_player: bool) -> void:
	if minion.card_data.race != Race.Type.HUMAN:
		return
	var allies: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	for ally in allies:
		if ally != minion and ally.has_human_keyword(KeywordHuman.Type.COMMANDEMENT):
			minion.base_attack += 1

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
