extends GutTest

# Couvre NetCommand (scripts/net/NetCommand.gd) : le vocabulaire de commandes
# échangées entre les deux clients (modèle relais). Vérifie la forme exacte
# des Dictionary produits par chaque constructeur, is_valid()/type_of(), et
# que le contenu ne survit qu'à des types de base (voir NetworkManager,
# sérialisé via var_to_bytes — jamais d'objets arbitraires).

func test_play_card_builds_expected_dictionary() -> void:
	var cmd := NetCommand.play_card("res://resources/cards/undead/bloated-giant.tres", "Front", 2, [5, 6], 3)
	assert_eq(cmd, {
		"type": NetCommand.PLAY_CARD,
		"card": "res://resources/cards/undead/bloated-giant.tres",
		"row": "Front",
		"index": 2,
		"ids": [5, 6],
		"target": 3,
	})

func test_play_card_defaults_to_no_ids_and_no_target() -> void:
	var cmd := NetCommand.play_card("res://card.tres", "Back", -1)
	assert_eq(cmd["ids"], [])
	assert_eq(cmd["target"], NetCommand.TARGET_NONE)

func test_attack_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.attack(7, 9), {"type": NetCommand.ATTACK, "attacker": 7, "defender": 9, "ids": []})
	assert_eq(NetCommand.attack(7, 9, [4]), {"type": NetCommand.ATTACK, "attacker": 7, "defender": 9, "ids": [4]})

func test_attack_hero_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.attack_hero(7), {"type": NetCommand.ATTACK_HERO, "attacker": 7, "ids": []})
	assert_eq(NetCommand.attack_hero(7, [4]), {"type": NetCommand.ATTACK_HERO, "attacker": 7, "ids": [4]})

func test_end_turn_builds_expected_dictionary_with_ids() -> void:
	assert_eq(NetCommand.end_turn([1, 2]), {"type": NetCommand.END_TURN, "ids": [1, 2]})

func test_end_turn_defaults_to_empty_ids() -> void:
	assert_eq(NetCommand.end_turn(), {"type": NetCommand.END_TURN, "ids": []})

func test_turn_start_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.turn_start([3]), {"type": NetCommand.TURN_START, "ids": [3]})

func test_activate_ritual_builds_expected_dictionary() -> void:
	var cmd := NetCommand.activate_ritual("res://ritual.tres", [1, 2], [8])
	assert_eq(cmd, {
		"type": NetCommand.ACTIVATE_RITUAL,
		"card": "res://ritual.tres",
		"victims": [1, 2],
		"ids": [8],
	})

func test_activate_fusion_builds_expected_dictionary() -> void:
	var cmd := NetCommand.activate_fusion(1, 2, "undead_keywords", "REVENANT")
	assert_eq(cmd, {
		"type": NetCommand.ACTIVATE_FUSION,
		"source": 1,
		"victim": 2,
		"pool": "undead_keywords",
		"keyword": "REVENANT",
		"ids": [],
	})
	var cmd_with_ids := NetCommand.activate_fusion(1, 2, "undead_keywords", "REVENANT", [9])
	assert_eq(cmd_with_ids["ids"], [9])

func test_hello_builds_expected_dictionary() -> void:
	var cmd := NetCommand.hello(["res://a.tres"], 2, 2, 12345, 99)
	assert_eq(cmd, {
		"type": NetCommand.HELLO,
		"deck": ["res://a.tres"],
		"start_id": 2,
		"stride": 2,
		"seed": 12345,
		"backend_id": 99,
	})

func test_hello_defaults_backend_id_to_zero() -> void:
	var cmd := NetCommand.hello(["res://a.tres"], 3, 2, 1)
	assert_eq(cmd["backend_id"], 0)

func test_hello_ack_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.hello_ack(), {"type": NetCommand.HELLO_ACK})

func test_mulligan_done_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.mulligan_done(), {"type": NetCommand.MULLIGAN_DONE})

func test_discard_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.discard(3), {"type": NetCommand.DISCARD, "count": 3})

func test_leave_match_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.leave_match(), {"type": NetCommand.LEAVE_MATCH})

func test_battle_ready_builds_expected_dictionary() -> void:
	assert_eq(NetCommand.battle_ready(), {"type": NetCommand.BATTLE_READY})

func test_type_of_returns_the_type_field() -> void:
	assert_eq(NetCommand.type_of(NetCommand.attack(1, 2)), NetCommand.ATTACK)

func test_type_of_returns_empty_string_when_missing() -> void:
	assert_eq(NetCommand.type_of({}), "")

func test_is_valid_true_for_well_formed_command() -> void:
	assert_true(NetCommand.is_valid(NetCommand.end_turn()))

func test_is_valid_false_for_non_dictionary() -> void:
	assert_false(NetCommand.is_valid("ATTACK"))
	assert_false(NetCommand.is_valid(42))
	assert_false(NetCommand.is_valid(null))

func test_is_valid_false_when_type_key_missing() -> void:
	assert_false(NetCommand.is_valid({"foo": "bar"}))

func test_is_valid_false_when_type_is_not_a_string() -> void:
	assert_false(NetCommand.is_valid({"type": 1}))

func test_commands_survive_var_to_bytes_round_trip_with_base_types_only() -> void:
	# NetworkManager sérialise chaque commande via var_to_bytes : vérifie que le
	# round-trip préserve exactement le contenu (aucun objet arbitraire à l'intérieur).
	var cmd := NetCommand.play_card("res://card.tres", "Front", 0, [1, 2], 5)
	var bytes := var_to_bytes(cmd)
	var decoded = bytes_to_var(bytes)
	assert_eq(decoded, cmd)
