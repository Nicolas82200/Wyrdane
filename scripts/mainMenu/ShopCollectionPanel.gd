extends RefCounted
class_name ShopCollectionPanel

# Inventaire de packs de la vue "Collection" (voir MainMenu.gd,
# _open_collection_view) — n'affiche plus la grille de cartes
# possédées (déplacée nulle part : ce n'était qu'un teaser, le deckbuilder
# reste la vraie vue de collection pour construire un deck) mais le stock de
# packs non ouverts (CurrencyManager.free_packs, qu'ils viennent d'un achat
# en Boutique ou d'une récompense gratuite — quêtes, parrainage, niveau, le
# stock ne distingue plus l'origine). Ouvrir un lot (1/5/10, borné au stock
# réel) délègue à `open_callback` (voir MainMenu._open_owned_packs_flow), qui
# affiche PackShop pour l'animation de révélation — son paquet apparaît
# centré au même endroit que l'image ci-dessous puis se décale à l'ouverture.

const OPEN_QUANTITIES := [1, 5, 10]
const PACK_IMAGE_SIZE := Vector2(160, 240)
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## image du dos de pack centrée, compteur de packs en stock, puis une rangée
## de boutons "Ouvrir N" centrée, chacun désactivé si le stock est inférieur à N.
static func build_into(parent: Control, open_callback: Callable) -> void:
	for child in parent.get_children():
		child.queue_free()

	var count: int = CurrencyManager.free_packs

	var center := CenterContainer.new()
	center.name = "PackInventoryCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	var col := VBoxContainer.new()
	col.name = "PackInventoryColumn"
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var count_label := Label.new()
	count_label.name = "PackInventoryCountLabel"
	count_label.add_theme_font_size_override("font_size", Typography.SECTION)
	count_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	count_label.text = SettingsManager.t("collection.packs_owned") % count
	col.add_child(count_label)

	var image := TextureRect.new()
	image.name = "PackInventoryImage"
	image.texture = load(PACK_BACK_TEXTURE)
	image.custom_minimum_size = PACK_IMAGE_SIZE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	image.modulate = Color(1, 1, 1, 1) if count > 0 else Color(0.5, 0.5, 0.5, 0.6)
	col.add_child(image)

	var hint_label := Label.new()
	hint_label.name = "PackInventoryHintLabel"
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55, 1))
	hint_label.add_theme_font_size_override("font_size", Typography.MICRO)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.custom_minimum_size = Vector2(260, 0)
	hint_label.text = SettingsManager.t("collection.packs_hint")
	col.add_child(hint_label)

	if count <= 0:
		var empty_label := Label.new()
		empty_label.name = "PackInventoryEmptyLabel"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5, 1))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty_label.text = SettingsManager.t("collection.no_packs")
		col.add_child(empty_label)
		return

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "PackInventoryButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons_row)

	for quantity in OPEN_QUANTITIES:
		buttons_row.add_child(_make_open_button(quantity, count, open_callback))

static func _make_open_button(quantity: int, available: int, open_callback: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 44)
	button.text = SettingsManager.t("collection.open_packs_button") % quantity
	button.disabled = available < quantity
	button.pressed.connect(open_callback.bind(quantity))
	return button
