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
	assert_eq(m.elimination_order, [p2])
	var ranking: Array[ArenaPlayerState] = m.final_ranking()
	assert_eq(ranking.size(), 2)
	assert_eq(ranking[0], p1, "le survivant est classé 1er")
	assert_eq(ranking[1], p2, "l'unique éliminé est classé dernier")

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

func test_eliminated_player_releases_suspended_cards_back_to_the_pool() -> void:
	# all_owned_minions() doit inclure `suspended` : sans ça, une carte
	# suspendue au moment de l'élimination de son possesseur disparaissait
	# définitivement du pool commun au lieu d'y retourner (voir README
	# « Règle de verrouillage » : toute carte revient au pool à l'élimination).
	var strong_card := _make_card("Strong", 3, "res://fake/match_susp_strong.tres", 10, 10)
	var weak_card := _make_card("Weak", 1, "res://fake/match_susp_weak.tres", 1, 1)
	var pool := ArenaCardPool.new([strong_card, weak_card])
	var p1 := ArenaPlayerState.new("P1")
	var p2 := ArenaPlayerState.new("P2")
	p2.hero_hp = 2
	p1.board_front.append(Minion.new(strong_card, true, "Front"))
	p2.board_front.append(Minion.new(weak_card, true, "Front"))
	var suspended_minion := Minion.new(weak_card, true, "Front")
	p2.suspended.append(suspended_minion)
	pool.take(weak_card)  # copie retirée du pool le temps qu'elle reste possédée
	var copies_before: int = pool.copies_remaining(weak_card)
	var players: Array[ArenaPlayerState] = [p1, p2]
	var m := ArenaMatch.new(players, pool)
	await m.start_combat_phase()
	assert_true(p2.is_eliminated)
	assert_eq(pool.copies_remaining(weak_card), copies_before + 1,
		"la copie suspendue du joueur éliminé doit retourner au pool")

func test_eliminated_player_releases_all_base_copies_of_a_merged_card() -> void:
	# Même règle qu'à la vente (README « Upgrade de cartes ») : perdre une
	# carte 2★ à l'élimination doit rendre ses 3 copies de base, pas 1 seule.
	var strong_card := _make_card("Strong", 3, "res://fake/match_elim_strong.tres", 10, 10)
	var merged_card := _make_card("Merged", 1, "res://fake/match_elim_merged.tres", 1, 1)
	var pool := ArenaCardPool.new([strong_card, merged_card])
	var p1 := ArenaPlayerState.new("P1")
	var p2 := ArenaPlayerState.new("P2")
	p2.hero_hp = 2
	p1.board_front.append(Minion.new(strong_card, true, "Front"))
	var merged := Minion.new(merged_card, true, "Front")
	merged.star_level = 2
	p2.board_front.append(merged)
	for i in 3:
		pool.take(merged_card)
	var copies_before: int = pool.copies_remaining(merged_card)
	var players: Array[ArenaPlayerState] = [p1, p2]
	var m := ArenaMatch.new(players, pool)
	await m.start_combat_phase()
	assert_true(p2.is_eliminated)
	assert_eq(pool.copies_remaining(merged_card), copies_before + 3,
		"perdre une carte 2★ à l'élimination doit rendre ses 3 copies de base")

func test_resolve_pairing_always_treats_the_human_as_side_a_regardless_of_argument_order() -> void:
	# run_combat() mappe front_a/back_a -> sim.player_minions (voir
	# SimulatedBattle), convention dont dépend le combat animé du joueur
	# humain (ArenaBattle._resolve_combat_phase/enable_live_visuals) pour
	# savoir quel plateau afficher côté "joueur" — _resolve_pairing doit donc
	# toujours ramener players[0] (le joueur humain) en position "a", même
	# quand l'appariement le donne en second argument.
	var strong_card := _make_card("Strong", 3, "res://fake/match_swap_strong.tres", 10, 10)
	var weak_card := _make_card("Weak", 1, "res://fake/match_swap_weak.tres", 1, 1)
	var pool := ArenaCardPool.new([strong_card, weak_card])
	var human := ArenaPlayerState.new("Human")
	var bot := ArenaPlayerState.new("Bot", true)
	bot.hero_hp = 2
	human.board_front.append(Minion.new(strong_card, true, "Front"))
	bot.board_front.append(Minion.new(weak_card, true, "Front"))
	var players: Array[ArenaPlayerState] = [human, bot]
	var m := ArenaMatch.new(players, pool)
	await m._resolve_pairing(bot, human)
	assert_false(human.is_eliminated, "le joueur humain (plateau fort) doit gagner peu importe l'ordre des arguments")
	assert_true(bot.is_eliminated, "le bot (plateau faible) doit être éliminé")
