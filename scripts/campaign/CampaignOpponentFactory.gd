extends RefCounted
class_name CampaignOpponentFactory

# Génère le plateau adverse d'un combat de campagne (pas un deck : pas de
# main/mana/pioche en Campagne, voir CAMPAIGN.md « Scaling de la difficulté »).
# Logique pure, aucune dépendance de scène — consommée par CampaignBattle.gd.

# ─── PV et nombre de cartes de base par type de nœud (avant scaling) ─────────
const BASE_HP := {
	CampaignMapNode.NodeType.COMBAT: 10,
	CampaignMapNode.NodeType.ELITE: 20,
	CampaignMapNode.NodeType.BOSS: 30,
}
const BASE_CARD_COUNT := {
	CampaignMapNode.NodeType.COMBAT: 3,
	CampaignMapNode.NodeType.ELITE: 5,
	CampaignMapNode.NodeType.BOSS: 7,
}
const MAX_BOARD_SIZE := 20

# ─── Scaling Normal : par palier (tous les 10) ────────────────────────────────
const NORMAL_SCALING_INTERVAL := 10
const NORMAL_SCALING_MULTIPLIER := 1.5
const NORMAL_CARD_GROWTH_INTERVAL := 2  # +1 carte tous les 2 paliers

# ─── Scaling Élite/Boss : par victoire de ce type (pas par palier) ────────────
const WIN_SCALING_MULTIPLIER := 1.5
# Nombre de cartes en plus par victoire de ce type (CAMPAIGN.md : « quelques
# cartes en plus, montant exact non fixé » — hypothèse simple +1/victoire).
const WIN_CARD_GROWTH := 1

# ─── Table de rareté (Normal) par tranche de 10 paliers, cumulative au-delà
# de la dernière tranche définie (CAMPAIGN.md « Decks/pools adverses »).
const RARITY_TABLE_BY_TRANCHE := [
	{"Common": 70, "Rare": 25, "Epic": 5, "Legendary": 0},
	{"Common": 55, "Rare": 30, "Epic": 12, "Legendary": 3},
	{"Common": 40, "Rare": 32, "Epic": 20, "Legendary": 8},
	{"Common": 28, "Rare": 32, "Epic": 26, "Legendary": 14},
	{"Common": 18, "Rare": 28, "Epic": 32, "Legendary": 22},
	{"Common": 10, "Rare": 22, "Epic": 35, "Legendary": 33},
]

# Assure que run.tier_race correspond à la tranche de 10 paliers du nœud visé,
# la retire au hasard si on vient d'entrer dans une nouvelle tranche.
static func ensure_tier_race(run: CampaignRun, node: CampaignMapNode) -> void:
	var tranche := (node.depth - 1) / NORMAL_SCALING_INTERVAL
	if tranche == run.tier_index and run.tier_race != Race.Type.NONE:
		return
	run.tier_index = tranche
	var races := Race.get_implemented_races()
	run.tier_race = races[run.rng.randi_range(0, races.size() - 1)]

static func hero_health_for(run: CampaignRun, node: CampaignMapNode) -> int:
	var base: int = BASE_HP.get(node.type, BASE_HP[CampaignMapNode.NodeType.COMBAT])
	var multiplier := _multiplier_for(run, node)
	return int(ceil(base * multiplier))

static func generate_board(run: CampaignRun, node: CampaignMapNode) -> Array[CardData]:
	ensure_tier_race(run, node)
	var card_count: int = min(_card_count_for(run, node), MAX_BOARD_SIZE)
	var multiplier := _multiplier_for(run, node)
	var rarity_weights := _rarity_weights_for(run, node)
	var board: Array[CardData] = []
	for i in range(card_count):
		var rarity := _roll_rarity(run.rng, rarity_weights)
		var card := _pick_card(run, rarity)
		if card != null:
			board.append(card)
	# Le multiplicateur de stats (PV/ATK) est appliqué au combat (CampaignBattle),
	# pas ici : generate_board ne retourne que la composition du plateau, le
	# multiplicateur est renvoyé séparément par stat_multiplier_for().
	return board

static func stat_multiplier_for(run: CampaignRun, node: CampaignMapNode) -> float:
	return _multiplier_for(run, node)

static func _multiplier_for(run: CampaignRun, node: CampaignMapNode) -> float:
	match node.type:
		CampaignMapNode.NodeType.ELITE:
			return pow(WIN_SCALING_MULTIPLIER, run.elite_wins)
		CampaignMapNode.NodeType.BOSS:
			return pow(WIN_SCALING_MULTIPLIER, run.boss_wins)
		_:
			var steps := (node.depth - 1) / NORMAL_SCALING_INTERVAL
			return pow(NORMAL_SCALING_MULTIPLIER, steps)

static func _card_count_for(run: CampaignRun, node: CampaignMapNode) -> int:
	var base: int = BASE_CARD_COUNT.get(node.type, BASE_CARD_COUNT[CampaignMapNode.NodeType.COMBAT])
	match node.type:
		CampaignMapNode.NodeType.ELITE:
			return base + run.elite_wins * WIN_CARD_GROWTH
		CampaignMapNode.NodeType.BOSS:
			return base + run.boss_wins * WIN_CARD_GROWTH
		_:
			return base + (node.depth - 1) / NORMAL_CARD_GROWTH_INTERVAL

static func _rarity_weights_for(run: CampaignRun, node: CampaignMapNode) -> Dictionary:
	# Élite/Boss : rareté indexée sur le compteur de victoires de ce type, pas
	# le palier (CAMPAIGN.md : table exacte non tranchée — hypothèse : même
	# logique de tranches par 10 que le Normal, mais sur le nombre de victoires).
	var index: int
	match node.type:
		CampaignMapNode.NodeType.ELITE:
			index = run.elite_wins / NORMAL_SCALING_INTERVAL
		CampaignMapNode.NodeType.BOSS:
			index = run.boss_wins / NORMAL_SCALING_INTERVAL
		_:
			index = (node.depth - 1) / NORMAL_SCALING_INTERVAL
	index = clamp(index, 0, RARITY_TABLE_BY_TRANCHE.size() - 1)
	return RARITY_TABLE_BY_TRANCHE[index]

static func _roll_rarity(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for w in weights.values():
		total += w
	if total <= 0:
		return "Common"
	var roll := rng.randi_range(1, total)
	var acc := 0
	for rarity in weights:
		acc += weights[rarity]
		if roll <= acc:
			return rarity
	return "Common"

const RARITY_FALLBACK := {
	"Legendary": "Epic",
	"Epic": "Rare",
	"Rare": "Common",
}

static func _pick_card(run: CampaignRun, rarity: String) -> CardData:
	var current := rarity
	while current != "":
		# Cartes à effet incompatible (pioche/mana/main) exclues aussi côté
		# adversaire : neutralisées en no-op par EffectManager de toute façon,
		# autant ne pas faire "perdre" une carte à l'IA. Incantations (Instant)
		# exclues aussi : CampaignBattle._place_card_on_board ne sait poser
		# qu'un Serviteur ou une Relique (Enchantement/Rituel), une Incantation
		# n'a pas d'emplacement de plateau et serait invoquée à tort comme
		# serviteur.
		var pool: Array[CardData] = CampaignCardFilter.filter_compatible(
			CardLibrary.get_cards_by_race_and_rarity(run.tier_race, current).filter(
				func(c: CardData) -> bool: return c.card_type != "Instant"))
		if not pool.is_empty():
			return pool[run.rng.randi_range(0, pool.size() - 1)]
		current = RARITY_FALLBACK.get(current, "")
	return null
