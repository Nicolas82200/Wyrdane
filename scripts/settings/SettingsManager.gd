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
signal match_stats_changed(wins: int, losses: int)
signal reduced_motion_changed(enabled: bool)
signal high_contrast_changed(enabled: bool)

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

# Échelle de l'interface (accessibilité : agrandit texte + éléments d'UI).
const TEXT_SCALE_MIN := 0.85
const TEXT_SCALE_MAX := 1.3
const DEFAULT_TEXT_SCALE := 1.0

# Filtre d'assistance daltonisme, voir resources/shaders/colorblind_filter.gdshader.
const COLORBLIND_MODES := ["none", "protanopia", "deuteranopia", "tritanopia"]
const DEFAULT_COLORBLIND_MODE := "none"

# Contraste élevé (accessibilité), voir resources/shaders/high_contrast_filter.gdshader.
const DEFAULT_HIGH_CONTRAST := false

# Réduction des animations (accessibilité) : désactive les tremblements
# d'écran et raccourcit les tweens de déplacement (voir AnimationSystem._t,
# Hand.gd, CardPopupSystem.gd). N'affecte pas les fondus/flashs courts, dont
# la disparition brutale serait plus perturbante que le mouvement lui-même.
const DEFAULT_REDUCED_MOTION := false
const REDUCED_MOTION_SCALE := 0.35

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

# Historique de parties (victoires/défaites), stocké localement uniquement —
# pas de synchronisation backend, contrairement à la collection/monnaie
# (voir CollectionManager/CurrencyManager). Compte les matchs solo comme
# réseau, tutoriel exclu (voir Battle._show_game_over).
var match_wins: int = 0
var match_losses: int = 0

var resolution: Vector2i = DEFAULT_RESOLUTION
var fullscreen: bool = false
var vsync: bool = true
var quality: String = DEFAULT_QUALITY
var text_scale: float = DEFAULT_TEXT_SCALE
var colorblind_mode: String = DEFAULT_COLORBLIND_MODE
var high_contrast: bool = DEFAULT_HIGH_CONTRAST
var reduced_motion: bool = DEFAULT_REDUCED_MOTION
var _colorblind_overlay: ColorRect
var _high_contrast_overlay: ColorRect

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
	_setup_colorblind_overlay()
	_setup_high_contrast_overlay()

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

func record_match_result(won: bool) -> void:
	if won:
		match_wins += 1
	else:
		match_losses += 1
	_save()
	match_stats_changed.emit(match_wins, match_losses)

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
	_apply_text_scale()

# --- Accessibilité (échelle de l'interface / assistance daltonisme) --------

func set_text_scale(value: float) -> void:
	var clamped: float = clampf(value, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	if is_equal_approx(clamped, text_scale):
		return
	text_scale = clamped
	_save()
	_apply_text_scale()
	display_settings_changed.emit()

func _apply_text_scale() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.root.content_scale_factor = text_scale

func set_colorblind_mode(mode: String) -> void:
	if not COLORBLIND_MODES.has(mode) or mode == colorblind_mode:
		return
	colorblind_mode = mode
	_save()
	_apply_colorblind_mode()
	display_settings_changed.emit()

# Overlay plein écran unique, ajouté à la racine de l'arbre (pas à la scène
# courante) pour survivre à tous les changements de scène (menu -> bataille
# -> etc.), comme un post-effet permanent. Voir
# resources/shaders/colorblind_filter.gdshader.
func _setup_colorblind_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 128
	tree.root.call_deferred("add_child", layer)
	_colorblind_overlay = ColorRect.new()
	_colorblind_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_colorblind_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colorblind_overlay.material = ShaderMaterial.new()
	_colorblind_overlay.material.shader = load("res://resources/shaders/colorblind_filter.gdshader")
	layer.call_deferred("add_child", _colorblind_overlay)
	_apply_colorblind_mode()

func _apply_colorblind_mode() -> void:
	if _colorblind_overlay == null or _colorblind_overlay.material == null:
		return
	var mode_index: int = COLORBLIND_MODES.find(colorblind_mode)
	_colorblind_overlay.material.set_shader_parameter("mode", maxi(mode_index, 0))

func set_high_contrast(enabled: bool) -> void:
	if high_contrast == enabled:
		return
	high_contrast = enabled
	_save()
	_apply_high_contrast()
	high_contrast_changed.emit(enabled)
	display_settings_changed.emit()

# Overlay plein écran unique, même principe que _setup_colorblind_overlay
# (survit aux changements de scène). Les deux overlays peuvent être actifs en
# même temps (assistance daltonisme + contraste élevé ne s'excluent pas).
func _setup_high_contrast_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 129
	tree.root.call_deferred("add_child", layer)
	_high_contrast_overlay = ColorRect.new()
	_high_contrast_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_high_contrast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_high_contrast_overlay.material = ShaderMaterial.new()
	_high_contrast_overlay.material.shader = load("res://resources/shaders/high_contrast_filter.gdshader")
	layer.call_deferred("add_child", _high_contrast_overlay)
	_apply_high_contrast()

func _apply_high_contrast() -> void:
	if _high_contrast_overlay == null or _high_contrast_overlay.material == null:
		return
	_high_contrast_overlay.material.set_shader_parameter("enabled", high_contrast)

func set_reduced_motion(enabled: bool) -> void:
	if reduced_motion == enabled:
		return
	reduced_motion = enabled
	_save()
	reduced_motion_changed.emit(enabled)
	display_settings_changed.emit()

# Facteur multiplicatif à appliquer à la durée des tweens de déplacement
# (voir AnimationSystem._t, Hand.gd, CardPopupSystem.gd).
func motion_scale() -> float:
	return REDUCED_MOTION_SCALE if reduced_motion else 1.0

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
	cfg.set_value("stats", "match_wins", match_wins)
	cfg.set_value("stats", "match_losses", match_losses)
	cfg.set_value("display", "text_scale", text_scale)
	cfg.set_value("display", "colorblind_mode", colorblind_mode)
	cfg.set_value("display", "high_contrast", high_contrast)
	cfg.set_value("display", "reduced_motion", reduced_motion)
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
	match_wins = cfg.get_value("stats", "match_wins", 0) as int
	match_losses = cfg.get_value("stats", "match_losses", 0) as int
	text_scale = cfg.get_value("display", "text_scale", DEFAULT_TEXT_SCALE) as float
	text_scale = clampf(text_scale, TEXT_SCALE_MIN, TEXT_SCALE_MAX)
	colorblind_mode = cfg.get_value("display", "colorblind_mode", DEFAULT_COLORBLIND_MODE) as String
	if not COLORBLIND_MODES.has(colorblind_mode):
		colorblind_mode = DEFAULT_COLORBLIND_MODE
	high_contrast = cfg.get_value("display", "high_contrast", DEFAULT_HIGH_CONTRAST) as bool
	reduced_motion = cfg.get_value("display", "reduced_motion", DEFAULT_REDUCED_MOTION) as bool
	var saved_keybinds = cfg.get_value("input", "keybinds", {})
	if saved_keybinds is Dictionary:
		for action in saved_keybinds:
			if REBINDABLE_ACTIONS.has(action):
				keybinds[action] = int(saved_keybinds[action])
