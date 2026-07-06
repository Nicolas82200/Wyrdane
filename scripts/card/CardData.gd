extends Resource
class_name CardData

@export var card_name: String
@export var description: String
@export_multiline var flavour_text: String
@export var texture: Texture2D
@export var cost: int = 1


@export var race: Race.Type = Race.Type.UNDEAD
@export var unit_style: UnitStyle.Type = UnitStyle.Type.ZOMBIE  
@export_enum("Minion", "Instant", "Ritual", "Enchantment") var card_type: String = "Minion"
# Rituels uniquement : nombre de tours actifs (0 = instantané, -1 = permanent)
@export var ritual_duration: int = 0

@export var attack: int = 0
@export var health: int = 0

# Réduction de dégâts inhérente : chaque source de dégâts subie est réduite de
# cette valeur, sans jamais descendre sous 1 (Défenseur Juré, Zombie Bouclier).
@export var damage_reduction: int = 0
# Immunité au débordement (RAVAGE) : quand ce serviteur défend et meurt, les
# dégâts excédentaires ne sont PAS reportés sur le héros (Colosse Décomposé).
@export var blocks_overkill: bool = false

@export var keywords: Array[KeywordChoice] = []
@export var human_keywords: Array[KeywordChoiceHuman] = []
@export var undead_keywords: Array[KeywordChoiceUndead] = []
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

func get_human_keyword_values() -> Array[int]:
	var values: Array[int] = []
	for kw in human_keywords:
		values.append(kw.keyword_type)
	return values

func get_undead_keyword_values() -> Array[int]:
	var values: Array[int] = []
	for kw in undead_keywords:
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
