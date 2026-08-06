extends RefCounted
class_name ArenaMatch

# Orchestrateur headless d'une partie Arena (voir README « Structure d'un
# round »). Round : start_shop_phase() -> achats/reroll/gel via
# buy_card/sell_card/reroll/buy_xp/ArenaPlayerState.toggle_shop_freeze ->
# positionnement (place_on_board côté ArenaPlayerState) -> end_shop_phase()
# -> start_combat_phase() -> advance_round().
#
# Appariement : ArenaPairing (cooldown anti-répétition) + GhostBoard (comble
# l'effectif impair avec le plateau figé du dernier joueur éliminé).

var players: Array[ArenaPlayerState] = []
var pool: ArenaCardPool
var round_number: int = 1
var rng := RandomNumberGenerator.new()
var merge_system := ArenaMergeSystem.new()
var ghost_board: GhostBoard = null
# Historique d'appariement partagé avec ArenaPairing (clé paire -> round).
var pairing_history: Dictionary = {}
# Résumés texte des combats du dernier appel à start_combat_phase() (pour
# affichage UI ; voir décision "résumé texte instantané" du plan Arena).
var last_combat_summaries: Array[String] = []
# Ordre d'élimination (le premier éliminé est en tête), pour le classement
# final (README « Fin de partie » : classement brut 1er → dernier).
var elimination_order: Array[ArenaPlayerState] = []

func _init(_players: Array[ArenaPlayerState], _pool: ArenaCardPool) -> void:
	players = _players
	pool = _pool

func alive_players() -> Array[ArenaPlayerState]:
	return players.filter(func(p: ArenaPlayerState): return p.is_alive())

func is_match_over() -> bool:
	return alive_players().size() <= 1

# Classement brut 1er → dernier (README « Fin de partie ») : les survivants
# d'abord (partie encore en cours = plusieurs "1ers" ex-aequo temporaires),
# puis les éliminés dans l'ordre INVERSE d'élimination (le dernier éliminé
# a survécu plus longtemps, donc mieux classé que le tout premier éliminé).
func final_ranking() -> Array[ArenaPlayerState]:
	var ranking: Array[ArenaPlayerState] = alive_players()
	var eliminated_reversed: Array[ArenaPlayerState] = elimination_order.duplicate()
	eliminated_reversed.reverse()
	ranking.append_array(eliminated_reversed)
	return ranking

# ─── Phase Boutique ─────────────────────────────────────────────────────────

func start_shop_phase() -> void:
	for player in alive_players():
		player.gold = ArenaEconomy.compute_gold_for_round(round_number, player.gold)
		player.xp += ArenaEconomy.compute_xp_gain(round_number)
		player.level = ArenaEconomy.hero_level_for_xp(player.xp)
		# Boutique gelée (voir ArenaPlayerState.shop_frozen) : offre entière
		# préservée pour CETTE manche, geste consommé une fois (façon TFT —
		# il faut regeler à chaque manche pour la garder plus longtemps).
		if player.shop_frozen:
			player.shop_frozen = false
			if player.shop_offer.size() == ArenaConstants.SHOP_SIZE:
				continue
		_refresh_shop_offer(player)

func _refresh_shop_offer(player: ArenaPlayerState) -> void:
	if player.shop_offer.size() != ArenaConstants.SHOP_SIZE:
		player.shop_offer.resize(ArenaConstants.SHOP_SIZE)
	for i in ArenaConstants.SHOP_SIZE:
		player.shop_offer[i] = pool.draw_card(player.level, rng)

func buy_card(player: ArenaPlayerState, shop_index: int) -> bool:
	if shop_index < 0 or shop_index >= player.shop_offer.size():
		return false
	var card_data: CardData = player.shop_offer[shop_index]
	if card_data == null or player.gold < card_data.cost or player.is_hand_full():
		return false
	# Une offre affichée n'est pas réservée (voir _refresh_shop_offer :
	# draw_card() ne retire rien du pool) : à 8 joueurs, la même copie rare
	# peut apparaître dans plusieurs boutiques la même manche. Le premier
	# acheteur la retire réellement (pool.take, plus bas) ; sans cette
	# vérification, un acheteur suivant pouvait quand même l'obtenir alors
	# qu'il n'en restait plus une seule — deux joueurs avec la même copie
	# unique. La case est vidée pour ne pas rester bloquée sur une offre
	# devenue indisponible.
	if pool.copies_remaining(card_data) <= 0:
		player.shop_offer[shop_index] = null
		return false
	player.gold -= card_data.cost
	pool.take(card_data)
	player.shop_offer[shop_index] = null
	if card_data.card_type == "Minion":
		var minion := Minion.new(card_data, true, "Front")
		player.add_to_hand(minion)
		merge_system.try_merge_all(player)
	else:
		# Incantation (arena_only, voir README « Cartes exclusives Arena ») :
		# rejoint la main, sera lancée séparément via cast_spell().
		player.add_spell_to_hand(card_data)
	return true

