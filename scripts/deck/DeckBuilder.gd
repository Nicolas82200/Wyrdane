# DeckBuilder.gd
extends Control

const ALL_CARDS_PATH := "res://resources/cards"
const MIN_CARDS := 40
const MAX_CARDS := 60
const MAX_COPIES := 4
# Nombre de cartes instanciées par frame — ajuste selon les perfs
const CARDS_PER_FRAME := 5

# Taille des cartes dans la grille de collection
const GRID_CARD_SCALE       := 0.9
const GRID_CARD_HOVER_SCALE := 1.5
const GRID_WRAPPER_SIZE     := Vector2(236, 354)
const CARD_BASE_SIZE        := Vector2(250, 375)  # taille native de Card.tscn

# Preview au survol — même principe et même échelle que sur le board (BoardMinion)
const PREVIEW_SCALE := 0.9
const PREVIEW_GAP   := 12.0
# Teinte des cartes de la grille dont le max de copies est atteint
const MAXED_TINT    := Color(0.38, 0.38, 0.38, 1)

@onready var card_grid:        GridContainer = %CardGrid
@onready var deck_list:        VBoxContainer = %DeckList
@onready var deck_name_edit:   LineEdit      = %DeckNameEdit
@onready var card_count_label: Label         = %CardCountLabel
@onready var save_button:      Button        = %SaveButton
@onready var back_button:      Button        = %BackButton
@onready var search_edit:      LineEdit      = %SearchEdit
@onready var filter_bar:       HBoxContainer = %FilterBar
@onready var header_label:     Label         = $MainVBox/HeaderBar/HeaderMargin/HeaderHBox/HeaderLabel

var current_deck: DeckData = null
var _all_cards: Array[CardData] = []
var _pending_cards: Array[CardData] = []
var _is_loading_grid: bool = false

# Tooltip state
var _keyword_tooltips: Array[Control] = []
var _tooltip_layer:    CanvasLayer    = null
var _hovering:         bool           = false
var _hovered_wrapper:  Control        = null
var _hovered_row:      Control        = null

# Preview de carte au survol (grille + liste du deck)
var _preview_layer: CanvasLayer = null
var _hover_preview: Card        = null
var _max_tooltip:   Control     = null

# resource_path -> Card (visuel dans la grille), pour griser au max de copies
var _grid_visuals: Dictionary = {}

# ─── Filtres ──────────────────────────────────────────────────────────────────

var _filter_text:       String = ""
var _filter_race:       int = -1   # Race.Type, -1 = tous
var _filter_rarity:     String = ""
var _filter_type:       String = ""
var _filter_cost:       int    = -1

const CARD_SCENE = preload("res://scenes/card/Card.tscn")

func _ready() -> void:
	_preview_layer = CanvasLayer.new()
	_preview_layer.layer = 19
	add_child(_preview_layer)
	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)
	deck_name_edit.text_changed.connect(_on_name_changed)
	search_edit.text_changed.connect(_on_search_changed)
	_load_all_cards()
	_refresh_deck_list()
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()   # construit aussi la barre de filtres localisée

# Met à jour les libellés fixes et la barre de filtres dans la langue courante.
func _retranslate() -> void:
	header_label.text            = SettingsManager.t("deck.title")
	back_button.text             = SettingsManager.t("ui.back")
	save_button.text             = SettingsManager.t("deck.save")
	search_edit.placeholder_text = SettingsManager.t("deck.search")
	deck_name_edit.placeholder_text = SettingsManager.t("deck.name_placeholder")
	_build_filter_bar()   # relocalise les libellés de filtres (sélection préservée)
	_update_count_label()

# ─── Chargement cartes ────────────────────────────────────────────────────────

func _load_all_cards() -> void:
	_all_cards = CardLibrary.all_cards.duplicate()
	_refresh_card_grid()


# ─── Grille cartes disponibles ────────────────────────────────────────────────

var _load_generation: int = 0

func _refresh_card_grid() -> void:
	_load_generation += 1
	var my_generation: int = _load_generation
	for child in card_grid.get_children():
		child.queue_free()
	_grid_visuals.clear()

	_pending_cards.clear()
	for card_data in _all_cards:
		if _match_filters(card_data):
			_pending_cards.append(card_data)

	_load_next_batch(my_generation)


