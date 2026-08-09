extends GutTest

# Couvre Card._fit_type_label (scripts/card/Card.gd) : le bandeau TypeLabel
# doit s'elargir ou se retrecir selon le texte affiche (ex. un Rituel a
# charges a un texte plus long qu'un Serviteur), toujours centre sur
# Card.TYPE_LABEL_CENTER_X et borne par TYPE_LABEL_MIN_WIDTH/MAX_WIDTH.
# Instancie une vraie Card.tscn (pas de mock) car la logique depend de la
# police reelle de TypeLabel.

const CARD_SCENE := preload("res://scenes/card/Card.tscn")

func _make_card(card_type: String, ritual_duration: int = 0) -> Card:
	var card: Card = CARD_SCENE.instantiate()
	add_child_autofree(card)
	var data := CardData.new()
	data.card_name = "Carte"
	data.description = ""
	data.flavour_text = ""
	data.card_type = card_type
	data.ritual_duration = ritual_duration
	data.race = Race.Type.DEMON
	card.data = data
	card.update_display()
	return card

func _type_label_width(card: Card) -> float:
	return card.type_label.offset_right - card.type_label.offset_left

func test_type_label_stays_centered_regardless_of_width() -> void:
	var card := _make_card("Minion")
	var center: float = (card.type_label.offset_left + card.type_label.offset_right) / 2.0
	assert_almost_eq(center, Card.TYPE_LABEL_CENTER_X, 0.5)

func test_type_label_width_never_exceeds_bounds() -> void:
	var short_card := _make_card("Minion")
	var long_card := _make_card("Ritual", 3)
	assert_gte(_type_label_width(short_card), Card.TYPE_LABEL_MIN_WIDTH)
	assert_lte(_type_label_width(short_card), Card.TYPE_LABEL_MAX_WIDTH)
	assert_gte(_type_label_width(long_card), Card.TYPE_LABEL_MIN_WIDTH)
	assert_lte(_type_label_width(long_card), Card.TYPE_LABEL_MAX_WIDTH)

func test_longer_type_text_produces_a_wider_label() -> void:
	var short_card := _make_card("Minion")
	var long_card := _make_card("Ritual", 3)
	assert_gt(long_card.type_label.text.length(), short_card.type_label.text.length(),
		"precondition : le texte du rituel a charges doit etre plus long")
	assert_gt(_type_label_width(long_card), _type_label_width(short_card),
		"un texte plus long doit produire un bandeau plus large")
