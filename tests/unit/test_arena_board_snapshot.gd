extends GutTest

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"

func test_serialize_row_captures_path_star_level_and_damage() -> void:
	var card: CardData = load(REAL_CARD_PATH)
	var minion := Minion.new(card, true, "Front")
	minion.star_level = 2
	minion.damage_taken = 3
	var out: Array = ArenaBoardSnapshot.serialize_row([minion])
	assert_eq(out.size(), 1)
	assert_eq(out[0]["resource_path"], REAL_CARD_PATH)
	assert_eq(out[0]["star_level"], 2)
	assert_eq(out[0]["damage_taken"], 3)

func test_deserialize_row_rebuilds_equivalent_minions() -> void:
	var entries: Array = [{"resource_path": REAL_CARD_PATH, "star_level": 2, "damage_taken": 1}]
	var row: Array[Minion] = ArenaBoardSnapshot.deserialize_row(entries, true)
	assert_eq(row.size(), 1)
	assert_eq(row[0].card_data.resource_path, REAL_CARD_PATH)
	assert_eq(row[0].star_level, 2)
	assert_eq(row[0].damage_taken, 1)
	assert_eq(row[0].board_row, "Front")

func test_deserialize_row_uses_back_when_is_front_false() -> void:
	var entries: Array = [{"resource_path": REAL_CARD_PATH, "star_level": 1, "damage_taken": 0}]
	var row: Array[Minion] = ArenaBoardSnapshot.deserialize_row(entries, false)
	assert_eq(row[0].board_row, "Back")

func test_deserialize_row_skips_a_rejected_card_path() -> void:
	var entries: Array = [{"resource_path": "res://resources/cards/undead/minor-zombie-token.tres", "star_level": 1, "damage_taken": 0}]
	var row: Array[Minion] = ArenaBoardSnapshot.deserialize_row(entries, true)
	assert_eq(row.size(), 0, "un jeton refusé par NetCardResolver ne doit produire aucun serviteur")

func test_a_merged_minion_keeps_its_buffed_stats_after_a_round_trip() -> void:
	# Régression : un serviteur fusionné (2★, voir ArenaMergeSystem) a des
	# base_attack/base_max_health SUPÉRIEURS aux valeurs brutes de sa carte
	# (somme des 3 copies fusionnées) — les recalculer depuis card_data côté
	# réception lui redonnerait silencieusement ses stats 1★ de base.
	var card: CardData = load(REAL_CARD_PATH)
	var merged := Minion.new(card, true, "Front")
	merged.star_level = 2
	merged.base_attack = card.attack * 3
	merged.base_max_health = card.health * 3
	var rebuilt: Array[Minion] = ArenaBoardSnapshot.deserialize_row(ArenaBoardSnapshot.serialize_row([merged]), true)
	assert_eq(rebuilt[0].base_attack, card.attack * 3, "les stats fusionnées ne doivent pas retomber sur les valeurs brutes de la carte")
	assert_eq(rebuilt[0].base_max_health, card.health * 3)

func test_serialize_then_deserialize_round_trips() -> void:
	var card: CardData = load(REAL_CARD_PATH)
	var original := Minion.new(card, true, "Front")
	original.star_level = 2
	original.damage_taken = 4
	var rebuilt: Array[Minion] = ArenaBoardSnapshot.deserialize_row(ArenaBoardSnapshot.serialize_row([original]), true)
	assert_eq(rebuilt[0].card_data.resource_path, original.card_data.resource_path)
	assert_eq(rebuilt[0].star_level, original.star_level)
	assert_eq(rebuilt[0].damage_taken, original.damage_taken)
