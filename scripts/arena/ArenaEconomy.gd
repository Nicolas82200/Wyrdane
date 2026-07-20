extends RefCounted
class_name ArenaEconomy

# Fonctions pures de l'économie Arena (voir README « Économie »).

# Or de départ round 1 fixe (1), puis un revenu qui grandit de round en round
# (+1 par rapport au revenu du round précédent, pas juste "+1" fixe ajouté au
# reste) s'ajoute au reliquat non dépensé, plafonné à 15. Sans ce revenu
# croissant, un joueur qui dépense tout chaque round (le comportement que le
# design encourage explicitement, voir README « Philosophie de design ») ne
# recevrait jamais plus de 1 or/round et resterait bloqué sur les cartes à
# 1⬡ toute la partie — contraire à l'objectif d'une partie de ~25-30 rounds
# où l'or plafonne naturellement à 15.
static func compute_gold_for_round(round_number: int, current_gold: int) -> int:
	if round_number <= 1:
		return ArenaConstants.STARTING_GOLD
	var income: int = min(round_number * ArenaConstants.GOLD_PER_ROUND, ArenaConstants.GOLD_CAP)
	return min(current_gold + income, ArenaConstants.GOLD_CAP)

# XP passive, automatique chaque round (pas de restriction round 1 : seul
# l'ACHAT d'XP est verrouillé au round 1, voir README).
static func compute_xp_gain(_round_number: int) -> int:
	return ArenaConstants.XP_PASSIVE_PER_ROUND

static func can_buy_xp(round_number: int) -> bool:
	return round_number >= 2

static func hero_level_for_xp(xp: int) -> int:
	return ArenaConstants.hero_level_for_xp(xp)

static func unlocked_costs_for_level(level: int) -> Array:
	return ArenaConstants.unlocked_costs_for_level(level)

static func sell_refund(cost: int, from_board: bool) -> int:
	var rate: float = ArenaConstants.SELL_REFUND_FROM_BOARD if from_board else ArenaConstants.SELL_REFUND_FROM_HAND
	return int(floor(cost * rate))
