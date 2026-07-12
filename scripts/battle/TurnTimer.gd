extends Control
class_name TurnTimer

## Décompte du temps de tour/mulligan du joueur local : au lieu d'un chiffre,
## la bordure du bouton Fin du tour / Commencer (end_turn_button) se vide
## progressivement pour indiquer le temps restant, dans le sens des aiguilles
## d'une montre à partir du coin haut-gauche. Attaché comme enfant du bouton
## par Battle (voir Battle._init_systems), sur le modèle du halo "ready hint"
## de EndTurnButton. À l'expiration, émet `timeout` : Battle enchaîne alors
## sur une fin de tour (ou de mulligan) automatique.

signal timeout

const DEFAULT_DURATION := 45.0
const WARNING_THRESHOLD := 10.0
const COLOR_NORMAL  := Color("c9a227d0")
const COLOR_WARNING := Color("e05252d0")
const BORDER_WIDTH := 4.0
const MARGIN := 4.0
const CORNER_RADIUS := 10.0
const ARC_POINTS := 8

var time_left: float = 0.0
var duration: float  = 0.0
var running: bool    = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# Démarre (ou redémarre) le décompte pour le tour/mulligan en cours.
func start(new_duration: float = DEFAULT_DURATION) -> void:
	duration = new_duration
	time_left = new_duration
	running = true
	visible = true
	_sync_rect()
	queue_redraw()

func stop() -> void:
	running = false
	visible = false

func _process(delta: float) -> void:
	if not running:
		return
	var just_timed_out := tick(delta)
	_sync_rect()
	queue_redraw()
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

# Se cale juste à l'extérieur du bouton parent (même marge que le halo
# "ready hint" de EndTurnButton).
func _sync_rect() -> void:
	var parent := get_parent()
	if parent is Control:
		var parent_size: Vector2 = (parent as Control).size
		position = Vector2(-MARGIN, -MARGIN)
		size = parent_size + Vector2(MARGIN, MARGIN) * 2.0

func _draw() -> void:
	if not visible or duration <= 0.0:
		return
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var r := minf(CORNER_RADIUS, minf(w, h) / 2.0)
	var segments := _rounded_rect_path(w, h, r)
	var frac := clampf(time_left / duration, 0.0, 1.0)
	var remaining := frac * _path_length(segments, r)
	var color := COLOR_WARNING if time_left <= WARNING_THRESHOLD else COLOR_NORMAL
	for seg in segments:
		if remaining <= 0.0:
			break
		remaining = _draw_segment(seg, r, remaining, color)

# Contour arrondi complet, dans le sens horaire à partir du bord haut (juste
# après le coin haut-gauche), en alternant côtés droits et arcs de coin.
func _rounded_rect_path(w: float, h: float, r: float) -> Array:
	return [
		{"type": "line", "a": Vector2(r, 0), "b": Vector2(w - r, 0)},
		{"type": "arc", "center": Vector2(w - r, r), "from": -PI / 2.0, "to": 0.0},
		{"type": "line", "a": Vector2(w, r), "b": Vector2(w, h - r)},
		{"type": "arc", "center": Vector2(w - r, h - r), "from": 0.0, "to": PI / 2.0},
		{"type": "line", "a": Vector2(w - r, h), "b": Vector2(r, h)},
		{"type": "arc", "center": Vector2(r, h - r), "from": PI / 2.0, "to": PI},
		{"type": "line", "a": Vector2(0, h - r), "b": Vector2(0, r)},
		{"type": "arc", "center": Vector2(r, r), "from": PI, "to": 3.0 * PI / 2.0},
	]

func _path_length(segments: Array, r: float) -> float:
	var total := 0.0
	for seg in segments:
		total += _segment_length(seg, r)
	return total

func _segment_length(seg: Dictionary, r: float) -> float:
	if seg["type"] == "line":
		return (seg["a"] as Vector2).distance_to(seg["b"])
	return r * absf(seg["to"] - seg["from"])

# Dessine la portion de ce segment couverte par `remaining`, et retourne ce
# qu'il en reste pour le segment suivant.
func _draw_segment(seg: Dictionary, r: float, remaining: float, color: Color) -> float:
	var seg_len := _segment_length(seg, r)
	if seg_len <= 0.0:
		return remaining
	var t := clampf(remaining / seg_len, 0.0, 1.0)
	if seg["type"] == "line":
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		draw_line(a, a.lerp(b, t), color, BORDER_WIDTH)
	else:
		var from: float = seg["from"]
		var to: float = seg["to"]
		draw_arc(seg["center"], r, from, from + (to - from) * t, ARC_POINTS, color, BORDER_WIDTH, true)
	return remaining - seg_len
