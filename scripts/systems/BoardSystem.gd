# BoardSystem.gd
extends Node
class_name BoardSystem

var battle

func init(_battle) -> void:
	battle = _battle

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	if not battle.can_summon_to_row(is_player, row):
		push_warning("Rangée %s pleine, impossible d'invoquer %s" % [row, card_data.card_name])
		return

	var minion := Minion.new(card_data, is_player, row)
	_insert(minion, is_player, row, insert_index)
	_spawn(minion, is_player)
	AudioManager.play_for_style(AudioManager.SUMMON, card_data.unit_style)
	await battle.get_tree().create_timer(0.2).timeout

	# ONPLAY = effet d'invocation du minion invoqué
	await battle.effect_manager.trigger_effects(battle, minion, "ONPLAY")

	# OnSummon déclenché sur tous les alliés déjà en jeu (pas le minion lui-même)
	var allies: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	for ally in allies:
		if ally != minion:
			await battle.effect_manager.trigger_effects(battle, ally, "OnSummon")

	battle.board_visual_system.refresh_board()

func _insert(minion: Minion, is_player: bool, row: String, insert_index: int) -> void:
	if is_player:
		battle._insert_minion_in_row(battle.player_minions, minion, row, insert_index)
	else:
		battle._insert_minion_in_row(battle.enemy_minions, minion, row, insert_index)

func _spawn(minion: Minion, is_player: bool) -> void:
	battle.board_visual_system.spawn_minion_visual(minion, is_player)
