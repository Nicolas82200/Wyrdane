extends Resource
class_name CardData

## Identité
@export var card_name: String
@export var description: String
@export var texture: Texture2D
@export var cost: int = 1
## Race / Faction
@export_enum("Undead", "Human", "Elf", "Dwarf", "Demon") var race: String = "Undead"

## Type de carte
@export_enum("Minion", "Instant", "Ritual", "Enchantment") var card_type: String = "Minion"

## Stats
@export var attack: int = 0
@export var health: int = 0

## Mots-clés
@export var keywords: Array[int] = []

## Effets — plusieurs triggers possibles par carte
@export var trigger_types: Array[String] = []
@export var effects: Array[CardEffect] = []
@export var requires_target: bool = false

## Rareté
@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: String = "Common"
