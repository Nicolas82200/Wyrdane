@tool
class_name LaneIndicator
extends Control

# Icône de rangée affichée au centre de chaque ligne du board.
# L'icône reflète l'orientation écran de la ligne : la rangée du haut de son
# côté utilise l'icône "front_lane" (rangée haute remplie), celle du bas utilise
# "back_lane" (rangée basse remplie).

const TOP_TEXTURE    := preload("res://assets/icons/front_lane.png")
const BOTTOM_TEXTURE := preload("res://assets/icons/back_lane.png")

@export_enum("Haut", "Bas") var filled_row: int = 0:
	set(value):
		filled_row = value
		queue_redraw()

@export var icon_color := Color(0, 0, 0, 0.85):
	set(value):
		icon_color = value
		queue_redraw()

func _draw() -> void:
	var tex: Texture2D = TOP_TEXTURE if filled_row == 0 else BOTTOM_TEXTURE
	if tex == null:
		return
	# Icône carrée conservée, centrée dans le contrôle (teintée en noir)
	var side := minf(size.x, size.y)
	var pos := (size - Vector2(side, side)) * 0.5
	draw_texture_rect(tex, Rect2(pos, Vector2(side, side)), false, icon_color)
