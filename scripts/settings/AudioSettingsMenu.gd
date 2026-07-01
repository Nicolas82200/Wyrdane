extends Control
class_name AudioSettingsMenu

signal back_requested  # ← ajouté pour SettingsMenu

const SAVE_PATH := "user://audio_settings.cfg"

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider:  HSlider = %MusicSlider
@onready var sfx_slider:    HSlider = %SFXSlider
@onready var master_label:  Label   = %MasterValueLabel
@onready var music_label:   Label   = %MusicValueLabel
@onready var sfx_label:     Label   = %SFXValueLabel
@onready var close_button:  Button  = %CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	close_button.pressed.connect(_on_close)
	hide()

func _on_master_changed(value: float) -> void:
	master_label.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))
	_save_settings()

func _on_music_changed(value: float) -> void:
	music_label.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value))
	_save_settings()

func _on_sfx_changed(value: float) -> void:
	sfx_label.text = "%d%%" % int(value * 100)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))
	_save_settings()

func _on_close() -> void:
	back_requested.emit()  # ← remplace hide() direct
	hide()

func open() -> void:
	_load_settings()
	show()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_slider.value)
	cfg.set_value("audio", "music",  music_slider.value)
	cfg.set_value("audio", "sfx",    sfx_slider.value)
	cfg.save(SAVE_PATH)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		master_slider.value = cfg.get_value("audio", "master", 0.5)
		music_slider.value  = cfg.get_value("audio", "music",  0.5)
		sfx_slider.value    = cfg.get_value("audio", "sfx",    0.5)
	else:
		master_slider.value = 0.5
		music_slider.value  = 0.5
		sfx_slider.value    = 0.5
	master_label.text = "%d%%" % int(master_slider.value * 100)
	music_label.text  = "%d%%" % int(music_slider.value  * 100)
	sfx_label.text    = "%d%%" % int(sfx_slider.value    * 100)
