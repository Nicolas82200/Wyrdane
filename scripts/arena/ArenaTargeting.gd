extends RefCounted
class_name ArenaTargeting

# Extraction statique, en lecture seule, de la logique de ciblage d'attaque du
# mode 1v1 (Battle.get_attackable_enemy_minions / Battle._can_attack_minion_target,
# voir scripts/battle/Battle.gd lignes ~661-667 et ~811-816). Ne modifie pas
# Battle.gd : nouveau fichier, même comportement, réutilisable en combat simulé.
#
# "Rempart" (README) correspond au mot-clé Keyword.Type.TAUNT dans le code
# (confirmé via translations/game.csv : KW_TAUNT_NAME -> "Rempart").

static func get_attackable_minions(attacker: Minion, enemy_minions: Array[Minion]) -> Array[Minion]:
	var alive: Array[Minion] = enemy_minions.filter(func(m: Minion): return not m.is_dead())
	if attacker and attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return alive
	var front: Array[Minion] = alive.filter(func(m: Minion): return m.board_row == "Front")
	if not front.is_empty():
		return front
	return alive

static func has_enemy_taunt(attacker: Minion, enemy_minions: Array[Minion]) -> bool:
	for minion in get_attackable_minions(attacker, enemy_minions):
		if minion.has_keyword(Keyword.Type.TAUNT):
			return true
	return false

static func can_attack_target(attacker: Minion, target: Minion, enemy_minions: Array[Minion]) -> bool:
	if target not in get_attackable_minions(attacker, enemy_minions):
		return false
	if has_enemy_taunt(attacker, enemy_minions) and not target.has_keyword(Keyword.Type.TAUNT):
		return false
	return true

# Choisit une cible pour `attacker` parmi `enemy_minions` : Rempart en
# priorité s'il y en a un dans les cibles attaquables, sinon aléatoire parmi
# les cibles attaquables (Avant s'il en reste, Arrière seulement si l'Avant
# ennemi est entièrement vide).
static func pick_target(attacker: Minion, enemy_minions: Array[Minion], rng: RandomNumberGenerator = null) -> Minion:
	var attackable: Array[Minion] = get_attackable_minions(attacker, enemy_minions)
	if attackable.is_empty():
		return null
	var taunts: Array[Minion] = attackable.filter(func(m: Minion): return m.has_keyword(Keyword.Type.TAUNT))
	var candidates: Array[Minion] = taunts if not taunts.is_empty() else attackable
	if rng == null:
		return candidates[0]
	return candidates[rng.randi() % candidates.size()]
