extends Control
class_name ArenaShopCardSlot

# Enveloppe autour d'une `Card` non-interactive (voir Card.set_non_interactive,
# scripts/card/Card.gd lignes 419-421) : la carte elle-même ignore la souris,
# c'est CE Control qui gère le drag pour acheter (API standard Godot
# _get_drag_data/set_drag_preview), sans dépendre du pipeline de jeu 1v1
# (Card.gd/DropSystem.gd, pensé pour le coût de mana et le ciblage, pas pour
# une économie en or — voir plan Arena « Refonte visuelle »).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")

var card_data: CardData
var shop_index: int = -1
# Appelé avec `shop_index` au clic sur le cadenas (voir ArenaBattle._refresh_shop).
var on_lock_toggled: Callable

func setup(data: CardData, index: int, locked: bool = false) -> void:
	card_data = data
	shop_index = index
	# Doit tenir dans la hauteur nominale d'une rangée (150, moins les marges
	# internes du panneau — content_margin_top/bottom = 8 chacune, voir
	# ArenaBattle._make_lane_panel) : à l'échelle 0.7 utilisée auparavant, la
	# carte (260x390 native) dépassait largement — le panneau grandissait donc
	# réellement pendant la boutique et se rétractait en combat (la boutique
	# vidée de ses offres tient, elle, dans les 150), décalant tout le
	# plateau du joueur en dessous à chaque passage boutique -> combat.
	custom_minimum_size = Vector2(88, 132)
	for child in get_children():
		child.queue_free()
	if data == null:
		return
	var card: Card = CARD_SCENE.instantiate()
	add_child(card)
	card.scale = Vector2(0.34, 0.34)
	card.set_data(data)
	card.set_non_interactive()
	# Le prix affiché doit être le coût en or de la boutique, pas la
	# répartition race/générique du mana 1v1 (sans objet en Arena).
	card.cost_label.text = str(data.cost)
	card.generic_cost_label.visible = false
	_add_lock_button(locked)

# Petit bouton cadenas en coin haut-gauche, au-dessus de la `Card` (dernier
# enfant ajouté = dessiné par-dessus) ; `mouse_filter` STOP par défaut sur un
# Button intercepte le clic avant qu'il n'atteigne _get_drag_data() du
# parent, donc verrouiller ne déclenche jamais un achat par erreur.
func _add_lock_button(locked: bool) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(22, 22)
	button.position = Vector2(2, 2)
	button.flat = true
	button.toggle_mode = true
	button.button_pressed = locked
	button.tooltip_text = SettingsManager.t("ARENA_SHOP_LOCK_TOOLTIP")
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.75, 0.62, 0.2, 0.9) if locked else Color(0.05, 0.05, 0.08, 0.6)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	button.add_theme_stylebox_override("normal", bg)
	button.add_theme_stylebox_override("pressed", bg)
	button.add_theme_stylebox_override("hover", bg)
	var icon := ArenaIcon.make(ArenaIcon.Kind.LOCK, 14.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(4, 4)
	icon.line_color = Color(0.92, 0.85, 0.65) if locked else Color(0.6, 0.6, 0.65)
	button.add_child(icon)
	button.pressed.connect(func(): if on_lock_toggled.is_valid(): on_lock_toggled.call(shop_index))
	add_child(button)

func _get_drag_data(_at_position: Vector2):
	if card_data == null:
		return null
	set_drag_preview(_build_preview())
	return {"arena_shop_index": shop_index}

func _build_preview() -> Control:
	var box := PanelContainer.new()
	box.modulate = Color(1.0, 1.0, 1.0, 0.85)
	var tex := TextureRect.new()
	tex.texture = card_data.texture
	tex.custom_minimum_size = Vector2(90, 135)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	box.add_child(tex)
	return box
