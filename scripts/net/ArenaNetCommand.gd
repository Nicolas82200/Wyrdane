extends RefCounted
class_name ArenaNetCommand

# Vocabulaire des commandes échangées pendant le HANDSHAKE D'OUVERTURE réseau
# Arena (voir ArenaNetHandshake) — même esprit que NetCommand.gd (1v1), gardé
# séparé (voir ArenaNetTransport). Ne couvre que "qui est qui, graine RNG
# partagée, tous prêts" ; le protocole de PARTIE proprement dit (achats/
# positionnement/combat synchronisés à 8 joueurs) est un vocabulaire distinct,
# voir ArenaGameCommand.

const HELLO := "ARENA_HELLO"               # client -> hôte : nom d'affichage + contribution de graine
const SEAT_ASSIGN := "ARENA_SEAT_ASSIGN"   # hôte -> client : seat_id attribué
const START_MATCH := "ARENA_START_MATCH"   # hôte -> tous : graine finale + liste des sièges

static func hello(display_name: String, seed_contribution: int) -> Dictionary:
	return {"type": HELLO, "display_name": display_name, "seed": seed_contribution}

static func seat_assign(seat_id: int) -> Dictionary:
	return {"type": SEAT_ASSIGN, "seat_id": seat_id}

# `roster` : Array de {"seat_id": int, "display_name": String, "is_bot": bool},
# trié par seat_id (siège 0 = hôte). Un siège `is_bot` a été comblé par
# ArenaNetHandshake.force_start_with_bots() plutôt que par un vrai HELLO.
static func start_match(seed: int, roster: Array) -> Dictionary:
	return {"type": START_MATCH, "seed": seed, "roster": roster}

static func type_of(command: Dictionary) -> String:
	return str(command.get("type", ""))
