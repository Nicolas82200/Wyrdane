extends Control

# Émis à chaque changement de sélection sur un réglage nécessitant "Appliquer"
# (résolution/plein écran/V-Sync/qualité) : true si la sélection diffère de ce
# qui est actuellement appliqué (SettingsManager), false une fois synchronisée.
# Le bouton Appliquer, désormais dans le pied de SettingsMenu (voir SettingsMenu.gd),
# s'appuie sur ce signal pour s'éclairer/s'assombrir.
signal dirty_changed(is_dirty: bool)

@onready var resolution_option: OptionButton = $VBox/RowsMargin/RowsScroll/RowsVBox/ResolutionRow/ResolutionOption
@onready var fullscreen_check:  CheckButton  = $VBox/RowsMargin/RowsScroll/RowsVBox/FullscreenRow/FullscreenCheck
@onready var vsync_check:       CheckButton  = $VBox/RowsMargin/RowsScroll/RowsVBox/VSyncRow/VSyncCheck
@onready var quality_option:    OptionButton = $VBox/RowsMargin/RowsScroll/RowsVBox/QualityRow/QualityOption
@onready var highlight_check:   CheckButton  = $VBox/RowsMargin/RowsScroll/RowsVBox/HighlightRow/HighlightCheck
@onready var language_option:   OptionButton = $VBox/RowsMargin/RowsScroll/RowsVBox/LanguageRow/LanguageOption
@onready var difficulty_option: OptionButton = $VBox/RowsMargin/RowsScroll/RowsVBox/DifficultyRow/DifficultyOption
@onready var text_scale_slider: HSlider      = $VBox/RowsMargin/RowsScroll/RowsVBox/TextScaleRow/TextScaleSlider
@onready var text_scale_value_label: Label   = $VBox/RowsMargin/RowsScroll/RowsVBox/TextScaleRow/TextScaleValueLabel
@onready var colorblind_option: OptionButton = $VBox/RowsMargin/RowsScroll/RowsVBox/ColorblindRow/ColorblindOption
@onready var high_contrast_check: CheckButton = $VBox/RowsMargin/RowsScroll/RowsVBox/HighContrastRow/HighContrastCheck
@onready var reduced_motion_check: CheckButton = $VBox/RowsMargin/RowsScroll/RowsVBox/ReducedMotionRow/ReducedMotionCheck

