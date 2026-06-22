extends Node
class_name BoardSystem

var battle

func init(_battle):
	battle = _battle


func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> void:
	if not battle.can_summon_to_row(is_player, row):
		push_warning("Rangée %s pleine, impossible d'invoquer %s" % [row, card_data.card_name])
		return
	var minion := Minion.new(card_data, is_player, row)
	_insert(minion, is_player, row, insert_index)
	_spawn(minion, is_player)
	AudioManager.play_for_style(AudioManager.SUMMON, card_data.unit_style)
	await battle.get_tree().create_timer(0.3).timeout
	battle.trigger_effects(minion, "ONPLAY")
	battle.refresh_board()


func _insert(minion, is_player, row, insert_index):
	if is_player:
		battle._insert_minion_in_row(battle.player_minions, minion, row, insert_index)
	else:
		battle._insert_minion_in_row(battle.enemy_minions, minion, row, insert_index)


func _spawn(minion, is_player):
	battle._spawn_minion_visual(minion, is_player)
