extends OpponentDriver
class_name AISystem

# IA adverse : gère son propre deck, sa main et son mana,
# puis joue son tour en 3 phases (ressource, pose, attaque).
# Joue tous les types de cartes (Serviteur, Éphémère, Rituel, Enchantement).
# La qualité de ses décisions dépend du réglage SettingsManager.ai_difficulty
# ("easy", "normal", "hard").

const DECK_SIZE       := 40  # cartes jouables (hors ressources), minimum imposé aux joueurs
const RESOURCE_COUNT  := 12  # cartes-ressource mélangées au deck (minimum 10, voir README)
const MAX_COPIES      := 2
const STARTING_HAND := 4

# Facile : chance de gaspiller son tour (carte au hasard plutôt que le meilleur
# choix, cible d'attaque au hasard plutôt que le meilleur trade).
const EASY_MISTAKE_CHANCE := 0.35
# Menace à partir de laquelle l'IA en mode Difficile priorise un sort de
# suppression sur un serviteur ennemi plutôt que la carte la plus chère.
const HARD_THREAT_ATTACK := 4

# Effets qui affaiblissent/suppriment un serviteur ennemi ciblé (utilisé pour
# prioriser la suppression d'une menace en mode Difficile).
const REMOVAL_EFFECTS := [
	"Damage", "Destroy", "DebuffATK", "Debuff", "Freeze", "Silence",
	"StealMinion", "StealMinionThenDestroy", "Corrupt", "InfectEnemy", "Transform",
]
# Effets à cible "AllyMinion"/"AnyMinion" dont l'IA ne choisit pas la cible :
# EffectManager retombe automatiquement sur les alliés les plus faibles.
const AUTO_TARGET_EFFECTS := ["SacrificeAlly", "SacrificeDrawPerVictim"]

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var difficulty: String = "normal"
# race_mana / race_max_mana sont hérités d'OpponentDriver (partagés avec le mode réseau).

func setup() -> void:
	difficulty = SettingsManager.ai_difficulty
	_build_deck()
	deck.shuffle()
	for i in range(STARTING_HAND):
		_draw_card()
	_mulligan()
	refresh_ui()

# Mulligan simple et immédiat (pas d'UI) : les cartes trop chères pour un
# début de partie sont remises dans le deck et remplacées.
const MULLIGAN_COST_THRESHOLD := 5

func _mulligan() -> void:
	var to_replace: Array[CardData] = []
	for card in hand:
		if card.cost >= MULLIGAN_COST_THRESHOLD:
			to_replace.append(card)
	if to_replace.is_empty():
		return
	for card in to_replace:
		hand.erase(card)
		deck.append(card)
	deck.shuffle()
	for i in range(to_replace.size()):
		_draw_card()

# Deck et main de l'IA visibles par le joueur (dos de cartes + compteurs)
func refresh_ui() -> void:
	battle.deck_system.update_enemy_deck_ui()
	battle.update_enemy_hand_ui()
	battle.update_enemy_mana_ui()

func get_deck_count() -> int:
	return deck.size()

# Pioche pour l'IA (effets déclenchés par une carte lui appartenant, ex. Autel
# des Damnés). Simple alias public de _draw_card, exposé via OpponentDriver.
func draw_card() -> void:
	_draw_card()

func get_hand_count() -> int:
	return hand.size()

# ─── Tour de l'IA ─────────────────────────────────────────────────────────────

func take_turn() -> void:
	if battle.game_over:
		return
	battle.set_enemy_turn(true)
	# Partagé avec le mode réseau (voir NetworkOpponent._apply, cas TURN_START) :
	# Éveil pour le camp qui commence son tour, Déclin pour le camp adverse,
	# OnTurnStart symétrique, reset "une fois par tour" et recalcul des auras/morts.
	await battle.turn_system.run_turn_start_triggers(false)
	_start_of_turn_phase()
	var played_cards := await _play_cards_phase()
	await _attack_phase(played_cards)
	# Partagé avec le mode réseau (voir NetworkOpponent.take_turn, cas END_TURN) :
	# OnTurnEnd des deux camps, Infection, expiration du blocage de soin.
	await battle.turn_system.run_turn_end_triggers(false)
	battle.set_enemy_turn(false)

# Miroir de TurnSystem._finish_turn_start : recharge les pools de ressource à
# leur maximum et pioche une carte, plus de choix Mana/Pioche. Le reste du
# début de tour est géré par run_turn_start_triggers ci-dessus (partagé).
func _start_of_turn_phase() -> void:
	battle.refill_mana_pool(false)
	_draw_card()
	battle.update_enemy_mana_ui()

