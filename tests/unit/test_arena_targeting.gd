extends GutTest

func _make_minion(name: String, atk: int = 1, hp: int = 1, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = name
	data.attack = atk
	data.health = hp
	var m := Minion.new(data, true, row)
	return m

func _with_taunt(minion: Minion) -> Minion:
	minion.add_keyword(Keyword.Type.TAUNT)
	return minion

func test_targets_front_row_when_present() -> void:
	var attacker := _make_minion("Attacker")
	var front := _make_minion("Front", 1, 1, "Front")
	var back := _make_minion("Back", 1, 1, "Back")
	var attackable := ArenaTargeting.get_attackable_minions(attacker, [back, front])
	assert_eq(attackable, [front])

func test_targets_back_row_when_front_empty() -> void:
	var attacker := _make_minion("Attacker")
	var back := _make_minion("Back", 1, 1, "Back")
	var attackable := ArenaTargeting.get_attackable_minions(attacker, [back])
	assert_eq(attackable, [back])

func test_dead_minions_are_never_attackable() -> void:
	var attacker := _make_minion("Attacker")
	var front := _make_minion("Front")
	front.health = 0
	var back := _make_minion("Back", 1, 1, "Back")
	var attackable := ArenaTargeting.get_attackable_minions(attacker, [front, back])
	assert_eq(attackable, [back], "l'Avant mort ne doit pas bloquer l'accès à l'Arrière")

func test_taunt_forces_target_priority() -> void:
	var attacker := _make_minion("Attacker")
	var front := _make_minion("Front")
	var taunt := _with_taunt(_make_minion("Rempart"))
	var can_hit_taunt := ArenaTargeting.can_attack_target(attacker, taunt, [front, taunt])
	var can_hit_front := ArenaTargeting.can_attack_target(attacker, front, [front, taunt])
	assert_true(can_hit_taunt, "le Rempart doit être une cible valide")
	assert_false(can_hit_front, "impossible de cibler un autre serviteur tant qu'un Rempart est en jeu")

func test_pick_target_prefers_taunt() -> void:
	var attacker := _make_minion("Attacker")
	var front := _make_minion("Front")
	var taunt := _with_taunt(_make_minion("Rempart"))
	var target := ArenaTargeting.pick_target(attacker, [front, taunt])
	assert_eq(target, taunt)

func test_black_wings_ignores_row_restriction() -> void:
	var attacker := _make_minion("Attacker")
	attacker.add_keyword(Keyword.Type.BLACK_WINGS)
	var front := _make_minion("Front")
	var back := _make_minion("Back", 1, 1, "Back")
	var attackable := ArenaTargeting.get_attackable_minions(attacker, [front, back])
	assert_eq(attackable.size(), 2, "BLACK_WINGS peut cibler n'importe quelle rangée")
