extends Control
class_name Hand

signal card_played(card_data: CardData, row: String, insert_index: int)
signal drag_started
signal drag_ended

@onready var container = $CardsContainer
@onready var preview   = $CardPreview

const CARD_SCENE      := preload("res://scenes/card/Card.tscn")
const NORMAL_SCALE    := Vector2(0.75, 0.75)
const SPACING         := 100.0
const COMPACT_SPACING := 20.0
const ARC_STRENGTH    := 20.0

const KEYWORD_DESCRIPTIONS := {
	Keyword.Type.TAUNT: {
		"title": "Rempart",
		"desc": "Les ennemis doivent attaquer cette créature en priorité."
	},
	Keyword.Type.AEGIS: {
		"title": "Égide",
		"desc": "Absorbe la prochaine source de dégâts. Le bouclier disparaît ensuite."
	},
	Keyword.Type.CHARGE: {
		"title": "Assaut",
		"desc": "Peut attaquer dès le tour où elle est invoquée."
	},
	Keyword.Type.LIFESTEAL: {
		"title": "Moisson",
		"desc": "Les dégâts infligés soignent votre héros d'autant."
	},
	Keyword.Type.FURY: {
		"title": "Frénésie",
		"desc": "Peut attaquer deux fois par tour."
	},
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

var _base_positions:    Dictionary     = {}
var _is_compact:        bool           = false
var can_play_check:     Callable       = Callable()
var create_drag_preview: Callable      = Callable()
var _keyword_tooltips:  Array[Control] = []
var _tooltip_layer:     CanvasLayer    = null
var _hovering: bool = false

func _ready() -> void:
	preview.hide()

func set_hand(cards: Array[CardData], animate_last: bool = false, deck_origin: Vector2 = Vector2.ZERO) -> void:
	if not animate_last:
		for c in container.get_children():
			c.queue_free()
		_base_positions.clear()
		await get_tree().process_frame
		for card_data in cards:
			var card: Card = CARD_SCENE.instantiate()
			container.add_child(card)
			card.set_data(card_data)
			card.scale = NORMAL_SCALE
			_connect_card(card)
		await get_tree().process_frame
		for card in container.get_children():
			card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
			card.visible = true
		_update_hand_layout(false)
		return

	var new_card_data: CardData = cards.back()
	var new_card: Card = CARD_SCENE.instantiate()
	new_card.visible = false
	container.add_child(new_card)
	new_card.set_data(new_card_data)
	new_card.scale = NORMAL_SCALE
	_connect_card(new_card)
	await get_tree().process_frame
	new_card.pivot_offset = Vector2(new_card.size.x / 2.0, new_card.size.y)
	_update_hand_layout(false)
	var children := container.get_children()
	for i in range(children.size() - 1):
		var card = children[i]
		var tween_existing := create_tween()
		tween_existing.set_parallel(true)
		tween_existing.tween_property(card, "position", _base_positions[card], 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_existing.tween_property(card, "scale",    card.scale,            0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var final_pos   = new_card.global_position
	var final_scale = new_card.scale
	var ghost: Card = CARD_SCENE.instantiate()
	get_tree().current_scene.add_child(ghost)
	ghost.set_data(new_card_data)
	ghost.drag_enabled = false
	ghost.show_back(true)
	ghost.scale    = final_scale
	ghost.modulate = Color.WHITE
	ghost.z_index  = 100
	ghost.visible  = false
	await get_tree().process_frame
	ghost.global_position = deck_origin - Vector2(
		ghost.size.x * final_scale.x / 2.0,
		ghost.size.y * final_scale.y / 2.0
	)
	ghost.visible = true
	var mid_pos := Vector2(
		(deck_origin.x + final_pos.x) / 2.0,
		(deck_origin.y + final_pos.y) / 2.0 - 100
	)
	var tween := create_tween()
	tween.set_parallel(false)
	tween.tween_property(ghost, "global_position", mid_pos,       0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ghost, "scale:x",         0.0,           0.1).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func(): ghost.show_back(false))
	tween.tween_property(ghost, "scale:x",         final_scale.x, 0.1).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(ghost, "global_position", final_pos,     0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		new_card.visible = true
		ghost.queue_free()
	)

# ─── Carte cliquée ────────────────────────────────────────────────────────────

func _on_card_clicked(card_data: CardData, row: String = "Front", insert_index: int = -1) -> void:
	card_played.emit(card_data, row, insert_index)

# ─── Hover ────────────────────────────────────────────────────────────────────

func _on_card_hover(card: Card) -> void:
	_hovering = true
	var battle = get_tree().current_scene
	if battle and battle.has_method("is_dragging_card") and battle.call("is_dragging_card"):
		return
	for c in container.get_children():
		if c is Card and c.dragging:
			return
	if card.dragging:
		return
	preview.set_data(card.data)
	preview.scale   = Vector2(1.1, 1.1)
	preview.z_index = 100
	var pos := card.global_position
	preview.global_position = Vector2(
		pos.x - preview.size.x * 0.25,
		pos.y - preview.size.y * 1.0
	)
	preview.show()
	card.drag_started.connect(func(): preview.hide())
	await get_tree().process_frame
	await get_tree().process_frame
	if not _hovering or not is_instance_valid(card) or card.dragging:
		return
	var tooltip_x: float = preview.global_position.x + preview.size.x * 1.1 + 15
	var tooltip_y: float = preview.global_position.y
	await _show_keyword_tooltips(card.data, tooltip_x, tooltip_y)

func _on_card_unhover() -> void:
	_hovering = false
	preview.hide()
	_hide_keyword_tooltips()

# ─── Tooltips ─────────────────────────────────────────────────────────────────

func _show_keyword_tooltips(card_data: CardData, base_x: float, base_y: float) -> void:
	_hide_keyword_tooltips()
	if card_data == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	get_tree().current_scene.add_child(_tooltip_layer)
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

# ─── Layout ───────────────────────────────────────────────────────────────────

func set_compact(compact: bool) -> void:
	if _is_compact == compact:
		return
	_is_compact = compact
	var cards := container.get_children()
	var count := cards.size()
	if count == 0:
		return
	var viewport           := get_viewport_rect().size
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	var hand_bottom        := size.y - 30.0
	var scale_factor       := 1.0 - (count - 1) * reduction_per_card
	scale_factor = clamp(scale_factor, 0.55, 1.2)
	var target_spacing: float = COMPACT_SPACING if compact else SPACING
	if count > 1:
		target_spacing = min(target_spacing, max_width / float(count - 1)) if not compact else COMPACT_SPACING
	target_spacing = max(target_spacing, SPACING * 0.3) if not compact else COMPACT_SPACING
	for i in range(count):
		var card   = cards[i]
		var offset := float(i) - float(count - 1) / 2.0
		var norm: float = offset / max(float(count - 1) / 2.0, 1.0)
		var pos := Vector2(
			80.0 + i * target_spacing,
			hand_bottom - card.size.y + (norm * norm) * ARC_STRENGTH
		)
		_base_positions[card] = pos
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(card, "position", pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func is_compact() -> bool:
	return _is_compact

func _update_hand_layout(animated: bool = false) -> void:
	var cards := container.get_children()
	var count := cards.size()
	if count == 0:
		return
	var viewport           := get_viewport_rect().size
	var max_width          := viewport.x * 0.3
	var reduction_per_card := 0.04
	var hand_bottom        := size.y - 30.0
	var scale_factor       := 1.0 - (count - 1) * reduction_per_card
	scale_factor = clamp(scale_factor, 0.55, 1.2)
	var hand_scale := Vector2(scale_factor, scale_factor)
	var spacing: float = SPACING if not _is_compact else COMPACT_SPACING
	if count > 1:
		spacing = min(spacing, max_width / float(count - 1)) if not _is_compact else COMPACT_SPACING
	spacing = max(spacing, SPACING * 0.3) if not _is_compact else COMPACT_SPACING
	var start_x := 80.0
	for i in range(count):
		var card   = cards[i]
		var offset := float(i) - float(count - 1) / 2.0
		var norm: float = offset / max(float(count - 1) / 2.0, 1.0)
		var pos := Vector2(
			start_x + i * spacing,
			hand_bottom - card.size.y + (norm * norm) * ARC_STRENGTH
		)
		_base_positions[card] = pos
		card.z_index  = i
		card.scale    = hand_scale
		card.position = pos
		if animated:
			var tween := create_tween()
			tween.set_parallel(true)
			tween.tween_property(card, "position", pos,        0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(card, "scale",    hand_scale, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			card.position = pos
			card.scale    = hand_scale

# ─── Connexions ───────────────────────────────────────────────────────────────

func _relay_drag_started() -> void:
	drag_started.emit()

func _relay_drag_ended() -> void:
	drag_ended.emit()

func _connect_card(card: Card) -> void:
	if not card.card_clicked.is_connected(_on_card_clicked):
		card.card_clicked.connect(_on_card_clicked)
	if not card.drag_started.is_connected(_relay_drag_started):
		card.drag_started.connect(_relay_drag_started)
	if not card.drag_ended.is_connected(_relay_drag_ended):
		card.drag_ended.connect(_relay_drag_ended)
	if not card.mouse_entered.is_connected(_on_card_hover):
		card.mouse_entered.connect(_on_card_hover.bind(card))
	if not card.mouse_exited.is_connected(_on_card_unhover):
		card.mouse_exited.connect(_on_card_unhover)
	for child in card.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	if can_play_check.is_valid():
		card.can_drag_check = can_play_check
	if create_drag_preview.is_valid():
		card.create_drag_preview = create_drag_preview
