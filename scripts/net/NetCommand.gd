extends RefCounted
class_name NetCommand

# Vocabulaire partagé des commandes de jeu échangées entre les deux clients.
# Modèle : relais de commandes — chaque client émet ses actions (invoquer,
# attaquer, choix de tour, fin de tour) et REJOUE localement celles reçues du
# pair distant. Les commandes ne transportent que des types de base
# (String/int/Array/Dictionary) : NetworkManager les sérialise via var_to_bytes
# sans jamais désérialiser d'objets arbitraires.
#
# Une carte est désignée par son resource_path (`res://resources/cards/...tres`),
# identique sur les deux clients. Un serviteur est désigné par son net_id stable
# attribué par NetRegistry.

# ─── Types de commandes ───────────────────────────────────────────────────────
const PLAY_CARD   := "PLAY_CARD"    # invoquer un serviteur / lancer un sort
const ATTACK      := "ATTACK"       # un serviteur en attaque un autre
const ATTACK_HERO := "ATTACK_HERO"  # un serviteur attaque le héros adverse
const TURN_CHOICE := "TURN_CHOICE"  # choix de début de tour : "mana" ou "draw"
const END_TURN    := "END_TURN"     # le pair distant termine son tour
const HELLO       := "HELLO"        # handshake d'ouverture (deck, parité, seed)

# ─── Marqueurs de cible ───────────────────────────────────────────────────────
const TARGET_NONE := 0   # aucune cible (net_id 0 = non enregistré)

# ─── Constructeurs ────────────────────────────────────────────────────────────

# net_id : id que l'émetteur a attribué au serviteur invoqué (0 pour un sort ou
# quand la carte ne crée pas de serviteur). Le pair distant crée le serviteur
# miroir avec CE MÊME id (NetRegistry.register_with_id) pour rester synchronisé.
static func play_card(card_path: String, row: String, insert_index: int,
		net_id: int = TARGET_NONE, target_net_id: int = TARGET_NONE) -> Dictionary:
	return {
		"type": PLAY_CARD,
		"card": card_path,
		"row": row,
		"index": insert_index,
		"net_id": net_id,
		"target": target_net_id,
	}

static func attack(attacker_net_id: int, defender_net_id: int) -> Dictionary:
	return {"type": ATTACK, "attacker": attacker_net_id, "defender": defender_net_id}

static func attack_hero(attacker_net_id: int) -> Dictionary:
	return {"type": ATTACK_HERO, "attacker": attacker_net_id}

static func turn_choice(choice: String) -> Dictionary:
	return {"type": TURN_CHOICE, "choice": choice}

static func end_turn() -> Dictionary:
	return {"type": END_TURN}

# deck_paths : liste des resource_path des cartes du deck local, dans l'ordre
# déjà mélangé. start_id/stride : parité d'ids réseau du pair (voir NetRegistry).
# seed : graine RNG partagée pour que les tirages aléatoires soient identiques.
static func hello(deck_paths: Array, start_id: int, stride: int, seed: int) -> Dictionary:
	return {
		"type": HELLO,
		"deck": deck_paths,
		"start_id": start_id,
		"stride": stride,
		"seed": seed,
	}

# ─── Lecture ──────────────────────────────────────────────────────────────────

static func type_of(command: Dictionary) -> String:
	return command.get("type", "")

static func is_valid(command: Variant) -> bool:
	return command is Dictionary and command.has("type") and command["type"] is String
