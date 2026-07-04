extends Node
# Autoload global : centralise les réglages d'affichage (persistés dans un
# ConfigFile) et fournit une couche de traduction FR/EN minimale.
#
# NOTE (i18n) : pour l'instant seule l'UI des paramètres est traduite, à titre
# de preuve de concept. Le dictionnaire STRINGS est destiné à être étendu
# progressivement (menus, HUD de bataille, puis noms/effets des cartes).

signal highlights_changed(enabled: bool)
signal language_changed(locale: String)

const CONFIG_PATH := "user://display_settings.cfg"
const DEFAULT_LANGUAGE := "fr"

# Affiche les surbrillances de zones jouables (pose de serviteurs) et de
# ciblage des sorts pendant le drag d'une carte.
var show_play_highlights: bool = true
var language: String = DEFAULT_LANGUAGE

# Table de traduction clé → texte, par locale. Toute clé absente retombe sur
# le français, puis sur la clé brute (utile pour repérer les oublis en jeu).
const STRINGS := {
	"fr": {
		"settings.title":            "Paramètres",
		"settings.audio":            "🔊  Audio",
		"settings.graphics":         "🖥  Graphismes",
		"settings.controls":         "🎮  Contrôles",
		"settings.close":            "Fermer",
		"settings.quit":             "🚪  Quitter la partie",
		"graphics.title":            "Graphismes",
		"graphics.resolution":       "Résolution",
		"graphics.fullscreen":       "Plein écran",
		"graphics.vsync":            "V-Sync",
		"graphics.quality":          "Qualité effets",
		"graphics.highlights":       "Surbrillance zones",
		"graphics.language":         "Langue",
		"graphics.apply":            "Appliquer",
		"graphics.back":             "← Retour",
		"quality.low":               "Basse",
		"quality.medium":            "Moyenne",
		"quality.high":              "Haute",
	},
	"en": {
		"settings.title":            "Settings",
		"settings.audio":            "🔊  Audio",
		"settings.graphics":         "🖥  Graphics",
		"settings.controls":         "🎮  Controls",
		"settings.close":            "Close",
		"settings.quit":             "🚪  Quit match",
		"graphics.title":            "Graphics",
		"graphics.resolution":       "Resolution",
		"graphics.fullscreen":       "Fullscreen",
		"graphics.vsync":            "V-Sync",
		"graphics.quality":          "Effects quality",
		"graphics.highlights":       "Zone highlights",
		"graphics.language":         "Language",
		"graphics.apply":            "Apply",
		"graphics.back":             "← Back",
		"quality.low":               "Low",
		"quality.medium":            "Medium",
		"quality.high":              "High",
	},
}

func _ready() -> void:
	_load()
	_apply_language()

# Retourne le texte traduit d'une clé dans la langue courante.
func t(key: String) -> String:
	var table: Dictionary = STRINGS.get(language, STRINGS[DEFAULT_LANGUAGE])
	if table.has(key):
		return table[key]
	# Repli sur le français puis sur la clé brute.
	return STRINGS[DEFAULT_LANGUAGE].get(key, key)

func set_highlights(enabled: bool) -> void:
	if show_play_highlights == enabled:
		return
	show_play_highlights = enabled
	_save()
	highlights_changed.emit(enabled)

func set_language(locale: String) -> void:
	if not STRINGS.has(locale) or locale == language:
		return
	language = locale
	_apply_language()
	_save()
	language_changed.emit(locale)

func available_languages() -> Array:
	return STRINGS.keys()

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
	cfg.save(CONFIG_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	show_play_highlights = cfg.get_value("display", "show_play_highlights", true) as bool
	language = cfg.get_value("display", "language", DEFAULT_LANGUAGE) as String
	if not STRINGS.has(language):
		language = DEFAULT_LANGUAGE
