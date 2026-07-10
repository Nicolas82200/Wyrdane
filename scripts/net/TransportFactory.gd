extends RefCounted
class_name TransportFactory

# Choisit l'implémentation de transport à utiliser : ENet (IP directe / LAN)
# ou Steam (lobby + P2P Steamworks via GodotSteam — voir SteamService pour la
# détection de l'extension et les instructions d'installation).

enum Backend { ENET, STEAM }

static func create(backend: Backend = Backend.ENET) -> NetTransport:
	match backend:
		Backend.ENET:
			return ENetTransport.new()
		Backend.STEAM:
			# La disponibilité réelle (extension + client Steam lancé) est
			# vérifiée par SteamTransport.host()/join() → ERR_UNAVAILABLE.
			return SteamTransport.new()
		_:
			return ENetTransport.new()