func _match_filters(c: CardData) -> bool:
	if _filter_text != "" and not c.display_name().to_lower().contains(_filter_text.to_lower()):
		return false
	if _filter_race != -1 and c.race != _filter_race:
		return false
	if _filter_rarity != "" and c.rarity != _filter_rarity:
		return false
	if _filter_type != "" and c.card_type != _filter_type:
		return false
	if _filter_cost == 7 and c.cost < 7:
		return false
	elif _filter_cost >= 0 and _filter_cost < 7 and c.cost != _filter_cost:
		return false
	return true

func _load_next_batch(generation: int) -> void:
	if generation != _load_generation or _pending_cards.is_empty():
		return
	for i in range(CARDS_PER_FRAME):
		if _pending_cards.is_empty():
			break
		_add_card_to_grid(_pending_cards.pop_front())
	await get_tree().process_frame
	_load_next_batch(generation)

func _add_card_to_grid(card_data: CardData) -> void:
	var wrapper := Control.new()
	wrapper.custom_minimum_size = GRID_WRAPPER_SIZE
	wrapper.size                = GRID_WRAPPER_SIZE
	wrapper.clip_contents       = false
	wrapper.mouse_filter        = Control.MOUSE_FILTER_STOP
	card_grid.add_child(wrapper)

	var card_visual: Card = CARD_SCENE.instantiate() as Card
	card_visual.set_non_interactive()
	card_visual.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	card_visual.scale         = Vector2(GRID_CARD_SCALE, GRID_CARD_SCALE)
	card_visual.pivot_offset  = Vector2(0, 0)
	card_visual.position      = Vector2(0, 0)
	wrapper.add_child(card_visual)
	card_visual.set_data(card_data)

	_grid_visuals[card_data.resource_path] = card_visual
	if _is_card_maxed(card_data):
		card_visual.modulate = MAXED_TINT

	wrapper.gui_input.connect(_on_card_wrapper_input.bind(card_data))
	wrapper.mouse_entered.connect(_on_card_wrapper_entered.bind(card_data, wrapper))
	wrapper.mouse_exited.connect(_on_card_wrapper_exited)

func _on_card_wrapper_input(event: InputEvent, card_data: CardData) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		_on_add_card(card_data)

func _on_card_wrapper_entered(card_data: CardData, wrapper: Control) -> void:
	_hovered_wrapper = wrapper
	_hovering = true
	_show_hover_preview(card_data, wrapper)
	if _is_card_maxed(card_data):
		_show_max_copies_tooltip(wrapper)
	await _show_keyword_tooltips(card_data)

func _on_card_wrapper_exited() -> void:
	_hovered_wrapper = null
	_hovering = false
	_clear_hover_preview()
	_hide_keyword_tooltips()

# ─── Liste deck à droite ──────────────────────────────────────────────────────

func _refresh_deck_list() -> void:
	# Si une ligne du deck était survolée, elle va être détruite : on nettoie
	# la preview pour éviter qu'elle reste affichée (mouse_exited ne tire pas).
	if _hovered_row != null:
		_hovered_row = null
		_hovering = false
		_clear_hover_preview()
		_hide_keyword_tooltips()
	for child in deck_list.get_children():
		child.queue_free()
	_update_grid_maxed_states()
	if current_deck == null:
		_update_count_label()
		return

	var counts: Dictionary = {}
	for path in current_deck.card_paths:
		counts[path] = counts.get(path, 0) + 1

	var seen: Array[String] = []
	for path in current_deck.card_paths:
		if path in seen:
			continue
		seen.append(path)
		var card := load(path) as CardData
		if card == null:
			continue
		deck_list.add_child(_make_deck_row(card, path, counts[path]))

	_update_count_label()

