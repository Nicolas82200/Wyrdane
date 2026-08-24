extends GutTest

# Couvre Card._fit_name_label/_fit_desc_label (scripts/card/Card.gd) :
# NameLabel doit s'agrandir vers le BAS (offset_top fixe) quand un nom de
# carte trop long deborderait sinon de sa case par defaut, sans jamais
# depasser Card.NAME_LABEL_MAX_GROWTH, et DescLabel juste en-dessous doit
# etre decale d'autant pour garder le meme espacement entre les deux.
# Instancie une vraie Card.tscn (pas de mock) car la logique depend de la
# police et de la largeur reelles de NameLabel.

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
	assert_eq(card.name_label.offset_bottom, Card.NAME_LABEL_DEFAULT_BOTTOM)
	assert_eq(card.desc_label.offset_top, Card.DESC_LABEL_DEFAULT_TOP)

func test_long_name_grows_the_box_downward() -> void:
	var card := _make_card("Ce-Qui-Ne-Finit-Jamais-de-Grandir")
	assert_eq(card.name_label.offset_top, Card.NAME_LABEL_DEFAULT_TOP,
		"le haut de la case ne doit jamais bouger, pour ne pas manger l'artwork au-dessus")
	assert_gt(card.name_label.offset_bottom, Card.NAME_LABEL_DEFAULT_BOTTOM,
		"un nom qui deborde de la case par defaut doit la faire grandir vers le bas")

func test_grown_box_never_exceeds_the_max_growth_clamp() -> void:
	var card := _make_card("Un Nom Absolument Interminable Qui Ne Tiendrait Jamais Dans Une Seule Case De Titre Meme Sur Plusieurs Lignes")
	assert_lte(card.name_label.offset_bottom,
		Card.NAME_LABEL_DEFAULT_BOTTOM + Card.NAME_LABEL_MAX_GROWTH)

func test_desc_label_shifts_down_to_preserve_spacing_with_name() -> void:
	var card := _make_card("Ce-Qui-Ne-Finit-Jamais-de-Grandir")
	var name_growth: float = card.name_label.offset_bottom - Card.NAME_LABEL_DEFAULT_BOTTOM
	assert_gt(name_growth, 0.0, "precondition : ce nom doit faire grandir la case")
	assert_eq(card.desc_label.offset_top, Card.DESC_LABEL_DEFAULT_TOP + name_growth,
		"DescLabel doit descendre exactement de la meme croissance que NameLabel")
