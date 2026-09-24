extends RefCounted
class_name RankTier

# Paliers dérivés côté client depuis le MMR brut renvoyé par
# /api/profile (champ ranked.mmr) — le backend ne connaît que le MMR, aucun
# concept de palier n'existe de son côté. 7 paliers (voir CLAUDE.md §Roadmap).
# Tout joueur démarre à 0 MMR (rankedModel.DEFAULT_MMR côté wyrdane-backend),
# donc Bronze est bien le palier de départ commun à tous.
enum Type {
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND,
	MASTER,
	LEGEND,
}

const THRESHOLDS := {
	Type.LEGEND:   1200,
	Type.MASTER:   1000,
	Type.DIAMOND:  800,
	Type.PLATINUM: 600,
	Type.GOLD:     400,
	Type.SILVER:   200,
}

const TIER_COLORS := {
	Type.BRONZE:   Color(0.62, 0.42, 0.24, 1),
	Type.SILVER:   Color(0.75, 0.76, 0.78, 1),
	Type.GOLD:     Color(0.85, 0.68, 0.30, 1),
	Type.PLATINUM: Color(0.60, 0.85, 0.80, 1),
	Type.DIAMOND:  Color(0.40, 0.70, 0.95, 1),
	Type.MASTER:   Color(0.85, 0.25, 0.35, 1),
	Type.LEGEND:   Color(0.70, 0.35, 0.85, 1),
}

# Icône dédiée par palier (voir CLAUDE.md §Accessibilité) : remplace les
# anciens glyphes texte, toujours affichée en plus de la couleur.
const TIER_ICONS := {
	Type.BRONZE:   preload("res://assets/icons/rank/bronze.png"),
	Type.SILVER:   preload("res://assets/icons/rank/silver.png"),
	Type.GOLD:     preload("res://assets/icons/rank/gold.png"),
	Type.PLATINUM: preload("res://assets/icons/rank/platine.png"),
	Type.DIAMOND:  preload("res://assets/icons/rank/diamond.png"),
	Type.MASTER:   preload("res://assets/icons/rank/master.png"),
	Type.LEGEND:   preload("res://assets/icons/rank/legend.png"),
}

static func from_mmr(mmr: int) -> int:
	if mmr >= THRESHOLDS[Type.LEGEND]:
		return Type.LEGEND
	if mmr >= THRESHOLDS[Type.MASTER]:
		return Type.MASTER
	if mmr >= THRESHOLDS[Type.DIAMOND]:
		return Type.DIAMOND
	if mmr >= THRESHOLDS[Type.PLATINUM]:
		return Type.PLATINUM
	if mmr >= THRESHOLDS[Type.GOLD]:
		return Type.GOLD
	if mmr >= THRESHOLDS[Type.SILVER]:
		return Type.SILVER
	return Type.BRONZE

static func tier_key(tier: int) -> String:
	match tier:
		Type.LEGEND:   return "RANK_TIER_LEGEND"
		Type.MASTER:   return "RANK_TIER_MASTER"
		Type.DIAMOND:  return "RANK_TIER_DIAMOND"
		Type.PLATINUM: return "RANK_TIER_PLATINUM"
		Type.GOLD:     return "RANK_TIER_GOLD"
		Type.SILVER:   return "RANK_TIER_SILVER"
		_:              return "RANK_TIER_BRONZE"

static func color(tier: int) -> Color:
	return TIER_COLORS.get(tier, TIER_COLORS[Type.BRONZE])

static func icon(tier: int) -> Texture2D:
	return TIER_ICONS.get(tier, TIER_ICONS[Type.BRONZE])

# Nombre de points de MMR restants pour atteindre le palier suivant, ou -1 si
# déjà au palier maximal (Légende, pas de plafond supérieur affiché).
static func mmr_to_next_tier(mmr: int) -> int:
	var tier := from_mmr(mmr)
	if tier == Type.LEGEND:
		return -1
	var next_threshold: int = THRESHOLDS[tier + 1]
	return max(0, next_threshold - mmr)
