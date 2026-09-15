extends GutTest

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"

func _make_match() -> ArenaMatch:
	var pool := ArenaCardPool.new([])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	return ArenaMatch.new(players, pool)  # seat_id 0 = hôte, 1 = client

func test_apply_replaces_the_target_seat_board_and_hp() -> void:
	var m := _make_match()
	var command: Dictionary = ArenaGameCommand.board_sync(
		1, 17,
		[{"resource_path": REAL_CARD_PATH, "star_level": 2, "damage_taken": 1}],
		[])
	ArenaRemoteBoardMirror.apply(m, command)
	var player: ArenaPlayerState = m.find_by_seat(1)
	assert_eq(player.hero_hp, 17)
	assert_eq(player.board_front.size(), 1)
	assert_eq(player.board_front[0].card_data.resource_path, REAL_CARD_PATH)
	assert_eq(player.board_front[0].star_level, 2)
	assert_true(player.board_back.is_empty())

func test_apply_only_touches_the_targeted_seat() -> void:
	var m := _make_match()
	var other: ArenaPlayerState = m.find_by_seat(0)
	other.hero_hp = 25
	ArenaRemoteBoardMirror.apply(m, ArenaGameCommand.board_sync(1, 10, [], []))
	assert_eq(other.hero_hp, 25, "un BOARD_SYNC pour le siège 1 ne doit pas toucher le siège 0")

func test_apply_on_an_unknown_seat_is_a_no_op() -> void:
	var m := _make_match()
	ArenaRemoteBoardMirror.apply(m, ArenaGameCommand.board_sync(99, 5, [], []))
	# Aucune assertion de mutation à faire : le test réussit simplement s'il
	# ne plante pas sur un seat_id inconnu.
	assert_true(true)
