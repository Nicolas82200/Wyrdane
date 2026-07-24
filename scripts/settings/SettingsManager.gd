extends Node
# Autoload global : centralise les réglages d'affichage (persistés dans un
# ConfigFile) et pilote la langue de l'interface.
#
# i18n : les textes sont fournis par le système de traduction natif de Godot
# (fichiers translations/game.<locale>.translation compilés depuis
# translations/game.csv). t(key) délègue au TranslationServer ; les nœuds UI
# rafraîchissent leurs libellés via _retranslate() sur le signal
# language_changed.

signal highlights_changed(enabled: bool)
signal language_changed(locale: String)
signal ai_difficulty_changed(level: String)
signal display_settings_changed
signal keybind_changed(action: String, keycode: int)

const CONFIG_PATH := "user://display_settings.cfg"
const DEFAULT_LANGUAGE := "fr"
const DEFAULT_AI_DIFFICULTY := "normal"

# Locales disponibles (doivent correspondre aux colonnes de game.csv).
const LOCALES := ["fr", "en"]

# Niveaux de difficulté disponibles pour l'IA adverse (AISystem).
const AI_DIFFICULTIES := ["easy", "normal", "hard"]

# Résolutions proposées en mode fenêtré (doivent rester cohérentes avec
# GraphismSettingsMenu.gd, qui les affiche dans le même ordre).
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const DEFAULT_RESOLUTION := Vector2i(1920, 1080)

# Niveaux de qualité effets : contrôlent l'anti-aliasing du viewport principal.
const QUALITIES := ["low", "medium", "high"]
const DEFAULT_QUALITY := "high"

# Actions d'InputMap que le joueur peut réattribuer depuis ControlSettingsMenu.
# Les touches par défaut sont celles déclarées dans project.godot ; elles sont
# capturées au premier _ready() pour permettre un « Réinitialiser » fiable
# même si aucune valeur n'a jamais été sauvegardée.
const REBINDABLE_ACTIONS := ["end_turn", "toggle_graveyard", "toggle_enemy_graveyard"]

# Affiche les surbrillances de zones jouables (pose de serviteurs) et de
# ciblage des sorts pendant le drag d'une carte.
var show_play_highlights: bool = true
var language: String = DEFAULT_LANGUAGE
var ai_difficulty: String = DEFAULT_AI_DIFFICULTY
# Tant que false : le nouveau joueur n'a pas encore terminé le tutoriel
# obligatoire (voir TutorialManager). Multijoueur et deckbuilder restent
# verrouillés dans MainMenu jusqu'à ce que ce flag passe à true.
var tutorial_completed: bool = false

var resolution: Vector2i = DEFAULT_RESOLUTION
var fullscreen: bool = false
var vsync: bool = true
var quality: String = DEFAULT_QUALITY

# Touches personnalisées : action -> keycode. Une action absente de ce
# dictionnaire utilise sa touche par défaut (_default_keycodes).
var keybinds: Dictionary = {}
var _default_keycodes: Dictionary = {}

func _ready() -> void:
	_capture_default_keycodes()
	_load()
	_apply_language()
	_apply_display()
	_apply_keybinds()

# Retourne le texte traduit d'une clé dans la langue courante. Une clé absente
# du CSV est renvoyée telle quelle (utile pour repérer les oublis en jeu).
func t(key: String) -> String:
	return TranslationServer.translate(key)

func set_highlights(enabled: bool) -> void:
	if show_play_highlights == enabled:
		return
	show_play_highlights = enabled
	_save()
	highlights_changed.emit(enabled)

func set_language(locale: String) -> void:
	if not LOCALES.has(locale) or locale == language:
		return
	language = locale
	_apply_language()
	_save()
	language_changed.emit(locale)

func available_languages() -> Array:
	return LOCALES

func set_ai_difficulty(level: String) -> void:
	if not AI_DIFFICULTIES.has(level) or level == ai_difficulty:
		return
	ai_difficulty = level
	_save()
	ai_difficulty_changed.emit(level)

func set_tutorial_completed() -> void:
	if tutorial_completed:
		return
	tutorial_completed = true
	_save()

# Debug/test uniquement (bouton temporaire de MainMenu) : repasse le flag à
# false pour pouvoir rejouer le tutoriel obligatoire sans éditer le fichier
# de config à la main.
func reset_tutorial_completed() -> void:
	if not tutorial_completed:
		return
	tutorial_completed = false
	_save()

# --- Affichage (résolution / plein écran / vsync / qualité) ---------------

func set_resolution(size: Vector2i) -> void:
	if resolution == size:
		return
	resolution = size
	_save()
	_apply_display()
	display_settings_changed.emit()

