extends GutTest

# Couvre BoardSystem (scripts/systems/BoardSystem.gd) : pose d'un serviteur
# (dépassement de rangée, redirection ASSAUT-de-rangée), ordre d'insertion,
# bonus COMMANDEMENT (Humain) et copie CHAIR ADAPTATIVE (Abomination) à
# l'arrivée. Utilise FakeBattle (tests/unit/doubles/fake_battle.gd),
# conformément à la convention GUT du projet (voir CLAUDE.md).

var board_system: BoardSystem
var battle: FakeBattle

func before_each() -> void:
	board_system = load("res://scripts/systems/BoardSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	board_system.init(battle)

func after_each() -> void:
	board_system.free()

func _card(attack: int = 1, health: int = 1, race: int = Race.Type.NONE, board_position: String = "Front") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.card_type = "Minion"
	data.attack = attack
	data.health = health
	data.race = race
	data.board_position = board_position
	return data

# Serviteur déjà en jeu, sans passer par BoardSystem (évite de dupliquer le
# comportement testé dans son propre fixture).
func _existing_minion(is_player: bool, row: String, race: int = Race.Type.NONE) -> Minion:
	var data := _card(1, 1, race)
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── Pose de base ──────────────────────────────────────────────────────────────

func test_summon_minion_return_adds_minion_to_player_minions() -> void:
	var minion := await board_system.summon_minion_return(_card(), true)
	assert_true(minion in battle.player_minions)

func test_summon_minion_return_adds_minion_to_enemy_minions() -> void:
	var minion := await board_system.summon_minion_return(_card(), false)
	assert_true(minion in battle.enemy_minions)

func test_summon_minion_return_sets_board_row() -> void:
	var minion := await board_system.summon_minion_return(_card(), true, "Back")
	assert_eq(minion.board_row, "Back")

# ─── Rangée pleine ──────────────────────────────────────────────────────────────

func test_summon_fails_when_row_is_full() -> void:
	for i in 10:
		_existing_minion(true, "Front")
	var minion := await board_system.summon_minion_return(_card(), true, "Front")
	assert_null(minion, "aucune place en Avant : la pose doit échouer")
	assert_eq(battle.player_minions.size(), 10, "le serviteur refusé ne doit pas être ajouté au plateau")

# ─── Pose libre de rangée (Stratège Royal) ──────────────────────────────────────

func test_get_allowed_rows_restricts_to_fixed_board_position_by_default() -> void:
	var front_card := _card(1, 1, Race.Type.NONE, "Front")
	var back_card := _card(1, 1, Race.Type.NONE, "Back")
	assert_eq(board_system.get_allowed_rows_for_card(front_card, true), ["Front"])
	assert_eq(board_system.get_allowed_rows_for_card(back_card, true), ["Back"])

func test_get_allowed_rows_for_hybrid_card_is_always_both_rows() -> void:
	var hybrid_card := _card(1, 1, Race.Type.NONE, "Hybrid")
	assert_eq(board_system.get_allowed_rows_for_card(hybrid_card, true), ["Front", "Back"])

func test_free_row_placement_ally_lets_fixed_row_card_be_played_anywhere() -> void:
	_existing_minion(true, "Front").card_data.allows_free_row_placement = true
	var front_card := _card(1, 1, Race.Type.NONE, "Front")
	var back_card := _card(1, 1, Race.Type.NONE, "Back")
	assert_eq(board_system.get_allowed_rows_for_card(front_card, true), ["Front", "Back"],
		"un Stratège Royal allié doit permettre de poser un serviteur à rangée fixe n'importe où")
	assert_eq(board_system.get_allowed_rows_for_card(back_card, true), ["Front", "Back"])

func test_free_row_placement_ally_only_applies_to_its_own_camp() -> void:
	_existing_minion(false, "Front").card_data.allows_free_row_placement = true
	var front_card := _card(1, 1, Race.Type.NONE, "Front")
	assert_eq(board_system.get_allowed_rows_for_card(front_card, true), ["Front"],
		"le Stratège Royal ennemi ne doit pas assouplir la pose côté joueur")

# ─── Ordre d'insertion ──────────────────────────────────────────────────────────

func test_summon_appends_to_end_of_row_by_default() -> void:
	var first := await board_system.summon_minion_return(_card(), true, "Front")
	var second := await board_system.summon_minion_return(_card(), true, "Front")
	assert_eq(battle.player_minions, [first, second])

func test_summon_with_insert_index_zero_places_minion_first_in_its_row() -> void:
	var first := await board_system.summon_minion_return(_card(), true, "Front")
	var inserted := await board_system.summon_minion_return(_card(), true, "Front", 0)
	assert_eq(battle.player_minions, [inserted, first])

func test_summon_insert_index_is_scoped_to_its_own_row() -> void:
	var front := await board_system.summon_minion_return(_card(), true, "Front")
	var back := await board_system.summon_minion_return(_card(), true, "Back")
	var new_front := await board_system.summon_minion_return(_card(), true, "Front", 0)
	assert_eq(battle.player_minions, [new_front, front, back])

# ─── COMMANDEMENT (Humain) ──────────────────────────────────────────────────────

func test_commandement_ally_buffs_newly_summoned_human() -> void:
	var commander := _existing_minion(true, "Front", Race.Type.HUMAN)
	commander.add_human_keyword(KeywordHuman.Type.COMMANDEMENT)
	var recruit := await board_system.summon_minion_return(_card(2, 2, Race.Type.HUMAN), true, "Front")
	assert_eq(recruit.base_attack, 3, "COMMANDEMENT doit accorder +1 ATK permanent au nouvel arrivant Humain")

func test_commandement_does_not_buff_non_human_recruit() -> void:
	var commander := _existing_minion(true, "Front", Race.Type.HUMAN)
	commander.add_human_keyword(KeywordHuman.Type.COMMANDEMENT)
	var recruit := await board_system.summon_minion_return(_card(2, 2, Race.Type.UNDEAD), true, "Front")
	assert_eq(recruit.base_attack, 2, "COMMANDEMENT ne concerne que les recrues Humaines")

# ─── CHAIR ADAPTATIVE (Abomination) ────────────────────────────────────────────

func test_chair_adaptative_copies_first_base_keyword_from_adjacent_ally() -> void:
	var neighbor := _existing_minion(true, "Front")
	neighbor.add_keyword(Keyword.Type.TAUNT)
	var card := _card(1, 1, Race.Type.ABOMINATION)
	var kw := KeywordChoiceAbomination.new()
	kw.keyword_type = KeywordAbomination.Type.CHAIR_ADAPTATIVE
	card.abomination_keywords = [kw]
	var minion := await board_system.summon_minion_return(card, true, "Front")
	assert_true(minion.has_keyword(Keyword.Type.TAUNT), "CHAIR ADAPTATIVE doit copier un mot-clé d'un allié adjacent")

# Plus de contrainte d'adjacence (ni de camp) : un mot-clé présent sur
# n'importe quel serviteur en jeu, y compris ennemi, doit pouvoir être copié.
func test_chair_adaptative_copies_from_enemy_minion_too() -> void:
	var enemy := _existing_minion(false, "Front")
	enemy.add_keyword(Keyword.Type.TAUNT)
	var card := _card(1, 1, Race.Type.ABOMINATION)
	var kw := KeywordChoiceAbomination.new()
	kw.keyword_type = KeywordAbomination.Type.CHAIR_ADAPTATIVE
	card.abomination_keywords = [kw]
	var minion := await board_system.summon_minion_return(card, true, "Front")
	assert_true(minion.has_keyword(Keyword.Type.TAUNT), "CHAIR ADAPTATIVE doit aussi pouvoir copier un mot-clé d'un serviteur ennemi")

func test_chair_adaptative_does_nothing_without_the_keyword() -> void:
	var neighbor := _existing_minion(true, "Front")
	neighbor.add_keyword(Keyword.Type.TAUNT)
	var minion := await board_system.summon_minion_return(_card(1, 1, Race.Type.ABOMINATION), true, "Front")
	assert_false(minion.has_keyword(Keyword.Type.TAUNT), "sans CHAIR ADAPTATIVE, aucune copie de mot-clé")
