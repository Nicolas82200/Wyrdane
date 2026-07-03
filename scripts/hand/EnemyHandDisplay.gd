extends Control
class_name EnemyHandDisplay

# Affiche la main de l'adversaire en dos de cartes (information cachée).
# Les cartes se resserrent dynamiquement pour ne jamais déborder de la zone.

const CARD_BACK := preload("res://assets/card_back/card-back.png")
const CARD_SIZE := Vector2(80, 120)
const MAX_SPACING := 90.0

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
		var back := TextureRect.new()
		back.texture = CARD_BACK
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.position = Vector2(start_x + float(i) * spacing, (size.y - CARD_SIZE.y) / 2.0)
		back.size = CARD_SIZE
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
