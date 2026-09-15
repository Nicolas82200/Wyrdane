extends RefCounted
class_name FakeArenaNetHub

# Simule la topologie étoile d'ArenaSteamTransport pour les tests : un hôte et
# jusqu'à N clients (FakeArenaNetTransport), chacun identifié par son peer_id.
# Livraison SYNCHRONE (pas de poll() à simuler) : un send()/broadcast() délivre
# immédiatement — suffisant pour tester le protocole (ArenaNetHandshake) sans
# reproduire le comportement asynchrone réel de Steam Networking Sockets.

var _host: FakeArenaNetTransport = null
var _clients: Dictionary = {}  # peer_id -> FakeArenaNetTransport

func register_host(transport: FakeArenaNetTransport) -> void:
	_host = transport

# Émet peer_joined des deux côtés (hôte ET client) au moment où le client
# rejoint, comme le ferait une vraie connexion P2P établie — voir
# ArenaSteamTransport._on_network_connection_status_changed (CONN_STATE_CONNECTED).
func register_client(transport: FakeArenaNetTransport) -> void:
	_clients[transport.peer_id] = transport
	if _host != null:
		_host.peer_joined.emit(transport.peer_id, "Peer %d" % transport.peer_id)
		transport.peer_joined.emit(_host.peer_id, "Host")

func route(from: FakeArenaNetTransport, target_peer_id: int, bytes: PackedByteArray) -> void:
	if from.is_host:
		var target: FakeArenaNetTransport = _clients.get(target_peer_id, null)
		if target != null:
			target.packet_received.emit(_host.peer_id, bytes)
	elif _host != null:
		_host.packet_received.emit(from.peer_id, bytes)

func broadcast(from: FakeArenaNetTransport, bytes: PackedByteArray) -> void:
	if not from.is_host:
		return
	for client in _clients.values():
		client.packet_received.emit(from.peer_id, bytes)

func connected_peer_ids(from: FakeArenaNetTransport) -> Array[int]:
	if from.is_host:
		var ids: Array[int] = []
		for id in _clients.keys():
			ids.append(id)
		return ids
	return [_host.peer_id] if _host != null else []
