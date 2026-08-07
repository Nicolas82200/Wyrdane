extends RefCounted
class_name CampaignUI

# Petits utilitaires visuels partagés par les 6 écrans du mode Campagne, pour
# éviter de dupliquer le style de bouton (repris de GameOverScreen._style_button)
# dans chaque script d'écran.

const BG_COLOR := Color("0d0d1ef2")
const PANEL_BG_COLOR := Color("1a1a2eaa")
const BORDER_COLOR := Color("8b6914")
const TITLE_COLOR := Color("e8d5a3")
const BODY_COLOR := Color("cfc2a0")

static func style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = PANEL_BG_COLOR
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = BORDER_COLOR
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	normal.content_margin_left   = 16
	normal.content_margin_right  = 16
	normal.content_margin_top    = 10
	normal.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("0d0d1eee")
	pressed_style.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	var disabled_style := normal.duplicate() as StyleBoxFlat
	disabled_style.bg_color     = Color("15151faa")
	disabled_style.border_color = Color("444444")
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_color",          TITLE_COLOR)
	btn.add_theme_color_override("font_hover_color",     Color("fff5d6"))
	btn.add_theme_color_override("font_disabled_color",  Color("777777"))
	btn.add_theme_font_size_override("font_size", 18)

static func style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color                   = PANEL_BG_COLOR
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = BORDER_COLOR
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left   = 24
	style.content_margin_right  = 24
	style.content_margin_top    = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)

static func make_title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", TITLE_COLOR)
	label.add_theme_font_size_override("font_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

static func make_body_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", BODY_COLOR)
	label.add_theme_font_size_override("font_size", 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label

static func make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bg