# Pause AVANT chaque action sauf la première : une action isolée reste fluide
func _play_cards_phase() -> bool:
	_maybe_play_resource_card()
	var played := false
	while not battle.game_over:
		var card: CardData = _pick_best_playable_card()
		if card == null:
			return played
		if played:
			await battle.pace_actions()
		hand.erase(card)
		battle.cost_system.pay(card, false)
		await battle.cost_system.on_card_played(card, false)
		refresh_ui()
		if card.card_type == "Minion":
			var row: String = _pick_row_for(card)
			await battle.board_system.summon_minion(card, false, row)
		else:
			await _cast_spell(card)
		played = true
	return played

func _attack_phase(already_acted: bool) -> void:
	var attacked := already_acted
	for attacker in battle.enemy_minions.duplicate():
		while not battle.game_over and not attacker.is_dead() and attacker.can_attack():
			var target: Minion = _pick_attack_target(attacker)
			if target == null and not battle._can_attack_hero(attacker):
				break
			if attacked:
				await battle.pace_actions()
			if target != null:
				await battle.combat_system.resolve_combat(attacker, target)
			else:
				await battle.combat_system.perform_hero_attack(attacker)
				battle.board_visual_system.refresh_board()
			attacked = true

# ─── Deck / main ──────────────────────────────────────────────────────────────

func _build_deck() -> void:
	deck.clear()
	CardLibrary.load_all_cards()
	var pool: Array[CardData] = []
	for card in CardLibrary.all_cards:
		if card.race == Race.Type.UNDEAD and card.card_type != "Resource":
			pool.append(card)
	if pool.is_empty():
		var fallback := load("res://resources/cards/undead/gaunt-servant.tres") as CardData
		for i in range(DECK_SIZE):
			deck.append(fallback)
	else:
		var copies: Dictionary = {}
		# Si le pool est trop petit pour respecter la limite de copies, on l'ignore
		var enforce_copies: bool = pool.size() * MAX_COPIES > DECK_SIZE
		while deck.size() < DECK_SIZE:
			var card: CardData = pool.pick_random()
			var count: int = copies.get(card, 0)
			if enforce_copies and count >= MAX_COPIES:
				continue
			copies[card] = count + 1
			deck.append(card)
	# Cartes-ressource (Âme) mélangées au deck, comme l'impose le deckbuilder joueur.
	var resource_card := load("res://resources/cards/undead/soul-shard.tres") as CardData
	if resource_card != null:
		for i in range(RESOURCE_COUNT):
			deck.append(resource_card)

func _draw_card() -> void:
	if deck.is_empty():
		return
	hand.append(deck.pop_back())
	refresh_ui()

# Pose une carte-ressource de sa main si elle en a une, une seule par tour
# (miroir du "land drop" du joueur — voir Battle.play_resource_card).
func _maybe_play_resource_card() -> void:
	if battle.resource_played_this_turn.get(false, false):
		return
	for card in hand:
		if card.card_type == "Resource":
			hand.erase(card)
			battle.play_resource_card(card, false)
			refresh_ui()
			return

# ─── Choix de pose ────────────────────────────────────────────────────────────

func _is_mistake() -> bool:
	return difficulty == "easy" and randf() < EASY_MISTAKE_CHANCE

# Cartes actuellement jouables (coût, rangée pour un serviteur, cible pour un
# sort ciblé, condition de ressource pour les effets de cimetière/sacrifice).
func _playable_cards() -> Array[CardData]:
	var result: Array[CardData] = []
	for card in hand:
		if _can_play_card(card):
			result.append(card)
	return result

# Les cartes-ressource sont gérées à part par _maybe_play_resource_card
# (action séparée, une seule par tour) : jamais choisies par la boucle normale.
func _can_play_card(card: CardData) -> bool:
	if card.card_type == "Resource":
		return false
	if not battle.cost_system.can_afford(card, false):
		return false
	if card.card_type == "Minion":
		return _pick_row_for(card) != ""
	for effect in card.effects:
		match effect.effect_id:
			"Resurrect", "ResurrectLast", "ReturnFromGrave":
				if battle.enemy_graveyard.get_minions().is_empty():
					return false
			"SacrificeAlly", "SacrificeDrawPerVictim":
				if battle.enemy_minions.is_empty():
					return false
	if card.requires_target:
		return _has_valid_spell_target(card)
	return true

func _pick_best_playable_card() -> CardData:
	var playable: Array[CardData] = _playable_cards()
	if playable.is_empty():
		return null
	if _is_mistake():
		return playable.pick_random()
	if difficulty == "hard":
		var lethal_burn: CardData = _find_lethal_burn(playable)
		if lethal_burn != null:
			return lethal_burn
		var removal: CardData = _find_priority_removal(playable)
		if removal != null:
			return removal
	return _highest_cost(playable)

