extends GutTest

func _make_card(name: String, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = 1
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	data.attack = 2
	data.health = 2
	return data

func test_capture_is_a_frozen_independent_copy() -> void:
	var card := _make_card("Grunt", "res://fake/ghost_grunt.tres")
	var player := ArenaPlayerState.new("Eliminated")
	var original := Minion.new(card, true, "Front")
	player.board_front.append(original)
	var ghost := GhostBoard.capture(player)
	assert_eq(ghost.front.size(), 1)
	assert_ne(ghost.front[0], original, "le fantôme doit être une copie, pas la même instance")
	original.base_attack = 999
	assert_eq(ghost.front[0].base_attack, 2, "modifier l'original ne doit jamais affecter le snapshot figé")

func test_capture_keeps_origin_name() -> void:
	var player := ArenaPlayerState.new("Eliminated")
	var ghost := GhostBoard.capture(player)
	assert_eq(ghost.origin_player_name, "Eliminated")
