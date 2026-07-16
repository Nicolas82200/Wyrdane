extends RefCounted
class_name TransportFactory

# Choisit l'implémentation de transport à utiliser. Seul le backend Steam
# (lobby + P2P Steamworks via GodotSteam — voir SteamService pour la
# détection de l'extension et les instructions d'installation) est disponible ;
# l'énum reste en place pour permettre l'ajout d'un futur backend sans
# changer la signature des appelants (NetworkManager, NetLobby).

enum Backend { STEAM }

static func create(_backend: Backend = Backend.STEAM) -> NetTransport:
	# La disponibilité réelle (extension + client Steam lancé) est vérifiée
	# par SteamTransport.host()/join() → ERR_UNAVAILABLE.
	return SteamTransport.new()
