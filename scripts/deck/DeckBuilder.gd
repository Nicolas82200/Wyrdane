extends Control

const ALL_CARDS_PATH := "res://resources/cards"
const MIN_CARDS := 40
const MAX_CARDS := 60
const MAX_COPIES := 4

@onready var card_grid:        GridContainer = %CardGrid
@onready var deck_list:        VBoxContainer = %DeckList
@onready var deck_name_edit:   LineEdit      = %DeckNameEdit
@onready var card_count_label: Label         = %CardCountLabel
@onready var save_button:      Button        = %SaveButton
@onready var back_button:      Button        = %BackButton
@onready var search_edit:      LineEdit      = %SearchEdit

var current_deck: DeckData = null
var _all_cards: Array[CardData] = []
var _keyword_tooltips: Array[Control] = []
var _tooltip_layer: CanvasLayer = null
var _hovering: bool = false
var _hovered_wrapper: Control = null

const CARD_SCENE = preload("res://scenes/card/Card.tscn")

func _ready() -> void:
	_style_button(save_button)
	_style_button(back_button)
	save_button.pressed.connect(_on_save)
	back_button.pressed.connect(_on_back)
	deck_name_edit.text_changed.connect(_on_name_changed)
	search_edit.text_changed.connect(_on_search_changed)
	_load_all_cards()
	_refresh_card_grid()
	_refresh_deck_list()

func _process(_delta: float) -> void:
	if _hovered_wrapper == null or not is_instance_valid(_hovered_wrapper):
		return
	if _keyword_tooltips.is_empty():
		return
	var base_x: float = _hovered_wrapper.global_position.x + _hovered_wrapper.size.x + 15
	var base_y: float = _hovered_wrapper.global_position.y
	for tooltip in _keyword_tooltips:
		if not is_instance_valid(tooltip):
			continue
		tooltip.global_position = Vector2(base_x, base_y)
		base_y += tooltip.size.y + 6
# ─── Chargement cartes ────────────────────────────────────────────────────────

func _load_all_cards() -> void:
	_all_cards.clear()
	_scan_cards_recursive(ALL_CARDS_PATH)
	_all_cards.sort_custom(func(a, b): return a.cost < b.cost)

func _scan_cards_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path + "/" + file_name
		if dir.current_is_dir():
			_scan_cards_recursive(full_path)
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is CardData:
				_all_cards.append(res)
		file_name = dir.get_next()
	dir.list_dir_end()

# ─── Grille cartes disponibles ────────────────────────────────────────────────

func _refresh_card_grid(filter: String = "") -> void:
	for child in card_grid.get_children():
		child.queue_free()
	for card_data in _all_cards:
		if filter != "" and not card_data.card_name.to_lower().contains(filter.to_lower()):
			continue

		var wrapper := Control.new()
		wrapper.custom_minimum_size = Vector2(200, 300)
		wrapper.size = Vector2(200, 300)
		wrapper.clip_contents = false
		wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
		card_grid.add_child(wrapper)

		var card_visual: Control = CARD_SCENE.instantiate()
		card_visual.set_non_interactive()
		card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_visual.scale = Vector2(0.75, 0.75)
		card_visual.pivot_offset = Vector2(0, 0)
		card_visual.position = Vector2(0, 0)
		wrapper.add_child(card_visual)
		card_visual.set_data(card_data)

		wrapper.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton \
					and event.button_index == MOUSE_BUTTON_LEFT \
					and event.pressed:
				_on_add_card(card_data)
		)
		wrapper.mouse_entered.connect(func():
			_hovered_wrapper = wrapper
			_hovering = true
			var tween := create_tween()
			tween.tween_property(card_visual, "scale", Vector2(0.80, 0.80), 0.12)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			await get_tree().process_frame
			await get_tree().process_frame
			if not _hovering:
				return
			var tooltip_x: float = wrapper.global_position.x + wrapper.size.x + 15
			var tooltip_y: float = wrapper.global_position.y
			await self._show_keyword_tooltips(card_data, tooltip_x, tooltip_y)
		)
		wrapper.mouse_exited.connect(func():
			_hovered_wrapper = null
			_hovering = false
			var tween := create_tween()
			tween.tween_property(card_visual, "scale", Vector2(0.75, 0.75), 0.12)\
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			self._hide_keyword_tooltips()
		)

# ─── Liste deck à droite ──────────────────────────────────────────────────────

