extends RefCounted

class_name BoardVisualSystem

const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")

var battle
var _refreshing := false
var _refresh_again := false
var minion_to_visual: Dictionary = {}

func init(_battle) -> void:
	battle = _battle


func spawn_minion_visual(minion: Minion, is_player: bool) -> void:
	var container: Control
	if is_player:
		container = battle.player_front_container if minion.board_row == battle.ROW_FRONT else battle.player_back_container
	else:
		container = battle.enemy_front_container if minion.board_row == battle.ROW_FRONT else battle.enemy_back_container
	if container == null:
		push_error("Container null pour spawn minion !")
		return
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	container.add_child(visual)
	visual.set_minion(minion)
	minion_to_visual[minion] = visual

	# ← Repositionne le visual selon l'index du minion dans l'array
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	var row_visuals: Array[Node] = []
	for child in container.get_children():
		if child is BoardMinion:
			row_visuals.append(child)
	# Trouve l'index visuel du minion dans sa row
	var row_index: int = 0
	for m in minions:
		if m.board_row != minion.board_row:
			continue
		if m == minion:
			break
		row_index += 1
	# Trouve la position enfant correspondante dans le container
	var seen: int = 0
	for i in range(container.get_child_count()):
		var child := container.get_child(i)
		if child == visual:
			continue
		if child is BoardMinion:
			if seen == row_index:
				container.move_child(visual, i)
				break
			seen += 1

	if is_player:
		visual.minion_clicked.connect(battle.selection_system.on_player_minion_clicked)
		visual.minion_clicked.connect(func(m, v): battle.targeting_system.on_ally_minion_clicked(m, v))
	else:
		visual.minion_clicked.connect(battle.selection_system.on_enemy_minion_clicked)
		visual.minion_clicked.connect(func(m, v): battle.targeting_system.on_enemy_minion_clicked(m, v))
	battle.animation_system.play_summon(visual)


func get_visual(minion: Minion) -> BoardMinion:
	return minion_to_visual.get(minion)


func remove_visual(minion: Minion) -> void:
	minion_to_visual.erase(minion)


func get_all_containers() -> Array[Control]:
	var containers: Array[Control] = []

	for c in [
		battle.player_front_container,
		battle.player_back_container,
		battle.enemy_front_container,
		battle.enemy_back_container,
	]:
		if c != null:
			containers.append(c)

	return containers


func find_visual(target_minion: Minion) -> BoardMinion:
	if target_minion == null:
		return null

	for container in get_all_containers():
		for child in container.get_children():
			if child is BoardMinion and child.minion == target_minion:
				return child
	return null

func refresh_board() -> void:
	if _refreshing:
		_refresh_again = true
		return

	_refreshing = true

	for minion in battle.player_minions + battle.enemy_minions:
		var visual: BoardMinion = minion_to_visual.get(minion)

		if visual and is_instance_valid(visual):
			visual.update_display()

	if battle.selection_system.selected_attacker \
	and battle.selection_system.selected_attacker not in battle.player_minions:
		battle.selection_system.clear_selection()

	_refreshing = false

	if _refresh_again:
		_refresh_again = false
		refresh_board()
