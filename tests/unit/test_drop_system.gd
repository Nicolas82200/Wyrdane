extends GutTest

# Couvre DropSystem (scripts/systems/DropSystem.gd) : la partie géométrique
# testable sans dépendre du visuel de drag (highlights/placeholder, hors
# scope — nécessitent le nœud "Board" réel, voir CLAUDE.md sur les autoloads/
# scènes complètes) : calcul de la rangée et de l'index de dépose sous la
# souris. Utilise de vrais Control (via add_child_autofree) car get_global_rect()
# a besoin d'un arbre de scène réel — extension de FakeBattle avec
# player_front_container/player_back_container/get_allowed_rows_for_card
# (mêmes formules que Battle.gd).

var drop_system
var battle: FakeBattle

func before_each() -> void:
	drop_system = load("res://scripts/systems/DropSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	drop_system.init(battle)
	battle.player_front_container.position = Vector2(0, 0)
	battle.player_front_container.size     = Vector2(400, 150)
	battle.player_back_container.position  = Vector2(0, 200)
	battle.player_back_container.size      = Vector2(400, 150)
	add_child_autofree(battle.player_front_container)
	add_child_autofree(battle.player_back_container)

func after_each() -> void:
	drop_system.free()

func _minion_card(board_position: String = "Front") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_MINION"
	data.card_type = "Minion"
	data.board_position = board_position
	return data

func _spell_card(card_type: String = "Instant") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_SPELL"
	data.card_type = card_type
	return data

# ─── get_player_drop_row_at : cartes non-serviteur (pas de lane à viser) ────

func test_non_minion_card_always_targets_front_row() -> void:
	# FakeHand (battle.hand) n'expose pas get_hand_zone_rect() : _is_over_hand()
	# est donc toujours false ici, et le repli est systématiquement ROW_FRONT —
	# comportement réel dès que le curseur n'est pas au-dessus de la main.
	var effect := _spell_card("Instant")
	assert_eq(drop_system.get_player_drop_row_at(Vector2(-999, -999), effect), battle.ROW_FRONT)

func test_resource_card_also_always_targets_front_row() -> void:
	var resource := _spell_card("Resource")
	assert_eq(drop_system.get_player_drop_row_at(Vector2(50, 50), resource), battle.ROW_FRONT)

# ─── get_player_drop_row_at : serviteurs, souris au-dessus d'une rangée ─────

func test_minion_card_over_front_container_returns_front() -> void:
	var card := _minion_card("Hybrid")
	var mouse := battle.player_front_container.get_global_rect().get_center()
	assert_eq(drop_system.get_player_drop_row_at(mouse, card), battle.ROW_FRONT)

func test_minion_card_over_back_container_returns_back() -> void:
	var card := _minion_card("Hybrid")
	var mouse := battle.player_back_container.get_global_rect().get_center()
	assert_eq(drop_system.get_player_drop_row_at(mouse, card), battle.ROW_BACK)

func test_minion_card_outside_both_containers_returns_empty() -> void:
	var card := _minion_card("Hybrid")
	assert_eq(drop_system.get_player_drop_row_at(Vector2(9999, 9999), card), "")

# ─── get_player_drop_row_at : respect de board_position ─────────────────────

func test_front_only_card_over_back_container_returns_empty() -> void:
	var card := _minion_card("Front")
	var mouse := battle.player_back_container.get_global_rect().get_center()
	assert_eq(drop_system.get_player_drop_row_at(mouse, card), "",
		"une carte restreinte à l'Avant ne doit pas pouvoir être déposée en Arrière")

func test_back_only_card_over_front_container_returns_empty() -> void:
	var card := _minion_card("Back")
	var mouse := battle.player_front_container.get_global_rect().get_center()
	assert_eq(drop_system.get_player_drop_row_at(mouse, card), "",
		"une carte restreinte à l'Arrière ne doit pas pouvoir être déposée en Avant")

# ─── update_player_drop_highlight : dégradation sans le nœud "Board" ────────
# battle.get_node_or_null("Board") est toujours null dans FakeBattle (pas de
# scène complète) : _ensure_drop_highlights() échoue silencieusement (juste un
# push_error), mais le placeholder (qui ne dépend que des conteneurs de
# rangée) doit continuer à fonctionner normalement.

func test_update_player_drop_highlight_still_returns_true_over_a_valid_row() -> void:
	var card := _minion_card("Hybrid")
	var mouse := battle.player_front_container.get_global_rect().get_center()
	var result: bool = drop_system.update_player_drop_highlight(card, mouse, true)
	assert_true(result)

func test_update_player_drop_highlight_returns_false_outside_any_row() -> void:
	var card := _minion_card("Hybrid")
	var result: bool = drop_system.update_player_drop_highlight(card, Vector2(9999, 9999), true)
	assert_false(result)

func test_update_player_drop_highlight_respects_row_full() -> void:
	var card := _minion_card("Front")
	for i in range(10):
		var m := Minion.new(_minion_card("Front"), true, "Front")
		battle.player_minions.append(m)
	var mouse := battle.player_front_container.get_global_rect().get_center()
	var result: bool = drop_system.update_player_drop_highlight(card, mouse, true)
	assert_false(result, "rangée Avant pleine (10 serviteurs) : pas de dépose possible")

# ─── _get_row_child_index_for_insert : ordre parmi de vrais BoardMinion ─────

func _board_minion(x_pos: float) -> BoardMinion:
	var bm: BoardMinion = load("res://scenes/minion/BoardMinion.tscn").instantiate()
	bm.position = Vector2(x_pos, 0)
	bm.size     = Vector2(100, 150)
	return bm

func test_row_child_index_for_insert_at_start() -> void:
	var container := Control.new()
	add_child_autofree(container)
	container.add_child(autofree(_board_minion(0)))
	container.add_child(autofree(_board_minion(100)))
	assert_eq(drop_system._get_row_child_index_for_insert(container, 0), 0)

func test_row_child_index_for_insert_in_the_middle() -> void:
	var container := Control.new()
	add_child_autofree(container)
	container.add_child(autofree(_board_minion(0)))
	container.add_child(autofree(_board_minion(100)))
	assert_eq(drop_system._get_row_child_index_for_insert(container, 1), 1)

func test_row_child_index_for_insert_past_the_end() -> void:
	var container := Control.new()
	add_child_autofree(container)
	container.add_child(autofree(_board_minion(0)))
	assert_eq(drop_system._get_row_child_index_for_insert(container, 5), 1,
		"un index au-delà du nombre de serviteurs retombe en fin de conteneur")

func test_row_child_index_for_insert_ignores_non_board_minion_children() -> void:
	var container := Control.new()
	add_child_autofree(container)
	container.add_child(autofree(Label.new()))  # ex: un label de rangée, pas un serviteur
	container.add_child(autofree(_board_minion(0)))
	assert_eq(drop_system._get_row_child_index_for_insert(container, 0), 1,
		"le Label ne compte pas comme serviteur, l'index vise bien le premier BoardMinion")

# ─── _get_raw_player_drop_index_at : position souris -> index parmi les serviteurs

func test_raw_drop_index_before_the_first_minion_is_zero() -> void:
	battle.player_front_container.add_child(autofree(_board_minion(0)))
	battle.player_front_container.add_child(autofree(_board_minion(100)))
	var mouse := Vector2(10, 75)  # bien à gauche du centre du premier BoardMinion (x=50)
	assert_eq(drop_system._get_raw_player_drop_index_at(mouse, battle.ROW_FRONT), 0)

func test_raw_drop_index_between_two_minions_is_one() -> void:
	battle.player_front_container.add_child(autofree(_board_minion(0)))
	battle.player_front_container.add_child(autofree(_board_minion(100)))
	var mouse := Vector2(160, 75)  # après le centre du 1er (x=50), avant le centre du 2e (x=150)
	assert_eq(drop_system._get_raw_player_drop_index_at(mouse, battle.ROW_FRONT), 1)

func test_raw_drop_index_after_all_minions_matches_their_count() -> void:
	battle.player_front_container.add_child(autofree(_board_minion(0)))
	battle.player_front_container.add_child(autofree(_board_minion(100)))
	var mouse := Vector2(500, 75)
	assert_eq(drop_system._get_raw_player_drop_index_at(mouse, battle.ROW_FRONT), 2)
