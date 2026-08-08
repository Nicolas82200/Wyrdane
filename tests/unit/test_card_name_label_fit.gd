extends GutTest

# Couvre Card._fit_name_label (scripts/card/Card.gd) : NameLabel doit
# s'agrandir vers le HAUT (offset_bottom fixe) quand un nom de carte trop
# long deborderait sinon de sa case par defaut, sans jamais depasser
# Card.NAME_LABEL_MIN_TOP. Instancie une vraie Card.tscn (pas de mock) car la
# logique depend de la police et de la largeur reelles de NameLabel.

const CARD_SCENE := preload("res://scenes/card/Card.tscn")

func _make_card(card_name: String) -> Card:
	var card: Card = CARD_SCENE.instantiate()
	add_child_autofree(card)
	var data := CardData.new()
	data.card_name = card_name
	data.description = ""
	data.flavour_text = ""
	data.card_type = "Minion"
	data.race = Race.Type.DEMON
	card.data = data
	card.update_display()
	return card

func test_short_name_keeps_default_box() -> void:
	var card := _make_card("Zombie")
	assert_eq(card.name_label.offset_top, Card.NAME_LABEL_DEFAULT_TOP)

func test_long_name_grows_the_box_upward() -> void:
	var card := _make_card("Ce-Qui-Ne-Finit-Jamais-de-Grandir")
	assert_lt(card.name_label.offset_top, Card.NAME_LABEL_DEFAULT_TOP,
		"un nom qui deborde de la case par defaut doit la faire grandir vers le haut")
	assert_eq(card.name_label.offset_bottom, Card.NAME_LABEL_BOTTOM,
		"le bas de la case ne doit jamais bouger, pour ne pas empieter sur DescLabel")

func test_grown_box_never_goes_above_the_min_top_clamp() -> void:
	var card := _make_card("Un Nom Absolument Interminable Qui Ne Tiendrait Jamais Dans Une Seule Case De Titre Meme Sur Plusieurs Lignes")
	assert_gte(card.name_label.offset_top, Card.NAME_LABEL_MIN_TOP)
