extends Node
class_name CombatSystem

var battle

# Accélération des attaques en rafale : plus des attaques s'enchaînent vite
# (plusieurs serviteurs de l'IA, ou le joueur qui enchaîne ses clics), plus
# l'animation de charge de chacune est courte — jusqu'à un plancher, jamais
# instantané. Le combo retombe à zéro dès qu'un délai réel dépasse
# COMBO_RESET_MS entre deux attaques (ex: le joueur réfléchit entre deux
# coups) : basé sur le temps réel écoulé, pas sur un compteur remis à zéro
# manuellement à un moment arbitraire du tour.
var _consecutive_attacks := 0
var _last_attack_time_msec := 0
const COMBO_RESET_MS := 1500
const COMBO_SPEED_STEP := 0.15
const COMBO_MIN_SPEED_SCALE := 0.4

func _combo_speed_scale() -> float:
	var now := Time.get_ticks_msec()
	if now - _last_attack_time_msec > COMBO_RESET_MS:
		_consecutive_attacks = 0
	_consecutive_attacks += 1
	_last_attack_time_msec = now
	return maxf(COMBO_MIN_SPEED_SCALE, 1.0 - COMBO_SPEED_STEP * (_consecutive_attacks - 1))

func init(_battle) -> void:
	battle = _battle

# `"play_sfx" in battle` : duck-typing, seul `SimulatedBattle` (combat Arena)
# porte cette propriété — absente sur le vrai `Battle` (1v1), qui joue donc
# toujours son son. `SimulatedBattle.play_sfx` reste faux par défaut (combat
# bot-contre-bot headless, jamais montré) et n'est mis à true que pour le
# combat réellement affiché au joueur (voir SimulatedBattle.enable_live_visuals)
# — sans ce garde-fou, chaque combat simulé en parallèle (jusqu'à 3-4 à
# 8 joueurs) ferait sonner ses propres coups en plus de celui qu'on regarde.
func _play_hit_sound() -> void:
	if not ("play_sfx" in battle) or battle.play_sfx:
		AudioManager.play(AudioManager.HIT)

func resolve_combat(attacker: Minion, defender: Minion) -> void:
	# Verrou de ré-entrance : empêche un effet déclenché en chaîne pendant cette
	# attaque (OnAttack, OnResonance, attaque immédiate...) de relancer une attaque
	# avec ce même serviteur avant que celle-ci soit terminée.
	if attacker.is_attacking:
		return
	attacker.is_attacking = true
	# Émission réseau : uniquement les attaques initiées par le joueur LOCAL.
	# Les attaques rejouées du pair (serviteur ennemi) ne réémettent pas.
	# begin_capture/end_capture (comme CardSystem.resolve_with_target) : un
	# Dernier Souffle déclenché par cette attaque (ex. le défenseur meurt et
	# invoque un jeton) doit imposer le MÊME net_id côté pair — sans capture,
	# chaque client attribuerait son propre id local au jeton et divergerait
	# durablement sur toute référence future à ce serviteur.
	var is_local_attack: bool = battle.net_emitter != null and attacker.owner_is_player
	if is_local_attack:
		battle.net_registry.begin_capture()
	var speed_scale := _combo_speed_scale()
	var attacker_visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	var defender_visual: BoardMinion = battle.board_visual_system.find_visual(defender)
	if attacker_visual and defender_visual:
		await battle.animation_system.play_attack_lunge(attacker_visual, defender_visual, speed_scale)
	var dealt_to_defender: int = await _execute_damage(attacker, defender)
	await battle.get_tree().create_timer(0.05 * speed_scale).timeout
	# Le résultat (mort ou non) n'est logué qu'une fois la résolution de mort
	# terminée (REVENANT peut relever le serviteur) ; les deux serviteurs sont
	# passés en "silent" pour que DeathSystem ne double-logue pas leur mort
	# séparément — leur sort est déjà visible dans cette entrée d'attaque.
	await battle.death_system.process_deaths([attacker, defender])
	battle.combat_log.attack(attacker, defender, dealt_to_defender, attacker.is_dead(), defender.is_dead())
	battle.hero_system.update_ui()
	battle.check_game_end()
	if is_local_attack:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.attack(attacker, defender, ids)
	attacker.is_attacking = false

