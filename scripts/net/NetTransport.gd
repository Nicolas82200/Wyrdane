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

# Tentative de reconnexion après une coupure transitoire (même pair visé) —
# appelée uniquement côté rejoignant (l'hôte reste passif : son socket
# d'écoute accepte déjà une nouvelle connexion entrante sans action requise).
# Par défaut, retente join() avec les mêmes params ; un backend peut
# spécialiser pour cibler directement le pair déjà identifié (voir
# SteamTransport, qui évite de relancer une recherche de lobby).
func try_reconnect(params: Dictionary) -> int:
	return join(params)

# Envoie des octets au pair distant. reliable = livraison garantie + ordonnée.
func send(_bytes: PackedByteArray, _reliable: bool = true) -> void:
	push_error("NetTransport.send() non implémenté")

# À appeler chaque frame : pompe les paquets entrants et émet les signaux.
func poll() -> void:
	pass

# Ferme proprement la session.
func close() -> void:
	pass

# Ouvre l'UI d'invitation d'amis du backend, si applicable (no-op sinon —
# seul SteamTransport l'implémente, via l'overlay Steam).
func invite_friends() -> void:
	pass
