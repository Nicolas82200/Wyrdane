extends Node2D
class_name PreviewLinkOverlay

## Trait discret reliant une carte survolée à l'aperçu agrandi qu'elle
## déclenche (voir Hand._on_card_hover) — même principe visuel que
## ArrowOverlay (courbe de Bézier dessinée via draw_line) mais volontairement
## moins net : plusieurs passes superposées, de plus en plus larges et
## transparentes, simulent un flou sans shader ni matériau.

var from_pos: Vector2 = Vector2.ZERO
var to_pos: Vector2 = Vector2.ZERO
var visible_link: bool = false

const LINK_COLOR := Color(0.92, 0.92, 0.95)
const CORE_ALPHA := 0.30
const CORE_WIDTH := 2.0
# [largeur, alpha] de chaque passe de flou, de la plus large/faible à la plus
# fine/marquée, dessinées sous le trait central.
const BLUR_PASSES: Array[Vector2] = [
	Vector2(12.0, 0.04),
	Vector2(8.0,  0.07),
	Vector2(5.0,  0.12),
]
const SEGMENTS := 24

func show_link(from: Vector2, to: Vector2) -> void:
	from_pos = from
	to_pos = to
	visible_link = true
	visible = true
	queue_redraw()

func hide_link() -> void:
	visible_link = false
	visible = false
	queue_redraw()

func _draw() -> void:
	if not visible_link:
		return
	var delta := to_pos - from_pos
	if delta.length() < 4.0:
		return

	# Légère courbe verticale (plutôt qu'un trait droit) pour rester cohérent
	# avec le style des flèches de ciblage.
	var cp1 := from_pos + Vector2(0, delta.y * 0.3)
	var cp2 := to_pos   - Vector2(0, delta.y * 0.3)
	var points := _bezier_points(from_pos, cp1, cp2, to_pos, SEGMENTS)

	for blur_pass in BLUR_PASSES:
		var color := Color(LINK_COLOR.r, LINK_COLOR.g, LINK_COLOR.b, blur_pass.y)
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1], color, blur_pass.x, true)

	var core_color := Color(LINK_COLOR.r, LINK_COLOR.g, LINK_COLOR.b, CORE_ALPHA)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], core_color, CORE_WIDTH, true)

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
