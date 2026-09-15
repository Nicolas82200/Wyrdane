extends RefCounted
class_name ArenaNetContext

# Passe-plat STATIQUE entre le lobby réseau Arena (ArenaNetLobby) et
# ArenaBattle.tscn — même rôle que NetContext pour le 1v1 : survit au
# changement de scène (`change_scene_to_file` détruit l'ancienne scène et
# tout ce qu'elle possédait, mais jamais les variables statiques).
#
# `active = false` (valeur par défaut) : ArenaBattle démarre en solo local
# exactement comme avant ce chantier réseau — zéro changement de comportement
# tant qu'on n'est jamais passé par le lobby réseau.

static var active: bool = false
static var is_host: bool = false
static var net: ArenaNetworkManager = null
# Hôte uniquement : conservé pour seat_for_peer/peer_for_seat (voir
# ArenaHostGameRouter/ArenaHostRoundSync) — jamais utilisé côté client.
static var handshake: ArenaNetHandshake = null
# Résultat d'ArenaNetHandshake.completed : {seed, seat_id, roster}.
static var setup: Dictionary = {}

static func reset() -> void:
	active = false
	is_host = false
	net = null
	handshake = null
	setup = {}
