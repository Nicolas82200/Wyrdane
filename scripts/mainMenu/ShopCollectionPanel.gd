extends RefCounted
class_name ShopCollectionPanel

# Inventaire de packs de la vue "Collection" (voir MainMenu.gd,
# _open_collection_view) : image du pack (centrée, comme avant) avec sa
# pastille dorée indiquant le stock. Cliquer sur le pack l'ouvre directement
# (1 exemplaire) ; Ctrl+clic en ouvre 5, Maj+clic en ouvre 10, uniquement si
# le stock le permet (voir _make_pack_input_handler) — le rappel de ces
# raccourcis est affiché en permanence en bas à droite du panneau, et le
# bouton "Acheter des packs" tout en bas (vraiment au bas du PANNEAU, pas
# juste sous le pack) : les deux vivent dans PackShop (voir CornerHintLabel/
# BuyPacksButton dans PackShop.tscn), un overlay permanent qui couvre tout
# CollectionContentRoot, plutôt qu'ici où ils suivraient le pack dans le flux
# de la colonne. L'ouverture elle-même (révélation des cartes) est déléguée
# à `open_callback` (voir MainMenu._open_owned_packs_flow → PackShop.open_owned),
# qui anime les cartes directement autour de l'image du pack ci-dessous
# plutôt que dans un écran séparé.

const PACK_IMAGE_SIZE := Vector2(140, 210)
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"
const BADGE_SIZE := 36.0
const BADGE_GAP := 10.0
const OPEN_QUANTITY_CTRL := 5
const OPEN_QUANTITY_SHIFT := 10

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## une colonne cliquable par race de pack effectivement en stock (voir
## CurrencyManager.free_packs_by_race), avec sa pastille de stock et son
## libellé. Stock vide : un seul pack multirace grisé, comme avant.
## `open_callback(quantity, pack_image, race)` est appelé au clic sur un pack
## si son stock le permet.
static func build_into(parent: Control, open_callback: Callable) -> void:
	for child in parent.get_children():
		child.queue_free()

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

	var owned: Array = []
	for race in CurrencyManager.PACK_RACES:
		if CurrencyManager.packs_of(race) > 0:
			owned.append(race)

	var row := HBoxContainer.new()
	row.name = "PackInventoryRow"
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(row)

	if owned.is_empty():
		row.add_child(_make_pack_column(CurrencyManager.MULTIRACE_PACK, 0, open_callback))
		var empty_label := Label.new()
		empty_label.name = "PackInventoryEmptyLabel"
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.5, 1))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty_label.text = SettingsManager.t("collection.no_packs")
		col.add_child(empty_label)
		return

	for race in owned:
		row.add_child(_make_pack_column(race, CurrencyManager.packs_of(race), open_callback))

## Un pack de l'inventaire : image teintée de la couleur de sa race (même
## accent que le carrousel de la Boutique), pastille de stock à droite, nom
## du pack en dessous.
static func _make_pack_column(race: String, count: int, open_callback: Callable) -> Control:
	var column := VBoxContainer.new()
	column.name = "PackInventoryColumn" + race
	column.add_theme_constant_override("separation", 8)

	var pack_holder := Control.new()
	pack_holder.name = "PackInventoryHolder"
	pack_holder.custom_minimum_size = Vector2(PACK_IMAGE_SIZE.x + BADGE_GAP + BADGE_SIZE, PACK_IMAGE_SIZE.y)
	pack_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(pack_holder)

	var image := TextureRect.new()
	image.name = "PackInventoryImage"
	# expand_mode/stretch_mode AVANT position/size : Control.set_size() remonte
	# toujours au moins à la taille minimale du contrôle, et tant que
	# expand_mode reste sur sa valeur par défaut (EXPAND_KEEP_SIZE), cette
	# taille minimale vaut la pleine résolution de la texture — assigner size
	# avant aurait donc silencieusement agrandi le pack à la taille native de
	# l'image (ex. 980x1441) au lieu de PACK_IMAGE_SIZE.
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.texture = load(PACK_BACK_TEXTURE)
	image.position = Vector2.ZERO
	image.size = PACK_IMAGE_SIZE
	var tint: Color = PackCarousel.accent_for(race).lerp(Color.WHITE, 0.45)
	image.modulate = tint if count > 0 else Color(0.5, 0.5, 0.5, 0.6)
	image.mouse_filter = Control.MOUSE_FILTER_STOP if count > 0 else Control.MOUSE_FILTER_IGNORE
	image.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if count > 0 else Control.CURSOR_ARROW
	pack_holder.add_child(image)

	var badge := _make_stock_badge(count)
	badge.position = Vector2(PACK_IMAGE_SIZE.x + BADGE_GAP, PACK_IMAGE_SIZE.y / 2.0 - BADGE_SIZE / 2.0)
	pack_holder.add_child(badge)

	var name_label := Label.new()
	name_label.name = "PackInventoryNameLabel"
	name_label.text = PackCarousel.title_for(race)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", Typography.MICRO)
	name_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	column.add_child(name_label)

	if count > 0 and open_callback.is_valid():
		image.gui_input.connect(_make_pack_input_handler(image, badge, race, open_callback))
	return column

## Clic gauche simple = ouvrir 1 pack ; Ctrl+clic = 5 ; Maj+clic = 10 —
## uniquement si le stock couvre exactement la quantité demandée (sinon un
## bref flash rouge sur la pastille signale l'échec, sans rien ouvrir). Le
## pack se désactive dès qu'une ouverture démarre pour éviter un double-clic
## pendant la révélation (réactivé au prochain rebuild de la vue Collection,
## voir MainMenu._on_pack_opening_closed).
static func _make_pack_input_handler(image: TextureRect, badge: Control, race: String, open_callback: Callable) -> Callable:
	return func(event: InputEvent):
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		var quantity := 1
		if event.shift_pressed:
			quantity = OPEN_QUANTITY_SHIFT
		elif event.ctrl_pressed:
			quantity = OPEN_QUANTITY_CTRL
		if CurrencyManager.packs_of(race) < quantity:
			_flash_badge_denied(badge)
			return
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		open_callback.call(quantity, image, race)

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
