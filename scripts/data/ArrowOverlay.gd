extends Node2D
class_name ArrowOverlay

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var to_points: Array[Vector2] = []
var visible_arrow: bool = false

const ARROW_COLOR    := Color(0.92, 0.92, 0.95, 0.90)
const OUTLINE_COLOR  := Color(0.15, 0.15, 0.2, 0.55)
const ARROW_WIDTH    := 3.0
const OUTLINE_WIDTH  := 6.0
const ARROWHEAD_SIZE := 16.0
const SEGMENTS       := 40  # fluidité de la courbe

func show_arrow(from: Vector2, to: Vector2) -> void:
	from_pos = from
	to_pos   = to
	to_points = [to]
	visible_arrow = true
	visible = true
	queue_redraw()

# Plusieurs cibles partageant la même origine (effets de zone / aléatoires)
func show_arrows(from: Vector2, tos: Array[Vector2]) -> void:
	from_pos = from
	to_points = tos.duplicate()
	visible_arrow = true
	visible = true
	queue_redraw()

func hide_arrow() -> void:
	visible_arrow = false
	visible = false
	to_points.clear()
	queue_redraw()

func _draw() -> void:
	if not visible_arrow:
		return
	for tp in to_points:
		_draw_curve(from_pos, tp)

func _draw_curve(start: Vector2, target: Vector2) -> void:
	var delta := target - start
	if delta.length() < 10.0:
		return

	# Points de contrôle : la courbe part vers la droite puis descend vers la cible
	var cp1 := start  + Vector2(delta.x * 0.6, 0)
	var cp2 := target - Vector2(0, delta.y * 0.3)

	var points := _bezier_points(start, cp1, cp2, target, SEGMENTS)

	# Direction finale pour la tête
	var dir := (points[points.size() - 1] - points[points.size() - 2]).normalized()
	var end := target - dir * ARROWHEAD_SIZE * 0.6

	# Tronque le dernier segment pour ne pas dépasser sous la tête
	points[points.size() - 1] = end

	# Contour
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], OUTLINE_COLOR, OUTLINE_WIDTH, true)
	# Trait
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], ARROW_COLOR, ARROW_WIDTH, true)


func _bezier_points(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var u := 1.0 - t
		var pt := u*u*u * p0 \
				+ 3.0*u*u*t * p1 \
				+ 3.0*u*t*t * p2 \
				+ t*t*t     * p3
		pts.append(pt)
	return pts
