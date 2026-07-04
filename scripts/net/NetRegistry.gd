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

# À appeler en début de partie réseau pour fixer la parité locale.
func configure(start_id: int, stride: int) -> void:
	_next_id = start_id
	_stride = stride

# Enregistre un serviteur créé localement : lui attribue le prochain id libre.
func register(minion: Minion) -> int:
	var id: int = _next_id
	_next_id += _stride
	minion.net_id = id
	_by_id[id] = minion
	return id

# Enregistre un serviteur miroir avec un id imposé (reçu du réseau).
func register_with_id(minion: Minion, id: int) -> void:
	minion.net_id = id
	_by_id[id] = minion

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
