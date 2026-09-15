extends Control
class_name MatchReplayView

## Fenêtre "Voir le replay" affichée après une partie (voir GameOverScreen) :
## liste en lecture seule du journal de combat de la partie qui vient de se
## terminer (SettingsManager.last_match_log). Ce n'est pas un vrai système de
## replay (aucun rejeu animé du plateau, aucune sérialisation d'état complet)
## — juste le même journal textuel affiché en jeu (CombatLogPanel), consultable
## après coup sans limite de taille. Créée entièrement en code, même
## convention que ConfirmActionPopup/TurnBanner.

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const PANEL_SIZE := Vector2(420, 520)

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _close_button: Button

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 160
	hide()

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a0e0ee6")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("c9a227")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_override("font", FONT_BOLD)
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color("e8d5a3"))
	vbox.add_child(_title_label)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(PANEL_SIZE.x - 32, PANEL_SIZE.y - 90)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)

	_close_button = Button.new()
	_close_button.custom_minimum_size = Vector2(0, 40)
	_close_button.pressed.connect(hide)
	vbox.add_child(_close_button)

	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

func show_log(entries: Array) -> void:
	for child in _list.get_children():
		child.queue_free()
	for entry in entries:
		if entry is Dictionary:
			_list.add_child(CombatLogPanel.make_entry_row(entry))
	show()
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0

func _retranslate() -> void:
	_title_label.text = SettingsManager.t("battle.gameover.replay_title")
	_close_button.text = SettingsManager.t("ui.back")
