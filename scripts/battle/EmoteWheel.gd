extends Control
class_name EmoteWheel

## Petit menu d'emotes cosmétiques (texte + emoji, aucun asset requis) —
## purement décoratif, aucune incidence sur l'état de partie. Envoyé au pair
## distant via NetCommand.EMOTE (id seulement, jamais de texte libre, pour
## éviter tout abus type chat). Créé entièrement en code par Battle, même
## convention que ConfirmActionPopup/TurnBanner.

signal emote_picked(emote_id: int)

const EMOTES := ["👋 Salut !", "😄 Bien joué !", "😠 Grr...", "🍀 Bonne chance !"]

var _panel: PanelContainer
var _toggle_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_toggle_button = Button.new()
	_toggle_button.text = "🙂"
	_toggle_button.custom_minimum_size = Vector2(40, 40)
	_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle_button.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_button)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a1a2eee")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("8b6914")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	_panel.add_theme_stylebox_override("panel", style)
	_panel.position = Vector2(0, _toggle_button.custom_minimum_size.y + 4)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	for i in EMOTES.size():
		var btn := Button.new()
		btn.text = EMOTES[i]
		btn.custom_minimum_size = Vector2(140, 32)
		btn.pressed.connect(_on_emote_selected.bind(i))
		vbox.add_child(btn)

func _on_toggle_pressed() -> void:
	_panel.visible = not _panel.visible

func _on_emote_selected(emote_id: int) -> void:
	_panel.visible = false
	emote_picked.emit(emote_id)

static func text_for(emote_id: int) -> String:
	if emote_id < 0 or emote_id >= EMOTES.size():
		return ""
	return EMOTES[emote_id]
