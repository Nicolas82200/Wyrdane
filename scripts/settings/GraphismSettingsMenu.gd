extends Control

signal back_requested

@onready var resolution_option: OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/ResolutionRow/ResolutionOption
@onready var fullscreen_check:  CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/FullscreenRow/FullscreenCheck
@onready var vsync_check:       CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/VSyncRow/VSyncCheck
@onready var quality_option:    OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/QualityRow/QualityOption
@onready var highlight_check:   CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/HighlightRow/HighlightCheck
@onready var language_option:   OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/LanguageRow/LanguageOption
@onready var difficulty_option: OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/DifficultyRow/DifficultyOption
@onready var apply_button:      Button       = $PanelContainer/VBox/BtnsMargin/BtnsRow/ApplyButton
@onready var back_button:       Button       = $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton

# Libellés localisés (clé de traduction → nœud à mettre à jour).
@onready var _localized_labels := {
	"graphics.title":       $PanelContainer/VBox/Margin/Title,
	"graphics.resolution":  $PanelContainer/VBox/RowsMargin/RowsVBox/ResolutionRow/ResolutionLabel,
	"graphics.fullscreen":  $PanelContainer/VBox/RowsMargin/RowsVBox/FullscreenRow/FullscreenLabel,
	"graphics.vsync":       $PanelContainer/VBox/RowsMargin/RowsVBox/VSyncRow/VSyncLabel,
	"graphics.quality":     $PanelContainer/VBox/RowsMargin/RowsVBox/QualityRow/QualityLabel,
	"graphics.highlights":  $PanelContainer/VBox/RowsMargin/RowsVBox/HighlightRow/HighlightLabel,
	"graphics.language":    $PanelContainer/VBox/RowsMargin/RowsVBox/LanguageRow/LanguageLabel,
	"graphics.difficulty":  $PanelContainer/VBox/RowsMargin/RowsVBox/DifficultyRow/DifficultyLabel,
	"graphics.apply":       $PanelContainer/VBox/BtnsMargin/BtnsRow/ApplyButton,
	"graphics.back":        $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton,
}

# Nom d'affichage de chaque locale dans le sélecteur de langue.
const LANGUAGE_LABELS := {
	"fr": "Français",
	"en": "English",
}

# Clé de traduction associée à chaque niveau de difficulté IA.
const DIFFICULTY_LABEL_KEYS := {
	"easy":   "difficulty.easy",
	"normal": "difficulty.normal",
	"hard":   "difficulty.hard",
}

# Clé de traduction associée à chaque niveau de qualité effets.
const QUALITY_LABEL_KEYS := {
	"low":    "quality.low",
	"medium": "quality.medium",
	"high":   "quality.high",
}

func _ready() -> void:
	_populate_resolutions()
	_populate_quality()
	_populate_languages()
	_populate_difficulties()

	fullscreen_check.button_pressed = SettingsManager.fullscreen
	vsync_check.button_pressed = SettingsManager.vsync
	resolution_option.disabled = SettingsManager.fullscreen
	fullscreen_check.toggled.connect(func(on: bool): resolution_option.disabled = on)

	# Surbrillances : appliqué immédiatement (pas besoin de « Appliquer »).
	highlight_check.button_pressed = SettingsManager.show_play_highlights
	highlight_check.toggled.connect(func(on: bool): SettingsManager.set_highlights(on))

	# Langue : appliquée immédiatement pour un retour visuel direct.
	language_option.item_selected.connect(_on_language_selected)

	# Difficulté IA : appliquée immédiatement, prise en compte à la prochaine bataille.
	difficulty_option.item_selected.connect(_on_difficulty_selected)

	apply_button.pressed.connect(_apply)
	back_button.pressed.connect(func(): back_requested.emit(); hide())

	SettingsManager.language_changed.connect(_on_language_changed)
	_retranslate()

func _populate_resolutions() -> void:
	resolution_option.clear()
	var resolutions: Array = SettingsManager.RESOLUTIONS
	for i in resolutions.size():
		var size: Vector2i = resolutions[i]
		resolution_option.add_item("%d × %d" % [size.x, size.y])
		if size == SettingsManager.resolution:
			resolution_option.selected = i
	if resolution_option.selected < 0:
		resolution_option.selected = 0

func _populate_quality() -> void:
	quality_option.clear()
	var levels: Array = SettingsManager.QUALITIES
	for i in levels.size():
		var level: String = levels[i]
		quality_option.add_item(SettingsManager.t(QUALITY_LABEL_KEYS.get(level, level)))
		quality_option.set_item_metadata(i, level)
		if level == SettingsManager.quality:
			quality_option.selected = i

func _populate_languages() -> void:
	language_option.clear()
	var langs: Array = SettingsManager.available_languages()
	for i in langs.size():
		var locale: String = langs[i]
		language_option.add_item(LANGUAGE_LABELS.get(locale, locale))
		language_option.set_item_metadata(i, locale)
		if locale == SettingsManager.language:
			language_option.selected = i

func _on_language_selected(index: int) -> void:
	var locale: String = language_option.get_item_metadata(index)
	SettingsManager.set_language(locale)

func _populate_difficulties() -> void:
	difficulty_option.clear()
	var levels: Array = SettingsManager.AI_DIFFICULTIES
	for i in levels.size():
		var level: String = levels[i]
		difficulty_option.add_item(SettingsManager.t(DIFFICULTY_LABEL_KEYS.get(level, level)))
		difficulty_option.set_item_metadata(i, level)
		if level == SettingsManager.ai_difficulty:
			difficulty_option.selected = i

func _on_difficulty_selected(index: int) -> void:
	var level: String = difficulty_option.get_item_metadata(index)
	SettingsManager.set_ai_difficulty(level)

func _on_language_changed(_locale: String) -> void:
	# La liste de qualité et celle de difficulté contiennent des textes
	# traduits : on les régénère en conservant la sélection courante.
	var prev_quality := quality_option.selected
	_populate_quality()
	quality_option.selected = prev_quality
	var prev_difficulty := difficulty_option.selected
	_populate_difficulties()
	difficulty_option.selected = prev_difficulty
	_retranslate()

# Met à jour tous les libellés de ce menu dans la langue courante.
func _retranslate() -> void:
	for key in _localized_labels:
		_localized_labels[key].text = SettingsManager.t(key)

func _apply() -> void:
	var resolutions: Array = SettingsManager.RESOLUTIONS
	var selected_size: Vector2i = resolutions[resolution_option.selected]
	SettingsManager.set_resolution(selected_size)
	SettingsManager.set_fullscreen(fullscreen_check.button_pressed)
	SettingsManager.set_vsync(vsync_check.button_pressed)
	var level: String = quality_option.get_item_metadata(quality_option.selected)
	SettingsManager.set_quality(level)
