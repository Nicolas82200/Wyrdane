extends GutTest

# ArenaBoardRow._can_drop_data() est le seul endroit qui décide si un
# serviteur déjà posé peut être déplacé : au sein de sa ligne pour n'importe
# quel serviteur (réordonner), ou d'une ligne à l'autre en plus pour un
# serviteur Hybride (CardData.board_position == "Hybrid") — voir README
# « Positionnement (lane types) ».

func _make_card(board_position: String) -> CardData:
	var data := CardData.new()
	data.card_name = "Test"
	data.card_type = "Minion"
	data.board_position = board_position
	return data

func _make_row(is_front: bool) -> ArenaBoardRow:
	var row := ArenaBoardRow.new()
	row.is_front = is_front
	row.on_reposition = func(_m, _f, _i): pass
	return row

func test_can_reorder_within_the_same_row() -> void:
	var minion := Minion.new(_make_card("Front"), true, "Front")
	var row := _make_row(true)
	assert_true(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))

func test_cannot_move_a_front_only_card_to_the_back_row() -> void:
	var minion := Minion.new(_make_card("Front"), true, "Front")
	var row := _make_row(false)
	assert_false(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))

func test_cannot_move_a_back_only_card_to_the_front_row() -> void:
	var minion := Minion.new(_make_card("Back"), true, "Back")
	var row := _make_row(true)
	assert_false(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))

func test_hybrid_card_can_move_from_front_to_back() -> void:
	var minion := Minion.new(_make_card("Hybrid"), true, "Front")
	var row := _make_row(false)
	assert_true(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))

func test_hybrid_card_can_move_from_back_to_front() -> void:
	var minion := Minion.new(_make_card("Hybrid"), true, "Back")
	var row := _make_row(true)
	assert_true(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))

func test_no_reposition_callback_rejects_the_drop_even_within_the_same_row() -> void:
	var minion := Minion.new(_make_card("Front"), true, "Front")
	var row := ArenaBoardRow.new()
	row.is_front = true
	# on_reposition jamais assigné : Callable() invalide par défaut.
	assert_false(row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}))
