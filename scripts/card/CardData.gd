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
# Retiré du jeu à la mort : ne rejoint pas le cimetière (Possédé Hurlant).
@export var exile_on_death: bool = false
# Tant que ce serviteur est en jeu, les dégâts que tes propres cartes infligent
# à ton héros sont annulés (Le Gardien du Pacte Brisé). Lu par HeroSystem.self_damage.
@export var blocks_self_damage: bool = false

@export var keywords: Array[KeywordChoice] = []
@export var human_keywords: Array[KeywordChoiceHuman] = []
@export var undead_keywords: Array[KeywordChoiceUndead] = []
@export var demon_keywords: Array[KeywordChoiceDemon] = []
@export var trigger_types: Array[TriggerTypeChoice] = []
@export var effects: Array[CardEffect] = []
@export var requires_target: bool = false

# ─── Coût de Sacrifice (Rituels à trigger OnSacrifice) ────────────────────────
# Nombre de serviteurs alliés à sacrifier pour activer le rituel (0 = pas de
# coût de sacrifice). Le joueur active le rituel en cliquant dessus puis en
# choisissant ses victimes (voir SacrificeSystem).
@export var sacrifice_count: int = 0
# Condition sur les victimes : HP max autorisés (-1 = pas de condition).
# Ex. Pacte Sanglant : "un serviteur allié à 2 HP ou moins".
@export var sacrifice_max_hp: int = -1

@export_enum("Common", "Rare", "Epic", "Legendary") var rarity: String = "Common"
@export_enum("Front", "Back", "Hybrid") var board_position: String = "Front"

# ─── Textes localisés ─────────────────────────────────────────────────────────
# Le texte français (nom/description/ambiance) sert de clé de traduction : il est
# résolu dans la langue courante via translations/game.csv. Si aucune traduction
# n'existe pour la locale active, TranslationServer renvoie la chaîne d'origine
# (donc le français), ce qui garde un repli naturel.
func display_name() -> String:
	return TranslationServer.translate(card_name)

func display_description() -> String:
	return TranslationServer.translate(description)

func display_flavour() -> String:
	return TranslationServer.translate(flavour_text)

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

func get_demon_keyword_values() -> Array[int]:
	var values: Array[int] = []
	for kw in demon_keywords:
		values.append(kw.keyword_type)
	return values

func get_trigger_names() -> Array[String]:
	var names: Array[String] = []
	for trigger in trigger_types:
		names.append(trigger.type)
	return names
