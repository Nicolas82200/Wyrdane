extends Control
class_name EnemyHandDisplay

# Main de l'adversaire affichée en éventail (dos de cartes uniquement — info cachée).
# Miroir de la main du joueur : les cartes pendent vers le bas et s'ouvrent en
# éventail, resserrées dynamiquement pour ne jamais déborder.

const CARD_BACK := preload("res://assets/card_back/card-back.png")
const CARD_SIZE := Vector2(110, 165)
const MAX_SPACING := 78.0        # écart horizontal max entre deux cartes
const MAX_ANGLE := 0.14          # inclinaison max des cartes de bord (radians)
const ARC_STRENGTH := 26.0       # profondeur de l'arc vertical

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
		var back := TextureRect.new()
		back.texture = CARD_BACK
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		back.custom_minimum_size = CARD_SIZE
		back.size = CARD_SIZE
		# Pivot en haut-centre : l'éventail s'ouvre vers le bas (miroir de la main joueur)
		back.pivot_offset = Vector2(CARD_SIZE.x / 2.0, 0.0)
		back.rotation = norm * MAX_ANGLE
		back.position = Vector2(
			start_x + float(i) * spacing,
			(norm * norm) * ARC_STRENGTH
		)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(back)
