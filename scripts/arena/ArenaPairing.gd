extends RefCounted
class_name ArenaPairing

# Appariement Arena avec cooldown anti-répétition (README « Anti-répétition
# d'appariement ») et Ghost Board (README « Ghost Board »). `participants`
# peut contenir des ArenaPlayerState et, à effectif impair, un GhostBoard
# unique — le fantôme est traité comme un participant à part entière pour le
# calcul du cooldown, sous une clé stable "GHOST" (peu importe de quel joueur
# éliminé il provient, un seul fantôme est actif à la fois).
#
# `history` est un Dictionary partagé, muté en place : clé "keyA|keyB" (triée)
# -> dernier round où cette paire s'est affrontée.

static func compute_pairings(participants: Array, history: Dictionary, round_number: int, rng: RandomNumberGenerator = null) -> Array:
	var unpaired: Array = participants.duplicate()
	if rng != null:
		unpaired.shuffle()
	var cooldown: int = int(ArenaConstants.PAIRING_COOLDOWN_BY_PARTICIPANTS.get(unpaired.size(), 0))
	var pairs: Array = []

	while unpaired.size() > 1:
		var a = unpaired.pop_front()
		var allowed: Array = unpaired.filter(func(b): return _is_allowed(a, b, history, round_number, cooldown))
		var candidates: Array = allowed if not allowed.is_empty() else unpaired.duplicate()
		var chosen = candidates[0] if rng == null else candidates[rng.randi() % candidates.size()]
		unpaired.erase(chosen)
		pairs.append([a, chosen])
		_record(history, a, chosen, round_number)

	if unpaired.size() == 1:
		pairs.append([unpaired[0], null])  # bye : ne devrait survenir qu'en garde-fou (effectif impair sans fantôme)
	return pairs

static func _is_allowed(a, b, history: Dictionary, round_number: int, cooldown: int) -> bool:
	var last: int = _last_faced(a, b, history)
	return last < 0 or (round_number - last) >= cooldown

static func _last_faced(a, b, history: Dictionary) -> int:
	return int(history.get(_pair_key(a, b), -1))

static func _record(history: Dictionary, a, b, round_number: int) -> void:
	history[_pair_key(a, b)] = round_number

static func _pair_key(a, b) -> String:
	var keys: Array = [_participant_key(a), _participant_key(b)]
	keys.sort()
	return "%s|%s" % [keys[0], keys[1]]

static func _participant_key(p) -> String:
	if p is GhostBoard:
		return "GHOST"
	return "P%d" % p.get_instance_id()
