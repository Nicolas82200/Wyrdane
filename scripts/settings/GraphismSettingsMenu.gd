extends Control

signal back_requested

@onready var resolution_option: OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/ResolutionRow/ResolutionOption
@onready var fullscreen_check:  CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/FullscreenRow/FullscreenCheck
@onready var vsync_check:       CheckButton  = $PanelContainer/VBox/RowsMargin/RowsVBox/VSyncRow/VSyncCheck
@onready var quality_option:    OptionButton = $PanelContainer/VBox/RowsMargin/RowsVBox/QualityRow/QualityOption
@onready var apply_button:      Button       = $PanelContainer/VBox/BtnsMargin/BtnsRow/ApplyButton
@onready var back_button:       Button       = $PanelContainer/VBox/BtnsMargin/BtnsRow/BackButton

func _ready() -> void:
	resolution_option.add_item("1280 × 720")
	resolution_option.add_item("1920 × 1080")
	resolution_option.add_item("2560 × 1440")

	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED

	quality_option.add_item("Basse")
	quality_option.add_item("Moyenne")
	quality_option.add_item("Haute")
	quality_option.selected = 2

	apply_button.pressed.connect(_apply)
	back_button.pressed.connect(func(): back_requested.emit(); hide())

func _apply() -> void:
	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	var vsync = DisplayServer.VSYNC_ENABLED if vsync_check.button_pressed else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync)
