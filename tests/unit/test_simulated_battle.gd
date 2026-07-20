extends GutTest

func _make_minion(name: String, atk: int, hp: int, cost: int = 1, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = name
	data.attack = atk
	data.health = hp
	data.cost = cost
	return Minion.new(data, true, row)

func test_stronger_side_wins_and_deals_survivor_mana_damage() -> void:
	var sim := SimulatedBattle.new()
	var strong := _make_minion("Strong", 5, 5, 3)
	var weak := _make_minion("Weak", 1, 1, 2)
	var result: SimulatedBattle.CombatResult = await sim.run_combat([strong], [], [weak], [])
	assert_true(result.player_won)
	assert_eq(result.damage_dealt, strong.card_data.cost, "dégâts = coût mana total des survivants du gagnant")

func test_mutual_wipe_deals_no_damage() -> void:
	var sim := SimulatedBattle.new()
	var a := _make_minion("A", 5, 1, 2)
	var b := _make_minion("B", 5, 1, 2)
	var result: SimulatedBattle.CombatResult = await sim.run_combat([a], [], [b], [])
	assert_eq(result.damage_dealt, 0, "égalité (aucun survivant des deux côtés) = 0 dégât")

func test_necrophage_permanent_buff_survives_even_if_bearer_dies() -> void:
	var sim := SimulatedBattle.new()
	# Fodder à l'Avant meurt en premier ; Necro à l'Arrière (donc pas encore
	# ciblé) doit gagner son buff permanent avant d'être lui-même exposé.
	var necro := _make_minion("Necro", 1, 10, 1, "Back")
	necro.undead_keywords = [KeywordUndead.Type.NECROPHAGE]
	var fodder := _make_minion("Fodder", 1, 1, 1, "Front")
	var enemy := _make_minion("Enemy", 100, 100, 8)
	var result: SimulatedBattle.CombatResult = await sim.run_combat([fodder], [necro], [enemy], [])
	assert_false(result.player_won)
	assert_gt(necro.base_attack, 1, "NÉCROPHAGE doit avoir gagné un buff permanent quand Fodder meurt")

func test_front_row_must_be_empty_before_back_row_is_attackable() -> void:
	var sim := SimulatedBattle.new()
	var attacker := _make_minion("Attacker", 3, 10, 1)
	var enemy_front := _make_minion("EnemyFront", 1, 1, 1, "Front")
	var enemy_back := _make_minion("EnemyBack", 1, 1, 1, "Back")
	var result: SimulatedBattle.CombatResult = await sim.run_combat([attacker], [], [enemy_front], [enemy_back])
	assert_true(result.player_won)
	assert_true(enemy_front.is_dead())
	assert_true(enemy_back.is_dead(), "une fois l'Avant vidé, l'attaquant doit continuer sur l'Arrière")
