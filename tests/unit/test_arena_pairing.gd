extends GutTest

func _make_players(n: int) -> Array:
	var players: Array = []
	for i in n:
		players.append(ArenaPlayerState.new("P%d" % i))
	return players

func test_even_count_pairs_only_real_players() -> void:
	var players := _make_players(4)
	var pairs := ArenaPairing.compute_pairings(players, {}, 1)
	assert_eq(pairs.size(), 2)
	for pair in pairs:
		assert_not_null(pair[1], "à effectif pair, personne ne doit recevoir de bye")

func test_odd_count_with_ghost_fills_every_participant() -> void:
	var players := _make_players(3)
	var ghost := GhostBoard.new()
	var participants: Array = players.duplicate()
	participants.append(ghost)
	var pairs := ArenaPairing.compute_pairings(participants, {}, 1)
	assert_eq(pairs.size(), 2, "4 participants (3 joueurs + fantôme) -> 2 paires, aucun bye")

func test_cooldown_prevents_immediate_rematch_when_alternative_exists() -> void:
	var players := _make_players(4)
	var history: Dictionary = {}
	# P0 et P1 se sont affrontés au round précédent (cooldown 4p = 2 rounds).
	var key := ArenaPairing._pair_key(players[0], players[1])
	history[key] = 1
	var pairs := ArenaPairing.compute_pairings(players, history, 2)
	var rematch := false
	for pair in pairs:
		if (pair[0] == players[0] and pair[1] == players[1]) or (pair[0] == players[1] and pair[1] == players[0]):
			rematch = true
	assert_false(rematch, "un round plus tard, avec d'autres adversaires disponibles, pas de revanche immédiate")

func test_cooldown_ignored_when_only_two_participants_remain() -> void:
	var players := _make_players(2)
	var history: Dictionary = {}
	history[ArenaPairing._pair_key(players[0], players[1])] = 1
	var pairs := ArenaPairing.compute_pairings(players, history, 2)
	assert_eq(pairs.size(), 1, "avec seulement 2 participants, ils doivent quand même être appariés")

func test_pairing_cooldown_table_matches_the_8_player_design() -> void:
	# Protège contre une faute de frappe dans ArenaConstants (voir README
	# « Anti-répétition d'appariement ») : table complète 8 joueurs, pas
	# seulement 4/3/2 comme dans l'ancienne échelle réduite du prototype.
	var expected := {8: 4, 7: 4, 6: 3, 5: 3, 4: 2, 3: 2, 2: 1}
	for count in expected:
		assert_eq(ArenaConstants.PAIRING_COOLDOWN_BY_PARTICIPANTS.get(count, -1), expected[count],
			"cooldown incorrect pour %d participants" % count)