func _make_deck_row(card: CardData, path: String, count: int) -> Control:
	var bg := StyleBoxFlat.new()
	bg.bg_color                   = Color(0.12, 0.10, 0.08, 1)
	bg.corner_radius_top_left     = 3
	bg.corner_radius_top_right    = 3
	bg.corner_radius_bottom_left  = 3
	bg.corner_radius_bottom_right = 3

	var bg_hover := bg.duplicate() as StyleBoxFlat
	bg_hover.bg_color             = Color(0.20, 0.16, 0.10, 1)
	bg_hover.border_color         = Color(0.55, 0.41, 0.08, 0.6)
	bg_hover.border_width_left    = 1
	bg_hover.border_width_right   = 1
	bg_hover.border_width_top     = 1
	bg_hover.border_width_bottom  = 1

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(0, 34)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	var cost_bg := StyleBoxFlat.new()
	cost_bg.bg_color                  = Color(0.55, 0.41, 0.08, 0.9)
	cost_bg.corner_radius_top_left    = 3
	cost_bg.corner_radius_bottom_left = 3
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", cost_bg)
	cost_panel.custom_minimum_size = Vector2(28, 0)
	var cost_lbl := Label.new()
	cost_lbl.text                 = str(card.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", Color(0.05, 0.04, 0.02, 1))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_panel.add_child(cost_lbl)
	row.add_child(cost_panel)

	var name_lbl := Label.new()
	name_lbl.text                  = card.display_name()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_lbl.add_theme_font_size_override("font_size", 14)
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 8)
	name_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_margin.add_child(name_lbl)
	row.add_child(name_margin)

	var qty_lbl := Label.new()
	qty_lbl.text                 = str(count)
	qty_lbl.custom_minimum_size  = Vector2(22, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.8))
	qty_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(qty_lbl)

	var del_btn := Button.new()
	del_btn.text                = "✕"
	del_btn.flat                = true
	del_btn.custom_minimum_size = Vector2(28, 0)
	del_btn.add_theme_color_override("font_color",       Color(0.6, 0.3, 0.3, 1))
	del_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4, 1))
	del_btn.add_theme_font_size_override("font_size", 12)
	del_btn.pressed.connect(_on_remove_one.bind(path))
	row.add_child(del_btn)

	panel.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", bg_hover)
		_hovered_row = panel
		_hovering = true
		_show_hover_preview(card, panel, true)
		_show_keyword_tooltips(card)
	)
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", bg)
		if _hovered_row == panel:
			_hovered_row = null
			_hovering = false
			_clear_hover_preview()
			_hide_keyword_tooltips()
	)

	return panel

func _update_count_label() -> void:
	var count := current_deck.size() if current_deck else 0
	card_count_label.text     = SettingsManager.t("deck.count_format") % [count, MAX_CARDS, MIN_CARDS]
	card_count_label.modulate = Color(1, 0.4, 0.4) if count < MIN_CARDS else Color(0.5, 0.9, 0.5)

# ─── Actions ──────────────────────────────────────────────────────────────────

func load_deck(deck: DeckData) -> void:
	current_deck = deck
	deck_name_edit.text = deck.name
	_refresh_deck_list()

func _on_add_card(card_data: CardData) -> void:
	if current_deck == null:
		return
	if not DeckManager.can_add_card(current_deck, card_data):
		return
	current_deck.add_card(card_data)
	_refresh_deck_list()
	# Si on vient d'atteindre le max de copies, feedback immédiat sous le curseur
	if _is_card_maxed(card_data) and _hovered_wrapper != null and is_instance_valid(_hovered_wrapper):
		_show_max_copies_tooltip(_hovered_wrapper)

func _on_remove_one(path: String) -> void:
	if current_deck == null:
		return
	var idx := current_deck.card_paths.rfind(path)
	if idx >= 0:
		current_deck.remove_card_at(idx)
	_refresh_deck_list()

func _on_name_changed(new_name: String) -> void:
	if current_deck:
		current_deck.name = new_name

func _on_search_changed(text: String) -> void:
	_filter_text = text
	_refresh_card_grid()

func _on_save() -> void:
	if current_deck == null or current_deck.size() < MIN_CARDS:
		return
	DeckManager.save_decks()

func _on_back() -> void:
	DeckManager.save_decks()
	queue_free()

# ─── Preview de carte au survol — même principe que sur le board ─────────────

## Affiche la carte en popup à côté de `anchor` (à droite par défaut,
## à gauche si demandé ou si la place manque à droite), sans l'agrandir.
func _show_hover_preview(card_data: CardData, anchor: Control, prefer_left: bool = false) -> void:
	_clear_hover_preview()
	var preview := CARD_SCENE.instantiate() as Card
	preview.set_non_interactive()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.scale = Vector2(PREVIEW_SCALE, PREVIEW_SCALE)
	_preview_layer.add_child(preview)
	preview.set_data(card_data)

	var pv_size := CARD_BASE_SIZE * PREVIEW_SCALE
	var vp := get_viewport_rect().size
	var x := anchor.global_position.x + anchor.size.x + PREVIEW_GAP
	if prefer_left or x + pv_size.x > vp.x:
		x = anchor.global_position.x - pv_size.x - PREVIEW_GAP
	var y := anchor.global_position.y + (anchor.size.y - pv_size.y) / 2.0
	y = clampf(y, 8.0, maxf(8.0, vp.y - pv_size.y - 8.0))
	preview.global_position = Vector2(x, y)
	_hover_preview = preview

