extends ArenaNetTransport
class_name FakeArenaNetTransport

# Double de test pour ArenaNetTransport : route les paquets directement entre
# instances enregistrées auprès d'un FakeArenaNetHub partagé, sans Steam ni
# réseau réel — permet de tester ArenaNetworkManager/ArenaNetHandshake en
# pure logique (voir CLAUDE.md « Tests automatisés » : la couche réseau
# dépendante de Steam elle-même reste hors de portée d'un test unitaire, mais
# le protocole au-dessus peut l'être via un transport simulé comme celui-ci).

var hub: FakeArenaNetHub
var peer_id: int
var is_host: bool

func _init(_hub: FakeArenaNetHub, _peer_id: int, _is_host: bool) -> void:
	hub = _hub
	peer_id = _peer_id
	is_host = _is_host

func host(_params: Dictionary) -> int:
	hub.register_host(self)
	return OK

func join(_params: Dictionary) -> int:
	hub.register_client(self)
	return OK

func send(target_peer_id: int, bytes: PackedByteArray, _reliable: bool = true) -> void:
	hub.route(self, target_peer_id, bytes)

func broadcast(bytes: PackedByteArray, _reliable: bool = true) -> void:
	hub.broadcast(self, bytes)

func connected_peer_ids() -> Array[int]:
	return hub.connected_peer_ids(self)
