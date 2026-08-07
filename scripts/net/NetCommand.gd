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
const END_TURN    := "END_TURN"     # le pair distant termine son tour
const TURN_START  := "TURN_START"   # début du tour distant (déclencheurs Éveil…)
const ACTIVATE_RITUAL := "ACTIVATE_RITUAL"  # activation d'un Rituel de Sacrifice
const ACTIVATE_FUSION := "ACTIVATE_FUSION"  # activation volontaire du mot-clé FUSION
const HELLO       := "HELLO"        # handshake d'ouverture (deck, parité, seed)
const HELLO_ACK   := "HELLO_ACK"    # accusé de réception du HELLO du pair
const MULLIGAN_DONE := "MULLIGAN_DONE"  # le joueur local a validé son mulligan
const LEAVE_MATCH := "LEAVE_MATCH"  # départ volontaire (concède/menu) — ne PAS tenter de reconnexion
const BATTLE_READY := "BATTLE_READY"  # le handshake est fini localement, en attente du pair avant Battle.tscn

# ─── Marqueurs de cible ───────────────────────────────────────────────────────
const TARGET_NONE := 0   # aucune cible (net_id 0 = non enregistré)

# ─── Constructeurs ────────────────────────────────────────────────────────────

# ids : liste ORDONNÉE des net_id de TOUS les serviteurs créés par l'action
# (la carte elle-même puis ses jetons d'effet), telle que capturée par l'émetteur.
# Vide pour une carte qui ne crée aucun serviteur. Le pair impose ces ids dans le
# même ordre (NetRegistry.set_imposed_ids) pour rester parfaitement synchronisé.
# pact_paid : choix du joueur local d'avoir payé (ou non) le coût en PV du
# mot-clé PACTE de la carte, à rejouer tel quel côté pair (voir
# NetworkOpponent._apply_play_card et CardSystem.handle_card_played). Sans
# incidence pour une carte sans PACTE.
static func play_card(card_path: String, row: String, insert_index: int,
		ids: Array = [], target_net_id: int = TARGET_NONE, pact_paid: bool = false) -> Dictionary:
	return {
		"type": PLAY_CARD,
		"card": card_path,
		"row": row,
		"index": insert_index,
		"ids": ids,
		"target": target_net_id,
		"pact_paid": pact_paid,
	}

static func attack(attacker_net_id: int, defender_net_id: int) -> Dictionary:
	return {"type": ATTACK, "attacker": attacker_net_id, "defender": defender_net_id}

static func attack_hero(attacker_net_id: int) -> Dictionary:
	return {"type": ATTACK_HERO, "attacker": attacker_net_id}

# ids : net_id des serviteurs créés par les déclencheurs de fin de tour, à imposer
# lors du rejeu de cette phase sur le pair.
static func end_turn(ids: Array = []) -> Dictionary:
	return {"type": END_TURN, "ids": ids}

# ids : serviteurs créés par les déclencheurs de début de tour, à imposer au rejeu.
static func turn_start(ids: Array = []) -> Dictionary:
	return {"type": TURN_START, "ids": ids}

# Activation volontaire d'un Rituel de Sacrifice : le rituel est désigné par son
# resource_path, les victimes par leur net_id ; ids = serviteurs créés par
# l'effet du rituel (à imposer au rejeu).
static func activate_ritual(card_path: String, victim_ids: Array, ids: Array = []) -> Dictionary:
	return {
		"type": ACTIVATE_RITUAL,
		"card": card_path,
		"victims": victim_ids,
		"ids": ids,
	}

# Activation volontaire de FUSION : source/victime désignées par net_id, le
# mot-clé absorbé par son pool ("keywords"/"human_keywords"/"undead_keywords"/
# "demon_keywords"/"abomination_keywords") et son nom (Type.keys()[value]),
# résolu via le from_name() de l'enum correspondant.
static func activate_fusion(source_id: int, victim_id: int, keyword_pool: String, keyword_name: String) -> Dictionary:
	return {
		"type": ACTIVATE_FUSION,
		"source": source_id,
		"victim": victim_id,
		"pool": keyword_pool,
		"keyword": keyword_name,
	}

# deck_paths : liste des resource_path des cartes du deck local, dans l'ordre
# déjà mélangé. start_id/stride : parité d'ids réseau du pair (voir NetRegistry).
# seed : graine RNG partagée pour que les tirages aléatoires soient identiques.
# backend_id : id utilisateur backend local (0 si non authentifié), utilisé
# côté profil/ranked pour rapporter le résultat du match (voir NetHandshake).
static func hello(deck_paths: Array, start_id: int, stride: int, seed: int, backend_id: int = 0) -> Dictionary:
	return {
		"type": HELLO,
		"deck": deck_paths,
		"start_id": start_id,
		"stride": stride,
		"seed": seed,
		"backend_id": backend_id,
	}

# Accusé de réception du HELLO : garantit à l'émetteur que son deck est bien
# arrivé (le premier paquet P2P peut se perdre pendant l'établissement de la
# session — voir la boucle de renvoi dans NetHandshake).
static func hello_ack() -> Dictionary:
	return {"type": HELLO_ACK}

# Le contenu du mulligan (cartes gardées/remplacées) reste privé : seule la fin
# de la décision est communiquée, pour synchroniser le début du tour 1.
static func mulligan_done() -> Dictionary:
	return {"type": MULLIGAN_DONE}

# Envoyé juste avant de fermer volontairement la connexion (concède/retour au
# menu) : permet au pair de distinguer un départ délibéré d'une coupure réseau
# transitoire, et donc de ne pas attendre inutilement une reconnexion qui ne
# viendra jamais (voir NetworkManager._on_packet_received).
static func leave_match() -> Dictionary:
	return {"type": LEAVE_MATCH}

# Signale que ce client a fini le handshake et son chargement local, et
# n'attend plus que le pair pour entrer dans Battle.tscn (voir NetBattleSync).
static func battle_ready() -> Dictionary:
	return {"type": BATTLE_READY}

# ─── Lecture ──────────────────────────────────────────────────────────────────

static func type_of(command: Dictionary) -> String:
	return command.get("type", "")

static func is_valid(command: Variant) -> bool:
	return command is Dictionary and command.has("type") and command["type"] is String
