extends Resource
class_name CardData

@export var card_name: String
@export var description: String
@export var texture: Texture2D
@export var cost: int = 1

@export var race: Race.Type = Race.Type.UNDEAD

@export_enum("Minion", "Instant", "Ritual", "Enchantment") var card_type: String = "Minion"

@export var attack: int = 0
@export var health: int = 0

@export var keywords: Array[int] = []
@export var trigger_types: Array[String] = []
@export var effects: Array[CardEffect] = []
@export var requires_target: bool = false

@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: String = "Common"
