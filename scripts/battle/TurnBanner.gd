extends Control
class_name TurnBanner

## Bannière de transition de tour : affiche brièvement « À vous de jouer » /
## « Tour adverse » au centre de l'écran, sans bloquer les inputs.
## Créée entièrement en code par Battle (aucun nœud dans Battle.tscn).

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const SHOW_TIME  := 0.25  # apparition (fondu + léger zoom)
const HOLD_TIME  := 0.9   # durée de lecture
const HIDE_TIME  := 0.35  # disparition

var _panel: PanelContainer
var _label: Label
var _hint_label: Label
var _tween: Tween

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color("1a0e0edd")
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color("c9a227")
	style.content_margin_left        = 60
	style.content_margin_right       = 60
	style.content_margin_top         = 12
	style.content_margin_bottom      = 12
	style.shadow_color               = Color(0, 0, 0, 0.5)
	style.shadow_size                = 8
	_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(vbox)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT_BOLD)
	_label.add_theme_font_size_override("font_size", 42)
	_label.add_theme_color_override("font_color", Color("e8d5a3"))
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	vbox.add_child(_label)

	_hint_label = Label.new()
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_override("font", FONT_BOLD)
	_hint_label.add_theme_font_size_override("font_size", 20)
	_hint_label.add_theme_color_override("font_color", Color("c9a227"))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)
	_hint_label.visible = false
	vbox.add_child(_hint_label)

	add_child(_panel)
	_panel.visible = false
	_panel.modulate.a = 0.0

# Affiche le texte donné (déjà traduit) puis disparaît toute seule.
func show_banner(text: String) -> void:
	await _show(text, false)
	_tween.tween_interval(HOLD_TIME)
	_tween.tween_property(_panel, "modulate:a", 0.0, HIDE_TIME)
	_tween.tween_callback(func(): _panel.visible = false)

# Affiche le texte donné avec un sous-texte optionnel et reste visible tant que
# hide_banner() n'est pas appelé explicitement (mulligan : dure jusqu'à confirmation).
func show_banner_persistent(text: String, hint: String = "") -> void:
	_hint_label.text = hint
	_hint_label.visible = not hint.is_empty()
	await _show(text, true)

# Fait disparaître une bannière affichée en mode persistant.
func hide_banner() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 0.0, HIDE_TIME)
	_tween.tween_callback(func():
		_panel.visible = false
		_hint_label.visible = false)

func _show(text: String, persistent: bool) -> void:
	_label.text = text
	if not persistent:
		_hint_label.visible = false
	if _tween:
		_tween.kill()
	# Centre le panneau après mise à jour de sa taille par le texte.
	_panel.reset_size()
	await get_tree().process_frame
	# Utilise la taille du viewport plutôt que celle du Control : au tout
	# premier affichage (début de bataille), le layout de ce Control
	# ancré en plein écran peut ne pas encore avoir propagé sa taille,
	# ce qui plaçait le panneau dans le coin haut-gauche, coupé.
	_panel.position = (get_viewport_rect().size - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.visible = true
	_panel.scale = Vector2(1.15, 1.15)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_panel, "modulate:a", 1.0, SHOW_TIME)
	_tween.tween_property(_panel, "scale", Vector2.ONE, SHOW_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
