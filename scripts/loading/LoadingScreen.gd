extends Control

@export var next_scene: String = "res://scenes/mainMenu/MainMenu.tscn"
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label       = %StatusLabel

func _ready() -> void:
	status_label.text  = "Chargement des cartes..."
	progress_bar.value = 0

	if CardLibrary.is_loaded:
		_on_loaded()
		return

	await get_tree().process_frame
	CardLibrary.load_all_cards()
	_on_loaded()

func _on_loaded() -> void:
	status_label.text  = "%d cartes chargées" % CardLibrary.all_cards.size()
	progress_bar.value = 100
	await get_tree().create_timer(0.4).timeout
	get_tree().change_scene_to_file(next_scene)
