extends Control
class_name ArenaBoardMinionSlot

# Enveloppe autour d'un `BoardMinion` déjà posé sur son propre plateau : permet
# de le glisser pour le repositionner (voir ArenaBoardRow.on_reposition) ou le
# vendre en le lâchant sur la boutique (voir ArenaSellZone). Même principe que
# ArenaShopCardSlot (API standard Godot _get_drag_data, pas Card.gd/DropSystem.gd,
# pensés pour le mana/ciblage 1v1) mais pour un BoardMinion plutôt qu'une Card.

const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")

var minion: Minion

func setup(m: Minion) -> void:
	minion = m
	for child in get_children():
		child.queue_free()
	if m == null:
		return
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	add_child(visual)
	visual.set_minion(m)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = visual.custom_minimum_size

func _get_drag_data(_at_position: Vector2):
	if minion == null:
		return null
	set_drag_preview(_build_preview())
	return {"arena_board_minion": minion}

func _build_preview() -> Control:
	var box := PanelContainer.new()
	box.modulate = Color(1.0, 1.0, 1.0, 0.85)
	var tex := TextureRect.new()
	tex.texture = minion.card_data.texture
	tex.custom_minimum_size = Vector2(70, 105)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	box.add_child(tex)
	return box
