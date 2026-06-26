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
			var tween := create_tween()
			tween.tween_property(card_visual, "scale", Vector2(0.80, 0.80), 0.12) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)
		wrapper.mouse_exited.connect(func():
			var tween := create_tween()
			tween.tween_property(card_visual, "scale", Vector2(0.75, 0.75), 0.12) \
				.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