func _refresh_deck_list() -> void:
	for child in deck_list.get_children():
		child.queue_free()
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
		var row := _make_deck_row(card, path, counts[path])
		deck_list.add_child(row)

	_update_count_label()

func _make_deck_row(card: CardData, path: String, count: int) -> Control:
	# Conteneur principal avec fond
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.08, 1)
	bg.corner_radius_top_left    = 3
	bg.corner_radius_top_right   = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right= 3

	var bg_hover := bg.duplicate() as StyleBoxFlat
	bg_hover.bg_color = Color(0.20, 0.16, 0.10, 1)
	bg_hover.border_color = Color(0.55, 0.41, 0.08, 0.6)
	bg_hover.border_width_left   = 1
	bg_hover.border_width_right  = 1
	bg_hover.border_width_top    = 1
	bg_hover.border_width_bottom = 1

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(0, 34)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	panel.add_child(row)

	# Badge coût mana
	var cost_bg := StyleBoxFlat.new()
	cost_bg.bg_color = Color(0.55, 0.41, 0.08, 0.9)
	cost_bg.corner_radius_top_left    = 3
	cost_bg.corner_radius_bottom_left = 3
	var cost_panel := PanelContainer.new()
	cost_panel.add_theme_stylebox_override("panel", cost_bg)
	cost_panel.custom_minimum_size = Vector2(28, 0)
	var cost_lbl := Label.new()
	cost_lbl.text = str(card.cost)
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cost_lbl.add_theme_color_override("font_color", Color(0.05, 0.04, 0.02, 1))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_panel.add_child(cost_lbl)
	row.add_child(cost_panel)

	# Nom de la carte
	var name_lbl := Label.new()
	name_lbl.text = card.card_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	name_lbl.add_theme_font_size_override("font_size", 14)
	var name_margin := MarginContainer.new()
	name_margin.add_theme_constant_override("margin_left", 8)
	name_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_margin.add_child(name_lbl)
	row.add_child(name_margin)

	# Badge quantité
	var qty_lbl := Label.new()
	qty_lbl.text = str(count)
	qty_lbl.custom_minimum_size = Vector2(22, 0)
	qty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_lbl.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 0.8))
	qty_lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(qty_lbl)

	# Bouton retirer
	var del_btn := Button.new()
	del_btn.text = "✕"
	del_btn.flat = true
	del_btn.custom_minimum_size = Vector2(28, 0)
	del_btn.add_theme_color_override("font_color", Color(0.6, 0.3, 0.3, 1))
	del_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4, 1))
	del_btn.add_theme_font_size_override("font_size", 12)
	del_btn.pressed.connect(_on_remove_one.bind(path))
	row.add_child(del_btn)

	# Hover sur le panel
	panel.mouse_entered.connect(func():
		panel.add_theme_stylebox_override("panel", bg_hover)
	)
	panel.mouse_exited.connect(func():
		panel.add_theme_stylebox_override("panel", bg)
	)

	return panel

func _update_count_label() -> void:
	var count := current_deck.size() if current_deck else 0
	card_count_label.text = "%d / %d  cartes  (min %d)" % [count, MAX_CARDS, MIN_CARDS]
	card_count_label.modulate = Color(1, 0.4, 0.4) if count < MIN_CARDS else Color(0.5, 0.9, 0.5)

# ─── Actions ──────────────────────────────────────────────────────────────────

func load_deck(deck: DeckData) -> void:
	current_deck = deck
	deck_name_edit.text = deck.name
	_refresh_deck_list()

func _on_add_card(card_data: CardData) -> void:
	if current_deck == null:
		return
	if current_deck.size() >= MAX_CARDS:
		return
	var copies := 0
	for path in current_deck.card_paths:
		if path == card_data.resource_path:
			copies += 1
	if copies >= MAX_COPIES:
		return
	current_deck.add_card(card_data)
	_refresh_deck_list()

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
	_refresh_card_grid(text)

func _on_save() -> void:
	if current_deck == null:
		return
	if current_deck.size() < MIN_CARDS:
		return
	DeckManager.save_decks()

func _on_back() -> void:
	DeckManager.save_decks()
	queue_free()

# ─── Style boutons ────────────────────────────────────────────────────────────

func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("1a1a2eaa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b6914")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("0d0d1eee")
	pressed_style.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("e8d5a3"))
	btn.add_theme_color_override("font_hover_color", Color("fff5d6"))
	btn.add_theme_font_size_override("font_size", 16)

