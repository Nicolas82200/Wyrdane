extends RefCounted

class_name BoardVisualSystem

const BOARD_MINION_SCENE = preload("res://scenes/minion/BoardMinion.tscn")

var battle
var _refreshing := false
var _refresh_again := false
var minion_to_visual: Dictionary = {}

func init(_battle) -> void:
	battle = _battle


func _row_container(minion: Minion, is_player: bool) -> Control:
	if is_player:
		return battle.player_front_container if minion.board_row == battle.ROW_FRONT else battle.player_back_container
	return battle.enemy_front_container if minion.board_row == battle.ROW_FRONT else battle.enemy_back_container


# Insère `visual` dans `container` à l'index correspondant à la position de
# `minion` dans le tableau de données de sa rangée, pour garder l'ordre
# visuel synchronisé avec player_minions/enemy_minions.
func _place_visual_in_row(container: Control, visual: BoardMinion, minion: Minion, is_player: bool) -> void:
	var minions: Array[Minion] = battle.player_minions if is_player else battle.enemy_minions
	var row_index: int = 0
	for m in minions:
		if m.board_row != minion.board_row:
			continue
		if m == minion:
			break
		row_index += 1

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


# (Re)connecte minion_clicked aux handlers du camp `is_player`, en coupant
# d'abord toute connexion existante (utile lors d'un changement de camp,
# ex: contrôle mental).
func _wire_visual_signals(visual: BoardMinion, is_player: bool) -> void:
	for connection in visual.minion_clicked.get_connections():
		visual.minion_clicked.disconnect(connection.callable)
	for connection in visual.fusion_requested.get_connections():
		visual.fusion_requested.disconnect(connection.callable)
	if is_player:
		visual.minion_clicked.connect(battle.selection_system.on_player_minion_clicked)
		visual.minion_clicked.connect(func(m, v): battle.targeting_system.on_ally_minion_clicked(m, v))
		visual.minion_clicked.connect(func(m, v): battle.sacrifice_system.on_ally_minion_clicked(m, v))
		visual.minion_clicked.connect(func(m, v): battle.fusion_system.on_ally_minion_clicked(m, v))
		visual.fusion_requested.connect(func(m): battle.fusion_system.try_begin(m))
	else:
		visual.minion_clicked.connect(battle.selection_system.on_enemy_minion_clicked)
		visual.minion_clicked.connect(func(m, v): battle.targeting_system.on_enemy_minion_clicked(m, v))


func spawn_minion_visual(minion: Minion, is_player: bool) -> void:
	var container: Control = _row_container(minion, is_player)
	if container == null:
		push_error("Container null pour spawn minion !")
		return
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	container.add_child(visual)
	visual.set_minion(minion)
	minion_to_visual[minion] = visual

	_place_visual_in_row(container, visual, minion, is_player)
	_wire_visual_signals(visual, is_player)
	battle.animation_system.play_summon(visual)


# Déplace le noeud visuel d'un serviteur vers le container du nouveau
# camp/rangée (ex: contrôle mental) et rebranche ses signaux de clic —
# sans cela le serviteur volé reste affiché du côté de son ancien
# propriétaire malgré le transfert de propriété côté données.
func reparent_minion_visual(minion: Minion, is_player: bool) -> void:
	var visual: BoardMinion = minion_to_visual.get(minion)
	if visual == null or not is_instance_valid(visual):
		return
	var container: Control = _row_container(minion, is_player)
	if container == null:
		return
	var old_parent: Node = visual.get_parent()
	if old_parent != null:
		old_parent.remove_child(visual)
	container.add_child(visual)
	_place_visual_in_row(container, visual, minion, is_player)
	_wire_visual_signals(visual, is_player)


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


	battle.enchantment_system.refresh_activatable()


	battle.update_end_turn_hint()

	_refreshing = false

	if _refresh_again:
		_refresh_again = false
		refresh_board()
