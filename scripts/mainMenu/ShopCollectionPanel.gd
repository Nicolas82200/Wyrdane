extends RefCounted
class_name ShopCollectionPanel

# Inventaire de packs de la vue "Collection" (voir MainMenu.gd,
# _open_collection_view) : image du pack, pastille dorée indiquant le stock,
# et bouton "Acheter des packs" qui renvoie vers la Boutique. Cliquer sur le
# pack l'ouvre directement (1 exemplaire) ; Ctrl+clic en ouvre 5, Maj+clic en
# ouvre 10, uniquement si le stock le permet (voir _on_pack_gui_input) — le
# rappel de ces raccourcis est affiché en permanence en bas à droite du
# panneau par PackShop (voir CornerHintLabel dans PackShop.tscn). L'ouverture
# elle-même (révélation des cartes) est déléguée à `open_callback` (voir
# MainMenu._open_owned_packs_flow → PackShop.open_owned), qui anime les
# cartes directement autour de l'image du pack ci-dessous plutôt que dans un
# écran séparé.

const PACK_IMAGE_SIZE := Vector2(160, 240)
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"
const BADGE_SIZE := 40.0
const BADGE_GAP := 14.0
const OPEN_QUANTITY_CTRL := 5
const OPEN_QUANTITY_SHIFT := 10

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## image du dos de pack (cliquable) avec sa pastille de stock, puis un
## bouton "Acheter des packs" en bas. `open_callback(quantity, pack_image)`
## est appelé au clic sur le pack si le stock le permet ; `buy_packs_callback()`
## au clic sur le bouton d'achat.
static func build_into(parent: Control, open_callback: Callable, buy_packs_callback: Callable = Callable()) -> void:
	for child in parent.get_children():
		child.queue_free()

	var count: int = CurrencyManager.free_packs

	var center := CenterContainer.new()
	center.name = "PackInventoryCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	var col := VBoxContainer.new()
	col.name = "PackInventoryColumn"
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var hint_label := Label.new()
	hint_label.name = "PackInventoryHintLabel"
	hint_label.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55, 1))
	hint_label.add_theme_font_size_override("font_size", Typography.MICRO)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint_label.custom_minimum_size = Vector2(260, 0)
	hint_label.text = SettingsManager.t("collection.packs_hint")
	col.add_child(hint_label)

	var pack_holder := Control.new()
	pack_holder.name = "PackInventoryHolder"
	pack_holder.custom_minimum_size = Vector2(PACK_IMAGE_SIZE.x + BADGE_GAP + BADGE_SIZE, PACK_IMAGE_SIZE.y)
	pack_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(pack_holder)

	var image := TextureRect.new()
	image.name = "PackInventoryImage"
	image.texture = load(PACK_BACK_TEXTURE)
	image.position = Vector2.ZERO
	image.size = PACK_IMAGE_SIZE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.modulate = Color(1, 1, 1, 1) if count > 0 else Color(0.5, 0.5, 0.5, 0.6)
	image.mouse_filter = Control.MOUSE_FILTER_STOP if count > 0 else Control.MOUSE_FILTER_IGNORE
	image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if count > 0 else Control.CURSOR_ARROW
	pack_holder.add_child(image)

	var badge := _make_stock_badge(count)
	badge.position = Vector2(PACK_IMAGE_SIZE.x + BADGE_GAP, PACK_IMAGE_SIZE.y / 2.0 - BADGE_SIZE / 2.0)
	pack_holder.add_child(badge)

	if count > 0 and open_callback.is_valid():
		image.gui_input.connect(_make_pack_input_handler(image, badge, open_callback))

	if count <= 0:
		var empty_label := Label.new()
		empty_label.name = "PackInventoryEmptyLabel"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5, 1))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty_label.text = SettingsManager.t("collection.no_packs")
		col.add_child(empty_label)

	var buy_button := Button.new()
	buy_button.name = "BuyPacksButton"
	buy_button.custom_minimum_size = Vector2(220, 48)
	buy_button.text = SettingsManager.t("collection.buy_packs_button")
	if buy_packs_callback.is_valid():
		buy_button.pressed.connect(buy_packs_callback)
	col.add_child(buy_button)

## Clic gauche simple = ouvrir 1 pack ; Ctrl+clic = 5 ; Maj+clic = 10 —
## uniquement si le stock couvre exactement la quantité demandée (sinon un
## bref flash rouge sur la pastille signale l'échec, sans rien ouvrir). Le
## pack se désactive dès qu'une ouverture démarre pour éviter un double-clic
## pendant la révélation (réactivé au prochain rebuild de la vue Collection,
## voir MainMenu._on_pack_opening_closed).
static func _make_pack_input_handler(image: TextureRect, badge: Control, open_callback: Callable) -> Callable:
	return func(event: InputEvent):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		var quantity := 1
		if event.shift_pressed:
			quantity = OPEN_QUANTITY_SHIFT
		elif event.ctrl_pressed:
			quantity = OPEN_QUANTITY_CTRL
		if CurrencyManager.free_packs < quantity:
			_flash_badge_denied(badge)
			return
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		open_callback.call(quantity, image)

static func _flash_badge_denied(badge: Control) -> void:
	if not is_instance_valid(badge):
		return
	var original: Color = badge.modulate
	var tween := badge.create_tween()
	tween.tween_property(badge, "modulate", Color(1.4, 0.4, 0.35, 1), 0.08)
	tween.tween_property(badge, "modulate", original, 0.22)

## Pastille dorée à droite du pack, affichant le nombre de packs en stock.
static func _make_stock_badge(count: int) -> Control:
	var badge := PanelContainer.new()
	badge.name = "PackStockBadge"
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.82, 0.62, 0.14, 1)
	style.border_color = Color(0.98, 0.85, 0.45, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(BADGE_SIZE / 2.0))
	badge.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.name = "PackStockBadgeLabel"
	label.text = str(count)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", Typography.BODY)
	label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.02, 1))
	badge.add_child(label)
	return badge
