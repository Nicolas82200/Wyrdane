extends GutTest

# Couvre Battle.track_card_played_for_quests (scripts/battle/Battle.gd) pour
# sa partie stats de cartes (cards_played_names, voir
# docs/backend-contracts/card-stats-and-leaderboard.md) en plus du suivi de
# quêtes par race déjà en place (cards_played_by_race) — logique pure, pas de
# dépendance de scène, instanciable directement (voir CLAUDE.md « Tests
# automatisés »).

var battle: Control

func before_each() -> void:
	battle = load("res://scripts/battle/Battle.gd").new()

func after_each() -> void:
	battle.free()

func _card(card_name: String, race: Race.Type) -> CardData:
	var data := CardData.new()
	data.card_name = card_name
	data.race = race
	return data

func test_appends_card_name_regardless_of_race() -> void:
	battle.track_card_played_for_quests(_card("Zombie affamé", Race.Type.UNDEAD))
	assert_eq(battle.cards_played_names, ["Zombie affamé"])

func test_appends_duplicate_entries_for_multiple_copies() -> void:
	battle.track_card_played_for_quests(_card("Zombie affamé", Race.Type.UNDEAD))
	battle.track_card_played_for_quests(_card("Zombie affamé", Race.Type.UNDEAD))
	assert_eq(battle.cards_played_names, ["Zombie affamé", "Zombie affamé"])

func test_tracks_name_even_for_a_raceless_card() -> void:
	battle.track_card_played_for_quests(_card("Carte neutre", Race.Type.NONE))
	assert_eq(battle.cards_played_names, ["Carte neutre"])
	assert_eq(battle.cards_played_by_race, {}, "une carte sans race n'incrémente pas cards_played_by_race")

func test_still_increments_cards_played_by_race_alongside_names() -> void:
	battle.track_card_played_for_quests(_card("Zombie affamé", Race.Type.UNDEAD))
	battle.track_card_played_for_quests(_card("Golem d'os", Race.Type.UNDEAD))
	assert_eq(battle.cards_played_by_race, {"Undead": 2})
	assert_eq(battle.cards_played_names, ["Zombie affamé", "Golem d'os"])