func _highest_cost(cards: Array[CardData]) -> CardData:
	var best: CardData = null
	for card in cards:
		if best == null or card.cost > best.cost:
			best = card
	return best

# Sort de dégâts directs au héros permettant de conclure la partie ce tour, en
# comptant les dégâts d'attaque déjà assurés (Difficile uniquement).
func _find_lethal_burn(cards: Array[CardData]) -> CardData:
	var ready: int = _ready_attack_total()
	for card in cards:
		if card.card_type == "Minion" or card.effects.is_empty():
			continue
		var effect: CardEffect = card.effects[0]
		if effect.effect_id == "Damage" and effect.target == "EnemyHero" \
				and ready + effect.value >= battle.player_hero.health:
			return card
	return null

# Priorise un sort de suppression sur le plus gros serviteur ennemi en jeu
# (Difficile uniquement).
func _find_priority_removal(cards: Array[CardData]) -> CardData:
	var threat: Minion = _best_hostile_target(battle.player_minions.duplicate())
	if threat == null or threat.attack < HARD_THREAT_ATTACK:
		return null
	for card in cards:
		if card.card_type == "Minion" or card.effects.is_empty():
			continue
		var effect: CardEffect = card.effects[0]
		if effect.effect_id in REMOVAL_EFFECTS and effect.target in ["EnemyMinion", "AnyMinion"]:
			return card
	return null

# Rangée autorisée avec de la place ; les hybrides fragiles vont derrière
func _pick_row_for(card: CardData) -> String:
	var rows: Array[String] = battle.get_allowed_rows_for_card(card)
	var order: Array[String] = rows.duplicate()
	if rows.size() > 1 and card.attack > card.health:
		order = [battle.ROW_BACK, battle.ROW_FRONT]
	for row in order:
		if battle.can_summon_to_row(false, row):
			return row
	return ""

# ─── Sorts / Rituels / Enchantements ──────────────────────────────────────────

# Joue un sort, rituel ou enchantement côté ENNEMI. Miroir de
# NetworkOpponent._apply_enemy_spell : un proxy Minion(owner_is_player=false)
# sert de lanceur pour qu'EffectManager résolve les cibles du bon camp.
func _cast_spell(card: CardData) -> void:
	var target: Minion = null
	if card.requires_target:
		target = _pick_spell_target(card)
	# Annulation de sort (Rituel de l'Éclipse Rouge) : un rituel du joueur peut
	# contrer un sort de l'IA ciblant un de ses serviteurs.
	if target != null and await battle.trigger_system.try_cancel_spell(false, target):
		battle.enemy_graveyard.add_spell(card)
		battle.board_visual_system.refresh_board()
		return
	var shows_popup: bool = card.card_type != "Enchantment" \
		and not (card.card_type == "Ritual" and card.ritual_duration != 0)
	if shows_popup:
		await battle.card_popup_system.show_card_popup(card)
	if card.card_type == "Instant" or card.card_type == "Ritual":
		AudioManager.play_spell_cast(card)
		battle.vfx_manager.spawn_for_spell(battle, card, false, target)
	# Sortilège — enchantements du joueur réagissent (miroir de CardSystem)
	await battle.trigger_system.fire("OnSpell", null, true)
	for ally in battle.enemy_minions.duplicate():
		await battle.effect_manager.trigger_effects(battle, ally, "OnSpell")
	if card.card_type == "Enchantment":
		battle.trigger_system.register_enchantment(card, false, -1)
		battle.enchantment_system.add_enchantment(card, false)
		battle.aura_system.recompute_all()
		await battle.death_system.process_deaths()
	elif card.card_type == "Ritual" and card.ritual_duration != 0:
		battle.trigger_system.register_enchantment(card, false, card.ritual_duration)
		battle.enchantment_system.add_ritual(card, false, card.ritual_duration)
		battle.aura_system.recompute_all()
		await battle.death_system.process_deaths()
	else:
		battle.enemy_graveyard.add_spell(card)
		var proxy := Minion.new(card, false, "")
		for effect in card.effects:
			await battle.effect_manager.execute_effect(battle, proxy, effect, target)
	battle.board_visual_system.refresh_board()

# Existe-t-il une cible valide pour le premier effet de cette carte ? Les
# effets à cible automatique (coût de sacrifice) n'ont besoin que d'un allié
# en jeu ; les cibles Héros n'ont jamais besoin de sélection.
func _has_valid_spell_target(card: CardData) -> bool:
	if card.effects.is_empty():
		return true
	var effect: CardEffect = card.effects[0]
	match effect.target:
		"EnemyMinion", "AllyMinion", "AnyMinion":
			if effect.effect_id in AUTO_TARGET_EFFECTS:
				return not battle.enemy_minions.is_empty()
			return _pick_spell_target(card) != null
		_:
			return true

