extends RefCounted
class_name TutorialDeck

# Cartes fixes du tutoriel obligatoire (voir TutorialManager) : un deck
# Mort-Vivant simple et déterministe, choisi pour que chaque mécanique de base
# (ressource, serviteur, rangée/Rempart, attaque, sort ciblé, enchantement,
# trigger Invocation) soit démontrée dans un ordre prévisible. Les coûts sont
# choisis pour correspondre exactement au mana disponible au moment où le
# script les demande (voir TutorialManager.run()) : ne pas réordonner sans
# revérifier le budget de mana par tour. Murmure Funeste (coût 1) est joué au
# tour 3 avec le mana restant après Souffle Nécrotique (3 max - 2 = 1) : ne
# pas la déplacer sans un tour disposant d'au moins 1 mana libre.

const RESOURCE       := "res://resources/cards/undead/soul-shard.tres"
const ZOMBIE         := "res://resources/cards/undead/zombie.tres"
const WANDERING_CORPSE := "res://resources/cards/undead/wandering-corpse.tres"
const NECROTIC_BREATH := "res://resources/cards/undead/necrotic-breath.tres"
const DOOMED_WHISPER  := "res://resources/cards/undead/doomed-whisper.tres"
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

static func doomed_whisper_card() -> CardData:
	return load(DOOMED_WHISPER) as CardData

static func gaunt_servant_card() -> CardData:
	return load(GAUNT_SERVANT) as CardData

static func enemy_zombie_card() -> CardData:
	return load(ENEMY_ZOMBIE) as CardData

static func enemy_pestilent_card() -> CardData:
	return load(ENEMY_PESTILENT) as CardData

# Le mulligan (voir TurnSystem.run_mulligan) est activé pendant le tutoriel pour
# enseigner ce système, mais chaque carte de la main de départ (hors Éclat
# d'Âme, présent en 3 exemplaires) est requise telle quelle par une étape
# précise du script (voir TutorialManager.run()) : l'échanger la ferait
# attendre indéfiniment une carte qui n'est plus en main. Seules les cartes-
# ressource (interchangeables entre elles) restent réellement échangeables ;
# les autres clics du mulligan sont ignorés (voir TurnSystem._on_mulligan_card_clicked).
static func is_swappable_during_tutorial(card: CardData) -> bool:
	return card != null and card.resource_path == RESOURCE

# Main de départ du joueur. Les 3 exemplaires de Chair sont groupés
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
		doomed_whisper_card(),
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
