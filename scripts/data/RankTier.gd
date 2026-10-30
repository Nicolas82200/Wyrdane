extends RefCounted
class_name RankTier

# Rang affiché au joueur, dérivé côté client du score Elo brut renvoyé par
# /api/profile (champ `ranked.mmr`) — le backend ne connaît que ce nombre,
# aucun concept de palier n'existe de son côté. 7 paliers (voir CLAUDE.md
# §Roadmap), chacun découpé en DIVISIONS_PER_TIER divisions numérotées.
# Tout joueur démarre à 0 (rankedModel.DEFAULT_MMR côté wyrdane-backend),
# donc Bronze I est le rang de départ commun à tous.
#
# Le nombre brut n'est JAMAIS montré au joueur (demande utilisateur explicite
# 2026-10-30 : « je ne veux plus voir écrit MMR, nulle part ») : tout ce qui
# s'affiche passe par display_name() / points_to_next(). Ne jamais réintroduire
# un libellé qui expose le score lui-même.
enum Type {
	BRONZE,
	SILVER,
	GOLD,
	PLATINUM,
	DIAMOND,
	MASTER,
	LEGEND,
}

# Seuil d'entrée de chaque palier. `RANK_TIER_MMR_THRESHOLDS`
# (uniqueQuestModel.ts côté wyrdane-backend) en est une copie manuelle qui
# valide les quêtes « Atteignez le palier X » : la mettre à jour en même temps
# si ces valeurs changent.
const THRESHOLDS := {
	Type.LEGEND:   1200,
	Type.MASTER:   1000,
	Type.DIAMOND:  800,
	Type.PLATINUM: 600,
	Type.GOLD:     400,
	Type.SILVER:   200,
	Type.BRONZE:   0,
}

# Un palier couvre 200 points, soit 4 divisions de 50. Avec le K-facteur Elo
# du backend (32, donc ±16 contre un adversaire de niveau égal), une division
# vaut environ trois victoires : assez court pour que chaque série de parties
# fasse visiblement bouger le rang.
const DIVISIONS_PER_TIER := 4
const POINTS_PER_DIVISION := 50

# Divisions en chiffres romains (Bronze I → Bronze IV), sauf Légende qui les
# compte en chiffres arabes et SANS PLAFOND (Légende 150 est un rang valide) :
# c'est le palier terminal, il doit pouvoir continuer à monter indéfiniment.
const DIVISION_NUMERALS := ["I", "II", "III", "IV"]

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

# Numéro de division dans le palier, à partir de 1. Borné à
# DIVISIONS_PER_TIER pour tous les paliers sauf Légende, qui n'a pas de
# plafond (un score très élevé donne Légende 37, Légende 150...).
static func division(mmr: int) -> int:
	var tier := from_mmr(mmr)
	var offset: int = max(0, mmr - int(THRESHOLDS[tier]))
	var index := offset / POINTS_PER_DIVISION + 1
	if tier == Type.LEGEND:
		return index
	return min(index, DIVISIONS_PER_TIER)

# Rang complet affichable, p. ex. « Bronze III » ou « Légende 12 ». C'est la
# SEULE forme sous laquelle le classement d'un joueur doit apparaître en jeu.
static func display_name(mmr: int) -> String:
	var tier := from_mmr(mmr)
	return "%s %s" % [SettingsManager.t(tier_key(tier)), division_label(mmr)]

static func division_label(mmr: int) -> String:
	var index := division(mmr)
	if from_mmr(mmr) == Type.LEGEND:
		return str(index)
	return DIVISION_NUMERALS[clampi(index - 1, 0, DIVISION_NUMERALS.size() - 1)]

# Points restants avant la division suivante. Toujours défini, Légende
# comprise : il y a toujours une division au-dessus.
static func points_to_next(mmr: int) -> int:
	var tier := from_mmr(mmr)
	var offset: int = max(0, mmr - int(THRESHOLDS[tier]))
	var consumed := offset % POINTS_PER_DIVISION
	return POINTS_PER_DIVISION - consumed

# Nom du rang immédiatement supérieur — sert à annoncer la progression
# (« Plus que 20 points avant Argent I »).
static func next_display_name(mmr: int) -> String:
	return display_name(mmr + points_to_next(mmr))
