extends RefCounted
class_name SteamP2PGuard

# Vérifications de sécurité P2P Steam partagées entre SteamTransport (1v1,
# exactement 2 pairs) et ArenaSteamTransport (Arena, jusqu'à
# ArenaConstants.PARTICIPANT_COUNT - 1 pairs en topologie étoile) — voir
# SteamTransport._on_network_connection_status_changed pour le contexte
# d'origine : un lobby PUBLIC expose son propriétaire (et son SteamID) à
# quiconque liste les lobbies "wyrdane"/"wyrdane-arena" sans jamais le
# rejoindre, donc une connexion P2P entrante doit toujours être vérifiée
# contre l'appartenance RÉELLE au lobby au moment de la connexion — jamais
# seulement contre un identifiant mémorisé plus tôt par un flux Steam
# asynchrone indépendant (lobby_chat_update), qui n'a aucune garantie
# d'ordre avec l'évènement de connexion P2P lui-même.
#
# Fonctions pures (pas d'état) : `steam` est le singleton Steam dynamique
# (voir SteamService), jamais importé statiquement ici.

static func is_lobby_member(steam: Object, lobby_id: int, steam_id: int) -> bool:
	if lobby_id == 0:
		return false
	var count: int = steam.getNumLobbyMembers(lobby_id)
	for i in count:
		if steam.getLobbyMemberByIndex(lobby_id, i) == steam_id:
			return true
	return false

# L'identité dans le dictionnaire "connection" (network_connection_status_changed)
# peut être un SteamID64 brut ou un dictionnaire selon la version de
# GodotSteam — gère les deux formes.
static func extract_remote_id(connection: Dictionary) -> int:
	var identity: Variant = connection.get("identity", 0)
	if identity is Dictionary:
		return int(identity.get("steam_id", identity.get("steamid", 0)))
	return int(identity)
