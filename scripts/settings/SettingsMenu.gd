extends Control

# Émis quand le joueur confirme le bouton Concéder (visible uniquement en jeu).
signal concede_requested

# Affiche le bouton Concéder rouge. Activé depuis la bataille pour permettre de
# concéder la partie ; laissé à false dans le menu principal. Le bouton Fermer,
# lui, est masqué en partie : on ferme le menu via la croix en haut à droite.
@export var show_quit: bool = false

# Activé quand ce menu est intégré dans le panneau Actualités du menu principal
# (au lieu d'être une popup plein écran par-dessus la bataille) : le panneau
# doit alors se fondre dans le panneau parent plutôt que dessiner son propre
# fond/bordure par-dessus (effet "panneau dans un panneau").
@export var embedded_in_panel: bool = false

@onready var panel                 = $Panel
@onready var audio_menu             = %AudioSettingsMenu
@onready var graphism_menu          = %GraphismSettingsMenu
@onready var control_menu           = %ControlSettingsMenu
@onready var audio_tab_button       = %AudioTabButton
@onready var graphism_tab_button    = %GraphismTabButton
@onready var control_tab_button     = %ControlTabButton
@onready var close_button          = $Panel/VBox/CloseMargin/CloseVBox/CloseButton
@onready var concede_button        = $Panel/VBox/CloseMargin/CloseVBox/ConcedeButton
@onready var close_x_button        = $Panel/VBox/TitleMargin/TitleRow/CloseXButton
@onready var title_label           = $Panel/VBox/TitleMargin/TitleRow/Title
@onready var confirm_panel         = $ConfirmPanel
@onready var confirm_message       = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmMessage
@onready var confirm_cancel_button = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonsRow/ConfirmCancelButton
@onready var confirm_yes_button    = $ConfirmPanel/ConfirmMargin/ConfirmVBox/ConfirmButtonsRow/ConfirmYesButton

# Onglets de la navbar <-> contenu associé. Un seul visible à la fois, la
# navbar reste toujours accessible (pas besoin de "retour" pour changer d'onglet).
@onready var _tabs := {}

func _ready() -> void:
	_tabs = {
		audio_tab_button:    audio_menu,
		graphism_tab_button: graphism_menu,
		control_tab_button:  control_menu,
	}

	_style_all_buttons()
	_style_danger_button(concede_button)
	_style_danger_button(confirm_yes_button)
	_style_close_x_button()
	if embedded_in_panel:
		panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var tab_group := ButtonGroup.new()
	for tab_button in _tabs:
		tab_button.button_group = tab_group
		tab_button.pressed.connect(_select_tab.bind(tab_button))

	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	# Le son de fermeture est joué dans close(), pas le clic générique
	close_button.set_meta("no_click_sound", true)
	close_button.pressed.connect(close)
	close_x_button.set_meta("no_click_sound", true)
	close_x_button.pressed.connect(close)

	# En partie : pas de bouton Fermer (la croix suffit), et Concéder remplace Quitter.
	close_button.visible = not show_quit
	concede_button.visible = show_quit
	concede_button.pressed.connect(_on_concede_pressed)
	confirm_cancel_button.pressed.connect(_on_confirm_cancel)
	confirm_yes_button.pressed.connect(_on_confirm_yes)

	_select_tab(audio_tab_button)

func open() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	confirm_panel.hide()
	panel.show()
	show()
	panel.pivot_offset = panel.size / 2.0
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.15)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	AudioManager.play(AudioManager.CLOSE_MENU)
	hide()

func _on_concede_pressed() -> void:
	panel.hide()
	confirm_panel.show()

func _on_confirm_cancel() -> void:
	confirm_panel.hide()
	panel.show()

func _on_confirm_yes() -> void:
	confirm_panel.hide()
	concede_requested.emit()

# Bascule le contenu affiché sans jamais quitter/masquer la navbar : le joueur
# passe d'un type de paramètre à l'autre en un clic (voir CLAUDE.md, principe
# UX "ne pas masquer les informations utiles à la décision en cours").
func _select_tab(selected_button: Button) -> void:
	selected_button.button_pressed = true
	for tab_button in _tabs:
		_tabs[tab_button].visible = tab_button == selected_button

# Met à jour les libellés du menu racine dans la langue courante.
func _retranslate() -> void:
	title_label.text           = SettingsManager.t("settings.title")
	audio_tab_button.text      = SettingsManager.t("settings.audio")
	graphism_tab_button.text   = SettingsManager.t("settings.graphics")
	control_tab_button.text    = SettingsManager.t("settings.controls")
	close_button.text          = SettingsManager.t("settings.close")
	concede_button.text        = SettingsManager.t("settings.concede")
	confirm_message.text       = SettingsManager.t("settings.concede_confirm_message")
	confirm_cancel_button.text = SettingsManager.t("settings.concede_confirm_cancel")
	confirm_yes_button.text    = SettingsManager.t("settings.concede_confirm_yes")

func _style_all_buttons() -> void:
	for btn in [audio_tab_button, graphism_tab_button, control_tab_button, close_button, confirm_cancel_button]:
		_style_button(btn)

# Boutons dangereux (Concéder, confirmation) : même forme que les autres mais habillage rouge sang.
func _style_danger_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("3a0d0daa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b1a1a")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("5a1414cc")
	hover.border_color = Color("c92727")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("2a0808ee")
	pressed_style.border_color = Color("f04040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("f0b0b0"))
	btn.add_theme_color_override("font_hover_color", Color("fff0f0"))
	btn.add_theme_font_size_override("font_size", 20)

# Petite croix discrète en haut à droite de la popup.
func _style_close_x_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color(0, 0, 0, 0)
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	close_x_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8b1a1a55")
	close_x_button.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color("8b1a1a88")
	close_x_button.add_theme_stylebox_override("pressed", pressed_style)
	close_x_button.add_theme_color_override("font_color",       Color("e8d5a3"))
	close_x_button.add_theme_color_override("font_hover_color", Color("fff0f0"))
	close_x_button.add_theme_font_size_override("font_size", 18)

# Style navbar/action commun. Les onglets utilisent toggle_mode : le style
# "pressed" reste donc affiché en continu tant que l'onglet est actif, ce qui
# sert directement d'indicateur de sélection.
func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color                   = Color("1a1a2eaa")
	normal.border_width_left          = 2
	normal.border_width_right         = 2
	normal.border_width_top           = 2
	normal.border_width_bottom        = 2
	normal.border_color               = Color("8b6914")
	normal.corner_radius_top_left     = 6
	normal.corner_radius_top_right    = 6
	normal.corner_radius_bottom_left  = 6
	normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color     = Color("2a2a4ecc")
	hover.border_color = Color("c9a227")
	btn.add_theme_stylebox_override("hover", hover)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color     = Color("0d0d1eee")
	pressed_style.border_color = Color("f0c040")
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color",       Color("e8d5a3"))
	btn.add_theme_color_override("font_hover_color", Color("fff5d6"))
	btn.add_theme_font_size_override("font_size", 20)
