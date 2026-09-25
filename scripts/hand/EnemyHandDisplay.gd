extends Control
class_name EnemyHandDisplay



const CARD_BACK := preload("res://assets/card_back/card-back.png")
const CARD_SIZE := Vector2(110, 165)
const MAX_SPACING := 78.0
const MAX_ANGLE := 0.14
const ARC_STRENGTH := 26.0

# Meme bordure noire que Card.tscn (BorderFrameBlack), a l'echelle de CARD_SIZE.
const BORDER_MARGIN := Vector2(3.5, 4.0)
static var _border_style: StyleBoxFlat

var _count: int = -1

func set_count(count: int) -> void:
	if count == _count:
		return
	_count = count
	for child in get_children():
		child.queue_free()
	if count <= 0:
		return
	var spacing := MAX_SPACING
	if count > 1:
		spacing = minf(MAX_SPACING, (size.x - CARD_SIZE.x) / float(count - 1))
	var total_width := CARD_SIZE.x + spacing * float(count - 1)
	var start_x := (size.x - total_width) / 2.0
	for i in range(count):
		var norm := 0.0
		if count > 1:
			norm = (float(i) - float(count - 1) / 2.0) / (float(count - 1) / 2.0)
		var wrapper := Control.new()
		wrapper.custom_minimum_size = CARD_SIZE
		wrapper.size = CARD_SIZE
		wrapper.pivot_offset = Vector2(CARD_SIZE.x / 2.0, 0.0)
		wrapper.rotation = norm * MAX_ANGLE
		wrapper.position = Vector2(
			start_x + float(i) * spacing,
			(norm * norm) * ARC_STRENGTH
		)
		wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(wrapper)

		var border := Panel.new()
		border.position = -BORDER_MARGIN
		border.size = CARD_SIZE + BORDER_MARGIN * 2.0
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.add_theme_stylebox_override("panel", _get_border_style())
		wrapper.add_child(border)

		var back := TextureRect.new()
		back.texture = CARD_BACK
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.custom_minimum_size = CARD_SIZE
		back.size = CARD_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrapper.add_child(back)

func _get_border_style() -> StyleBoxFlat:
	if _border_style == null:
		_border_style = StyleBoxFlat.new()
		_border_style.bg_color = Color(0, 0, 0, 1)
		_border_style.corner_radius_top_left = 4
		_border_style.corner_radius_top_right = 4
		_border_style.corner_radius_bottom_right = 4
		_border_style.corner_radius_bottom_left = 4
		_border_style.corner_detail = 10
	return _border_style