func _clear_hover_preview() -> void:
	if _hover_preview != null and is_instance_valid(_hover_preview):
		_hover_preview.queue_free()
	_hover_preview = null
	if _max_tooltip != null and is_instance_valid(_max_tooltip):
		_max_tooltip.queue_free()
	_max_tooltip = null

# ─── Limite de copies ─────────────────────────────────────────────────────────

func _count_in_deck(path: String) -> int:
	if current_deck == null:
		return 0
	var count := 0
	for p in current_deck.card_paths:
		if p == path:
			count += 1
	return count

func _is_card_maxed(card_data: CardData) -> bool:
	return _count_in_deck(card_data.resource_path) >= MAX_COPIES

## Grise les cartes de la grille dont le deck contient déjà le max de copies.
func _update_grid_maxed_states() -> void:
	for path in _grid_visuals.keys():
		var visual: Card = _grid_visuals[path]
		if not is_instance_valid(visual):
			continue
		visual.modulate = MAXED_TINT if _count_in_deck(path) >= MAX_COPIES else Color.WHITE

## Tooltip centré sur la carte grisée : max de copies atteint.
func _show_max_copies_tooltip(anchor: Control) -> void:
	if _max_tooltip != null and is_instance_valid(_max_tooltip):
		_max_tooltip.queue_free()
	var panel := TooltipData.make_race_tooltip("deck.max_copies_reached")
	panel.position = Vector2(-9999, -9999)
	_preview_layer.add_child(panel)
	_max_tooltip = panel
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	if not _hovering or not is_instance_valid(anchor):
		_clear_hover_preview()
		return
	panel.global_position = anchor.global_position + (anchor.size - panel.size) / 2.0

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

## Panneaux de mots-clés à côté de la preview, tooltip de race centré dessous.
func _show_keyword_tooltips(card_data: CardData) -> void:
	_hide_keyword_tooltips()
	if card_data == null or _hover_preview == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	add_child(_tooltip_layer)
	var panels: Array[Control] = TooltipData.build_panels_for_card(card_data, _tooltip_layer)

	var race_panel: Control = null
	if TooltipData.RACE_DESCRIPTIONS.has(card_data.race):
		race_panel = TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)

	await get_tree().process_frame
	if not _hovering or not is_instance_valid(_hover_preview):
		_hide_keyword_tooltips()
		return

	var pv_pos  := _hover_preview.global_position
	var pv_size := CARD_BASE_SIZE * PREVIEW_SCALE
	var vp      := get_viewport_rect().size
	var base_y  := pv_pos.y
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		var px := pv_pos.x + pv_size.x + PREVIEW_GAP
		if px + panel.size.x > vp.x:
			px = pv_pos.x - panel.size.x - PREVIEW_GAP
		panel.global_position = Vector2(px, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

	if race_panel != null and is_instance_valid(race_panel):
		var rx: float = clampf(
			pv_pos.x + pv_size.x / 2.0 - race_panel.size.x / 2.0,
			4.0, vp.x - race_panel.size.x - 4.0)
		var ry: float = pv_pos.y + pv_size.y + 4.0
		if ry + race_panel.size.y > vp.y:
			ry = pv_pos.y - race_panel.size.y - 4.0
		race_panel.global_position = Vector2(rx, ry)
		_keyword_tooltips.append(race_panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null
		
# ─── Filtres ──────────────────────────────────────────────────────────────────

## Crée la barre de filtres directement en code sous la SearchEdit.
## Appelle cette fonction dans _ready(), après _load_all_cards().
func _build_filter_bar() -> void:
	# Reconstruit à chaque appel (notamment au changement de langue) : on vide
	# d'abord les libellés/groupes existants. La sélection active est préservée
	# car chaque groupe s'initialise depuis les variables _filter_*.
	for child in filter_bar.get_children():
		child.queue_free()

	var all_label := SettingsManager.t("deck.filter_all")

	# Race
	var race_values: Array = [-1]
	var race_labels: Array[String] = [all_label]
	for key in Race.Type.keys():
		race_values.append(Race.Type[key])
		race_labels.append(SettingsManager.t("RACE_" + key))
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_race")))
	_add_filter_group(filter_bar, race_values,
		func(v: int) -> void: _filter_race = v; _refresh_card_grid(),
		func() -> int: return _filter_race,
		race_labels)

	# Type de carte
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_type")))
	_add_filter_group(filter_bar, ["", "Minion", "Instant", "Ritual", "Enchantment"],
		func(v: String) -> void: _filter_type = v; _refresh_card_grid(),
		func() -> String: return _filter_type,
		[all_label, SettingsManager.t("cardtype.minion"), SettingsManager.t("cardtype.instant"),
			SettingsManager.t("cardtype.ritual"), SettingsManager.t("cardtype.enchantment")])

	# Rareté
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_rarity")))
	_add_filter_group(filter_bar, ["", "Common", "Rare", "Epic", "Legendary"],
		func(v: String) -> void: _filter_rarity = v; _refresh_card_grid(),
		func() -> String: return _filter_rarity,
		[all_label, "Common", "Rare", "Epic", "Legendary"])

	# Coût
	filter_bar.add_child(_make_filter_label(SettingsManager.t("deck.filter_cost")))
	_add_filter_group(filter_bar, [-1, 0, 1, 2, 3, 4, 5, 6, 7],
		func(v: int) -> void: _filter_cost = v; _refresh_card_grid(),
		func() -> int: return _filter_cost,
		[all_label, "0", "1", "2", "3", "4", "5", "6", "7+"])


func _make_filter_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 0.4, 1))
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


