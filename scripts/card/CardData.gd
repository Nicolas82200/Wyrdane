extends Resource
class_name CardData

@export var card_name: String
@export var description: String
@export var texture: Texture2D
@export var cost: int = 1


@export var race: Race.Type = Race.Type.UNDEAD
@export var unit_style: UnitStyle.Type = UnitStyle.Type.ZOMBIE  # ← ici
@export_enum("Minion", "Instant", "Ritual", "Enchantment") var card_type: String = "Minion"

@export var attack: int = 0
@export var health: int = 0

@export var keywords: Array[KeywordChoice] = []
@export var trigger_types: Array[TriggerTypeChoice] = []
@export var effects: Array[CardEffect] = []
@export var requires_target: bool = false

@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export_enum("Front", "Back", "Hybrid") var board_position: String = "Front"

func get_keyword_values() -> Array[int]:
	var values: Array[int] = []
	for kw in keywords:
		values.append(kw.keyword_type)
	return values

func get_trigger_names() -> Array[String]:
	var names: Array[String] = []
	for trigger in trigger_types:
		names.append(trigger.type)
	return names

func get_trigger_types_as_enum() -> Array[int]:
	var enum_types: Array[int] = []
	for trigger in trigger_types:
		enum_types.append(TriggerType.from_name(trigger.type))
	return enum_types
