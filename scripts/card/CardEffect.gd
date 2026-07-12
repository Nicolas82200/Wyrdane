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
	"GrantKeyword", "AttackImmediate", "GrantExtraAttack",
	"CureInfection", "AuraInfectionImmunity", "AuraDamageReduction",
	"SacrificeAlly", "GrantCounterOffensive",
	"GainMana", "DrawCardDiscount",
	"AuraSpellCostReduction", "AuraFirstOfRaceCostReduction",
	"DestroyRandomEnchantment",
	"AuraBuffRow", "AuraBuffPerAllyInRow",
	"Corrupt", "StealHealthFromHero", "BlockSelfDamage",
	"PreventEnemyHeroHeal", "CancelSpellOnRaceTarget",
	"SacrificeDrawPerVictim", "StealMinionThenDestroy",
	"AuraSelfDamageReduction", "GrantSpellImmunity", "GroupAttackImmediate"
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

# ─── Conditions sur la cible ──────────────────────────────────────────────────
# -1 = pas de condition. Sert aux sorts du type "un serviteur ennemi de 3 HP ou
# moins" (Poigne du Cimetière) ou "ayant 2 ATK ou moins" (Jugement Divin).
# Vérifié au ciblage (TargetingSystem) ET à la résolution (EffectManager).
@export var target_max_hp: int = -1
@export var target_max_atk: int = -1
# Ne peut cibler qu'un serviteur ramené du cimetière (Minion.was_resurrected),
# ex. Brise-Mort.
@export var requires_resurrected_target: bool = false

# ─── Condition d'exécution ────────────────────────────────────────────────────
# L'effet n'est appliqué que si la condition est remplie. "None" = toujours.
#  AlliesInPlay          : nombre de serviteurs alliés en jeu
#  AlliesOfRaceInPlay    : idem filtré par condition_race
#  LegendaryAllyInPlay   : nombre d'alliés Légendaires (filtré par condition_race si non vide)
#  EnemyFrontCount       : nombre d'ennemis en rangée Avant
#  TriggerSourceLegendary: la cible/source de l'évènement (ex: allié mort) est
#                          Légendaire (filtrée par condition_race si non vide)
#  TriggerSourceRace     : la cible/source de l'évènement est de race condition_race
@export_enum("None", "AlliesInPlay", "AlliesOfRaceInPlay", "AlliesInRowInPlay", "LegendaryAllyInPlay", "EnemyFrontCount", "TriggerSourceLegendary", "TriggerSourceRace", "KeywordHumanInPlay") var condition_type: String = "None"
@export_enum("GreaterOrEqual", "LessOrEqual", "Equal") var condition_op: String = "GreaterOrEqual"
@export var condition_count: int = 1
@export var condition_race: String = ""   # "Human", "Undead"... ou "" = toutes races

# ─── Compte dynamique (SummonMinion) ──────────────────────────────────────────
# "Fixed"        : invoque `count` serviteurs.
# "PerAllyOfRace": invoque un serviteur par allié de `count_race` déjà en jeu,
#                  plafonné à `count_max` (Porte-Étendard : par Humain, max 3).
@export_enum("Fixed", "PerAllyOfRace") var count_mode: String = "Fixed"
@export var count_race: String = ""
@export var count_max: int = -1           # -1 = pas de plafond

# ─── Rangée d'invocation (SummonMinion / SummonRandom) ────────────────────────
# "Front"  : toujours en rangée Avant (comportement par défaut : la quasi-totalité
#            des cartes d'invocation précisent « en rangée Avant »).
# "Back"   : toujours en rangée Arrière.
# "Source" : dans la rangée du serviteur source (utile pour un serviteur qui
#            invoque à côté de lui). Retombe sur Avant si la source est un sort.
# Dans tous les cas, si la rangée voulue est pleine, on bascule sur l'autre.
@export_enum("Front", "Back", "Source") var summon_row: String = "Front"

# ─── Pool d'invocation aléatoire (SummonRandom) ───────────────────────────────
@export var pool_max_cost: int = -1        # -1 = pas de limite
@export var pool_min_cost: int = -1
@export var pool_race_filter: String = ""  # "" = toutes races. Ex: "UNDEAD", "HUMAN"
											# Séparé de race_filter, qui sert au CIBLAGE
											# (éviter toute collision si un effet a besoin des deux).

# ─── Octroi de mot-clé temporaire ou permanent (GrantKeyword) ────────────────
@export var granted_keyword: String = ""          # "TAUNT", "AEGIS", "CHARGE", "DISCIPLINE"...
@export var granted_keyword_is_human: bool = false # true si le nom ci-dessus vient de KeywordHuman.Type
@export var granted_keyword_is_demon: bool = false # true si le nom ci-dessus vient de KeywordDemon.Type
# Durée gérée par le champ `duration` déjà présent plus haut ;
# le retrait en fin de tour est assuré par TempEffectSystem.

# ─── Seuils conditionnels avec comparateur ───────────────────────────────────
# Permet "si N ou plus / N ou moins / exactement N, alors valeur ou nombre différent".
# Ex: Volée de Flèches (>=4 -> value_if_threshold), Appel aux Armes (==0 -> count_if_threshold).
@export_enum("None", "GreaterOrEqual", "LessOrEqual", "Equal") var threshold_op: String = "None"
@export var threshold_count: int = -1
@export var value_if_threshold: int = 0
@export var count_if_threshold: int = 0
# Le seuil est comparé au nombre de cibles résolues (Damage/DamageAll/Buff/BuffRow)
# ou, pour SummonMinion/SummonRandom, au nombre d'alliés dans la rangée d'invocation.
