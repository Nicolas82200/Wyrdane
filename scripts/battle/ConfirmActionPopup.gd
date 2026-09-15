extends Control
class_name ConfirmActionPopup

## Popup de confirmation générique (Oui/Non) utilisée pour les réglages
## Gameplay "Confirmation avant attaque"/"Confirmation avant sacrifice" (voir
## SettingsManager.confirm_before_attack/confirm_before_sacrifice). Créée
## entièrement en code par Battle (aucun nœud dans Battle.tscn), même
## convention que TurnBanner/CombatLogPanel/KeywordGlossaryPanel.
## N'occupe qu'un petit panneau centré (pas de plein écran) : le plateau
## reste visible derrière, conformément aux principes UX de CLAUDE.md.

const FADE_TIME := 0.15

var _overlay: ColorRect
var _panel: PanelContainer
var _label: Label
var _yes_button: Button
var _no_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 150
	hide()

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.45)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a1a2eee")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("8b6914")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	_panel.add_theme_stylebox_override("panel", style)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	_panel.add_child(vbox)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color("e8d5a3"))
	vbox.add_child(_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_yes_button = Button.new()
	_yes_button.custom_minimum_size = Vector2(120, 40)
	btn_row.add_child(_yes_button)

	_no_button = Button.new()
	_no_button.custom_minimum_size = Vector2(120, 40)
	btn_row.add_child(_no_button)

# Affiche la popup avec le texte donné (déjà traduit), bloque jusqu'au choix du
# joueur. Retourne true si "Oui" (confirmé), false si "Non"/annulé.
func confirm(text: String) -> bool:
	_label.text = text
	_yes_button.text = SettingsManager.t("battle.confirm.yes")
	_no_button.text = SettingsManager.t("battle.confirm.no")
	modulate.a = 0.0
	show()
	_panel.reset_size()
	await get_tree().process_frame
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_TIME)

	var result: bool = await _wait_for_choice()
	hide()
	return result

func _wait_for_choice() -> bool:
	var yes_pressed := false
	var done := false
	var on_yes := func():
		yes_pressed = true
		done = true
	var on_no := func():
		yes_pressed = false
		done = true
	_yes_button.pressed.connect(on_yes, CONNECT_ONE_SHOT)
	_no_button.pressed.connect(on_no, CONNECT_ONE_SHOT)
	while not done:
		await get_tree().process_frame
	return yes_pressed
