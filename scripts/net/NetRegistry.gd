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
# Capture (côté émetteur) : ensemble de niveaux de capture actifs, chacun
# identifié par un jeton unique plutôt qu'empilés sans identité. Deux captures
# peuvent être imbriquées (ex. un effet ONPLAY qui déclenche lui-même un combat
# capturé) OU simplement se chevaucher sans imbrication stricte (ex. deux
# attaques différentes lancées coup sur coup avant que la première ne soit
# résolue, voir CombatSystem.resolve_combat — seul le SERVITEUR attaquant est
# verrouillé pendant sa résolution, rien n'empêche un second attaquant
# différent de démarrer entre-temps) : dans les deux cas, chaque id enregistré
# est ajouté à TOUS les niveaux actifs (une capture englobante récupère aussi
# les ids créés pendant une capture imbriquée), et end_capture() retire
# précisément le niveau demandé par son jeton — jamais "le dernier ouvert" —
# pour qu'une capture qui se termine avant une autre, plus ancienne, ne lui
# vole pas son propre niveau (ce qui assignerait le mauvais net_id au mauvais
# serviteur entre les deux clients).
var _capture_levels: Dictionary = {}  # int (jeton) -> Array[int]
var _next_capture_token: int = 1

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
	for level in _capture_levels.values():
		level.append(id)
	return id

# ─── Capture (émetteur) ───────────────────────────────────────────────────────

# Retourne un jeton à conserver par l'appelant et à repasser tel quel à
# end_capture() — jamais un end_capture() "générique" qui retirerait par
# erreur le niveau d'un autre appelant encore actif (voir commentaire plus haut).
func begin_capture() -> int:
	var token: int = _next_capture_token
	_next_capture_token += 1
	# Le tableau DOIT être typé (Array[int]) dès sa création, pas seulement au
	# retour : GDScript ne convertit un Array vers Array[int] qu'à l'affectation
	# d'une variable typée, jamais à un `return` ni au stockage/relecture depuis
	# un Dictionary — un niveau créé "nu" ([]) resterait un Array générique à
	# vie même une fois relu dans une variable Array[int], et end_capture()
	# échouerait alors silencieusement à l'exécution, renvoyant [] et perdant
	# tous les ids capturés (piégé une première fois de cette façon ici).
	var level: Array[int] = []
	_capture_levels[token] = level
	return token

func end_capture(token: int) -> Array[int]:
	if not _capture_levels.has(token):
		return []
	var level: Array[int] = _capture_levels[token]
	_capture_levels.erase(token)
	return level

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
