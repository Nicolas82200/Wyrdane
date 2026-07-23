extends Control
class_name ArenaIcon

# Icône vectorielle simple dessinée à la volée (au lieu d'un glyphe Unicode,
# dont le rendu dépend de la police active et n'est pas garanti — voir
# ArenaBattle._style_button) pour les quelques actions sans image dédiée dans
# assets/icons/ (reroll, XP, cadenas, prêt, round suivant, retour au menu).

enum Kind { REROLL, STAR, PLAY, FORWARD, HOME, HEART }

@export var kind: Kind = Kind.PLAY
@export var line_color: Color = Color(0.92, 0.85, 0.65)

func _draw() -> void:
	var s: Vector2 = size
	var c: Vector2 = s * 0.5
	var r: float = min(s.x, s.y) * 0.5
	match kind:
		Kind.REROLL:
			draw_arc(c, r * 0.75, -2.4, 1.6, 24, line_color, r * 0.14, true)
			var tip: Vector2 = c + Vector2(cos(1.6), sin(1.6)) * r * 0.75
			var perp: Vector2 = Vector2(-sin(1.6), cos(1.6)) * r * 0.28
			var back_dir: Vector2 = Vector2(cos(1.6 - 1.2), sin(1.6 - 1.2)) * r * 0.3
			draw_polygon([tip + back_dir, tip + perp, tip - perp], [line_color, line_color, line_color])
		Kind.STAR:
			var points: Array[Vector2] = []
			for i in 10:
				var ang: float = -PI / 2 + i * PI / 5
				var rad: float = r if i % 2 == 0 else r * 0.42
				points.append(c + Vector2(cos(ang), sin(ang)) * rad)
			draw_colored_polygon(points, line_color)
		Kind.PLAY:
			draw_colored_polygon([
				c + Vector2(-r * 0.5, -r * 0.65),
				c + Vector2(-r * 0.5, r * 0.65),
				c + Vector2(r * 0.65, 0.0),
			], line_color)
		Kind.FORWARD:
			draw_colored_polygon([
				c + Vector2(-r * 0.75, -r * 0.6),
				c + Vector2(-r * 0.75, r * 0.6),
				c + Vector2(-r * 0.05, 0.0),
			], line_color)
			draw_colored_polygon([
				c + Vector2(r * 0.05, -r * 0.6),
				c + Vector2(r * 0.05, r * 0.6),
				c + Vector2(r * 0.75, 0.0),
			], line_color)
		Kind.HEART:
			var lobe_r: float = r * 0.42
			draw_circle(c + Vector2(-lobe_r * 0.9, -lobe_r * 0.5), lobe_r, line_color)
			draw_circle(c + Vector2(lobe_r * 0.9, -lobe_r * 0.5), lobe_r, line_color)
			draw_colored_polygon([
				c + Vector2(-r * 0.85, -r * 0.1),
				c + Vector2(r * 0.85, -r * 0.1),
				c + Vector2(0.0, r * 0.75),
			], line_color)
		Kind.HOME:
			draw_colored_polygon([
				c + Vector2(-r * 0.7, r * 0.1),
				c + Vector2(0.0, -r * 0.7),
				c + Vector2(r * 0.7, r * 0.1),
			], line_color)
			draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.05), Vector2(r * 0.9, r * 0.65)), line_color, false, r * 0.12)

static func make(icon_kind: Kind, extent: float = 32.0) -> ArenaIcon:
	var icon := ArenaIcon.new()
	icon.kind = icon_kind
	icon.custom_minimum_size = Vector2(extent, extent)
	return icon
