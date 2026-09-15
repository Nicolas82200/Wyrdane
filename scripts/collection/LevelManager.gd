# LevelManager.gd
extends Node

# Niveau de compte par XP, autoritaire côté wyrdane-backend (levelModel.ts) —
# même philosophie que CurrencyManager : pas de cache hors-ligne, seule la
# dernière sync backend fait foi. Remplace l'ancien affichage de récompense
# d'or par match classé : un match réseau (classé/partie rapide) rapporte
# désormais de l'XP de compte, pas d'or directement (voir
# MatchResultReporter._report_ranked).

# Valeur de départ affichée avant la première sync (barre de progression) ;
# la courbe réelle (croissance linéaire 100 + 10×niveau, et le multiplicateur
# d'XP de victoire par série) est appliquée et vérifiée côté serveur (voir
# xpToReachNextLevel/winXpForStreak dans
# wyrdane-backend/backend/src/model/levelModel.ts).
const XP_CURVE_BASE := 100

var level: int = 1
var xp: int = 0
var xp_to_next: int = XP_CURVE_BASE
var is_synced: bool = false

signal level_changed(level: int, xp: int, xp_to_next: int)
## Émis uniquement quand un rapport de match fait franchir un ou plusieurs
## niveaux (jamais à une simple sync) : rewards est le tableau brut renvoyé
## par le backend (chaque entrée a "level"/"type"["card"|"pack"|"gold"],
## éventuellement "card"/"dusted"/"gold" — voir levelModel.ts côté backend).
signal leveled_up(rewards: Array)

# on_complete (optionnel) est appelé avec (success: bool).
func sync_from_backend(on_complete: Callable = Callable()) -> void:
	BackendClient.get_profile(func(success: bool, data: Dictionary) -> void:
		if success and data.has("level"):
			is_synced = true
			_apply(data.get("level", {}))
		if on_complete.is_valid():
			on_complete.call(success)
	)

# Appelé par MatchResultReporter avec la réponse brute de
# POST /api/ranked/matches/report (xpGained/level/xp/xpToNext/rewards au
# premier niveau du payload, voir rankedController.reportMatch côté backend).
func apply_match_result(data: Dictionary) -> void:
	if not data.has("level"):
		return
	_apply(data)
	var rewards: Array = data.get("rewards", [])
	if not rewards.is_empty():
		leveled_up.emit(rewards)

func _apply(data: Dictionary) -> void:
	level = int(data.get("level", level))
	xp = int(data.get("xp", xp))
	xp_to_next = int(data.get("xpToNext", xp_to_next))
	level_changed.emit(level, xp, xp_to_next)
