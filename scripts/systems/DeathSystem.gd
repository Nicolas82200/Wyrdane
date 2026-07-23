extends RefCounted
class_name DeathSystem

var battle
var processing_deaths := false

func init(_battle) -> void:
	battle = _battle

func process_deaths(silent: Array = []) -> void:
	if processing_deaths:
		return
	processing_deaths = true
	var revived := _apply_revenant(battle.player_minions + battle.enemy_minions)
	var dead_player: Array[Minion] = battle.player_minions.filter(func(m: Minion): return m.is_dead())
	var dead_enemy:  Array[Minion] = battle.enemy_minions.filter(func(m: Minion): return m.is_dead())
	var dead_all:    Array[Minion] = []
	dead_all.append_array(dead_player)
	dead_all.append_array(dead_enemy)
	if dead_all.is_empty():
		processing_deaths = false
		# Si REVENANT a relevé un serviteur (health 0 → 1) sans qu'aucune mort ne
		# subsiste, la sortie anticipée sauterait le refresh de fin de vague : le
		# visuel resterait figé à 0 HP.
		if revived:
			battle.board_visual_system.refresh_board()
		return
	# VIRULENT (Abomination) : capture les cibles AVANT retrait du plateau, la
	# recherche d'adjacence se fait sur les listes de serviteurs encore en jeu.
	var virulent_adjacent: Array[Minion] = _collect_virulent_adjacent(dead_all)
	await _animate_deaths(dead_all, silent)
	battle.player_minions = battle.player_minions.filter(func(m: Minion): return not m.is_dead())
	battle.enemy_minions  = battle.enemy_minions.filter(func(m: Minion): return not m.is_dead())
	for dead in dead_all:
		battle.net_registry.unregister(dead)
	_send_to_graveyards(dead_player, dead_enemy)
	await _trigger_deathrattle(dead_player)
	await _trigger_deathrattle(dead_enemy)
	for adjacent in virulent_adjacent:
		if not adjacent.is_dead():
			await battle.effect_manager.roll_mutation(battle, adjacent)
	await _trigger_death_reactions(dead_player, true)
	await _trigger_death_reactions(dead_enemy, false)
	await _trigger_devoration(dead_all)
	await _trigger_sacrifice(dead_player, true)
	await _trigger_sacrifice(dead_enemy, false)
	processing_deaths = false
	battle.aura_system.recompute_all()
	battle.board_visual_system.refresh_board()
	await process_deaths()

# REVENANT : au lieu de mourir, se relève avec 1 HP — une seule fois par partie.
# Un Sacrifice volontaire consomme le serviteur normalement (pas de relève).
# Retourne true si au moins un serviteur a été relevé.
func _apply_revenant(minions: Array[Minion]) -> bool:
	var revived := false
	for minion in minions:
		if not minion.is_dead():
			continue
		if minion.sacrificed or minion.revenant_triggered:
			continue
		if not minion.has_undead_keyword(KeywordUndead.Type.REVENANT):
			continue
		minion.revenant_triggered = true
		minion.health = 1
		revived = true
		var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
		if visual:
			battle.animation_system.play_revenant(visual)
	return revived

func _animate_deaths(dead_minions: Array[Minion], silent: Array = []) -> void:
	for minion in dead_minions:
		# Les morts déjà représentées dans une entrée de log dédiée (ex : attaque
		# fusionnée attaquant/défenseur) ne dupliquent pas de ligne 💀 séparée.
		if not silent.has(minion):
			battle.combat_log.minion_died(minion)
		var visual = battle.board_visual_system.get_visual(minion)
		if visual:
			battle.animation_system.play_death(visual)
	if not dead_minions.is_empty():
		await battle.get_tree().create_timer(AnimationSystem.DEATH_ANIMATION_DURATION).timeout
	for minion in dead_minions:
		var visual = battle.board_visual_system.get_visual(minion)
		if visual and is_instance_valid(visual):
			visual.queue_free()
		battle.board_visual_system.remove_visual(minion)

func _send_to_graveyards(dead_player: Array[Minion], dead_enemy: Array[Minion]) -> void:
	# Les serviteurs "retirés du jeu" (Possédé Hurlant) ne vont pas au cimetière.
	for minion in dead_player:
		if not minion.card_data.exile_on_death:
			battle.player_graveyard.add_minion(minion.card_data)
	for minion in dead_enemy:
		if not minion.card_data.exile_on_death:
			battle.enemy_graveyard.add_minion(minion.card_data)