# Lance une Incantation depuis la main : n'accepte que les effets ciblant le
# lanceur/ses propres alliés (Buff/GrantKeyword/HealHero sur Self, AllAllies*,
# OwnerHero) — pas de ciblage ennemi en Arena v1 (l'adversaire du round n'est
# révélé qu'au moment du combat, voir plan Arena). Réutilise SimulatedBattle
# comme contexte d'exécution : enemy_minions reste vide (sans objet ici),
# player_minions/player_hero reflètent l'état réel du lanceur, puis sont
# resynchronisés vers ArenaPlayerState après résolution (Minion partagés par
# référence pour le plateau ; hero_hp copié explicitement).
func cast_spell(player: ArenaPlayerState, card_data: CardData) -> bool:
	if not player.spell_hand.has(card_data):
		return false
	var sim := SimulatedBattle.new()
	sim.player_hero = Hero.new(player.hero_hp)
	sim.player_minions = (player.board_front + player.board_back).duplicate()
	for m in sim.player_minions:
		m.owner_is_player = true
	for effect in card_data.effects:
		await sim.effect_manager.execute_effect(sim, null, effect, null)
	sim.aura_system.recompute_all()
	player.hero_hp = sim.player_hero.health
	player.spell_hand.erase(card_data)
	return true

# Vente 100% depuis la main, 50% depuis le plateau (README « Cycle de vie
# d'une carte »). Une seule copie rendue au pool quel que soit star_level
# (règle de la fusion, voir étape 5).
func sell_card(player: ArenaPlayerState, minion: Minion, from_board: bool) -> bool:
	if from_board:
		if not (player.board_front.has(minion) or player.board_back.has(minion)):
			return false
		player.remove_from_board(minion)
	else:
		if not player.hand.has(minion):
			return false
		player.remove_from_hand(minion)
	pool.release(minion.card_data, _base_copies_for_star_level(minion.star_level))
	player.gold += ArenaEconomy.sell_refund(minion.card_data.cost, from_board)
	return true

# Nombre de copies de base qu'une carte représente (voir README « Upgrade de
# cartes ») : 1 pour une carte normale, 3 pour une 2★ dorée (3 copies
# fusionnées) — il n'existe pas de palier au-delà du 2★.
func _base_copies_for_star_level(star_level: int) -> int:
	return 3 if star_level >= 2 else 1

# Une Incantation non lancée reste en main jusqu'à être vendue (100%, comme
# n'importe quelle carte en main) ou lancée (cast_spell).
func sell_spell(player: ArenaPlayerState, card_data: CardData) -> bool:
	if not player.spell_hand.has(card_data):
		return false
	player.spell_hand.erase(card_data)
	pool.release(card_data)
	player.gold += ArenaEconomy.sell_refund(card_data.cost, false)
	return true

func reroll(player: ArenaPlayerState) -> bool:
	if player.gold < ArenaConstants.REROLL_COST:
		return false
	player.gold -= ArenaConstants.REROLL_COST
	# Un reroll manuel rejette explicitement l'offre gelée : dégeler plutôt que
	# de la préserver, sans quoi le joueur paierait un reroll pour rien.
	player.shop_frozen = false
	_refresh_shop_offer(player)
	return true

func buy_xp(player: ArenaPlayerState) -> bool:
	if not ArenaEconomy.can_buy_xp(round_number):
		return false
	if player.gold < ArenaConstants.GOLD_TO_XP_RATE:
		return false
	player.gold -= ArenaConstants.GOLD_TO_XP_RATE
	player.xp += ArenaConstants.GOLD_TO_XP_RATE
	player.level = ArenaEconomy.hero_level_for_xp(player.xp)
	return true

# Fin de phase Boutique/Positionnement : main+suspens > 10 -> défausse
# aléatoire de l'excédent (README).
func end_shop_phase() -> void:
	for player in alive_players():
		for discarded in player.discard_overflow(rng):
			pool.release(discarded.card_data)

