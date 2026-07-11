extends Node
class_name NetTransport

# Interface de transport réseau (contrat minimal, agnostique de la techno).
# La logique de jeu ne parle QU'À cette interface : elle envoie/reçoit des
# octets bruts, sans jamais connaître ENet ni Steam. Chaque backend (ENet
# aujourd'hui, Steam plus tard) est une implémentation interchangeable.
#
# Règle d'or : aucun type spécifique au backend (peer_id ENet, SteamID...) ne
# doit fuiter hors de son implémentation. C'est ce qui rend le swap indolore.

const DEFAULT_PORT := 8910

# Le pair distant est connecté : on peut commencer le handshake.
signal connected()
# Des octets sont arrivés du pair distant.
signal packet_received(bytes: PackedByteArray)
# Le pair distant est parti (déconnexion volontaire ou perte de lien).
signal disconnected(reason: String)
# Trace lisible des étapes d'établissement de la connexion (diagnostic affiché
# dans le journal du lobby — voir NetLobby).
signal status(message: String)

# Héberge une session. params opaque selon le backend (ex. {"port": int}).
# Retourne OK ou un code d'erreur.
func host(_params: Dictionary) -> int:
	push_error("NetTransport.host() non implémenté")
	return ERR_UNCONFIGURED

# Rejoint une session. params opaque (ex. {"ip": String, "port": int}).
func join(_params: Dictionary) -> int:
	push_error("NetTransport.join() non implémenté")
	return ERR_UNCONFIGURED

# Envoie des octets au pair distant. reliable = livraison garantie + ordonnée.
func send(_bytes: PackedByteArray, _reliable: bool = true) -> void:
	push_error("NetTransport.send() non implémenté")

# À appeler chaque frame : pompe les paquets entrants et émet les signaux.
func poll() -> void:
	pass

# Ferme proprement la session.
func close() -> void:
	pass
