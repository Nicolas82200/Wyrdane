extends Node
class_name AISystem

# IA adverse : gère son propre deck, sa main et son mana,
# puis joue son tour en 3 phases (ressource, pose, attaque).

const DECK_SIZE    := 20
const MAX_COPIES   := 2
const MANA_CAP     := 10
const STARTING_HAND := 4

var battle

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var mana: int             = 0
var max_mana: int         = 0

func init(_battle) -> void:
	battle = _battle

func setup() -> void:
	_build_deck()
	deck.shuffle()
	for i in range(STARTING_HAND):
		_draw_card()

# ─── Tour de l'IA ─────────────────────────────────────────────────────────────

func take_turn() -> void:
	if battle.game_over:
		return
	battle.enemy_turn_active = true
	battle.end_turn_button.disabled = true
	_resource_phase()
	await _pause()
	await _play_cards_phase()
	await _attack_phase()
	battle.end_turn_button.disabled = false
	battle.enemy_turn_active = false

# Symétrique du TurnChoicePanel du joueur : pioche OU mana
func _resource_phase() -> void:
	if max_mana >= MANA_CAP or (hand.size() <= 2 and max_mana >= 4):
		_draw_card()
	else:
		max_mana += 1
	mana = max_mana
	for minion in battle.enemy_minions:
		minion.refresh_attacks()

func _play_cards_phase() -> void:
	while not battle.game_over:
		var card: CardData = _pick_best_playable_card()
		if card == null:
			return
		var row: String = _pick_row_for(card)
		hand.erase(card)
		mana -= card.cost
		await battle.board_system.summon_minion(card, false, row)
		await _pause()

func _attack_phase() -> void:
	for attacker in battle.enemy_minions.duplicate():
		while not battle.game_over and not attacker.is_dead() and attacker.can_attack():
			var target: Minion = _pick_attack_target(attacker)
			if target != null:
				await battle.combat_system.resolve_combat(attacker, target)
			elif _can_attack_player_hero(attacker):
				await battle.combat_system.perform_hero_attack(attacker)
				battle.board_visual_system.refresh_board()
			else:
				break
			await _pause()

# ─── Deck / main ──────────────────────────────────────────────────────────────

func _build_deck() -> void:
	deck.clear()
	CardLibrary.load_all_cards()
	var pool: Array[CardData] = []
	for card in CardLibrary.all_cards:
		if card.card_type == "Minion" and card.race == Race.Type.UNDEAD:
			pool.append(card)
	if pool.is_empty():
		var fallback := load("res://resources/cards/undead/gaunt-servant.tres") as CardData
		for i in range(DECK_SIZE):
			deck.append(fallback)
		return
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

func _draw_card() -> void:
	if deck.is_empty():
		return
	hand.append(deck.pop_back())

# ─── Choix de pose ────────────────────────────────────────────────────────────

# La carte jouable la plus chère en priorité
func _pick_best_playable_card() -> CardData:
	var best: CardData = null
	for card in hand:
		if card.card_type != "Minion" or card.cost > mana:
			continue
		if _pick_row_for(card) == "":
			continue
		if best == null or card.cost > best.cost:
			best = card
	return best

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

# ─── Choix de cible ───────────────────────────────────────────────────────────

# null = attaquer le héros (si autorisé), sinon aucune action possible
func _pick_attack_target(attacker: Minion) -> Minion:
	var candidates: Array[Minion] = _attackable_player_minions(attacker)
	if candidates.is_empty():
		return null
	var taunts: Array[Minion] = candidates.filter(
		func(m: Minion) -> bool: return m.has_keyword(Keyword.Type.TAUNT))
	if not taunts.is_empty():
		return _best_trade(attacker, taunts)
	if _can_attack_player_hero(attacker):
		# Létal disponible → tout sur le héros
		if _ready_attack_total() >= battle.player_hero.health:
			return null
		# Trade favorable : tuer sans mourir
		var safe_kill: Minion = _find_safe_kill(attacker, candidates)
		if safe_kill != null:
			return safe_kill
		return null
	return _best_trade(attacker, candidates)

# Miroir de Battle.get_attackable_enemy_minions pour un attaquant ennemi
func _attackable_player_minions(attacker: Minion) -> Array[Minion]:
	if attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return battle.player_minions.duplicate()
	var front: Array[Minion] = battle.get_front_minions(true)
	if not front.is_empty():
		return front
	return battle.player_minions.duplicate()

# Miroir de Battle._can_attack_hero pour un attaquant ennemi
func _can_attack_player_hero(attacker: Minion) -> bool:
	for minion in _attackable_player_minions(attacker):
		if minion.has_keyword(Keyword.Type.TAUNT):
			return false
	return attacker.has_keyword(Keyword.Type.BLACK_WINGS) \
		or battle.get_front_minions(true).is_empty()

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

func _pause() -> void:
	await battle.pace_actions()
