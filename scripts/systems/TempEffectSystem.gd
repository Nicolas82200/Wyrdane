extends RefCounted
class_name TempEffectSystem

# Gère les effets à durée limitée (CardEffect.duration != "Permanent") :
# buffs/debuffs de stats et mots-clés octroyés, retirés automatiquement
# à la fin du tour du joueur ("UntilEndOfTurn") ou à la fin du tour
# adverse ("UntilEndOfEnemyTurn").
#
# Provenance ("created_locally") : ces deux durées sont relatives au tour
# PENDANT LEQUEL l'effet a été créé, pas à qui le lance ni à qui il cible —
# "UntilEndOfTurn" expire à la fin de CE tour-là, "UntilEndOfEnemyTurn" à la
# fin du tour adverse SUIVANT. Or seul le joueur LOCAL passe par
# TurnSystem.end_turn() pour finir son tour ; le tour de l'IA/de l'adversaire
# réseau se termine à l'intérieur d'AISystem.take_turn()/NetworkOpponent.take_turn()
# (voir run_turn_end_triggers(false) dans ces deux fichiers). Sans savoir quel
# camp jouait quand l'effet a été créé, il est impossible de le purger au bon
# moment des deux côtés : un effet "UntilEndOfTurn" créé pendant le tour
# adverse ne doit PAS attendre la fin du tour local suivant pour disparaître
# (bug confirmé en partie réelle : Sergent de Troupe posé par l'adversaire
# réseau restait actif un tour entier de trop). `created_locally` capture
# `not battle.enemy_turn_active` au moment de l'ajout (fiable : ce flag est
# vrai pendant toute la durée de OpponentDriver.take_turn(), IA comme réseau)
# pour que les 4 combinaisons (durée × provenance) purgent chacune au bon
# moment — voir les 4 fonctions d'expiration plus bas.

var battle
var _entries: Array[Dictionary] = []

func init(_battle) -> void:
	battle = _battle

# ─── Enregistrement ───────────────────────────────────────────────────────────

func _created_locally() -> bool:
	return battle == null or not battle.enemy_turn_active

func add_temp_stat_change(minion: Minion, attack_delta: int, health_delta: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":         "stats",
		"minion":       minion,
		"attack_delta": attack_delta,
		"health_delta": health_delta,
		"duration":     duration,
		"created_locally": _created_locally(),
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
		"created_locally": _created_locally(),
	})

func add_temp_spell_immunity(minion: Minion, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "spell_immunity",
		"minion":   minion,
		"duration": duration,
		"created_locally": _created_locally(),
	})

func add_temp_demon_keyword(minion: Minion, keyword: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "keyword_demon",
		"minion":   minion,
		"keyword":  keyword,
		"duration": duration,
		"created_locally": _created_locally(),
	})

func add_temp_abomination_keyword(minion: Minion, keyword: int, duration: String) -> void:
	if duration == "Permanent" or minion == null:
		return
	_entries.append({
		"kind":     "keyword_abomination",
		"minion":   minion,
		"keyword":  keyword,
		"duration": duration,
		"created_locally": _created_locally(),
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
		"created_locally": _created_locally(),
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
		"created_locally": _created_locally(),
	})

# ─── Lecture (affichage) ───────────────────────────────────────────────────────

# Somme des deltas de stats temporaires actuellement actifs sur ce serviteur.
# Utilisé par BoardMinion pour distinguer un debuff temporaire (orange) d'un
# debuff permanent (rouge) alors que les deux modifient base_attack/base_max_health.
func get_temp_stat_delta(minion: Minion) -> Vector2i:
	var attack_delta := 0
	var health_delta := 0
	for entry in _entries:
		if entry["kind"] == "stats" and entry["minion"] == minion:
			attack_delta += entry["attack_delta"]
			health_delta += entry["health_delta"]
	return Vector2i(attack_delta, health_delta)

# ─── Expiration ───────────────────────────────────────────────────────────────
# 4 combinaisons (durée × provenance), chacune purgée au bon moment :
#  - "UntilEndOfTurn"      + créé localement : à la fin de NOTRE tour (le tour
#    pendant lequel l'effet a été créé) — TurnSystem.end_turn(), avant l'envoi
#    de END_TURN.
#  - "UntilEndOfTurn"      + créé à distance : à la fin du tour ADVERSE (IA ou
#    réseau) — appelé depuis AISystem.take_turn()/NetworkOpponent.take_turn()
#    au moment de leur END_TURN.
#  - "UntilEndOfEnemyTurn" + créé localement : à la fin du tour adverse SUIVANT
#    (celui qui vient de se jouer) — TurnSystem.end_turn(), juste après
#    opponent.take_turn().
#  - "UntilEndOfEnemyTurn" + créé à distance : à la fin de NOTRE tour SUIVANT
#    (le "tour adverse" du point de vue de qui a créé l'effet) — même moment
#    que le premier cas, donc regroupé avec lui dans expire_end_of_local_turn().

# À appeler quand NOTRE propre tour se termine (TurnSystem.end_turn()).
func expire_end_of_local_turn() -> void:
	await _expire("UntilEndOfTurn", true)
	await _expire("UntilEndOfEnemyTurn", false)

# À appeler quand le tour ADVERSE (IA ou réseau) se termine, depuis
# l'intérieur même de son take_turn() — symétrique à expire_end_of_local_turn
# pour le camp qui ne passe jamais par TurnSystem.end_turn().
func expire_end_of_remote_turn() -> void:
	await _expire("UntilEndOfTurn", false)

# À appeler juste après que opponent.take_turn() soit revenu (le tour adverse
# qui vient de se jouer était le "tour adverse suivant" d'effets créés
# pendant NOTRE tour précédent).
func expire_after_remote_turn() -> void:
	await _expire("UntilEndOfEnemyTurn", true)

func _expire(duration: String, created_locally: bool) -> void:
	var remaining: Array[Dictionary] = []
	var needs_death_processing := false
	for entry in _entries:
		if entry["duration"] != duration or entry.get("created_locally", true) != created_locally:
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
