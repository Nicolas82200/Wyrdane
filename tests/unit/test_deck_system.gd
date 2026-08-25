extends GutTest

# Couvre DeckSystem.mulligan_replace_one (scripts/systems/DeckSystem.gd), en
# particulier le cas spécial tutoriel : le deck de pioche du tutoriel
# (TutorialDeck.player_deck_padding) ne contient aucune carte-ressource, donc
# échanger une ressource doit toujours en redonner une nouvelle, jamais piocher
# au hasard dans le deck (sans quoi le script du tutoriel se bloque en
# attendant une ressource qui n'arrivera jamais — voir TutorialManager.run()).

var deck_system: DeckSystem
var battle: FakeBattle

func before_each() -> void:
	deck_system = load("res://scripts/systems/DeckSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	deck_system.init(battle)

func _resource_card() -> CardData:
	return load("res://scripts/tutorial/TutorialDeck.gd").resource_card()

func _zombie_card() -> CardData:
	return load("res://scripts/tutorial/TutorialDeck.gd").zombie_card()

func test_mulligan_replace_one_normal_draws_from_deck() -> void:
	battle.tutorial_active = false
	var old_card := _zombie_card()
	var deck_card := _resource_card()
	battle.hand_cards = [old_card]
	battle.deck = [deck_card]
	var new_card: CardData = deck_system.mulligan_replace_one(0)
	# battle.deck est mélangé avant de piocher : la nouvelle carte est l'une des
	# deux (ancienne carte remise + carte déjà présente), pas forcément
	# deck_card — on vérifie donc la permutation plutôt qu'un résultat fixe.
	assert_true(new_card == deck_card or new_card == old_card,
		"hors tuto, la nouvelle carte doit venir du pool deck+ancienne carte")
	assert_eq(battle.hand_cards[0], new_card, "la main doit contenir la nouvelle carte")
	assert_eq(battle.deck.size(), 1, "le deck garde la même taille : une carte rendue, une piochée")
	assert_ne(battle.deck[0], new_card, "la carte piochée ne doit plus être dans le deck")

func test_mulligan_replace_one_normal_empty_deck_returns_null() -> void:
	battle.tutorial_active = false
	battle.hand_cards = [_zombie_card()]
	battle.deck = []
	assert_null(deck_system.mulligan_replace_one(0))

func test_mulligan_replace_one_tutorial_resource_always_gives_new_resource() -> void:
	battle.tutorial_active = true
	var old_resource := _resource_card()
	# Deck de pioche du tuto : uniquement des Zombies, aucune ressource (voir
	# TutorialDeck.player_deck_padding).
	battle.hand_cards = [old_resource]
	battle.deck = [_zombie_card(), _zombie_card()]
	var new_card: CardData = deck_system.mulligan_replace_one(0)
	assert_eq(new_card.resource_path, old_resource.resource_path,
		"une ressource échangée en tuto doit toujours être remplacée par une nouvelle ressource")
	assert_true(battle.deck.has(old_resource), "l'ancienne ressource retourne dans le deck")

func test_mulligan_replace_one_tutorial_non_resource_unaffected() -> void:
	battle.tutorial_active = true
	var old_card := _zombie_card()
	var deck_card := _resource_card()
	battle.hand_cards = [old_card]
	battle.deck = [deck_card]
	var new_card: CardData = deck_system.mulligan_replace_one(0)
	assert_true(new_card == deck_card or new_card == old_card,
		"les cartes non-ressource suivent le tirage normal dans le deck (le clic est déjà filtré en amont par Battle)")

# ─── deck_races (quêtes quotidiennes de race) ──────────────────────────────────
# _compute_deck_races testé directement plutôt que via load_deck() : ce
# dernier dépend de l'autoload DeckManager, pas fiable sous le runner GUT
# (-s) — voir CLAUDE.md « Tests automatisés ».

func test_compute_deck_races_deduplicates_races() -> void:
	var zombie := _zombie_card() # Mort-Vivant
	battle.deck = [zombie, zombie, zombie]
	deck_system._compute_deck_races()
	assert_eq(battle.deck_races, ["Undead"], "chaque race ne doit apparaître qu'une fois même avec plusieurs copies")

func test_compute_deck_races_ignores_race_none_cards() -> void:
	var no_race_card := CardData.new()
	no_race_card.race = Race.Type.NONE
	battle.deck = [no_race_card]
	deck_system._compute_deck_races()
	assert_eq(battle.deck_races, [], "une carte sans race (Type.NONE) ne doit jamais apparaître dans deck_races")
