extends Node2D
class_name AttackLineOverlay

# Ligne(s) rouge(s) reliant le/les serviteur(s) sélectionné(s) pour attaquer à
# la souris, pour visualiser clairement qui est choisi comme attaquant.
# Autonome (son propre _process suit la souris tant qu'active) : ne dépend pas
# du toggle battle.set_process() utilisé par ailleurs pour le ciblage de sort.

var _origins: Array[Control] = []
var _active: bool = false

const LINE_COLOR    := Color(0.95, 0.15, 0.15, 0.85)
const OUTLINE_COLOR := Color(0.25, 0.02, 0.02, 0.55)
const LINE_WIDTH    := 3.0
const OUTLINE_WIDTH := 6.0

func set_origins(nodes: Array[Control]) -> void:
	_origins = nodes.filter(func(n): return is_instance_valid(n))
	_active  = not _origins.is_empty()
	visible  = _active
	set_process(_active)
	queue_redraw()

func clear() -> void:
	_origins.clear()
	_active = false
	visible = false
	set_process(false)
	queue_redraw()

func _process(_delta: float) -> void:
	if _active:
		queue_redraw()

func _draw() -> void:
	if not _active:
		return
	var to: Vector2 = get_viewport().get_mouse_position()
	for node in _origins:
		if not is_instance_valid(node):
			continue
		var from: Vector2 = node.global_position + node.size * 0.5
		draw_line(from, to, OUTLINE_COLOR, OUTLINE_WIDTH, true)
		draw_line(from, to, LINE_COLOR, LINE_WIDTH, true)