# Libellés localisés (clé de traduction → nœud à mettre à jour).
@onready var _localized_labels := {
	"graphics.resolution":  $VBox/RowsMargin/RowsScroll/RowsVBox/ResolutionRow/ResolutionLabel,
	"graphics.fullscreen":  $VBox/RowsMargin/RowsScroll/RowsVBox/FullscreenRow/FullscreenLabel,
	"graphics.vsync":       $VBox/RowsMargin/RowsScroll/RowsVBox/VSyncRow/VSyncLabel,
	"graphics.quality":     $VBox/RowsMargin/RowsScroll/RowsVBox/QualityRow/QualityLabel,
	"graphics.highlights":  $VBox/RowsMargin/RowsScroll/RowsVBox/HighlightRow/HighlightLabel,
	"graphics.language":    $VBox/RowsMargin/RowsScroll/RowsVBox/LanguageRow/LanguageLabel,
	"graphics.difficulty":  $VBox/RowsMargin/RowsScroll/RowsVBox/DifficultyRow/DifficultyLabel,
	"graphics.text_scale":  $VBox/RowsMargin/RowsScroll/RowsVBox/TextScaleRow/TextScaleLabel,
	"graphics.colorblind":  $VBox/RowsMargin/RowsScroll/RowsVBox/ColorblindRow/ColorblindLabel,
	"graphics.high_contrast":  $VBox/RowsMargin/RowsScroll/RowsVBox/HighContrastRow/HighContrastLabel,
	"graphics.reduced_motion": $VBox/RowsMargin/RowsScroll/RowsVBox/ReducedMotionRow/ReducedMotionLabel,
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

# Clé de traduction associée à chaque mode d'assistance daltonisme.
const COLORBLIND_LABEL_KEYS := {
	"none":         "colorblind.none",
	"protanopia":   "colorblind.protanopia",
	"deuteranopia": "colorblind.deuteranopia",
	"tritanopia":   "colorblind.tritanopia",
}

func _ready() -> void:
	_populate_resolutions()
	_populate_quality()
	_populate_languages()
	_populate_difficulties()
	_populate_colorblind_modes()

	fullscreen_check.button_pressed = SettingsManager.fullscreen
	vsync_check.button_pressed = SettingsManager.vsync
	resolution_option.disabled = SettingsManager.fullscreen
	fullscreen_check.toggled.connect(func(on: bool): resolution_option.disabled = on)

	# Réglages nécessitant "Appliquer" : chaque changement de sélection
	# recalcule l'état "modifications en attente" (voir dirty_changed ci-dessus).
	resolution_option.item_selected.connect(func(_i): _update_dirty_state())
	fullscreen_check.toggled.connect(func(_on): _update_dirty_state())
	vsync_check.toggled.connect(func(_on): _update_dirty_state())
	quality_option.item_selected.connect(func(_i): _update_dirty_state())

	# Surbrillances : appliqué immédiatement (pas besoin de « Appliquer »).
	highlight_check.button_pressed = SettingsManager.show_play_highlights
	highlight_check.toggled.connect(func(on: bool): SettingsManager.set_highlights(on))

	# Langue : appliquée immédiatement pour un retour visuel direct.
	language_option.item_selected.connect(_on_language_selected)

	# Difficulté IA : appliquée immédiatement, prise en compte à la prochaine bataille.
	difficulty_option.item_selected.connect(_on_difficulty_selected)

	# Accessibilité : taille de l'interface et assistance daltonisme, appliquées
	# immédiatement pour un retour visuel direct (pas besoin de « Appliquer »).
	text_scale_slider.value = SettingsManager.text_scale
	_update_text_scale_label(SettingsManager.text_scale)
	text_scale_slider.value_changed.connect(func(value: float):
		SettingsManager.set_text_scale(value)
		_update_text_scale_label(value)
	)
	colorblind_option.item_selected.connect(_on_colorblind_selected)

	high_contrast_check.button_pressed = SettingsManager.high_contrast
	high_contrast_check.toggled.connect(func(on: bool): SettingsManager.set_high_contrast(on))
	reduced_motion_check.button_pressed = SettingsManager.reduced_motion
	reduced_motion_check.toggled.connect(func(on: bool): SettingsManager.set_reduced_motion(on))

	SettingsManager.language_changed.connect(_on_language_changed)
	_retranslate()
	_update_dirty_state()

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

func _populate_colorblind_modes() -> void:
	colorblind_option.clear()
	var modes: Array = SettingsManager.COLORBLIND_MODES
	for i in modes.size():
		var mode: String = modes[i]
		colorblind_option.add_item(SettingsManager.t(COLORBLIND_LABEL_KEYS.get(mode, mode)))
		colorblind_option.set_item_metadata(i, mode)
		if mode == SettingsManager.colorblind_mode:
			colorblind_option.selected = i

func _on_colorblind_selected(index: int) -> void:
	var mode: String = colorblind_option.get_item_metadata(index)
	SettingsManager.set_colorblind_mode(mode)

func _update_text_scale_label(value: float) -> void:
	text_scale_value_label.text = "%d%%" % round(value * 100.0)

func _on_language_changed(_locale: String) -> void:
	# La liste de qualité et celle de difficulté contiennent des textes
	# traduits : on les régénère en conservant la sélection courante.
	var prev_quality := quality_option.selected
	_populate_quality()
	quality_option.selected = prev_quality
	var prev_difficulty := difficulty_option.selected
	_populate_difficulties()
	difficulty_option.selected = prev_difficulty
	var prev_colorblind := colorblind_option.selected
	_populate_colorblind_modes()
	colorblind_option.selected = prev_colorblind
	_retranslate()

# Met à jour tous les libellés de ce menu dans la langue courante.
func _retranslate() -> void:
	for key in _localized_labels:
		_localized_labels[key].text = SettingsManager.t(key)

func apply_changes() -> void:
	var resolutions: Array = SettingsManager.RESOLUTIONS
	var selected_size: Vector2i = resolutions[resolution_option.selected]
	SettingsManager.set_resolution(selected_size)
	SettingsManager.set_fullscreen(fullscreen_check.button_pressed)
	SettingsManager.set_vsync(vsync_check.button_pressed)
	var level: String = quality_option.get_item_metadata(quality_option.selected)
	SettingsManager.set_quality(level)
	_update_dirty_state()

# Résolution/plein écran/V-Sync/qualité ne s'appliquent qu'au clic sur
# "Appliquer" (contrairement au reste de ce menu, en direct) : indique si la
# sélection courante diffère de ce qui est réellement appliqué.
func has_pending_changes() -> bool:
	var resolutions: Array = SettingsManager.RESOLUTIONS
	if resolution_option.selected < 0 or resolution_option.selected >= resolutions.size():
		return false
	var selected_size: Vector2i = resolutions[resolution_option.selected]
	if selected_size != SettingsManager.resolution:
		return true
	if fullscreen_check.button_pressed != SettingsManager.fullscreen:
		return true
	if vsync_check.button_pressed != SettingsManager.vsync:
		return true
	var level: String = quality_option.get_item_metadata(quality_option.selected)
	if level != SettingsManager.quality:
		return true
	return false

func _update_dirty_state() -> void:
	dirty_changed.emit(has_pending_changes())
