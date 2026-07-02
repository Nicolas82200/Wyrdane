extends Resource
class_name CardEffect

@export_enum(
	"Damage", "Heal", "Buff", "Debuff", "Destroy",
	"DrawCard", "SummonMinion", "SummonRandom", "SummonSelf",
	"StealHealth", "HealHero", "ReturnToHand",
	"InfectEnemy", "InfectAdjacent", "Freeze",
	"Resurrect", "ResurrectLast", "StealMinion",
	"Silence", "Transform",
	"DamageAll", "BuffRow", "BuffAdjacent", "SplashDamage",
	"DebuffATK", "DestroyLowHP", "BuffIfCondition",
	"DamageAllMinions", "ReturnFromGrave",
	"GrantKeyword"
) var effect_id: String = "Damage"

@export_enum(
	"Self", "EnemyHero", "OwnerHero",
	"EnemyMinion", "AllyMinion", "AllEnemies",
	"AllAllies", "AllMinions", "RandomEnemy", "RandomAlly",
	"AnyMinion", "AllEnemiesFront", "AllEnemiesBack",
	"AllAlliesFront", "AllAlliesBack", "PerInfectedEnemy"
) var target: String = "Self"

@export_enum("Permanent", "UntilEndOfTurn", "UntilEndOfEnemyTurn") var duration: String = "Permanent"

@export var value: int = 0
@export var value_2: int = 0
@export var count: int = 1
@export var summon_card: CardData
@export var transform_card: CardData
@export var race_filter: String = ""
@export var row_filter: String = ""  # "Front", "Back", ou "" pour les deux

# ─── Pool d'invocation aléatoire (SummonRandom) ───────────────────────────────
@export var pool_max_cost: int = -1        # -1 = pas de limite
@export var pool_min_cost: int = -1
@export var pool_race_filter: String = ""  # "" = toutes races. Ex: "UNDEAD", "HUMAN"
											# Séparé de race_filter, qui sert au CIBLAGE
											# (éviter toute collision si un effet a besoin des deux).

# ─── Octroi de mot-clé temporaire ou permanent (GrantKeyword) ────────────────
@export var granted_keyword: String = ""          # "TAUNT", "AEGIS", "CHARGE", "DISCIPLINE"...
@export var granted_keyword_is_human: bool = false # true si le nom ci-dessus vient de KeywordHuman.Type
# Durée gérée par le champ `duration` déjà présent plus haut.
# ⚠️ Le retrait effectif du mot-clé en fin de tour n'est PAS encore câblé côté EffectManager/TurnSystem —
# seul le champ de configuration est prêt ici.

# ─── Seuils conditionnels avec comparateur ───────────────────────────────────
# Permet "si N ou plus / N ou moins / exactement N, alors valeur ou nombre différent".
# Ex: Volée de Flèches (>=4 -> value_if_threshold), Appel aux Armes (==0 -> count_if_threshold).
@export_enum("None", "GreaterOrEqual", "LessOrEqual", "Equal") var threshold_op: String = "None"
@export var threshold_count: int = -1
@export var value_if_threshold: int = 0
@export var count_if_threshold: int = 0
# ⚠️ threshold_op / threshold_scope ne sont pas encore lus par EffectManager — à câbler
# dans _damage_all, _buff, _buff_row et la logique de SummonMinion/SummonRandom (count_if_threshold).

func get_effect_type() -> int:
	return EffectType.from_name(effect_id)

func get_target_type() -> int:
	return TargetType.from_name(target)
