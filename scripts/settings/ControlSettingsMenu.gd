extends Control

signal back_requested

@onready var end_turn_button:       Button = $PanelContainer/VBox/BindsMargin/BindsVBox/EndTurnRow/EndTurnButton
@onready var graveyard_button:      Button = $PanelContainer/VBox/BindsMargin/BindsVBox/ToggleGraveyardRow/ToggleGraveyardButton
@onready var enemy_graveyard_button: Button = $PanelContainer/VBox/BindsMargin/BindsVBox/ToggleEnemyGraveyardRow/ToggleEnemyGraveyardButton
@onready var reset_button:     Button = $PanelContainer/VBox/BtnsMargin/BtnsRow/ResetButton
@onready var back_button:      Button = $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton
@onready var title_label:      Label  = $PanelContainer/VBox/TitleMargin/Title
@onready var hint_label:       Label  = $PanelContainer/VBox/HintMargin/HintLabel
@onready var end_turn_label:   Label  = $PanelContainer/VBox/BindsMargin/BindsVBox/EndTurnRow/EndTurnLabel
@onready var graveyard_label:  Label  = $PanelContainer/VBox/BindsMargin/BindsVBox/ToggleGraveyardRow/ToggleGraveyardLabel
@onready var enemy_graveyard_label: Label = $PanelContainer/VBox/BindsMargin/BindsVBox/ToggleEnemyGraveyardRow/ToggleEnemyGraveyardLabel
@onready var conflict_label:   Label  = %ConflictLabel

# Action InputMap <-> bouton associé.
@onready var _action_buttons := {
	"end_turn":               end_turn_button,
	"toggle_graveyard":       graveyard_button,
	"toggle_enemy_graveyard": enemy_graveyard_button,
}

var listening_action: String = ""

func _ready() -> void:
	back_button.pressed.connect(func(): back_requested.emit(); hide())
	reset_button.pressed.connect(_reset_defaults)
	for action in _action_buttons:
		var btn: Button = _action_buttons[action]
		btn.pressed.connect(_start_listening.bind(action))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_refresh_buttons()
	_retranslate()

# Met à jour les libellés fixes du menu dans la langue courante.
func _retranslate() -> void:
	title_label.text          = SettingsManager.t("controls.title")
	hint_label.text           = SettingsManager.t("controls.hint")
	end_turn_label.text       = SettingsManager.t("controls.end_turn")
	graveyard_label.text      = SettingsManager.t("controls.toggle_graveyard")
	enemy_graveyard_label.text = SettingsManager.t("controls.toggle_enemy_graveyard")
	reset_button.text         = SettingsManager.t("controls.reset")
	back_button.text          = SettingsManager.t("controls.back")

func _refresh_buttons() -> void:
	for action in _action_buttons:
		var btn: Button = _action_buttons[action]
		btn.text = OS.get_keycode_string(SettingsManager.get_keybind(action))

func _start_listening(action: String) -> void:
	if listening_action != "":
		_action_buttons[listening_action].text = OS.get_keycode_string(SettingsManager.get_keybind(listening_action))
	listening_action = action
	conflict_label.visible = false
	_action_buttons[action].text = SettingsManager.t("controls.listening")

func _input(event: InputEvent) -> void:
	if listening_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode: int = event.keycode
		var action := listening_action
		accept_event()

		if keycode == KEY_ESCAPE:
			_action_buttons[action].text = OS.get_keycode_string(SettingsManager.get_keybind(action))
			listening_action = ""
			return

		var conflicting_action := SettingsManager.set_keybind(action, keycode)
		if conflicting_action != "":
			conflict_label.text = SettingsManager.t("controls.conflict") % SettingsManager.t("controls." + conflicting_action)
			conflict_label.visible = true
			_action_buttons[action].text = OS.get_keycode_string(SettingsManager.get_keybind(action))
		else:
			conflict_label.visible = false
			_action_buttons[action].text = OS.get_keycode_string(keycode)
		listening_action = ""

func _reset_defaults() -> void:
	SettingsManager.reset_keybinds()
	conflict_label.visible = false
	_refresh_buttons()
