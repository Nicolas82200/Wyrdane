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

func add_temp_spell_immunity(minion: Minion, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "spell_immunity",
		"minion":   minion,
		"duration": duration,
	})

func add_temp_demon_keyword(minion: Minion, keyword: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "keyword_demon",
		"minion":   minion,
		"keyword":  keyword,
		"duration": duration,
	})

func add_temp_abomination_keyword(minion: Minion, keyword: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "keyword_abomination",
		"minion":   minion,
		"keyword":  keyword,
		"duration": duration,
	})

# Emprise Écarlate : le serviteur (volé temporairement) est détruit à
# l'expiration de la durée, quel que soit son camp à ce moment-là.
func add_destroy_at_expiry(minion: Minion, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "destroy",
		"minion":   minion,
		"duration": duration,
	})

# Silence temporaire (Inquisiteur de Fer, L'Éternel Gardien) : capture les
# mots-clés avant qu'EffectManager ne les efface, pour les restaurer à
# l'expiration. Un Silence "Permanent" (défaut de la plupart des cartes)
# n'enregistre rien et reste donc définitif.
func add_temp_silence(minion: Minion, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":            "silence",
		"minion":          minion,
		"keywords":        minion.keywords.duplicate(),
		"human_keywords":  minion.human_keywords.duplicate(),
		"undead_keywords": minion.undead_keywords.duplicate(),
		"demon_keywords":  minion.demon_keywords.duplicate(),
		"abomination_keywords": minion.abomination_keywords.duplicate(),
		"duration":        duration,
	})

# ─── Expiration ───────────────────────────────────────────────────────────────

func expire_end_of_player_turn() -> void:
	await _expire("UntilEndOfTurn")

func expire_end_of_enemy_turn() -> void:
	await _expire("UntilEndOfEnemyTurn")

func _expire(duration: String) -> void:
	var remaining: Array[Dictionary] = []
	var needs_death_processing := false
	for entry in _entries:
		if entry["duration"] != duration:
			remaining.append(entry)
			continue
		_revert(entry)
		if entry["kind"] == "destroy":
			needs_death_processing = true
	_entries = remaining
	if needs_death_processing:
		await battle.death_system.process_deaths()
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
		"keyword_demon":
			minion.remove_demon_keyword(entry["keyword"])
		"keyword_abomination":
			minion.remove_abomination_keyword(entry["keyword"])
		"destroy":
			# La mort est résolue en batch par _expire, après tous les reverts
			minion.health = 0
		"silence":
			minion.keywords        = entry["keywords"].duplicate()
			minion.human_keywords  = entry["human_keywords"].duplicate()
			minion.undead_keywords = entry["undead_keywords"].duplicate()
			minion.demon_keywords  = entry["demon_keywords"].duplicate()
			minion.abomination_keywords = entry["abomination_keywords"].duplicate()
			minion.silenced = false
		"spell_immunity":
			minion.spell_immune = false

func _is_on_board(minion: Minion) -> bool:
	return minion in battle.player_minions or minion in battle.enemy_minions
