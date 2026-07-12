extends Control

signal back_requested

@onready var move_down_button: Button = $PanelContainer/VBox/BindsMargin/BindsVBox/MoveDownRow/MoveDownButton
@onready var confirm_button:   Button = $PanelContainer/VBox/BindsMargin/BindsVBox/ConfirmRow/ConfirmButton
@onready var cancel_button:    Button = $PanelContainer/VBox/BindsMargin/BindsVBox/CancelRow/CancelButton
@onready var reset_button:     Button = $PanelContainer/VBox/BtnsMargin/BtnsRow/ResetButton
@onready var back_button:      Button = $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton
@onready var title_label:      Label  = $PanelContainer/VBox/TitleMargin/Title
@onready var hint_label:       Label  = $PanelContainer/VBox/HintMargin/HintLabel
@onready var move_down_label:  Label  = $PanelContainer/VBox/BindsMargin/BindsVBox/MoveDownRow/MoveDownLabel
@onready var confirm_label:    Label  = $PanelContainer/VBox/BindsMargin/BindsVBox/ConfirmRow/ConfirmLabel
@onready var cancel_label:     Label  = $PanelContainer/VBox/BindsMargin/BindsVBox/CancelRow/CancelLabel

var listening_button: Button = null

func _ready() -> void:
	back_button.pressed.connect(func(): back_requested.emit(); hide())
	reset_button.pressed.connect(_reset_defaults)
	for btn in [move_down_button, confirm_button, cancel_button]:
		btn.pressed.connect(_start_listening.bind(btn))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

# Met à jour les libellés fixes du menu dans la langue courante.
func _retranslate() -> void:
	title_label.text     = SettingsManager.t("controls.title")
	hint_label.text      = SettingsManager.t("controls.hint")
	move_down_label.text = SettingsManager.t("controls.move_down")
	confirm_label.text   = SettingsManager.t("controls.confirm")
	cancel_label.text    = SettingsManager.t("controls.cancel")
	reset_button.text    = SettingsManager.t("controls.reset")
	back_button.text     = SettingsManager.t("controls.back")

func _start_listening(btn: Button) -> void:
	listening_button = btn
	btn.text = "..."

func _input(event: InputEvent) -> void:
	if listening_button == null:
		return
	if event is InputEventKey and event.pressed:
		listening_button.text = OS.get_keycode_string(event.keycode)
		listening_button = null
		accept_event()

func _reset_defaults() -> void:
	move_down_button.text = "S"
	confirm_button.text   = SettingsManager.t("key.enter")
	cancel_button.text    = SettingsManager.t("key.escape")
