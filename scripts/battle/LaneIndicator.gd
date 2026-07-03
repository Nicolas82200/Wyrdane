@tool
class_name LaneIndicator
extends Control

# Petit schéma de 2 rangées de 5 cases affiché à côté de chaque ligne du board.
# La rangée remplie indique la position de la ligne : cases hautes remplies si
# la ligne est celle du haut de son côté, cases basses sinon (orientation écran).

const COLS := 5
const ROWS := 2
const GAP  := 3.0

@export_enum("Haut", "Bas") var filled_row: int = 0:
	set(value):
		filled_row = value
		queue_redraw()

@export var fill_color := Color(0.85, 0.72, 0.45, 0.85):
	set(value):
		fill_color = value
		queue_redraw()

@export var empty_color := Color(1, 1, 1, 0.08):
	set(value):
		empty_color = value
		queue_redraw()

@export var border_color := Color(1, 1, 1, 0.28):
	set(value):
		border_color = value
		queue_redraw()

func _draw() -> void:
	var cell_w := (size.x - GAP * (COLS - 1)) / COLS
	var cell_h := (size.y - GAP * (ROWS - 1)) / ROWS
	for row in ROWS:
		for col in COLS:
			var cell := Rect2(col * (cell_w + GAP), row * (cell_h + GAP), cell_w, cell_h)
			draw_rect(cell, fill_color if row == filled_row else empty_color, true)
			draw_rect(cell, border_color, false, 1.0)
