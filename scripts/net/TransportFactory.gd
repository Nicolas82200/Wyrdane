extends RefCounted
class_name TransportFactory

# Choisit l'implémentation de transport à utiliser. Aujourd'hui : ENet.
# Demain : ajouter Backend.STEAM + son implémentation, sans toucher au reste.

enum Backend { ENET, STEAM }

static func create(backend: Backend = Backend.ENET) -> NetTransport:
	match backend:
		Backend.ENET:
			return ENetTransport.new()
		Backend.STEAM:
			push_error("SteamTransport pas encore implémenté — fallback ENet")
			return ENetTransport.new()
		_:
			return ENetTransport.new()