# ─── Tooltips ─────────────────────────────────────────────────────────────────

const KEYWORD_DESCRIPTIONS := {
	Keyword.Type.TAUNT:      { "title": "Rempart",       "desc": "Les ennemis doivent attaquer cette créature en priorité." },
	Keyword.Type.AEGIS:      { "title": "Égide",         "desc": "Absorbe la prochaine source de dégâts. Le bouclier disparaît ensuite." },
	Keyword.Type.CHARGE:     { "title": "Assaut",        "desc": "Peut attaquer dès le tour où elle est invoquée." },
	Keyword.Type.LIFESTEAL:  { "title": "Moisson",       "desc": "Les dégâts infligés soignent votre héros d'autant." },
	Keyword.Type.FURY:       { "title": "Frénésie",      "desc": "Peut attaquer deux fois par tour." },
}

const TRIGGER_DESCRIPTIONS := {
	"ONPLAY":      { "title": "Invocation",     "desc": "Déclenché quand cette créature est jouée depuis la main." },
	"DEATHRATTLE": { "title": "Dernier souffle", "desc": "Déclenché quand cette créature meurt." },
	"ASSAUT":      { "title": "Assaut",          "desc": "Déclenché quand cette créature attaque." },
	"BLESSURE":    { "title": "Blessure",        "desc": "Déclenché quand cette créature reçoit des dégâts." },
	"EVEIL":       { "title": "Éveil",           "desc": "Déclenché au début de votre tour." },
	"DECLIN":      { "title": "Déclin",          "desc": "Déclenché à la fin de votre tour." },
	"RALLIEMENT":  { "title": "Ralliement",      "desc": "Déclenché quand un allié est invoqué." },
	"DEUIL":       { "title": "Deuil",           "desc": "Déclenché quand un allié meurt." },
	"SORTILEGE":   { "title": "Sortilège",       "desc": "Déclenché quand un sort est lancé." },
	"SACRIFICE":   { "title": "Sacrifice",       "desc": "Déclenché quand un allié est sacrifié." },
	"EXECUTION":   { "title": "Exécution",       "desc": "Déclenché quand cette créature détruit un ennemi." },
	"CARNAGE":     { "title": "Carnage",         "desc": "Déclenché quand cette créature survit à un combat." },
}

func _show_keyword_tooltips(card_data: CardData, base_x: float, base_y: float) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	add_child(_tooltip_layer)
	var panels: Array[Control] = []
	for keyword in card_data.get_keyword_values():
		if not KEYWORD_DESCRIPTIONS.has(keyword):
			continue
		var info: Dictionary = KEYWORD_DESCRIPTIONS[keyword]
		var panel := _make_tooltip_panel(info["title"], info["desc"])
		panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(panel)
		panels.append(panel)
	for trigger in card_data.trigger_types:
		if not TRIGGER_DESCRIPTIONS.has(trigger.type):
			continue
		var info: Dictionary = TRIGGER_DESCRIPTIONS[trigger.type]
		var panel := _make_tooltip_panel(info["title"], info["desc"])
		panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(panel)
		panels.append(panel)
	await get_tree().process_frame
	if not _hovering:
		_hide_keyword_tooltips()
		return
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null

func _make_tooltip_panel(title: String, desc: String) -> PanelContainer:
	var bg := StyleBoxFlat.new()
	bg.bg_color            = Color(0.13, 0.10, 0.06, 0.96)
	bg.border_width_left   = 2
	bg.border_width_right  = 2
	bg.border_width_top    = 2
	bg.border_width_bottom = 2
	bg.border_color        = Color(0.55, 0.38, 0.10, 1.0)
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", bg)
	panel.custom_minimum_size = Vector2(220, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color            = Color(0.22, 0.16, 0.07, 1.0)
	title_bg.border_width_bottom = 1
	title_bg.border_color        = Color(0.55, 0.38, 0.10, 0.8)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35, 1.0))
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_stylebox_override("normal", title_bg)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	var desc_label := Label.new()
	desc_label.text = desc
	desc_label.add_theme_color_override("font_color", Color(0.82, 0.78, 0.70, 1.0))
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.add_theme_constant_override("margin_left", 6)
	desc_label.add_theme_constant_override("margin_right", 6)
	desc_label.add_theme_constant_override("margin_bottom", 6)
	vbox.add_child(desc_label)
	return panel