# Choisit la cible d'un sort ciblé pour l'IA : le serviteur ennemi (au joueur)
# le plus menaçant pour les effets hostiles, l'allié le plus faible pour les
# effets bénéfiques. Retourne null pour les cibles Héros (ignorées par
# EffectManager, qui résout OwnerHero/EnemyHero via le camp du lanceur).
func _pick_spell_target(card: CardData) -> Minion:
	if card.effects.is_empty():
		return null
	var effect: CardEffect = card.effects[0]
	if effect.effect_id in AUTO_TARGET_EFFECTS:
		return null
	match effect.target:
		"EnemyMinion":
			return _best_hostile_target(_filter_spell_targets(battle.player_minions, effect))
		"AllyMinion":
			return _best_friendly_target(_filter_spell_targets(battle.enemy_minions, effect))
		"AnyMinion":
			var hostile: Minion = _best_hostile_target(_filter_spell_targets(battle.player_minions, effect))
			if hostile != null:
				return hostile
			return _best_friendly_target(_filter_spell_targets(battle.enemy_minions, effect))
		_:
			return null

# Filtres de l'effet (race/rangée/seuils HP-ATK), miroir d'EffectManager._filter_targets.
func _filter_spell_targets(minions: Array[Minion], effect: CardEffect) -> Array[Minion]:
	var race_id: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	return minions.filter(func(m: Minion) -> bool:
		if not effect.race_filter.is_empty() and m.card_data.race != race_id:
			return false
		if not effect.row_filter.is_empty() and m.board_row != effect.row_filter:
			return false
		if effect.target_max_hp >= 0 and m.health > effect.target_max_hp:
			return false
		if effect.target_max_atk >= 0 and m.attack > effect.target_max_atk:
			return false
		return true
	)

func _best_hostile_target(candidates: Array[Minion]) -> Minion:
	if candidates.is_empty():
		return null
	var best: Minion = null
	for m in candidates:
		if best == null or m.attack > best.attack or (m.attack == best.attack and m.health < best.health):
			best = m
	return best

func _best_friendly_target(candidates: Array[Minion]) -> Minion:
	if candidates.is_empty():
		return null
	var best: Minion = null
	for m in candidates:
		if best == null or m.health < best.health:
			best = m
	return best

# ─── Choix de cible d'attaque ─────────────────────────────────────────────────

# null = attaquer le héros (si autorisé), sinon aucune action possible
func _pick_attack_target(attacker: Minion) -> Minion:
	var candidates: Array[Minion] = battle.get_attackable_enemy_minions(attacker)
	if candidates.is_empty():
		return null
	var taunts: Array[Minion] = candidates.filter(
		func(m: Minion) -> bool: return m.has_keyword(Keyword.Type.TAUNT))
	if not taunts.is_empty():
		return _choose_trade(attacker, taunts)
	if battle._can_attack_hero(attacker):
		# Létal disponible → tout sur le héros
		if _ready_attack_total() >= battle.player_hero.health:
			return null
		# Trade favorable : tuer sans mourir (Facile passe parfois à côté)
		if not _is_mistake():
			var safe_kill: Minion = _find_safe_kill(attacker, candidates)
			if safe_kill != null:
				return safe_kill
		return null
	return _choose_trade(attacker, candidates)

# Facile : choix au hasard dans le pool. Normal/Difficile : le meilleur trade.
func _choose_trade(attacker: Minion, pool: Array[Minion]) -> Minion:
	if _is_mistake():
		return pool.pick_random()
	return _best_trade(attacker, pool)

func _best_trade(attacker: Minion, candidates: Array[Minion]) -> Minion:
	var killable: Array[Minion] = candidates.filter(
		func(m: Minion) -> bool: return m.health <= attacker.attack)
	var pool: Array[Minion] = killable if not killable.is_empty() else candidates
	var best: Minion = null
	for minion in pool:
		if best == null or minion.attack > best.attack:
			best = minion
	return best

func _find_safe_kill(attacker: Minion, candidates: Array[Minion]) -> Minion:
	var best: Minion = null
	for minion in candidates:
		if minion.health > attacker.attack:
			continue
		if minion.attack >= attacker.health:
			continue
		if best == null or minion.attack > best.attack:
			best = minion
	return best

func _ready_attack_total() -> int:
	var total: int = 0
	for minion in battle.enemy_minions:
		if minion.can_attack():
			total += minion.attack * minion.attacks_remaining
	return total