func set_fullscreen(enabled: bool) -> void:
	if fullscreen == enabled:
		return
	fullscreen = enabled
	_save()
	_apply_display()
	display_settings_changed.emit()

func set_vsync(enabled: bool) -> void:
	if vsync == enabled:
		return
	vsync = enabled
	_save()
	_apply_display()
	display_settings_changed.emit()

func set_quality(level: String) -> void:
	if not QUALITIES.has(level) or level == quality:
		return
	quality = level
	_save()
	_apply_display()
	display_settings_changed.emit()

func _apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(resolution)
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen_size - resolution) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_apply_quality()

func _apply_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var msaa: int = Viewport.MSAA_DISABLED
	if quality == "medium":
		msaa = Viewport.MSAA_2X
	elif quality == "high":
		msaa = Viewport.MSAA_4X
	vp.msaa_3d = msaa
	vp.msaa_2d = msaa

# --- Contrôles (rebind de touches) -----------------------------------------

func _capture_default_keycodes() -> void:
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				_default_keycodes[action] = (event as InputEventKey).keycode
				break

func default_keybind(action: String) -> int:
	return _default_keycodes.get(action, KEY_NONE)

func get_keybind(action: String) -> int:
	return keybinds.get(action, default_keybind(action))

# Réattribue `action` à `keycode`. Retourne le nom de l'action déjà liée à
# cette touche en cas de conflit (chaîne vide si aucun conflit, réattribution
# effectuée dans ce cas).
func set_keybind(action: String, keycode: int) -> String:
	for other in REBINDABLE_ACTIONS:
		if other != action and get_keybind(other) == keycode:
			return other
	keybinds[action] = keycode
	_apply_keybind(action, keycode)
	_save()
	keybind_changed.emit(action, keycode)
	return ""

func reset_keybinds() -> void:
	keybinds.clear()
	for action in REBINDABLE_ACTIONS:
		_apply_keybind(action, default_keybind(action))
	_save()
	for action in REBINDABLE_ACTIONS:
		keybind_changed.emit(action, default_keybind(action))

func _apply_keybind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)

func _apply_keybinds() -> void:
	for action in keybinds:
		_apply_keybind(action, keybinds[action])

func _apply_language() -> void:
	# Aligne aussi le TranslationServer de Godot pour préparer une future
	# migration vers des fichiers de traduction natifs.
	TranslationServer.set_locale(language)

func _save() -> void:
	var cfg := ConfigFile.new()
	# Recharge d'abord pour ne pas écraser d'éventuelles autres sections.
	cfg.load(CONFIG_PATH)
	cfg.set_value("display", "show_play_highlights", show_play_highlights)
	cfg.set_value("display", "language", language)
	cfg.set_value("display", "ai_difficulty", ai_difficulty)
	cfg.set_value("display", "tutorial_completed", tutorial_completed)
	cfg.set_value("display", "resolution_x", resolution.x)
	cfg.set_value("display", "resolution_y", resolution.y)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("display", "quality", quality)
	cfg.set_value("input", "keybinds", keybinds)
	cfg.save(CONFIG_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	show_play_highlights = cfg.get_value("display", "show_play_highlights", true) as bool
	language = cfg.get_value("display", "language", DEFAULT_LANGUAGE) as String
	if not LOCALES.has(language):
		language = DEFAULT_LANGUAGE
	ai_difficulty = cfg.get_value("display", "ai_difficulty", DEFAULT_AI_DIFFICULTY) as String
	if not AI_DIFFICULTIES.has(ai_difficulty):
		ai_difficulty = DEFAULT_AI_DIFFICULTY
	tutorial_completed = cfg.get_value("display", "tutorial_completed", false) as bool

	var res_x: int = cfg.get_value("display", "resolution_x", DEFAULT_RESOLUTION.x) as int
	var res_y: int = cfg.get_value("display", "resolution_y", DEFAULT_RESOLUTION.y) as int
	resolution = Vector2i(res_x, res_y)
	fullscreen = cfg.get_value("display", "fullscreen", false) as bool
	vsync = cfg.get_value("display", "vsync", true) as bool
	quality = cfg.get_value("display", "quality", DEFAULT_QUALITY) as String
	if not QUALITIES.has(quality):
		quality = DEFAULT_QUALITY

	var saved_keybinds = cfg.get_value("input", "keybinds", {})
	if saved_keybinds is Dictionary:
		for action in saved_keybinds:
			if REBINDABLE_ACTIONS.has(action):
				keybinds[action] = int(saved_keybinds[action])
