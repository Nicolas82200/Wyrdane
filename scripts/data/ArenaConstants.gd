extends RefCounted
class_name ArenaConstants

# Constantes du mode Arena (voir README « Mode Battle Royale (8 joueurs) — Design (v1) »).
# Prototype à 8 participants (1 joueur + 7 bots), conditions réelles du design.

const PARTICIPANT_COUNT := 8

const STARTING_HERO_HP := 30
const STARTING_GOLD := 1
const GOLD_PER_ROUND := 1
const GOLD_CAP := 15
const REROLL_COST := 1
const HAND_MAX := 10
const BOARD_ROW_MAX := 10
const SHOP_SIZE := 5
const XP_PASSIVE_PER_ROUND := 2
const GOLD_TO_XP_RATE := 1
const SELL_REFUND_FROM_HAND := 1.0
const SELL_REFUND_FROM_BOARD := 0.5

# Copies disponibles dans le pool par rareté (README « Copies disponibles
# dans le pool », valeurs 8 joueurs).
const POOL_COPIES_BY_RARITY := {
	"Common": 19,
	"Rare": 14,
	"Epic": 9,
	"Legendary": 3,
}

# XP cumulé requis par niveau de héros (README, table niveau 1-8).
const HERO_LEVEL_XP_THRESHOLDS := {
	1: 0,
	2: 4,
	3: 10,
	4: 18,
	5: 28,
	6: 40,
	7: 54,
	8: 70,
}

# Coûts mana débloqués en boutique par niveau de héros.
const HERO_LEVEL_UNLOCKED_COSTS := {
	1: [1],
	2: [1, 2],
	3: [1, 2, 3],
	4: [1, 2, 3, 4],
	5: [1, 2, 3, 4, 5],
	6: [1, 2, 3, 4, 5, 6],
	7: [1, 2, 3, 4, 5, 6, 7],
	8: [1, 2, 3, 4, 5, 6, 7, 8],
}

# Probabilité de tirage d'un coût mana en boutique, par niveau de héros
# (clé = niveau, valeur = {cout: probabilite}, somme = 1.0).
const HERO_LEVEL_COST_ODDS := {
	1: {1: 1.0},
	2: {1: 0.6, 2: 0.4},
	3: {1: 0.4, 2: 0.35, 3: 0.25},
	4: {1: 0.28, 2: 0.30, 3: 0.27, 4: 0.15},
	5: {1: 0.20, 2: 0.22, 3: 0.25, 4: 0.22, 5: 0.11},
	6: {1: 0.14, 2: 0.16, 3: 0.20, 4: 0.22, 5: 0.20, 6: 0.08},
	7: {1: 0.10, 2: 0.12, 3: 0.15, 4: 0.18, 5: 0.20, 6: 0.18, 7: 0.07},
	8: {1: 0.06, 2: 0.08, 3: 0.11, 4: 0.15, 5: 0.18, 6: 0.20, 7: 0.16, 8: 0.06},
}

# Probabilité de rareté au sein d'un coût mana tiré (README).
const RARITY_ODDS_BY_COST := {
	1: {"Common": 0.60, "Rare": 0.30, "Epic": 0.08, "Legendary": 0.02},
	2: {"Common": 0.60, "Rare": 0.30, "Epic": 0.08, "Legendary": 0.02},
	3: {"Common": 0.45, "Rare": 0.35, "Epic": 0.15, "Legendary": 0.05},
	4: {"Common": 0.45, "Rare": 0.35, "Epic": 0.15, "Legendary": 0.05},
	5: {"Common": 0.25, "Rare": 0.35, "Epic": 0.30, "Legendary": 0.10},
	6: {"Common": 0.25, "Rare": 0.35, "Epic": 0.30, "Legendary": 0.10},
	7: {"Common": 0.10, "Rare": 0.25, "Epic": 0.40, "Legendary": 0.25},
	8: {"Common": 0.10, "Rare": 0.25, "Epic": 0.40, "Legendary": 0.25},
}

# Cooldown (en rounds) avant de refaire face au même adversaire (ou au
# fantôme), selon le nombre de participants restants (fantôme inclus) —
# table complète 8 joueurs (README « Anti-répétition d'appariement »).
const PAIRING_COOLDOWN_BY_PARTICIPANTS := {
	8: 4,
	7: 4,
	6: 3,
	5: 3,
	4: 2,
	3: 2,
	2: 1,
}

static func hero_level_for_xp(xp: int) -> int:
	var level := 1
	for lvl in HERO_LEVEL_XP_THRESHOLDS:
		if xp >= HERO_LEVEL_XP_THRESHOLDS[lvl]:
			level = max(level, lvl)
	return level

static func unlocked_costs_for_level(level: int) -> Array:
	return HERO_LEVEL_UNLOCKED_COSTS.get(clampi(level, 1, 8), [1])

# XP cumulé requis pour atteindre le PROCHAIN niveau (-1 si niveau 8 = max,
# déjà atteint). Pour l'affichage "XP : 4/10" en boutique.
static func xp_required_for_next_level(level: int) -> int:
	if level >= 8:
		return -1
	return int(HERO_LEVEL_XP_THRESHOLDS.get(level + 1, -1))
