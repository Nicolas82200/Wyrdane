extends RefCounted
class_name RankTier

# Paliers dérivés côté client depuis le MMR brut renvoyé par
# /api/profile (champ ranked.mmr) — le backend ne connaît que le MMR, aucun
# concept de palier n'existe de son côté. Bornes volontairement larges (4
# paliers seulement) : avec une petite base de joueurs, une ladder à 20
# paliers créerait des paliers vides en permanence. Voir CLAUDE.md §Roadmap.
enum Type {
	BRONZE,
	SILVER,
	GOLD,
	LEGEND,
}

const THRESHOLDS := {
	Type.LEGEND: 1600,
	Type.GOLD:   1300,
	Type.SILVER: 1000,
}

const TIER_COLORS := {
	Type.BRONZE: Color(0.62, 0.42, 0.24, 1),
	Type.SILVER: Color(0.75, 0.76, 0.78, 1),
	Type.GOLD:   Color(0.85, 0.68, 0.30, 1),
	Type.LEGEND: Color(0.70, 0.35, 0.85, 1),
}

# Un seul glyphe par palier plutôt qu'une icône dédiée : cohérent avec les
# autres indicateurs non basés sur la seule couleur du projet (voir
# CLAUDE.md §Accessibilité, Card.RARITY_SYMBOLS).
const TIER_SYMBOLS := {
	Type.BRONZE: "●",
	Type.SILVER: "◆",
	Type.GOLD:   "★",
	Type.LEGEND: "♛",
}

static func from_mmr(mmr: int) -> int:
	if mmr >= THRESHOLDS[Type.LEGEND]:
		return Type.LEGEND
	if mmr >= THRESHOLDS[Type.GOLD]:
		return Type.GOLD
	if mmr >= THRESHOLDS[Type.SILVER]:
		return Type.SILVER
	return Type.BRONZE

static func tier_key(tier: int) -> String:
	match tier:
		Type.LEGEND: return "RANK_TIER_LEGEND"
		Type.GOLD:   return "RANK_TIER_GOLD"
		Type.SILVER: return "RANK_TIER_SILVER"
		_:            return "RANK_TIER_BRONZE"

static func color(tier: int) -> Color:
	return TIER_COLORS.get(tier, TIER_COLORS[Type.BRONZE])

static func symbol(tier: int) -> String:
	return TIER_SYMBOLS.get(tier, TIER_SYMBOLS[Type.BRONZE])

# Nombre de points de MMR restants pour atteindre le palier suivant, ou -1 si
# déjà au palier maximal (Légende, pas de plafond supérieur affiché).
static func mmr_to_next_tier(mmr: int) -> int:
	var tier := from_mmr(mmr)
	if tier == Type.LEGEND:
		return -1
	var next_threshold: int = THRESHOLDS[tier + 1]
	return max(0, next_threshold - mmr)
