extends Control
class_name TurnTimer

## Décompte du temps de tour du joueur local : un petit panneau affichant le
## temps restant (mm:ss), qui passe en alerte sous WARNING_THRESHOLD secondes.
## Créé entièrement en code par Battle (aucun nœud dans Battle.tscn), sur le
## modèle de TurnBanner. À l'expiration, émet `timeout` : Battle enchaîne alors
## sur une fin de tour automatique (voir Battle._on_turn_timer_timeout).

signal timeout

const FONT_BOLD := preload("res://assets/fonts/MedievalSharp-Bold.ttf")
const DEFAULT_DURATION := 90.0
const WARNING_THRESHOLD := 10.0
const COLOR_NORMAL  := Color("e8d5a3")
const COLOR_WARNING := Color("e05252")

var time_left: float = 0.0
var running: bool    = false

var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 32)
	offset_left   = -230.0
	offset_top    = -140.0
	offset_right  = -60.0
	offset_bottom = -108.0

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color              = Color("1a0e0edd")
	style.border_width_top      = 1
	style.border_width_bottom   = 1
	style.border_color          = Color("c9a227")
	style.content_margin_top    = 4
	style.content_margin_bottom = 4
	_panel.add_theme_stylebox_override("panel", style)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", FONT_BOLD)
	_label.add_theme_font_size_override("font_size", 22)
	_panel.add_child(_label)

	add_child(_panel)
	visible = false

# Démarre (ou redémarre) le décompte pour le tour en cours.
func start(duration: float = DEFAULT_DURATION) -> void:
	time_left = duration
	running = true
	visible = true
	_refresh_label()

func stop() -> void:
	running = false
	visible = false

func _process(delta: float) -> void:
	if not running:
		return
	var just_timed_out := tick(delta)
	_refresh_label()
	if just_timed_out:
		timeout.emit()

# Logique pure du décompte, testable sans arbre de scène : avance le temps
# restant et retourne true si le compteur vient d'atteindre zéro (une seule
# fois, puis le timer s'arrête).
func tick(delta: float) -> bool:
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0 and running:
		running = false
		return true
	return false

func _refresh_label() -> void:
	if _label == null:
		return
	var seconds := int(ceil(time_left))
	_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
	_label.add_theme_color_override("font_color", COLOR_WARNING if time_left <= WARNING_THRESHOLD else COLOR_NORMAL)