func _execute_damage(attacker: Minion, defender: Minion) -> int:
	# defender passé en cible pour les effets d'attaque (ex: Mâcheur d'Os = splash
	# sur les serviteurs adjacents à la cible).
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack", defender)
	# Résonance — enchantements réagissent quand un allié de la même race attaque.
	# La cible de l'attaque est transmise pour les effets qui la visent
	# (Aura de Corruption, Idole du Grand Pacte).
	await battle.trigger_system.fire("OnResonance", attacker, attacker.owner_is_player, {"target": defender})

	var attacker_visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	var defender_visual: BoardMinion = battle.board_visual_system.find_visual(defender)
	var attacker_had_aegis: bool = attacker.has_keyword(Keyword.Type.AEGIS)
	var defender_had_aegis: bool = defender.has_keyword(Keyword.Type.AEGIS)

	var a_dmg: int = attacker.attack
	var d_dmg: int = defender.attack
	var defender_health_before: int = defender.health
	var dealt_to_defender: int = defender.take_damage(a_dmg)
	var dealt_to_attacker: int = attacker.take_damage(d_dmg)
	_play_hit_sound()

	if defender_had_aegis and not defender.has_keyword(Keyword.Type.AEGIS):
		battle.animation_system.play_aegis_break(defender_visual)
	if attacker_had_aegis and not attacker.has_keyword(Keyword.Type.AEGIS):
		battle.animation_system.play_aegis_break(attacker_visual)

	# CHAIR MORTE : immunisé au poison — Venin mortel ne détruit pas la cible
	if attacker.has_keyword(Keyword.Type.DEADLY_POISON) and not defender.has_undead_keyword(KeywordUndead.Type.CHAIR_MORTE):
		if not defender.is_dead():
			battle.animation_system.play_deadly_poison(defender_visual)
		defender.health = 0
	if defender.has_keyword(Keyword.Type.DEADLY_POISON) and not attacker.has_undead_keyword(KeywordUndead.Type.CHAIR_MORTE):
		if not attacker.is_dead():
			battle.animation_system.play_deadly_poison(attacker_visual)
		attacker.health = 0

	# PESTIFÉRÉ : l'attaque inflige Infection en plus des dégâts
	# (pas d'infection si les dégâts ont été annulés, ex: ÉGIDE ; le setter
	# de infected gère l'immunité CHAIR MORTE)
	if attacker.has_undead_keyword(KeywordUndead.Type.PESTIFERE) and dealt_to_defender > 0 and not defender.is_dead():
		defender.infected = true
		battle.animation_system.play_infection(defender_visual)

	# CORRUPTION : l'attaque inflige Corruption en plus des dégâts (-1 ATK
	# permanent, cumulable ; apply_corruption gère l'immunité CHAIR DE SOUFRE)
	if attacker.has_demon_keyword(KeywordDemon.Type.CORRUPTION) and dealt_to_defender > 0 and not defender.is_dead():
		defender.apply_corruption(1)
		battle.animation_system.play_corruption(defender_visual)

	# TERREUR : la cible ne peut pas attaquer lors du prochain tour adverse
	# (sans effet sur les serviteurs immunisés à la peur)
	if attacker.has_demon_keyword(KeywordDemon.Type.TERREUR) and not defender.is_dead() and not defender.is_fear_immune():
		defender.terror_turns = max(defender.terror_turns, 1)
		battle.animation_system.play_terror(defender_visual)

	if dealt_to_attacker > 0:
		await battle.effect_manager.notify_damaged(battle, attacker)
	if dealt_to_defender > 0 and not defender.is_dead():
		await battle.effect_manager.notify_damaged(battle, defender)
		if defender.has_human_keyword(KeywordHuman.Type.CONTRE_ATTAQUE):
			var counter: int = attacker.take_damage(defender.attack)
			if counter > 0:
				battle.animation_system.play_counter_attack(defender_visual, attacker_visual)
				await battle.effect_manager.notify_damaged(battle, attacker)

	if attacker.has_keyword(Keyword.Type.LIFESTEAL) and dealt_to_defender > 0:
		battle.hero_system.get_owner_hero(attacker).heal(dealt_to_defender)
		var hero_panel: Control = battle.get_node("PlayerHeroPanel" if attacker.owner_is_player else "EnemyHeroPanel")
		battle.animation_system.play_lifesteal(attacker_visual, hero_panel, dealt_to_defender)

	if defender.is_dead():
		await battle.effect_manager.trigger_effects(battle, attacker, "OnExecution")
		if attacker.has_keyword(Keyword.Type.RAVAGE) and not defender.card_data.blocks_overkill:
			var excess: int = a_dmg - defender_health_before
			if excess > 0:
				battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), excess)
				var enemy_hero_panel: Control = battle.get_node("EnemyHeroPanel" if attacker.owner_is_player else "PlayerHeroPanel")
				battle.animation_system.play_ravage_overkill(attacker_visual, enemy_hero_panel)
		# Contre-Offensive : un Humain qui tue rejoue immédiatement (+1 attaque, le
		# consume_attack ci-dessous ramène au net d'une relance).
		if attacker.card_data.race == Race.Type.HUMAN and battle.counter_offensive.get(attacker.owner_is_player, false):
			attacker.attacks_remaining += 1

	attacker.consume_attack()
	battle.board_visual_system.refresh_board()
	return dealt_to_defender

func perform_hero_attack(attacker: Minion) -> void:
	# Voir resolve_combat : même verrou de ré-entrance, même capture d'ids
	# réseau (le trigger OnAttack ci-dessous peut invoquer un serviteur).
	if attacker.is_attacking:
		return
	attacker.is_attacking = true
	var is_local_attack: bool = battle.net_emitter != null and attacker.owner_is_player
	if is_local_attack:
		battle.net_registry.begin_capture()
	var speed_scale := _combo_speed_scale()
	var panel_name: String = "EnemyHeroPanel" if attacker.owner_is_player else "PlayerHeroPanel"
	var visual: BoardMinion = battle.board_visual_system.find_visual(attacker)
	if visual:
		var hero_panel: Control = battle.get_node(panel_name)
		await battle.animation_system.play_attack_lunge(visual, hero_panel, speed_scale)
	_play_hit_sound()
	await battle.effect_manager.trigger_effects(battle, attacker, "OnAttack")
	battle.hero_system.damage(battle.hero_system.get_enemy_hero(attacker), attacker.attack)
	battle.combat_log.attack_hero(attacker, not attacker.owner_is_player, attacker.attack)
	if attacker.has_keyword(Keyword.Type.LIFESTEAL) and attacker.attack > 0:
		battle.hero_system.get_owner_hero(attacker).heal(attacker.attack)
		if visual:
			var owner_panel: Control = battle.get_node("PlayerHeroPanel" if attacker.owner_is_player else "EnemyHeroPanel")
			battle.animation_system.play_lifesteal(visual, owner_panel, attacker.attack)
	if is_local_attack:
		var ids: Array = battle.net_registry.end_capture()
		battle.net_emitter.attack_hero(attacker, ids)
	attacker.consume_attack()
	attacker.is_attacking = false
