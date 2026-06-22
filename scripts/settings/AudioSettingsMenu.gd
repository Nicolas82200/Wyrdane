extends Control
class_name AudioSettingsMenu

const SAVE_PATH := "user://audio_settings.cfg"

@onready var master_slider: HSlider = $VBoxContainer/MasterRow/MasterSlider
@onready var music_slider:  HSlider = $VBoxContainer/MusicRow/MusicSlider
@onready var sfx_slider:    HSlider = $VBoxContainer/SFXRow/SFXSlider
@onready var master_label:  Label   = $VBoxContainer/MasterRow/MasterValueLabel
@onready var music_label:   Label   = $VBoxContainer/MusicRow/MusicValueLabel
@onready var sfx_label:     Label   = $VBoxContainer/SFXRow/SFXValueLabel
@onready var close_button:  Button  = $VBoxContainer/CloseButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # actif même si le jeu est pausé
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

	# Forcer la mise à jour des labels
	master_label.text = "%d%%" % int(master_slider.value * 100)
	music_label.text  = "%d%%" % int(music_slider.value * 100)
	sfx_label.text    = "%d%%" % int(sfx_slider.value * 100)
	# Les labels se mettent à jour via value_changed déclenché par l'assignation
