extends Control

class_name TurnChoicePanel

signal draw_selected
signal mana_selected

@onready var draw_button = %DrawButton
@onready var mana_button = %ManaButton

func _ready() -> void:
	hide()
	draw_button.pressed.connect(_on_draw_button_pressed)
	mana_button.pressed.connect(_on_mana_button_pressed)

func show_choice() -> void:
	draw_button.disabled = false
	mana_button.disabled = false
	show()

func _on_draw_button_pressed() -> void:
	draw_button.disabled = true
	mana_button.disabled = true
	hide()
	draw_selected.emit()

func _on_mana_button_pressed() -> void:
	hide()
	mana_selected.emit()
