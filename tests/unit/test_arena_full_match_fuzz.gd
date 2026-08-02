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

# `seed_value` entre dans resource_path (propriété native `Resource`, pas un
# champ maison) : le réutiliser tel quel entre plusieurs itérations de la
# boucle de graines ferait collisionner des `CardData.new()` distincts sur le
# même chemin dans le registre interne de ressources de Godot, ce qui peut
# vider silencieusement resource_path sur l'un des deux — repéré via un faux
# positif de _assert_pool_conservation (chemin vide) à seed=6/round=27 avant
# ce correctif, pas un vrai bug du mode Arena.
func _make_pool_cards(seed_value: int) -> Array[CardData]:
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
				data.resource_path = "res://fake/arena_fuzz/seed%d_%s.tres" % [seed_value, data.card_name]
				cards.append(data)
	return cards

# 1 pour une copie normale, 3 pour une 2★ (fusion de 3 copies de base) — même
# règle que ArenaMatch._base_copies_for_star_level, dupliquée ici pour ne pas
# dépendre d'une méthode interne de la classe testée.
func _base_copies_for_star_level(star_level: int) -> int:
	return 3 if star_level >= 2 else 1

# Loi de conservation : à tout instant, pool + (copies possédées par tous les
# joueurs, une 2★ comptant pour 3) doit égaler le total de copies de rareté
# pour cette carte — aucune copie ne doit apparaître ou disparaître "de nulle
# part". Une carte affichée en boutique (shop_offer) n'est PAS retirée du pool
# tant qu'elle n'est pas achetée (voir ArenaMatch.buy_card), donc ne compte pas
# ici. Détecterait un bug de comptage (perte/duplication de copie) qu'un simple
# "jamais négatif" ne peut pas voir.
func _assert_pool_conservation(pool: ArenaCardPool, players: Array[ArenaPlayerState], path_to_card: Dictionary, context: String) -> void:
	var in_play: Dictionary = {}
	for player in players:
		for minion in player.all_owned_minions():
			var path: String = minion.card_data.resource_path
			in_play[path] = int(in_play.get(path, 0)) + _base_copies_for_star_level(minion.star_level)
		for card_data in player.spell_hand:
			var spath: String = card_data.resource_path
			in_play[spath] = int(in_play.get(spath, 0)) + 1
	for path in path_to_card:
		var card: CardData = path_to_card[path]
		var expected_total: int = int(ArenaConstants.POOL_COPIES_BY_RARITY.get(card.rarity, 0))
		var actual_total: int = int(pool.remaining_copies.get(path, 0)) + int(in_play.get(path, 0))
		assert_eq(actual_total, expected_total,
			"%s : total de copies de %s doit rester %d (pool=%d + en jeu=%d)" % [
				context, path, expected_total, int(pool.remaining_copies.get(path, 0)), int(in_play.get(path, 0))])

func test_full_matches_run_to_completion_without_crashing() -> void:
	for seed_value in range(SEED_COUNT):
		var source_cards: Array[CardData] = _make_pool_cards(seed_value)
		var path_to_card: Dictionary = {}
		for c in source_cards:
			path_to_card[c.resource_path] = c
		var pool := ArenaCardPool.new(source_cards)
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
			_assert_pool_conservation(pool, players, path_to_card, "seed=%d round=%d" % [seed_value, rounds])

			if not match_.is_match_over():
				match_.advance_round()
				match_.start_shop_phase()

		assert_eq(match_.final_ranking().size(), ArenaConstants.PARTICIPANT_COUNT,
			"seed=%d : le classement final doit toujours lister tous les participants" % seed_value)
		if match_.is_match_over():
			assert_lte(match_.alive_players().size(), 1, "seed=%d : au plus un survivant une fois la partie terminée" % seed_value)
