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

func _card(attack: int = 1, health: int = 1, race: int = Race.Type.NONE, allows_overflow: bool = false) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.card_type = "Minion"
	data.attack = attack
	data.health = health
	data.race = race
	data.allows_row_overflow = allows_overflow
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

# ─── Dépassement de rangée ──────────────────────────────────────────────────────

func test_summon_fails_when_row_is_full_and_no_overflow_ally() -> void:
	for i in 10:
		_existing_minion(true, "Front")
	var minion := await board_system.summon_minion_return(_card(), true, "Front")
	assert_null(minion, "aucune place en Avant, aucun allié REMPART/débordement : la pose doit échouer")
	assert_eq(battle.player_minions.size(), 10, "le serviteur refusé ne doit pas être ajouté au plateau")

func test_summon_redirects_to_other_row_with_overflow_ally_and_room() -> void:
	for i in 10:
		_existing_minion(true, "Front")
	_existing_minion(true, "Front", Race.Type.NONE).card_data.allows_row_overflow = true
	var minion := await board_system.summon_minion_return(_card(), true, "Front")
	assert_not_null(minion, "un allié à débordement de rangée doit permettre la redirection")
	assert_eq(minion.board_row, "Back", "redirigé vers la rangée alternative disponible")

func test_summon_fails_when_both_rows_are_full_even_with_overflow_ally() -> void:
	for i in 10:
		_existing_minion(true, "Front")
	for i in 10:
		_existing_minion(true, "Back")
	_existing_minion(true, "Front").card_data.allows_row_overflow = true
	var minion := await board_system.summon_minion_return(_card(), true, "Front")
	assert_null(minion, "les deux rangées pleines : impossible de rediriger")

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

func test_chair_adaptative_does_nothing_without_the_keyword() -> void:
	var neighbor := _existing_minion(true, "Front")
	neighbor.add_keyword(Keyword.Type.TAUNT)
	var minion := await board_system.summon_minion_return(_card(1, 1, Race.Type.ABOMINATION), true, "Front")
	assert_false(minion.has_keyword(Keyword.Type.TAUNT), "sans CHAIR ADAPTATIVE, aucune copie de mot-clé")
