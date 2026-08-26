# Autoload global : remplace les change_scene_to_file() bruts par un fondu au
# noir, pour éviter le figeage/flash d'une frame vide entre deux scènes (menu
# ↔ Battle, retour Arena, fin de handshake réseau...). Reprend le principe
# anti-flash de LoadingScreen._swap_to_next_scene (nouvelle scène ajoutée
# avant que l'ancienne soit libérée) en le généralisant à tout appelant via un
# cache-écran opaque plutôt qu'un fondu de contenu spécifique à une scène.
extends CanvasLayer

const FADE_DURATION := 0.25

@onready var _overlay: ColorRect = _make_overlay()

func _make_overlay() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay)

# Remplace get_tree().change_scene_to_file(path) : fondu au noir, swap sans
# frame vide, fondu retour. Bloque les clics pendant la transition.
func change_scene(path: String) -> void:
	await _fade(1.0)
	_swap_scene(path)
	await _fade(0.0)

func _fade(target_alpha: float) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if target_alpha > 0.0 else Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION * SettingsManager.motion_scale())
	await tween.finished

func _swap_scene(path: String) -> void:
	var tree := get_tree()
	var old_root := tree.current_scene
	var next_root: Node = (load(path) as PackedScene).instantiate()
	tree.root.add_child(next_root)
	tree.current_scene = next_root
	if old_root:
		old_root.queue_free()
