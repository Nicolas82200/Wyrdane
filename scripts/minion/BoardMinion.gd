# BoardMinion.gd
extends Control
class_name BoardMinion

signal minion_clicked(minion, board_minion)

var minion = null
var is_selected := false

@onready var art              = $Art
@onready var attack_label     = $AttackLabel
@onready var health_label     = $HealthLabel
@onready var border_highlight: Panel     = $BorderHighlight
@onready var border_color: Panel         = get_node_or_null("BorderColor")
@onready var keyword_icons: HBoxContainer = $KeywordIcons

const KEYWORD_ICONS := {
	Keyword.Type.TAUNT: preload("res://assets/icons/taunt-icon.png"),
	Keyword.Type.AEGIS: preload("res://assets/icons/aegis-icon.png"),
	Keyword.Type.DEADLY_POISON: preload("res://assets/icons/poison-icon.png"),
	Keyword.Type.CHARGE: preload("res://assets/icons/charge-icon.png"),
	Keyword.Type.FURY: preload("res://assets/icons/fury-icon.png")
}

const BORDER_RACE_COLORS := {
	Race.Type.UNDEAD: Color("342e1ae1"),
	Race.Type.HUMAN:  Color("5a4a35e1"),
	Race.Type.ELF:    Color("2f5d50e1"),
	Race.Type.DWARF:  Color("5a3a22e1"),
	Race.Type.DEMON:  Color("5a1f1fe1"),
}

var _keyword_tooltips: Array[Control] = []
var _highlight_style: StyleBoxFlat
var _race_style: StyleBoxFlat
var _targetable_style: StyleBoxFlat = null
var _targetable: bool = false
var _pulse_time: float = 0.0
var _mouse_is_over: bool = false

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
var _hover_preview: Card = null
var _tooltip_layer: CanvasLayer = null

# [FIX] Référence mise en cache — plus de get_tree().current_scene partout
var _battle: Node = null

func _ready() -> void:
	_battle = get_tree().current_scene

	# [FIX] Chaque instance crée son propre StyleBoxFlat — pas de partage accidentel
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

# ─── Données ──────────────────────────────────────────────────────────────────

func set_minion(new_minion) -> void:
	minion = new_minion
	update_display()

func update_display() -> void:
	if minion == null or minion.card_data == null:
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

# ─── Sélection / Ciblage ──────────────────────────────────────────────────────

func set_selected(value: bool, multi: bool = false) -> void:
	is_selected = value
	if not _targetable:
		border_highlight.visible = value
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
	_highlight_style.border_color = Color(1.0, 0.45, 0.05) if (value and multi) else Color(1.0, 0.9, 0.3)
	border_highlight.queue_redraw()

func set_targetable(value: bool, color: Color = Color.WHITE) -> void:
	_targetable = value
	_pulse_time = 0.0
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
		border_highlight.add_theme_stylebox_override("panel", _highlight_style)
		border_highlight.visible = is_selected

# ─── Input ────────────────────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		minion_clicked.emit(minion, self)

# ─── Hover & Preview ──────────────────────────────────────────────────────────

func _on_mouse_entered() -> void:
	_mouse_is_over = true
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if _battle and _battle.has_method("is_dragging_card") and _battle.call("is_dragging_card"):
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
	_battle.add_child(_hover_preview)
	_hover_preview.set_data(minion.card_data)
	_hover_preview.scale = Vector2(0.9, 0.9)
	await get_tree().process_frame

	# [FIX] Guard sur _mouse_is_over — évite les états invalides si la souris sort pendant l'await
	if not _mouse_is_over or not is_instance_valid(_hover_preview):
		_cleanup_hover()
		return

	_hover_preview.global_position = global_position + Vector2(
		size.x + 15,
		(size.y - _hover_preview.size.y * 0.9) / 2.0
	)
	var tooltip_x := _hover_preview.global_position.x + _hover_preview.size.x * 0.9 + 15
	var tooltip_y := _hover_preview.global_position.y
	await _show_keyword_tooltips(tooltip_x, tooltip_y)

func _on_mouse_exited() -> void:
	_mouse_is_over = false
	if _targetable:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)
	_cleanup_hover()

func _cleanup_hover() -> void:
	_hide_keyword_tooltips()
	if _hover_preview:
		_hover_preview.queue_free()
		_hover_preview = null

# ─── Tooltips — délégués à TooltipData ───────────────────────────────────────

func _show_keyword_tooltips(base_x: float, base_y_override: float = -1.0) -> void:
	_hide_keyword_tooltips()
	if minion == null:
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 20
	_battle.add_child(_tooltip_layer)

	var panels: Array[Control] = TooltipData.build_panels_for_card(minion.card_data, _tooltip_layer)
	await get_tree().process_frame

	if not _mouse_is_over:
		_hide_keyword_tooltips()
		return

	var base_y := base_y_override if base_y_override >= 0.0 else get_screen_position().y
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.global_position = Vector2(base_x, base_y)
		base_y += panel.size.y + 6
		_keyword_tooltips.append(panel)

	if TooltipData.RACE_DESCRIPTIONS.has(minion.card_data.race):
		if not is_instance_valid(_tooltip_layer):
			return
		var race_panel := TooltipData.make_race_tooltip(TooltipData.RACE_DESCRIPTIONS[minion.card_data.race])
		race_panel.position = Vector2(-9999, -9999)
		_tooltip_layer.add_child(race_panel)
		await get_tree().process_frame
		if is_instance_valid(race_panel) and is_instance_valid(_hover_preview):
			var preview_bottom  := _hover_preview.global_position.y + _hover_preview.size.y * 0.9
			var preview_center_x := _hover_preview.global_position.x + (_hover_preview.size.x * 0.9) / 2.0
			race_panel.global_position = Vector2(
				preview_center_x - race_panel.size.x / 2.0,
				preview_bottom + 6
			)
			_keyword_tooltips.append(race_panel)

func _hide_keyword_tooltips() -> void:
	for tooltip in _keyword_tooltips:
		if is_instance_valid(tooltip):
			tooltip.queue_free()
	_keyword_tooltips.clear()
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		_tooltip_layer.queue_free()
		_tooltip_layer = null

# ─── Icônes de keywords ───────────────────────────────────────────────────────

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
