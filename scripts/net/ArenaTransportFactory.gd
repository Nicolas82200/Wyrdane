extends RefCounted
class_name ArenaTransportFactory

# Choisit l'implémentation de transport réseau Arena à utiliser — même rôle
# que TransportFactory.gd pour le 1v1, gardé séparé (voir ArenaNetTransport).

enum Backend { STEAM }

static func create(_backend: Backend = Backend.STEAM) -> ArenaNetTransport:
	# La disponibilité réelle (extension + client Steam lancé) est vérifiée
	# par ArenaSteamTransport.host()/join() → ERR_UNAVAILABLE.
	return ArenaSteamTransport.new()
