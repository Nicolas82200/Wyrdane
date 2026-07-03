extends Control

signal back_requested

@onready var resolution_option: OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/ResolutionRow/ResolutionOption
@onready var fullscreen_check:  CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/FullscreenRow/FullscreenCheck
@onready var vsync_check:       CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/VSyncRow/VSyncCheck
@onready var quality_option:    OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/QualityRow/QualityOption
@onready var highlight_check:   CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/HighlightRow/HighlightCheck
@onready var language_option:   OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/LanguageRow/LanguageOption
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
	"graphics.apply":       $PanelContainer/VBox/BtnsMargin/BtnsRow/ApplyButton,
	"graphics.back":        $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton,
}

# Nom d'affichage de chaque locale dans le sélecteur de langue.
const LANGUAGE_LABELS := {
	"fr": "Français",
	"en": "English",
}

func _ready() -> void:
	resolution_option.add_item("1280 × 720")
	resolution_option.add_item("1920 × 1080")
	resolution_option.add_item("2560 × 1440")

	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

	_populate_quality()
	_populate_languages()

	# Surbrillances : appliqué immédiatement (pas besoin de « Appliquer »).
	highlight_check.button_pressed = SettingsManager.show_play_highlights
	highlight_check.toggled.connect(func(on: bool): SettingsManager.set_highlights(on))

	# Langue : appliquée immédiatement pour un retour visuel direct.
	language_option.item_selected.connect(_on_language_selected)

	apply_button.pressed.connect(_apply)
	back_button.pressed.connect(func(): back_requested.emit(); hide())

	SettingsManager.language_changed.connect(_on_language_changed)
	_retranslate()

func _populate_quality() -> void:
	quality_option.clear()
	quality_option.add_item(SettingsManager.t("quality.low"))
	quality_option.add_item(SettingsManager.t("quality.medium"))
	quality_option.add_item(SettingsManager.t("quality.high"))
	quality_option.selected = 2

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

func _on_language_changed(_locale: String) -> void:
	# La liste de qualité contient des textes traduits : on la régénère
	# en conservant la sélection courante.
	var prev_quality := quality_option.selected
	_populate_quality()
	quality_option.selected = prev_quality
	_retranslate()

# Met à jour tous les libellés de ce menu dans la langue courante.
func _retranslate() -> void:
	for key in _localized_labels:
		_localized_labels[key].text = SettingsManager.t(key)

func _apply() -> void:
	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync = DisplayServer.VSYNC_ENABLED if vsync_check.button_pressed else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)
