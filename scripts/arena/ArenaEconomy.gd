extends RefCounted
class_name ArenaEconomy

# Fonctions pures de l'économie Arena (voir README « Économie »).

# Or de départ round 1 fixe (1), puis +1/round plafonné à 15 sur l'or restant
# (pas d'intérêt : l'or non dépensé n'est pas bonifié, juste reporté).
static func compute_gold_for_round(round_number: int, current_gold: int) -> int:
	if round_number <= 1:
		return ArenaConstants.STARTING_GOLD
	return min(current_gold + ArenaConstants.GOLD_PER_ROUND, ArenaConstants.GOLD_CAP)

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
