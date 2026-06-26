extends Control
class_name BoardMinion

signal minion_clicked(minion, board_minion)

var minion = null
var is_selected := false

@onready var art              = $Art
@onready var attack_label     = $AttackLabel
@onready var health_label     = $HealthLabel
@onready var border_highlight: Panel = $BorderHighlight
@onready var border_color: Panel = get_node_or_null("BorderColor")
@onready var keyword_icons: HBoxContainer = $KeywordIcons

const KEYWORD_ICONS := {
	Keyword.Type.TAUNT:       preload("res://assets/icons/taunt-icon.png"),
	Keyword.Type.AEGIS:       preload("res://assets/icons/aegis-icon.png"),
}
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
	"ONPLAY": {
		"title": "Invocation",
		"desc": "Déclenché quand cette créature est jouée depuis la main."
	},
	"DEATHRATTLE": {
		"title": "Dernier souffle",
		"desc": "Déclenché quand cette créature meurt."
	},
	"ASSAUT": {
		"title": "Assaut",
		"desc": "Déclenché quand cette créature attaque."
	},
	"BLESSURE": {
		"title": "Blessure",
		"desc": "Déclenché quand cette créature reçoit des dégâts."
	},
	"EVEIL": {
		"title": "Éveil",
		"desc": "Déclenché au début de votre tour."
	},
	"DECLIN": {
		"title": "Déclin",
		"desc": "Déclenché à la fin de votre tour."
	},
	"RALLIEMENT": {
		"title": "Ralliement",
		"desc": "Déclenché quand un allié est invoqué."
	},
	"DEUIL": {
		"title": "Deuil",
		"desc": "Déclenché quand un allié meurt."
	},
	"SORTILEGE": {
		"title": "Sortilège",
		"desc": "Déclenché quand un sort est lancé."
	},
	"SACRIFICE": {
		"title": "Sacrifice",
		"desc": "Déclenché quand un allié est sacrifié."
	},
	"EXECUTION": {
		"title": "Exécution",
		"desc": "Déclenché quand cette créature détruit un ennemi."
	},
	"CARNAGE": {
		"title": "Carnage",
		"desc": "Déclenché quand cette créature survit à un combat."
	},
}

var _keyword_tooltips: Array[Control] = []
var _highlight_style: StyleBoxFlat
var _race_style: StyleBoxFlat
var _targetable_style: StyleBoxFlat = null
var _targetable: bool = false
var _pulse_time: float = 0.0

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
var _hover_preview: Card = null

const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

func _ready() -> void:
	_highlight_style = StyleBoxFlat.new()
	_highlight_style.bg_color            = Color.TRANSPARENT
	_highlight_style.border_width_left   = 2
	_highlight_style.border_width_right  = 2
	_highlight_style.border_width_top    = 2
	_highlight_style.border_width_bottom = 2
	_highlight_style.border_color        = Color(1.0, 0.9, 0.3)
	border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	border_highlight.visible = false

	_race_style = StyleBoxFlat.new()
	_race_style.bg_color            = Color.TRANSPARENT
	_race_style.border_width_left   = 8
	_race_style.border_width_right  = 8
	_race_style.border_width_top    = 15
	_race_style.border_width_bottom = 0
	_race_style.border_blend        = true
	if border_color:
		border_color.add_theme_stylebox_override("panel", _race_style)

	mouse_filter = Control.MOUSE_FILTER_STOP
	for child in get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _process(delta: float) -> void:
	if not _targetable or _targetable_style == null:
		return
	_pulse_time += delta * 3.0
	var alpha: float = 0.6 + sin(_pulse_time) * 0.4
	_targetable_style.border_color.a = alpha
	border_highlight.queue_redraw()

func set_minion(new_minion) -> void:
	minion = new_minion
	update_display()

func update_display() -> void:
	if minion == null:
		return
	attack_label.text = str(minion.attack)
	health_label.text = str(max(minion.health, 0))
	var c := Color.WHITE if minion.can_attack() else Color(0.7, 0.7, 0.7)
	modulate.r = c.r
	modulate.g = c.g
	modulate.b = c.b
	if minion.card_data.texture:
		art.texture = minion.card_data.texture
	_race_style.border_color = BORDER_RACE_COLORS.get(minion.card_data.race, Color.WHITE)
	if border_color:
		border_color.queue_redraw()
	_refresh_keyword_icons()

