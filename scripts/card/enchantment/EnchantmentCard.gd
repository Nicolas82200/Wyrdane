extends PanelContainer

var card_data: CardData
var is_player: bool

func _ready() -> void:
	custom_minimum_size = Vector2(100, 150)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func setup(new_data: CardData, new_is_player: bool) -> void:
	card_data = new_data
	is_player = new_is_player
	if has_node("MarginContainer/VBox/NameLabel"):
		$MarginContainer/VBox/NameLabel.text = card_data.card_name
	if has_node("MarginContainer/VBox/DescLabel"):
		$MarginContainer/VBox/DescLabel.text = card_data.description
	if has_node("CostBadge"):
		$CostBadge.text = str(card_data.cost)
	if card_data.texture and has_node("MarginContainer/VBox/ArtRect"):
		$MarginContainer/VBox/ArtRect.texture = card_data.texture