## Crée un groupe de boutons radio pour un filtre donné.
## values      : tableau de valeurs (String ou int)
## on_select   : callable(value) appelé au clic
## get_current : callable() → valeur active
## labels      : libellés affichés (même taille que values)
func _add_filter_group(parent: Control, values: Array, on_select: Callable,
		get_current: Callable, labels: Array) -> void:
	var group_box := HBoxContainer.new()
	group_box.add_theme_constant_override("separation", 2)
	parent.add_child(group_box)

	var buttons: Array[Button] = []
	for i in range(values.size()):
		var val   = values[i]
		var label = labels[i] if i < labels.size() else str(val)
		var btn   := Button.new()
		btn.text               = label
		btn.toggle_mode        = true
		btn.button_pressed     = (val == get_current.call())
		btn.custom_minimum_size = Vector2(0, 26)
		btn.add_theme_font_size_override("font_size", 12)
		_style_filter_button(btn, btn.button_pressed)
		buttons.append(btn)
		group_box.add_child(btn)

		btn.pressed.connect(func() -> void:
			# Déselectionne les autres du groupe
			for b in buttons:
				b.button_pressed = false
				_style_filter_button(b, false)
			btn.button_pressed = true
			_style_filter_button(btn, true)
			on_select.call(val)
		)


func _style_filter_button(btn: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color                   = Color(0.35, 0.26, 0.06, 0.9) if active else Color(0.12, 0.10, 0.08, 0.85)
	sb.border_color               = Color(0.78, 0.58, 0.10, 1) if active else Color(0.30, 0.24, 0.10, 0.6)
	sb.border_width_left          = 1
	sb.border_width_right         = 1
	sb.border_width_top           = 1
	sb.border_width_bottom        = 1
	sb.corner_radius_top_left     = 4
	sb.corner_radius_top_right    = 4
	sb.corner_radius_bottom_left  = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left        = 7
	sb.content_margin_right       = 7
	sb.content_margin_top         = 3
	sb.content_margin_bottom      = 3
	btn.add_theme_stylebox_override("normal",   sb)
	btn.add_theme_stylebox_override("pressed",  sb)
	btn.add_theme_stylebox_override("hover",    sb)
	var font_color := Color(0.98, 0.85, 0.40, 1) if active else Color(0.72, 0.64, 0.48, 1)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_pressed_color", font_color)
	btn.add_theme_color_override("font_hover_color",   Color(1, 0.92, 0.60, 1))
