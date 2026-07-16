extends Control
class_name ReconnectOverlay

## Voile de pause affiché quand le pair réseau subit une coupure transitoire :
## bloque visuellement le plateau et affiche un décompte avant abandon.
## Créée entièrement en code par Battle (aucun nœud dans Battle.tscn),
## comme TurnBanner/CombatLogPanel.

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")

var _panel: PanelContainer
var _label: Label
var _seconds_left: float = 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color              = Color("1a0e0edd")
	style.border_width_left     = 2
	style.border_width_right    = 2
	style.border_width_top      = 2
	style.border_width_bottom   = 2
	style.border_color          = Color("c9a227")
	style.content_margin_left   = 40
	style.content_margin_right  = 40
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	style.shadow_color          = Color(0, 0, 0, 0.5)
	style.shadow_size           = 8
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT_BOLD)
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color("e8d5a3"))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_panel.add_child(_label)

	add_child(_panel)

func show_overlay(grace_seconds: float) -> void:
	_seconds_left = grace_seconds
	visible = true
	_update_label()
	_center_panel()

func hide_overlay() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_seconds_left = maxf(_seconds_left - delta, 0.0)
	_update_label()

func _update_label() -> void:
	_label.text = SettingsManager.t("battle.reconnect.waiting") % int(ceil(_seconds_left))
	_center_panel()

func _center_panel() -> void:
	_panel.reset_size()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0
