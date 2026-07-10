extends RefCounted
class_name NetRegistry

# Attribue à chaque serviteur de plateau un identifiant réseau stable et partagé,
# et permet de retrouver un Minion à partir de son id. Indispensable pour que
# "l'attaquant #7 frappe la cible #3" désigne les MÊMES serviteurs sur les deux
# clients.
#
# Partitionnement de l'espace d'ids en réseau (via configure) : chaque client
# génère les ids des serviteurs qu'IL invoque, sur une parité distincte
# (host: 2,4,6... / invité: 3,5,7...), pour éviter toute collision. En solo,
# tout est local : start=1, stride=1.

var _next_id: int = 1
var _stride: int = 1
var _by_id: Dictionary = {}  # int -> Minion

# File d'ids imposés (rejeu distant) : register() les consomme dans l'ordre au
# lieu de générer, pour que les serviteurs miroirs (carte + jetons d'effet)
# portent EXACTEMENT les mêmes ids que chez l'émetteur.
var _imposed: Array[int] = []
# Capture (côté émetteur) : liste ordonnée des ids créés par l'action en cours,
# transmise ensuite au pair pour le rejeu.
var _capturing: bool = false
var _captured: Array[int] = []

# À appeler en début de partie réseau pour fixer la parité locale.
func configure(start_id: int, stride: int) -> void:
	_next_id = start_id
	_stride = stride

# Enregistre un serviteur créé localement : lui attribue le prochain id libre,
# ou un id imposé si une file de rejeu est en cours.
func register(minion: Minion) -> int:
	var id: int
	if not _imposed.is_empty():
		id = _imposed.pop_front()
	else:
		id = _next_id
		_next_id += _stride
	minion.net_id = id
	_by_id[id] = minion
	if _capturing:
		_captured.append(id)
	return id

# ─── Capture (émetteur) ───────────────────────────────────────────────────────

func begin_capture() -> void:
	_capturing = true
	_captured = []

func end_capture() -> Array[int]:
	_capturing = false
	return _captured

# ─── Ids imposés (rejeu distant) ──────────────────────────────────────────────

func set_imposed_ids(ids: Array) -> void:
	_imposed = []
	for i in ids:
		_imposed.append(int(i))

func unregister(minion: Minion) -> void:
	if minion != null:
		_by_id.erase(minion.net_id)

# Retrouve le serviteur portant cet id, ou null s'il n'existe pas / plus.
func resolve(id: int) -> Minion:
	return _by_id.get(id, null)

func clear() -> void:
	_by_id.clear()
	_next_id = 1
	_stride = 1
