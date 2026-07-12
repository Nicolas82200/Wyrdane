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

const CONFIG_PATH := "user://display_settings.cfg"
const DEFAULT_LANGUAGE := "fr"
const DEFAULT_AI_DIFFICULTY := "normal"

# Locales disponibles (doivent correspondre aux colonnes de game.csv).
const LOCALES := ["fr", "en"]

# Niveaux de difficulté disponibles pour l'IA adverse (AISystem).
const AI_DIFFICULTIES := ["easy", "normal", "hard"]

# Affiche les surbrillances de zones jouables (pose de serviteurs) et de
# ciblage des sorts pendant le drag d'une carte.
var show_play_highlights: bool = true
var language: String = DEFAULT_LANGUAGE
var ai_difficulty: String = DEFAULT_AI_DIFFICULTY

func _ready() -> void:
	_load()
	_apply_language()

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
