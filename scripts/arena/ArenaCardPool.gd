extends RefCounted
class_name ArenaCardPool

# Pool de cartes partagé du mode Arena (voir README « Pool de cartes partagé »).
# Contient les Serviteurs (des 4 races) et, depuis l'ajout des Incantations
# Arena, les sorts marqués `CardData.arena_only = true` (voir CARDS.md
# « Cartes exclusives Arena ») — jamais les ~100 Incantations 1v1 existantes,
# pensées pour un modèle de ciblage/pioche incompatible (voir README
# « Incantations »). Rituels/Enchantements restent hors scope v1.

var remaining_copies: Dictionary = {}       # resource_path (String) -> int
var _cards_by_path: Dictionary = {}         # resource_path (String) -> CardData
var _cards_by_cost_rarity: Dictionary = {}  # cost (int) -> rarity (String) -> Array[CardData]

func _init(source_cards: Array[CardData] = []) -> void:
	var cards := source_cards
	if cards.is_empty():
		cards = CardLibrary.all_cards
	for card in cards:
		if card.is_token:
			continue
		var is_eligible: bool = card.card_type == "Minion" or (card.card_type == "Instant" and card.arena_only)
		if not is_eligible:
			continue
		var path: String = card.resource_path
		_cards_by_path[path] = card
		remaining_copies[path] = int(ArenaConstants.POOL_COPIES_BY_RARITY.get(card.rarity, 0))
		if not _cards_by_cost_rarity.has(card.cost):
			_cards_by_cost_rarity[card.cost] = {}
		var by_rarity: Dictionary = _cards_by_cost_rarity[card.cost]
		if not by_rarity.has(card.rarity):
			by_rarity[card.rarity] = []
		(by_rarity[card.rarity] as Array).append(card)

# Tirage en deux étapes : coût (selon niveau du héros), puis rareté (selon
# coût), puis carte précise pondérée par copies restantes. Redistribue les
# probabilités si une rareté est absente à un coût donné.
func draw_card(hero_level: int, rng: RandomNumberGenerator) -> CardData:
	var cost := _draw_cost(hero_level, rng)
	if cost < 0:
		return null
	var rarity := _draw_rarity(cost, rng)
	if rarity.is_empty():
		return null
	return _draw_weighted_card(cost, rarity, rng)

func _draw_cost(hero_level: int, rng: RandomNumberGenerator) -> int:
	var odds: Dictionary = ArenaConstants.HERO_LEVEL_COST_ODDS.get(clampi(hero_level, 1, 8), {1: 1.0})
	var available_costs: Array = odds.keys().filter(func(c): return _cards_by_cost_rarity.has(c))
	if available_costs.is_empty():
		available_costs = _cards_by_cost_rarity.keys()
	if available_costs.is_empty():
		return -1
	var total: float = 0.0
	for c in available_costs:
		total += float(odds.get(c, 0.0))
	if total <= 0.0:
		return available_costs[rng.randi() % available_costs.size()]
	var roll := rng.randf() * total
	var acc := 0.0
	for c in available_costs:
		acc += float(odds.get(c, 0.0))
		if roll <= acc:
			return c
	return available_costs[-1]

func _draw_rarity(cost: int, rng: RandomNumberGenerator) -> String:
	var by_rarity: Dictionary = _cards_by_cost_rarity.get(cost, {})
	if by_rarity.is_empty():
		return ""
	var odds: Dictionary = ArenaConstants.RARITY_ODDS_BY_COST.get(cost, {})
	var available: Array = by_rarity.keys().filter(func(r): return not (by_rarity[r] as Array).is_empty())
	if available.is_empty():
		return ""
	var total: float = 0.0
	for r in available:
		total += float(odds.get(r, 0.0))
	if total <= 0.0:
		return available[rng.randi() % available.size()]
	var roll := rng.randf() * total
	var acc := 0.0
	for r in available:
		acc += float(odds.get(r, 0.0))
		if roll <= acc:
			return r
	return available[-1]

func _draw_weighted_card(cost: int, rarity: String, rng: RandomNumberGenerator) -> CardData:
	var candidates: Array = (_cards_by_cost_rarity.get(cost, {}).get(rarity, []) as Array) \
			.filter(func(c: CardData): return int(remaining_copies.get(c.resource_path, 0)) > 0)
	if candidates.is_empty():
		return null
	var total_copies := 0
	for c in candidates:
		total_copies += int(remaining_copies.get(c.resource_path, 0))
	var roll := rng.randi_range(1, total_copies)
	var acc := 0
	for c in candidates:
		acc += int(remaining_copies.get(c.resource_path, 0))
		if roll <= acc:
			return c
	return candidates[-1]

# Retire une copie du pool (achat).
func take(card_data: CardData) -> void:
	var path: String = card_data.resource_path
	remaining_copies[path] = max(0, int(remaining_copies.get(path, 0)) - 1)

# Remet `count` copie(s) au pool (vente, ou élimination du possesseur).
# `count` > 1 sert à rendre les 3 copies de base d'une carte 2★ dorée fusionnée
# (voir README « Upgrade de cartes »), pas une seule.
func release(card_data: CardData, count: int = 1) -> void:
	var path: String = card_data.resource_path
	if not _cards_by_path.has(path):
		return
	var cap: int = int(ArenaConstants.POOL_COPIES_BY_RARITY.get(card_data.rarity, 0))
	remaining_copies[path] = min(cap, int(remaining_copies.get(path, 0)) + count)

func copies_remaining(card_data: CardData) -> int:
	return int(remaining_copies.get(card_data.resource_path, 0))
