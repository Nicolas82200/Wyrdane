extends RefCounted
class_name ArenaHostGameRouter

# Relie le protocole de partie (ArenaGameCommand) au reste de la pile réseau,
# CÔTÉ HÔTE : écoute ArenaNetworkManager.command_received, résout le seat_id
# du peer_id émetteur (via `seat_for_peer`, typiquement
# ArenaNetHandshake.seat_for_peer une fois le handshake terminé), applique la
# REQUEST_* à l'ArenaMatch autoritaire (ArenaHostAuthority.apply) puis
# distribue les deux réponses — BOARD_SYNC diffusé à tous, PRIVATE_STATE_SYNC
# envoyé uniquement à l'émetteur.
#
# `seat_for_peer` est un Callable (func(peer_id: int) -> int) plutôt qu'une
# dépendance directe à ArenaNetHandshake : ce routeur n'a besoin de connaître
# QUE cette correspondance, jamais le reste du handshake — découplage qui
# simplifie aussi les tests (une simple lambda de dictionnaire suffit, voir
# tests/unit/test_arena_host_game_router.gd).
#
# Une commande dont le peer_id n'est pas (encore) un siège valide (handshake
# pas terminé, ou tentative usurpée) est ignorée sans erreur.

var match_: ArenaMatch
var net: ArenaNetworkManager
var seat_for_peer: Callable

func _init(_match: ArenaMatch, _net: ArenaNetworkManager, _seat_for_peer: Callable) -> void:
	match_ = _match
	net = _net
	seat_for_peer = _seat_for_peer
	net.command_received.connect(_on_command_received)

func _on_command_received(peer_id: int, command: Dictionary) -> void:
	var seat_id: int = int(seat_for_peer.call(peer_id))
	if seat_id < 0:
		return
	var result: Dictionary = ArenaHostAuthority.apply(match_, seat_id, command)
	if result.is_empty():
		return
	net.broadcast_command(result["public"])
	net.send_command(peer_id, result["private"])