func set_selected(value: bool, multi: bool = false) -> void:
	is_selected = value
	if not _targetable:
		border_highlight.visible = value
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	if value and multi:
		_highlight_style.border_color = Color(1.0, 0.45, 0.05)
	else:
		_highlight_style.border_color = Color(1.0, 0.9, 0.3)
	border_highlight.queue_redraw()

func set_targetable(value: bool, color: Color = Color.WHITE) -> void:
	_targetable  = value
	_pulse_time  = 0.0
	if value:
		if _targetable_style == null:
			_targetable_style = StyleBoxFlat.new()
			_targetable_style.bg_color            = Color.TRANSPARENT
			_targetable_style.border_width_left   = 3
			_targetable_style.border_width_right  = 3
			_targetable_style.border_width_top    = 3
			_targetable_style.border_width_bottom = 3
		_targetable_style.border_color = color
		border_highlight.add_theme_stylebox_override("panel", _targetable_style)
		border_highlight.visible = true
	else:
		# Remet le style de sélection normal
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
		border_highlight.visible = is_selected

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		minion_clicked.emit(minion, self)

func _on_mouse_entered() -> void:
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var battle = get_tree().current_scene
	if battle and battle.has_method("is_dragging_card") and battle.call("is_dragging_card"):
		return
	if _hover_preview != null:
		return
	if CARD_SCENE == null or not CARD_SCENE.can_instantiate():
		push_error("BoardMinion: CARD_SCENE is invalid")
		return
	_hover_preview = CARD_SCENE.instantiate()
	if _hover_preview == null:
		push_error("BoardMinion: instantiate() returned null")
		return
	_hover_preview.drag_enabled = false
	_hover_preview.z_index = 1000
	get_tree().current_scene.add_child(_hover_preview)
	_hover_preview.set_data(minion.card_data)
	_hover_preview.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame
	if not is_instance_valid(_hover_preview):
		return
	_hover_preview.global_position = global_position + Vector2(
		size.x + 15,
		(size.y - _hover_preview.size.y * 0.9) / 2.0
	)
	var tooltip_x := _hover_preview.global_position.x + _hover_preview.size.x * 0.9 + 15
	var tooltip_y := _hover_preview.global_position.y
	await _show_keyword_tooltips(tooltip_x, tooltip_y)

func _on_mouse_exited() -> void:
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	_hide_keyword_tooltips() 
	if _hover_preview:
		_hover_preview.queue_free()
		_hover_preview = null
var _tooltip_layer: CanvasLayer = null

func _show_keyword_tooltips(base_x: float = 0.0, base_y_override: float = -1.0) -> void:
	_hide_keyword_tooltips()
	if minion == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	get_tree().current_scene.add_child(_tooltip_layer)
	if base_x == 0.0:
		base_x = global_position.x + size.x + 15 + 225 * 0.9 + 15
	var panels: Array[Control] = []
	for keyword in minion.keywords:
		if not KEYWORD_DESCRIPTIONS.has(keyword):
			continue
		var panel := _make_tooltip_panel(KEYWORD_DESCRIPTIONS[keyword]["title"], KEYWORD_DESCRIPTIONS[keyword]["desc"])
		panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(panel)
		panels.append(panel)
	for trigger in minion.card_data.trigger_types:
		if not TRIGGER_DESCRIPTIONS.has(trigger.type):
			continue
		var panel := _make_tooltip_panel(TRIGGER_DESCRIPTIONS[trigger.type]["title"], TRIGGER_DESCRIPTIONS[trigger.type]["desc"])
		panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(panel)
		panels.append(panel)
	await get_tree().process_frame
	var base_y := base_y_override if base_y_override >= 0.0 else get_screen_position().y
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
	# Fond style Hearthstone — brun foncé avec bordure dorée
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

	# Séparateur titre
	var title_bg := StyleBoxFlat.new()
	title_bg.bg_color      = Color(0.22, 0.16, 0.07, 1.0)
	title_bg.border_width_bottom = 1
	title_bg.border_color  = Color(0.55, 0.38, 0.10, 0.8)

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



func _refresh_keyword_icons() -> void:
	if not is_node_ready() or keyword_icons == null:
		return
	for child in keyword_icons.get_children():
		child.queue_free()
	for keyword in minion.keywords:
		if not KEYWORD_ICONS.has(keyword):
			continue
		var icon := TextureRect.new()
		icon.texture             = KEYWORD_ICONS[keyword]
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter        = Control.MOUSE_FILTER_PASS
		keyword_icons.add_child(icon)
