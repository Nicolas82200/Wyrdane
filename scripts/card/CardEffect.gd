extends Resource
class_name CardEffect

@export_enum(
	"Damage", "Heal", "Buff", "SummonMinion","SummonSelf",
	"DrawCard", "Destroy", "Silence", "Transform", "StealHealth",
	"DamageEnemy", "DamageEnemyHero", "DamageAll", "DamageAllEnemies",
	"BuffAlly", "BuffAllAllies", "DestroyMinion", "TransformEnemy",
	"HealHero", "ReturnToHand", "InfectEnemy"
) var effect_id: String = "Damage"

@export_enum(
	"Self", "EnemyHero", "OwnerHero",
	"EnemyMinion", "AllyMinion", "AllEnemies",
	"AllAllies", "AllMinions", "RandomEnemy", "RandomAlly", "AnyMinion"
) var target: String = "EnemyHero"

@export var value: int = 0
@export var value_2: int = 0
@export var count: int = 1
@export var summon_card: CardData
@export var transform_card: CardData
@export var race_filter: String = ""
