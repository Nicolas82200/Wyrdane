extends Resource
class_name CardEffect

@export_enum(
	"Damage", "Heal", "Buff", "SummonMinion", "SummonSelf",
	"DrawCard", "Destroy", "Silence", "Transform", "StealHealth",
	"HealHero", "ReturnToHand", "InfectEnemy"
) var effect_id: String = "Damage"

@export_enum(
	"Self", "EnemyHero", "OwnerHero",
	"EnemyMinion", "AllyMinion", "AllEnemies",
	"AllAllies", "AllMinions", "RandomEnemy", "RandomAlly", "AnyMinion"
) var target: String = "Self"

@export var value: int = 0
@export var value_2: int = 0
@export var count: int = 1
@export var summon_card: CardData
@export var transform_card: CardData
@export var race_filter: String = ""

func get_effect_type() -> int:
	return EffectType.from_name(effect_id)

func get_target_type() -> int:
	return TargetType.from_name(target)
