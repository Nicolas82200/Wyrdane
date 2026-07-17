extends RefCounted
class_name TutorialDeck

# Cartes fixes du tutoriel obligatoire (voir TutorialManager) : un deck
# Mort-Vivant simple et déterministe, choisi pour que chaque mécanique de base
# (ressource, serviteur, rangée/Rempart, attaque, sort ciblé, trigger
# Invocation) soit démontrée dans un ordre prévisible. Les coûts sont choisis
# pour correspondre exactement au mana disponible au moment où le script les
# demande (voir TutorialManager.run()) : ne pas réordonner sans revérifier le
# budget de mana par tour.

const RESOURCE       := "res://resources/cards/undead/soul-shard.tres"
const ZOMBIE         := "res://resources/cards/undead/zombie.tres"
const WANDERING_CORPSE := "res://resources/cards/undead/wandering-corpse.tres"
const NECROTIC_BREATH := "res://resources/cards/undead/necrotic-breath.tres"
const GAUNT_SERVANT   := "res://resources/cards/undead/gaunt-servant.tres"
const ENEMY_ZOMBIE    := "res://resources/cards/undead/zombie.tres"
const ENEMY_PESTILENT := "res://resources/cards/undead/pestilent-one.tres"

static func resource_card() -> CardData:
	return load(RESOURCE) as CardData

static func zombie_card() -> CardData:
	return load(ZOMBIE) as CardData

static func wandering_corpse_card() -> CardData:
	return load(WANDERING_CORPSE) as CardData

static func necrotic_breath_card() -> CardData:
	return load(NECROTIC_BREATH) as CardData

static func gaunt_servant_card() -> CardData:
	return load(GAUNT_SERVANT) as CardData

static func enemy_zombie_card() -> CardData:
	return load(ENEMY_ZOMBIE) as CardData

static func enemy_pestilent_card() -> CardData:
	return load(ENEMY_PESTILENT) as CardData

# Main de départ du joueur. Les 3 exemplaires d'Éclat d'Âme sont groupés
# côte à côte (plutôt qu'éparpillés) : TutorialManager surligne les cartes
# interchangeables en fusionnant leurs rectangles en une seule zone —
# éparpillées, cette zone s'étendrait sur toute la largeur de la main.
static func player_hand() -> Array[CardData]:
	var hand: Array[CardData] = [
		resource_card(),
		resource_card(),
		resource_card(),
		zombie_card(),
		wandering_corpse_card(),
		necrotic_breath_card(),
		gaunt_servant_card(),
	]
	return hand

# Pioches restantes une fois la main de départ distribuée : de simples
# copies supplémentaires pour que le joueur puisse continuer à jouer
# librement une fois le script du tutoriel terminé (voir TutorialManager).
static func player_deck_padding() -> Array[CardData]:
	var deck: Array[CardData] = []
	for i in range(4):
		deck.append(zombie_card())
	for i in range(2):
		deck.append(wandering_corpse_card())
	return deck
