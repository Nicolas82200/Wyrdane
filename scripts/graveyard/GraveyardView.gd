extends Control
class_name GraveyardView

const CARD_SCENE = preload("res://scenes/card/Card.tscn")
const CARD_BACK  = preload("res://assets/card_back/card-back.png")

@onready var container   = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var count_label = $PanelContainer/MarginContainer/VBoxContainer/Header/CountLabel
@onready var close_btn   = $PanelContainer/MarginContainer/VBoxContainer/Header/CloseButton
@onready var color_rect  = $ColorRect

func _ready() -> void:
	$PanelContainer/MarginContainer/VBoxContainer/ScrollContainer.custom_minimum_size = Vector2(0, 400)
	# Le son de fermeture est joué dans close(), pas le clic générique
	close_btn.set_meta("no_click_sound", true)
	close_btn.pressed.connect(close)
	color_rect.gui_input.connect(_on_background_clicked)
	hide()

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		close()

func close() -> void:
	AudioManager.play(AudioManager.CLOSE_MENU)
	hide()

func open(graveyard: Graveyard) -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	for child in container.get_children():
		child.queue_free()
	count_label.text = SettingsManager.t("graveyard.count_format") % graveyard.size()
	for entry in graveyard.entries:
		if graveyard.is_face_down(entry):
			_add_card_back()
		else:
			_add_card_front(entry["card_data"])
	show()

func _add_card_front(card_data: CardData) -> void:
	var card: Card = CARD_SCENE.instantiate()
	card.drag_enabled = false  
	card.scale = Vector2(0.5, 0.5)
	container.add_child(card)
	card.set_data(card_data)

func _add_card_back() -> void:
	var img := TextureRect.new()
	img.texture = CARD_BACK
	img.custom_minimum_size = Vector2(120, 168)
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(img)
