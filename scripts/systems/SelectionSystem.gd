extends Node
class_name SelectionSystem

# ─── Déclaration puis verrouillage des attaques (façon MTG Arena) ──────────────
#
# Le joueur déclare une à une des paires (attaquant, cible) SANS qu'aucune ne
# se résolve immédiatement — la carte peut continuer d'être jouée normalement
# pendant ce temps (voir `lock_attacks`, seul point qui déclenche vraiment les
# dégâts). Chaque paire est { attacker: Minion, attacker_board, target: Minion
# ou null, target_is_hero: bool }. Un même attaquant peut apparaître dans
# plusieurs paires tant qu'il lui reste des charges d'attaque déclarables
# (FRÉNÉSIE : 2 attaques), voir `_declared_count_for`.
#
# Revalidation : `lock_attacks` réévalue CHAQUE paire juste avant de la
# résoudre (attaquant toujours vivant/capable d'attaquer, cible toujours
# vivante, règle REMPART toujours respectée) — une mort survenue plus tôt dans
# la même séquence de verrouillage (ex: le REMPART ciblé par une paire meurt
# lors d'une paire précédente) fait sauter silencieusement la paire suivante
# sans jamais planter.

var battle

var declared_pairs: Array[Dictionary] = []
var pending_attacker: Minion = null
var pending_attacker_board: BoardMinion = null
var is_locking: bool = false

# Boards dont la surbrillance a été activée par ce système, pour pouvoir
# l'éteindre proprement dès qu'ils ne sont plus pending ni déclarés.
var _highlighted_boards: Array = []

func init(_battle) -> void:
	battle = _battle

# ─── Sélection joueur (déclaration d'une paire) ────────────────────────────────

func on_player_minion_clicked(minion: Minion, board_minion: BoardMinion) -> void:
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active or not minion.can_attack():
		return
	# Clic destiné au ciblage (sort/effet) ou au choix d'une victime de
	# Sacrifice/FUSION : pas une sélection d'attaquant.
	if battle.targeting_system.is_targeting() or battle.sacrifice_system.is_active() \
			or battle.fusion_system.is_active():
		return

	if minion == pending_attacker:
		# Re-clic sur l'attaquant en attente d'une cible : annule cette sélection.
		clear_pending()
		return

	var declared_count := _declared_count_for(minion)
	if declared_count > 0 and declared_count >= minion.attacks_remaining:
		# Toutes les charges d'attaque de ce serviteur sont déjà déclarées :
		# re-cliquer dessus retire la dernière paire déclarée le concernant
		# (façon d'annuler une déclaration avant verrouillage).
		_remove_last_pair_for(minion)
		return

	pending_attacker       = minion
	pending_attacker_board = board_minion
	_refresh_highlights()

# ─── Attaque ennemie (cible de la paire en cours de déclaration) ───────────────

func on_enemy_minion_clicked(target: Minion, _board_minion: BoardMinion) -> void:
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active:
		return
	if pending_attacker == null:
		return
	if not battle._can_attack_minion_target(pending_attacker, target):
		return
	declared_pairs.append({
		"attacker": pending_attacker,
		"attacker_board": pending_attacker_board,
		"target": target,
		"target_is_hero": false,
	})
	clear_pending()

func on_enemy_hero_clicked() -> void:
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active:
		return
	if pending_attacker == null:
		return
	if not battle._can_attack_hero(pending_attacker):
		return
	declared_pairs.append({
		"attacker": pending_attacker,
		"attacker_board": pending_attacker_board,
		"target": null,
		"target_is_hero": true,
	})
	clear_pending()

# ─── Verrouillage (résolution séquentielle des paires déclarées) ──────────────

func has_declared_attacks() -> bool:
	return not declared_pairs.is_empty()

func lock_attacks() -> void:
	if is_locking or declared_pairs.is_empty():
		return
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active:
		return

	is_locking = true
	var pairs := declared_pairs.duplicate()
	declared_pairs.clear()
	pending_attacker       = null
	pending_attacker_board = null
	_refresh_highlights()

	for pair in pairs:
		var attacker: Minion = pair.get("attacker")
		# Revalidation de l'attaquant : peut être mort ou avoir épuisé ses
		# charges d'attaque à cause d'une paire précédente de ce même batch
		# (ex: FRÉNÉSIE dont la 1ère attaque a été fatale à l'attaquant).
		if attacker == null or attacker.is_dead() or not attacker.can_attack():
			continue
		if pair.get("target_is_hero", false):
			if not battle._can_attack_hero(attacker):
				continue
			await battle.combat_system.perform_hero_attack(attacker)
			battle.check_game_end()
			battle.board_visual_system.refresh_board()
		else:
			var target: Minion = pair.get("target")
			# Revalidation de la cible : peut être morte entre-temps (une
			# paire précédente l'a tuée) ou ne plus être une cible légale
			# (ex: un REMPART est apparu/mort, changeant la priorité de rangée).
			if target == null or target.is_dead():
				continue
			if not battle._can_attack_minion_target(attacker, target):
				continue
			await battle.combat_system.resolve_combat(attacker, target)
		if battle.tutorial_manager:
			await battle.tutorial_manager.notify_combat()
		await battle.get_tree().create_timer(0.3).timeout

	is_locking = false
	await battle.check_auto_pass_turn()

# ─── Déclaration : requêtes internes ───────────────────────────────────────────

func _declared_count_for(attacker: Minion) -> int:
	var count := 0
	for pair in declared_pairs:
		if pair.get("attacker") == attacker:
			count += 1
	return count

func _remove_last_pair_for(attacker: Minion) -> void:
	for i in range(declared_pairs.size() - 1, -1, -1):
		if declared_pairs[i].get("attacker") == attacker:
			declared_pairs.remove_at(i)
			break
	_refresh_highlights()

# ─── Surbrillance ───────────────────────────────────────────────────────────────
# Orange (multi=true) : attaquant en attente d'une cible pour sa paire en cours.
# Doré (multi=false)  : attaquant déjà affecté à au moins une paire déclarée.

func _refresh_highlights() -> void:
	var boards_needed: Dictionary = {}
	for pair in declared_pairs:
		var b = pair.get("attacker_board")
		if b != null and is_instance_valid(b):
			if not boards_needed.has(b):
				boards_needed[b] = false
	if pending_attacker_board != null and is_instance_valid(pending_attacker_board):
		boards_needed[pending_attacker_board] = true

	for b in _highlighted_boards:
		if is_instance_valid(b) and not boards_needed.has(b):
			b.set_selected(false)
	for b in boards_needed.keys():
		b.set_selected(true, boards_needed[b])
	_highlighted_boards = boards_needed.keys()

	if battle.has_method("_refresh_lock_attacks_button"):
		battle._refresh_lock_attacks_button()

# ─── Clear ────────────────────────────────────────────────────────────────────

func clear_pending() -> void:
	pending_attacker       = null
	pending_attacker_board = null
	_refresh_highlights()

# Annule toute déclaration en cours (pending + paires non verrouillées), ex:
# à la fin du tour ou quand un autre contexte de clic prend la main (ciblage,
# sacrifice...). Ne touche pas à une résolution déjà en cours (`is_locking`).
func clear_selection() -> void:
	declared_pairs.clear()
	pending_attacker       = null
	pending_attacker_board = null
	_refresh_highlights()

func _sort_attackers_left_to_right(attackers: Array[Minion]) -> Array[Minion]:
	var sorted: Array[Minion] = attackers.duplicate()
	sorted.sort_custom(func(a, b): return battle.player_minions.find(a) < battle.player_minions.find(b))
	return sorted
