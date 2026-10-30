extends GutTest

# Couvre le choix du texte de DescLabel dans Card.update_display
# (scripts/card/Card.gd) : le flavour text est cosmetique, il doit disparaitre
# des que la description de regle est assez longue pour remplir la case seule
# (Card.DESC_FLAVOUR_HIDE_THRESHOLD), plutot que de pousser l'ensemble sur le
# cran de police reduit. Verifie aussi que ce cran reduit ne descend jamais
# sous le plancher de lisibilite (Card.DESC_LABEL_SHRUNK_FONT_SIZE).
# Instancie une vraie Card.tscn (pas de mock) : la hauteur de contenu depend
# de la police et de la largeur reelles de DescLabel.

const CARD_SCENE := preload("res://scenes/card/Card.tscn")

const FLAVOUR := "Un murmure monte des ruines, et personne ne sait qui parle."

func _make_card(description: String, flavour: String) -> Card:
	var card: Card = CARD_SCENE.instantiate()
	add_child_autofree(card)
	var data := CardData.new()
	data.card_name = "Carte Test"
	data.description = description
	data.flavour_text = flavour
	data.card_type = "Minion"
	data.race = Race.Type.DEMON
	card.data = data
	card.update_display()
	return card

func test_short_description_keeps_the_flavour() -> void:
	var card := _make_card("Arrivee : piochez 1 carte.", FLAVOUR)
	assert_true(card.desc_label.text.contains(FLAVOUR),
		"sous le seuil, le flavour text doit rester affiche")

func test_long_description_drops_the_flavour() -> void:
	var long_desc := "Arrivee : les serviteurs Demons allies gagnent +1/+1 de facon permanente, puis votre heros recupere 2 points de vie."
	assert_gt(long_desc.length(), Card.DESC_FLAVOUR_HIDE_THRESHOLD,
		"la description de ce cas doit bien depasser le seuil, sinon le test ne prouve rien")
	var card := _make_card(long_desc, FLAVOUR)
	assert_true(card.desc_label.text.contains("Arrivee"),
		"le texte de regle, lui, est indispensable et doit toujours etre affiche")
	assert_false(card.desc_label.text.contains(FLAVOUR),
		"au-dela du seuil, le flavour text doit ceder la place au texte de regle")

func test_empty_description_still_shows_the_flavour() -> void:
	# Carte sans effet : le flavour est alors le seul texte, quel que soit le seuil.
	var card := _make_card("", FLAVOUR)
	assert_true(card.desc_label.text.contains(FLAVOUR),
		"une carte sans texte de regle doit toujours afficher son flavour")

func test_shrunk_font_size_stays_readable() -> void:
	# Garde-fou sur la regression corrigee le 2026-10-28 : le cran reduit etait
	# tombe a 14px, illisible dans la case de description.
	assert_gte(Card.DESC_LABEL_SHRUNK_FONT_SIZE, 16,
		"le cran de police reduit ne doit pas descendre sous 16px")
	assert_lt(Card.DESC_LABEL_SHRUNK_FONT_SIZE, Card.DESC_LABEL_DEFAULT_FONT_SIZE,
		"le cran reduit doit rester plus petit que la taille par defaut, sinon il ne sert a rien")

func test_flavour_is_rendered_smaller_than_the_rule_text() -> void:
	# L'italique ne sert qu'au flavour : son ecart de taille avec le texte
	# normal EST la hierarchie entre regle et ambiance (demande 2026-10-29).
	var card := _make_card("Arrivee : piochez 1 carte.", FLAVOUR)
	var rule_size: int = card.desc_label.get_theme_font_size("normal_font_size")
	var flavour_size: int = card.desc_label.get_theme_font_size("italics_font_size")
	assert_eq(flavour_size, rule_size - Card.DESC_FLAVOUR_FONT_SIZE_DELTA,
		"le flavour doit etre plus petit que le texte de regle de l'ecart prevu")
	assert_lt(flavour_size, rule_size,
		"le flavour ne doit jamais etre rendu aussi grand que le texte de regle")

func test_description_text_is_not_centered() -> void:
	# Mise en page façon carte Magic (demande 2026-10-29) : le bloc de texte
	# commence en haut a gauche de sa case, jamais centre.
	var card := _make_card("Arrivee : piochez 1 carte.", FLAVOUR)
	assert_eq(card.desc_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT,
		"le texte de la carte doit etre aligne a gauche")
	assert_eq(card.desc_label.vertical_alignment, VERTICAL_ALIGNMENT_TOP,
		"le texte de la carte doit commencer en haut de sa case")
	assert_false(card.desc_label.text.contains("[center]"),
		"aucune balise [center] ne doit subsister dans le bbcode de la carte")

func test_flavour_only_card_is_not_centered_either() -> void:
	# Chemin distinct dans update_display (description vide) : c'est celui qui
	# portait la balise [center].
	var card := _make_card("", FLAVOUR)
	assert_false(card.desc_label.text.contains("[center]"),
		"une carte sans texte de regle ne doit pas centrer son flavour")
