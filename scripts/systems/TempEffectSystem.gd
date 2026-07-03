extends RefCounted
class_name TempEffectSystem

# Gère les effets à durée limitée (CardEffect.duration != "Permanent") :
# buffs/debuffs de stats et mots-clés octroyés, retirés automatiquement
# à la fin du tour du joueur ("UntilEndOfTurn") ou à la fin du tour
# adverse ("UntilEndOfEnemyTurn").

var battle
var _entries: Array[Dictionary] = []

func init(_battle) -> void:
	battle = _battle

# ─── Enregistrement ───────────────────────────────────────────────────────────

func add_temp_stat_change(minion: Minion, attack_delta: int, health_delta: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":         "stats",
		"minion":       minion,
		"attack_delta": attack_delta,
		"health_delta": health_delta,
		"duration":     duration,
	})

func add_temp_keyword(minion: Minion, keyword: int, is_human: bool, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "keyword",
		"minion":   minion,
		"keyword":  keyword,
		"is_human": is_human,
		"duration": duration,
	})

# ─── Expiration ───────────────────────────────────────────────────────────────

func expire_end_of_player_turn() -> void:
	_expire("UntilEndOfTurn")

func expire_end_of_enemy_turn() -> void:
	_expire("UntilEndOfEnemyTurn")

func _expire(duration: String) -> void:
	var remaining: Array[Dictionary] = []
	for entry in _entries:
		if entry["duration"] != duration:
			remaining.append(entry)
			continue
		_revert(entry)
	_entries = remaining
	battle.board_visual_system.refresh_board()

func _revert(entry: Dictionary) -> void:
	var minion: Minion = entry["minion"]
	if minion == null or minion.is_dead() or not _is_on_board(minion):
		return
	match entry["kind"]:
		"stats":
			minion.base_attack     -= entry["attack_delta"]
			minion.base_max_health -= entry["health_delta"]
		"keyword":
			if entry["is_human"]:
				minion.remove_human_keyword(entry["keyword"])
			else:
				minion.remove_keyword(entry["keyword"])

func _is_on_board(minion: Minion) -> bool:
	return minion in battle.player_minions or minion in battle.enemy_minions
