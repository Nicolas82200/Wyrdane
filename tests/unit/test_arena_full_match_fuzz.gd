extends GutTest

# Test de fumée (fuzz) : joue des parties Arena complètes (8 bots, aucun
# joueur humain) jusqu'à élimination ou plafond de manches, sur plusieurs
# graines RNG différentes, en pilotant uniquement ArenaMatch/ArenaBotDriver
# (sans scène/UI, voir convention FakeBattle-like du projet) — attrape les
# bugs d'intégration multi-manches (pool qui passe en négatif, Ghost Board à
# effectif impair fluctuant, débordement de main répété, fusion sur plusieurs
# manches...) qu'un test unitaire d'un seul système ou le smoke test 1-2
# manches de test_arena_battle_scene.gd ne peut pas voir.

const MAX_ROUNDS := 40
const SEED_COUNT := 10

func _make_pool_cards() -> Array[CardData]:
	var cards: Array[CardData] = []
	var rarities := ["Common", "Rare", "Epic", "Legendary"]
	var positions := ["Front", "Back", ""]
	for cost in range(1, 9):
		for rarity in rarities:
			for variant in range(3):
				var data := CardData.new()
				data.card_name = "C%d_%s_%d" % [cost, rarity, variant]
				data.cost = cost
				data.rarity = rarity
				data.card_type = "Minion"
				data.attack = max(1, cost + variant - 1)
				data.health = max(1, cost + variant)
				data.board_position = positions[variant % positions.size()]
				data.resource_path = "res://fake/arena_fuzz/%s.tres" % data.card_name
				cards.append(data)
	return cards

func test_full_matches_run_to_completion_without_crashing() -> void:
	for seed_value in range(SEED_COUNT):
		var pool := ArenaCardPool.new(_make_pool_cards())
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var driver := ArenaBotDriver.new(rng)
		var players: Array[ArenaPlayerState] = []
		for i in ArenaConstants.PARTICIPANT_COUNT:
			players.append(ArenaPlayerState.new("Bot %d" % i, true))
		var match_ := ArenaMatch.new(players, pool)
		match_.rng.seed = seed_value
		match_.start_shop_phase()

		var rounds := 0
		while not match_.is_match_over() and rounds < MAX_ROUNDS:
			rounds += 1
			for player in match_.alive_players():
				driver.play_shop_phase(player, match_)
				driver.play_positioning_phase(player)
				await driver.cast_spells_phase(player, match_)
			match_.end_shop_phase()
			await match_.start_combat_phase()

			# Invariants vérifiés à CHAQUE manche plutôt qu'une seule fois à la
			# fin : une régression qui ne casse qu'une manche intermédiaire
			# (ex: manche 12 sur 40) ne doit pas passer inaperçue.
			for player in players:
				assert_gte(player.gold, 0, "seed=%d round=%d : or négatif pour %s" % [seed_value, rounds, player.display_name])
				assert_gte(player.hero_hp, 0, "seed=%d round=%d : PV négatifs pour %s" % [seed_value, rounds, player.display_name])
				assert_lte(player.hand.size() + player.suspended.size(), ArenaConstants.HAND_MAX,
					"seed=%d round=%d : main de %s au-delà de la limite après discard_overflow" % [seed_value, rounds, player.display_name])
			for path in pool.remaining_copies:
				assert_gte(int(pool.remaining_copies[path]), 0, "seed=%d round=%d : pool négatif pour %s" % [seed_value, rounds, path])

			if not match_.is_match_over():
				match_.advance_round()
				match_.start_shop_phase()

		assert_eq(match_.final_ranking().size(), ArenaConstants.PARTICIPANT_COUNT,
			"seed=%d : le classement final doit toujours lister tous les participants" % seed_value)
		if match_.is_match_over():
			assert_lte(match_.alive_players().size(), 1, "seed=%d : au plus un survivant une fois la partie terminée" % seed_value)
