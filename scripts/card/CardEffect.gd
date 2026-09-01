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
	"SacrificeAlly", "GrantCounterOffensive", "ProtectFrontLine",
	"GainMana", "DrawCardDiscount",
	"AuraSpellCostReduction", "AuraFirstOfRaceCostReduction",
	"DestroyRandomEnchantment",
	"AuraBuffRow", "AuraBuffPerAllyInRow",
	"Corrupt", "StealHealthFromHero", "BlockSelfDamage",
	"PreventEnemyHeroHeal", "CancelSpellOnRaceTarget",
	"SacrificeDrawPerVictim", "StealMinionThenDestroy",
	"AuraSelfDamageReduction", "GrantSpellImmunity", "GroupAttackImmediate", "DestroyEnchantment",
	"ApplyMutation", "GrantKeywordAdjacent", "AbsorbAdjacentStats", "CopyAdjacentKeyword",
	"DrawCardPerAllyDeathThisTurn", "MoveRow", "MimicTarget", "CancelFirstEnemySpellPerTurn"
) var effect_id: String = "Damage"

@export_enum(
	"Self", "EnemyHero", "OwnerHero",
	"EnemyMinion", "AllyMinion", "AllEnemies",
	"AllAllies", "AllMinions", "RandomEnemy", "RandomAlly",
	"AnyMinion", "AllEnemiesFront", "AllEnemiesBack",
	"AllAlliesFront", "AllAlliesBack", "PerInfectedEnemy",
	"EnemyEnchantment", "AllyEnchantment", "AnyEnchantment",
	"TriggerSource"
) var target: String = "Self"

@export_enum("Permanent", "UntilEndOfTurn", "UntilEndOfEnemyTurn") var duration: String = "Permanent"

# Trigger d'appartenance. Vide = l'effet se déclenche pour n'importe lequel des
# trigger_types de la carte (cas général). Renseigné = l'effet n'est joué que
# pour ce trigger précis, utile aux cartes portant plusieurs déclencheurs
# distincts avec des effets différents (ex: Prêtre de Guerre, Éveil vs Dernier
# Souffle). Filtré par EffectManager.trigger_effects et le chemin enchantement.
@export var trigger: String = ""

@export var value: int = 0
@export var value_2: int = 0
# Buff uniquement : au lieu d'appliquer value/value_2 tels quels, tire au sort
# une seule fois par déclenchement entre value/0 (ATK) et 0/value_2 (PV) — ex:
# Maréchal de Campagne, "+0/+1 ou +1/+0 au hasard".
@export var random_atk_or_health: bool = false
@export var count: int = 1
@export var summon_card: CardData
@export var transform_card: CardData
@export var race_filter: String = ""
# Inverse le sens de race_filter : ne retient que les cibles qui N'appartiennent
# PAS à cette race (ex: Fléau Écarlate, "serviteurs non Démons ennemis").
@export var race_filter_exclude: bool = false
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
# Exclut les cibles de rareté Légendaire (ex: Morsure Infectieuse : "un
# serviteur ennemi non-Légendaire"). Vérifié au ciblage ET à la résolution.
@export var exclude_legendary: bool = false
# Ne retient que les cibles actuellement infectées (Brouillard Pestilentiel :
# "les serviteurs ennemis infectés perdent 1 HP supplémentaire").
@export var requires_infected_target: bool = false

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
# Inverse le test TriggerSourceRace : condition remplie si la race NE correspond
# PAS à condition_race (ex: Briseur de Horde, "si la cible n'est pas Humaine").
@export var condition_race_exclude: bool = false

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
# Abomination (SummonRandom) : nombre de mutations immédiates à appliquer au
# serviteur invoqué (0 = aucune). Ex. L'Éternel Recommencement (1), Éclosion
# Sans Fin (2).
@export var mutate_on_summon_count: int = 0

# ─── Octroi de mot-clé temporaire ou permanent (GrantKeyword) ────────────────
@export var granted_keyword: String = ""          # "TAUNT", "AEGIS", "CHARGE", "DISCIPLINE"...
@export var granted_keyword_is_human: bool = false # true si le nom ci-dessus vient de KeywordHuman.Type
@export var granted_keyword_is_demon: bool = false # true si le nom ci-dessus vient de KeywordDemon.Type
@export var granted_keyword_is_abomination: bool = false # true si le nom ci-dessus vient de KeywordAbomination.Type
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

# ─── Bonus de Pacte (mot-clé PACTE) ────────────────────────────────────────────
# Un effet marqué pact_bonus ne s'exécute que si le joueur choisit de payer le
# coût en PV du Pacte (KeywordChoiceDemon.value) au moment où ce trigger se
# déclenche — redemandé à chaque déclenchement, pas seulement à l'Arrivée (voir
# EffectManager.trigger_effects / PactChoiceSystem.resolve_trigger). Les effets
# non marqués (base) s'exécutent toujours, gratuitement.
@export var pact_bonus: bool = false
# Si vrai ET que ce bonus est payé, les effets de base du même trigger sont
# REMPLACÉS par ce bonus au lieu de s'ajouter à eux (ex: invoque un serviteur
# amélioré à la place du serviteur de base). Sans effet si pact_bonus est faux.
@export var pact_replaces_base: bool = false
