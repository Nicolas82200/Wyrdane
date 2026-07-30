extends GutTest

# Couvre BoardVisualSystem (scripts/systems/BoardVisualSystem.gd), la partie
# testable sans passer par spawn_minion_visual()/refresh_board() (branchement
# de signaux vers selection_system/targeting_system/sacrifice_system/
# fusion_system, animations — hors scope, voir CLAUDE.md) : le suivi
# minion -> visuel (get_visual/remove_visual/find_visual) et le réordonnancement
# des nœuds visuels pour rester synchronisé avec l'ordre des données
# (_place_visual_in_row). Instancie la vraie scène BoardMinion.tscn (comme
# test_drop_system.gd) car `child is BoardMinion` exige une instance réelle.

var board_visual_system
var battle: FakeBattle

func before_each() -> void:
	board_visual_system = load("res://scripts/systems/BoardVisualSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	board_visual_system.init(battle)

func _minion(is_player: bool = true, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _board_minion(minion: Minion) -> BoardMinion:
	var bm: BoardMinion = load("res://scenes/minion/BoardMinion.tscn").instantiate()
	bm.minion = minion
	return bm

# ─── get_visual / remove_visual (suivi minion -> visuel) ────────────────────

func test_get_visual_returns_null_when_untracked() -> void:
	var minion := _minion()
	assert_null(board_visual_system.get_visual(minion))

func test_get_visual_returns_the_tracked_visual() -> void:
	var minion := _minion()
	var visual: BoardMinion = autofree(_board_minion(minion))
	board_visual_system.minion_to_visual[minion] = visual
	assert_eq(board_visual_system.get_visual(minion), visual)

func test_remove_visual_untracks_the_minion() -> void:
	var minion := _minion()
	var visual: BoardMinion = autofree(_board_minion(minion))
	board_visual_system.minion_to_visual[minion] = visual
	board_visual_system.remove_visual(minion)
	assert_null(board_visual_system.get_visual(minion))

# ─── get_all_containers ──────────────────────────────────────────────────────

func test_get_all_containers_returns_all_four_row_containers() -> void:
	var containers: Array[Control] = board_visual_system.get_all_containers()
	assert_eq(containers.size(), 4)
	assert_true(battle.player_front_container in containers)
	assert_true(battle.player_back_container in containers)
	assert_true(battle.enemy_front_container in containers)
	assert_true(battle.enemy_back_container in containers)

# ─── find_visual (recherche à travers les 4 conteneurs) ─────────────────────

func test_find_visual_locates_the_matching_board_minion() -> void:
	var minion := _minion(false, "Back")
	var visual: BoardMinion = autofree(_board_minion(minion))
	battle.enemy_back_container.add_child(visual)
	assert_eq(board_visual_system.find_visual(minion), visual)

func test_find_visual_returns_null_for_an_untracked_minion() -> void:
	var minion := _minion()
	assert_null(board_visual_system.find_visual(minion))

func test_find_visual_returns_null_for_a_null_minion() -> void:
	assert_null(board_visual_system.find_visual(null))

func test_find_visual_does_not_confuse_two_different_minions() -> void:
	var a := _minion(true, "Front")
	var b := _minion(true, "Front")
	var visual_a: BoardMinion = autofree(_board_minion(a))
	var visual_b: BoardMinion = autofree(_board_minion(b))
	battle.player_front_container.add_child(visual_a)
	battle.player_front_container.add_child(visual_b)
	assert_eq(board_visual_system.find_visual(a), visual_a)
	assert_eq(board_visual_system.find_visual(b), visual_b)

# ─── _place_visual_in_row : réordonnancement visuel selon l'ordre des données

func test_place_visual_in_row_reorders_to_match_data_order() -> void:
	var m0 := _minion() # 1er dans battle.player_minions
	var m1 := _minion() # 2e
	var v0 := _board_minion(m0)
	var v1 := _board_minion(m1)
	var container: Control = autofree(Control.new())
	# Ajoutés dans l'ordre inverse des données (v1 avant v0) : simule un
	# réordonnancement de plateau (ex: retour en main + repose ailleurs).
	container.add_child(v1)
	container.add_child(v0)
	board_visual_system._place_visual_in_row(container, v0, m0, true)
	assert_eq(container.get_child(0), v0, "v0 doit être replacé en tête, comme m0 dans les données")
	assert_eq(container.get_child(1), v1)

func test_place_visual_in_row_leaves_already_correct_order_untouched() -> void:
	var m0 := _minion()
	var m1 := _minion()
	var v0 := _board_minion(m0)
	var v1 := _board_minion(m1)
	var container: Control = autofree(Control.new())
	container.add_child(v0)
	container.add_child(v1)
	board_visual_system._place_visual_in_row(container, v1, m1, true)
	assert_eq(container.get_child(0), v0)
	assert_eq(container.get_child(1), v1)

func test_place_visual_in_row_positions_a_third_minion_in_the_middle() -> void:
	# battle.player_minions (ordre des données) : m0, m1, m2 — m1 arrive au
	# milieu. Le conteneur reçoit ses visuels dans un ordre différent (m2
	# posé avant m1, comme lors d'une pose ciblée avec insert_index) : la
	# repositionner doit la ramener entre v0 et v2.
	var m0 := _minion()
	var m1 := _minion()
	var m2 := _minion()
	var v0 := _board_minion(m0)
	var v1 := _board_minion(m1)
	var v2 := _board_minion(m2)
	var container: Control = autofree(Control.new())
	container.add_child(v0)
	container.add_child(v2)
	container.add_child(v1)
	board_visual_system._place_visual_in_row(container, v1, m1, true)
	assert_eq(container.get_child(0), v0)
	assert_eq(container.get_child(1), v1)
	assert_eq(container.get_child(2), v2)
