extends Node
class_name ArenaNetTransport

# Interface de transport réseau pour l'Arena (jusqu'à
# ArenaConstants.PARTICIPANT_COUNT joueurs, topologie ÉTOILE : l'hôte fait
# autorité et relaie — voir README « Réseau & Visibilité », recommandation
# "simulation centralisée : hôte calcule et diffuse le résultat").
#
# Volontairement SÉPARÉE de NetTransport.gd (1v1, exactement 2 pairs) plutôt
# que d'en hériter : les deux interfaces divergent structurellement (1 seul
# pair implicite en 1v1, contre jusqu'à 7 côté hôte Arena — `packet_received`
# doit donc identifier l'émetteur ici, jamais implicite comme en 1v1). Forcer
# les deux à partager un contrat commun aurait complexifié les deux sans
# bénéfice réel, et surtout risqué de régresser le 1v1 déjà en production. Les
# vérifications de sécurité P2P réellement communes (validation d'appartenance
# au lobby, extraction d'identité depuis la connexion Steam) sont en revanche
# factorisées dans SteamP2PGuard, réutilisé par les deux implémentations
# concrètes (SteamTransport pour le 1v1, ArenaSteamTransport ici).
#
# `peer_id` est un identifiant opaque dépendant du backend (SteamID64 pour
# ArenaSteamTransport) — jamais interprété par les couches au-dessus.

signal peer_joined(peer_id: int, display_name: String)
signal peer_left(peer_id: int, reason: String)
signal packet_received(peer_id: int, bytes: PackedByteArray)
signal status(message: String)
# Coupure définitive du transport lui-même (échec de lobby, etc.) — distinct
# de peer_left, qui ne concerne qu'un pair parmi d'autres.
signal disconnected(reason: String)
# Même rôle que NetTransport.session_ready : l'hôte connaît son propre
# lobby_id dès la création, avant qu'aucun pair ne rejoigne.
signal session_ready(session_id: int)

func host(_params: Dictionary) -> int:
	return ERR_UNAVAILABLE

func join(_params: Dictionary) -> int:
	return ERR_UNAVAILABLE

# Envoie à un pair précis. Côté hôte : peer_id désigne un client connecté.
# Côté client : peer_id est ignoré, le seul pair possible étant l'hôte.
func send(_peer_id: int, _bytes: PackedByteArray, _reliable: bool = true) -> void:
	pass

# Hôte uniquement : envoie à tous les pairs connectés.
func broadcast(_bytes: PackedByteArray, _reliable: bool = true) -> void:
	pass

func poll() -> void:
	pass

func close() -> void:
	pass

func invite_friends() -> void:
	pass

func open_add_friend_overlay(_peer_id: int) -> void:
	pass

# Pairs actuellement connectés (hôte uniquement — un client n'a qu'un seul
# pair possible, l'hôte, déjà accessible autrement).
func connected_peer_ids() -> Array[int]:
	return []