# ─── Phase Combat ───────────────────────────────────────────────────────────

# `live_setup` (optionnel) : callable `func(sim: SimulatedBattle) -> void`
# fourni par ArenaBattle pour rejouer le combat du joueur humain avec les
# vraies animations 1v1 (voir SimulatedBattle.enable_live_visuals) au lieu
# d'une résolution headless instantanée. Uniquement appliqué à l'appariement
# qui implique `players[0]` (le joueur humain, jamais un bot) : les autres
# combats (bots entre eux, jamais regardés) restent résolus en headless.
func start_combat_phase(live_setup: Callable = Callable()) -> void:
	last_combat_summaries.clear()
	var alive: Array = alive_players()
	var participants: Array = alive.duplicate()
	# Le fantôme ne comble que l'effectif impair (README « Ghost Board ») ;
	# à effectif pair, tous les appariements sont entre joueurs réels.
	if participants.size() % 2 == 1 and ghost_board != null:
		participants.append(ghost_board)
	var pairs: Array = ArenaPairing.compute_pairings(participants, pairing_history, round_number, rng)
	for pair in pairs:
		var a = pair[0]
		var b = pair[1]
		if b == null:
			continue  # bye : garde-fou, ne devrait survenir qu'en effectif impair sans fantôme disponible
		await _resolve_pairing(a, b, live_setup)

func _resolve_pairing(a, b, live_setup: Callable = Callable()) -> void:
	# Le joueur humain (players[0]) doit toujours être "a" : run_combat()
	# mappe front_a/back_a -> sim.player_minions, la convention dont dépend
	# live_setup pour savoir quel plateau afficher côté "joueur".
	if not players.is_empty() and b == players[0] and a != players[0]:
		var tmp = a
		a = b
		b = tmp
	var a_is_ghost: bool = a is GhostBoard
	var b_is_ghost: bool = b is GhostBoard
	var front_a: Array[Minion] = a.front if a_is_ghost else a.board_front
	var back_a: Array[Minion] = a.back if a_is_ghost else a.board_back
	var front_b: Array[Minion] = b.front if b_is_ghost else b.board_front
	var back_b: Array[Minion] = b.back if b_is_ghost else b.board_back
	var sim := SimulatedBattle.new()
	var is_human_pairing: bool = live_setup.is_valid() and not players.is_empty() and a == players[0]
	var result: SimulatedBattle.CombatResult = await sim.run_combat(
		front_a, back_a, front_b, back_b, live_setup if is_human_pairing else Callable())
	var name_a: String = "Fantôme (%s)" % a.origin_player_name if a_is_ghost else a.display_name
	var name_b: String = "Fantôme (%s)" % b.origin_player_name if b_is_ghost else b.display_name
	var winner_name: String = (name_a if result.player_won else name_b) if result.damage_dealt > 0 else ""
	if result.damage_dealt <= 0:
		last_combat_summaries.append("%s vs %s : égalité, aucun dégât" % [name_a, name_b])
	else:
		last_combat_summaries.append("%s vs %s : %s gagne, %d dégâts" % [name_a, name_b, winner_name, result.damage_dealt])
		for line in result.log:
			last_combat_summaries.append("    " + line)
	# Application des dégâts : le perdant réel (pas le fantôme, qui n'a pas de héros) encaisse.
	if result.damage_dealt > 0:
		if result.player_won:
			if not b_is_ghost:
				_apply_damage(b, result.damage_dealt)
		else:
			if not a_is_ghost:
				_apply_damage(a, result.damage_dealt)
	if not a_is_ghost:
		a.reset_after_combat()
	if not b_is_ghost:
		b.reset_after_combat()

func _apply_damage(player: ArenaPlayerState, amount: int) -> void:
	player.hero_hp = max(0, player.hero_hp - amount)
	if player.hero_hp <= 0:
		_eliminate(player)

func _eliminate(player: ArenaPlayerState) -> void:
	player.is_eliminated = true
	elimination_order.append(player)
	ghost_board = GhostBoard.capture(player)
	for minion in player.all_owned_minions():
		pool.release(minion.card_data, _base_copies_for_star_level(minion.star_level))
	for card_data in player.spell_hand:
		pool.release(card_data)
	player.hand.clear()
	player.board_front.clear()
	player.board_back.clear()
	player.suspended.clear()
	player.spell_hand.clear()

func advance_round() -> void:
	round_number += 1