func _trigger_deathrattle(dead_minions: Array[Minion]) -> void:
	for minion in dead_minions:
		var target: Minion = await battle.effect_manager.resolve_trigger_target(battle, minion, "DEATHRATTLE")
		await battle.effect_manager.trigger_effects(battle, minion, "DEATHRATTLE", target)

func _trigger_death_reactions(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	if dead_minions.is_empty():
		return
	var same_camp: Array[Minion]  = battle.player_minions if dead_were_player else battle.enemy_minions
	var other_camp: Array[Minion] = battle.enemy_minions if dead_were_player else battle.player_minions

	# NÉCROPHAGE : chaque survivant du camp gagne +1/+1 permanent par allié mort
	for minion in same_camp:
		if minion.has_undead_keyword(KeywordUndead.Type.NECROPHAGE):
			minion.base_attack     += dead_minions.size()
			minion.base_max_health += dead_minions.size()
			var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
			if visual:
				battle.animation_system.play_necrophage(visual, dead_minions.size())

	# Deuil (OnGrief) : un ALLIÉ vient de mourir → survivants du même camp réagissent
	for minion in same_camp:
		await battle.effect_manager.trigger_effects(battle, minion, "OnGrief")

	# Carnage (Rituel/Enchantement) : un ENNEMI vient de mourir
	# (Mort-rage n'est PAS lié à la mort : il se déclenche via notify_damaged
	# quand le serviteur passe sous 50% de ses HP max)
	for minion in other_camp:
		await battle.effect_manager.trigger_effects(battle, minion, "OnCarnage")

	# Un OnGrief par allié mort (source = le mort) afin que les enchantements
	# puissent conditionner leur effet sur qui vient de mourir (ex: Mémorial des
	# Héros : seulement si un Humain Légendaire meurt).
	for dead in dead_minions:
		await battle.trigger_system.fire("OnGrief", dead, dead_were_player)
	await battle.trigger_system.fire("OnCarnage", null, not dead_were_player)

# VIRULENT (Abomination) : Dernier Souffle — le serviteur allié adjacent
# déclenche immédiatement une mutation. Doit être calculé AVANT que les morts
# ne soient retirées du plateau (l'adjacence se lit sur les listes en jeu).
func _collect_virulent_adjacent(dead_minions: Array[Minion]) -> Array[Minion]:
	var result: Array[Minion] = []
	for dead in dead_minions:
		if not dead.has_abomination_keyword(KeywordAbomination.Type.VIRULENT):
			continue
		for adjacent in battle.effect_manager._get_adjacent_minions(battle, dead):
			result.append(adjacent)
	return result

# Dévoration (Abomination) : se déclenche quand N'IMPORTE QUEL serviteur meurt,
# allié ou ennemi — contrairement à Deuil/Carnage qui sont scindés par camp.
# ASSIMILATION (mot-clé) est traité ici en dur, sur le même modèle que
# NÉCROPHAGE ci-dessus : +1/+1 permanent par vague de morts (pas par mort
# individuelle, pour éviter qu'une mort groupée ne cumule démesurément).
func _trigger_devoration(dead_minions: Array[Minion]) -> void:
	if dead_minions.is_empty():
		return
	var survivors: Array[Minion] = battle.player_minions + battle.enemy_minions
	for minion in survivors:
		if minion.has_abomination_keyword(KeywordAbomination.Type.ASSIMILATION):
			minion.base_attack     += 1
			minion.base_max_health += 1
			var visual: BoardMinion = battle.board_visual_system.get_visual(minion)
			if visual:
				battle.animation_system.play_assimilation_buff(visual)
	for minion in survivors:
		await battle.effect_manager.trigger_effects(battle, minion, "OnDevoration")
	await battle.trigger_system.fire("OnDevoration", null, true)
	await battle.trigger_system.fire("OnDevoration", null, false)

func _trigger_sacrifice(dead_minions: Array[Minion], dead_were_player: bool) -> void:
	var sacrificed_ones: Array[Minion] = dead_minions.filter(func(m: Minion): return m.sacrificed)
	if sacrificed_ones.is_empty():
		return
	var survivors: Array[Minion] = battle.player_minions if dead_were_player else battle.enemy_minions
	for survivor in survivors:
		await battle.effect_manager.trigger_effects(battle, survivor, "OnSacrifice")
