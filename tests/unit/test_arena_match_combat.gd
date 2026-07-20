extends GutTest

func _make_card(name: String, cost: int, path: String, atk: int, hp: int) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	data.attack = atk
	data.health = hp
	return data

func test_combat_phase_damages_loser_and_eliminates_at_zero_hp() -> void:
	var strong_card := _make_card("Strong", 3, "res://fake/match_strong.tres", 10, 10)
	var weak_card := _make_card("Weak", 1, "res://fake/match_weak.tres", 1, 1)
	var pool := ArenaCardPool.new([strong_card, weak_card])
	var p1 := ArenaPlayerState.new("P1")
	var p2 := ArenaPlayerState.new("P2")
	p2.hero_hp = 2  # meurt dès le premier combat perdu (dégâts = coût du survivant = 3)
	p1.board_front.append(Minion.new(strong_card, true, "Front"))
	p2.board_front.append(Minion.new(weak_card, true, "Front"))
	var players: Array[ArenaPlayerState] = [p1, p2]
	var m := ArenaMatch.new(players, pool)
	await m.start_combat_phase()
	assert_true(p2.is_eliminated, "PV à 0 ou moins doit éliminer le joueur")
	assert_true(m.is_match_over())

func test_reset_after_combat_clears_temporary_death_state() -> void:
	var a_card := _make_card("A", 2, "res://fake/match_reset_a.tres", 1, 1)
	var b_card := _make_card("B", 2, "res://fake/match_reset_b.tres", 1, 1)
	var pool := ArenaCardPool.new([a_card, b_card])
	var p1 := ArenaPlayerState.new("P1")
	var p2 := ArenaPlayerState.new("P2")
	var a := Minion.new(a_card, true, "Front")
	var b := Minion.new(b_card, true, "Front")
	p1.board_front.append(a)
	p2.board_front.append(b)
	var players: Array[ArenaPlayerState] = [p1, p2]
	var m := ArenaMatch.new(players, pool)
	await m.start_combat_phase()
	# égalité (1atk/1hp des deux côtés) -> les deux meurent en simulation mais
	# doivent réapparaître (mort temporaire) sur le plateau au round suivant.
	assert_true(p1.board_front.has(a), "un serviteur mort en combat simulé reste sur le plateau (mort temporaire)")
	assert_eq(a.damage_taken, 0, "l'état de vie doit être réinitialisé après le combat")
