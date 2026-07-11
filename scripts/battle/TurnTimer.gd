extends Control
class_name TurnTimer

## Décompte du temps de tour du joueur local : une barre verticale qui se vide
## (de haut en bas), placée à gauche de ManaDisplay/EndTurnButton, qui passe en
## alerte sous WARNING_THRESHOLD secondes. Créée entièrement en code par Battle
## (aucun nœud dans Battle.tscn), sur le modèle de TurnBanner. À l'expiration,
## émet `timeout` : Battle enchaîne alors sur une fin de tour (ou de mulligan)
## automatique (voir Battle._on_turn_timer_timeout).

signal timeout

const DEFAULT_DURATION := 45.0
const WARNING_THRESHOLD := 10.0
const COLOR_NORMAL  := Color("c9a227")
const COLOR_WARNING := Color("e05252")
const BAR_WIDTH := 14.0

var time_left: float = 0.0
var running: bool    = false

var _bar: ProgressBar
var _fill_style: StyleBoxFlat

func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(BAR_WIDTH, 116)
	# Aligné à gauche du bloc ManaDisplay/EndTurnButton (voir leurs offsets dans
	# Battle.tscn : x -230..-60, y -172..-56), avec un petit espace entre les deux.
	offset_left   = -254.0
	offset_top    = -172.0
	offset_right  = -240.0
	offset_bottom = -56.0

	_bar = ProgressBar.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_bar.show_percentage = false
	_bar.min_value = 0.0

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color        = Color("1a0e0edd")
	bg_style.border_width_left   = 1
	bg_style.border_width_right  = 1
	bg_style.border_width_top    = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color("c9a227")
	_bar.add_theme_stylebox_override("background", bg_style)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = COLOR_NORMAL
	_bar.add_theme_stylebox_override("fill", _fill_style)

	add_child(_bar)
	visible = false

# Démarre (ou redémarre) le décompte pour le tour/mulligan en cours.
func start(duration: float = DEFAULT_DURATION) -> void:
	time_left = duration
	running = true
	visible = true
	if _bar != null:
		_bar.max_value = duration
		_bar.value = duration
	if _fill_style != null:
		_fill_style.bg_color = COLOR_NORMAL

func stop() -> void:
	running = false
	visible = false

func _process(delta: float) -> void:
	if not running:
		return
	var just_timed_out := tick(delta)
	_refresh_bar()
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

func _refresh_bar() -> void:
	if _bar == null:
		return
	_bar.value = time_left
	_fill_style.bg_color = COLOR_WARNING if time_left <= WARNING_THRESHOLD else COLOR_NORMAL
