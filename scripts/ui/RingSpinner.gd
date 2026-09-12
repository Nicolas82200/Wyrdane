extends Control
class_name RingSpinner

# Anneau de chargement dessiné (pas de texture) — remplace les anciens
# spinners "cristal qui tourne" (texture symétrique en rotation, peu lisible
# comme indicateur de chargement — un joyau qui tourne sur lui-même a
# quasiment le même aspect à chaque frame). S'anime tout seul tant qu'il est
# visible ; s'arrête dès qu'il est masqué (voir _process).

@export var ring_color: Color = Color(0.91, 0.835, 0.639, 1)
@export var line_width: float = 3.0
@export var arc_degrees: float = 270.0
@export var turns_per_second: float = 0.9

var _angle := 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_angle = fmod(_angle + delta * TAU * turns_per_second, TAU)
	queue_redraw()

func _draw() -> void:
	var radius: float = min(size.x, size.y) / 2.0 - line_width
	if radius <= 0.0:
		return
	draw_arc(size / 2.0, radius, _angle, _angle + deg_to_rad(arc_degrees), 32, ring_color, line_width, true)
