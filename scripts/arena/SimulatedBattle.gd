extends RefCounted
class_name SimulatedBattle

# Objet "battle" duck-typé pour le mode Arena : joue le même rôle que le node
# `Battle` vis-à-vis de `CombatSystem`/`DeathSystem`/`EffectManager`/`AuraSystem`
# (qui n'exigent qu'un objet exposant certaines propriétés, voir
# `tests/unit/doubles/fake_battle.gd`), mais headless et sans scène : aucun
# vrai délai, aucune animation, aucun réseau. N'est PAS un test double : c'est
# l'implémentation de production du combat auto-résolu Arena.
#
# Contrairement au mode 1v1, ceci ne modifie JAMAIS `Battle.gd` : les systèmes
# réels (`CombatSystem`, `DeathSystem`, `EffectManager`, `AuraSystem`) sont de
# simples consommateurs de cet objet.

const ROW_FRONT := "Front"
const ROW_BACK := "Back"

var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion] = []
var player_hero: Hero = Hero.new(ArenaConstants.STARTING_HERO_HP)
var enemy_hero: Hero = Hero.new(ArenaConstants.STARTING_HERO_HP)
var player_graveyard := Graveyard.new()
var enemy_graveyard := Graveyard.new()
var net_registry := NetRegistry.new()
var net_emitter = null
# Sentinelle non-nulle (jamais un vrai NetworkManager) : EffectManager
# n'utilise `network_manager` que comme témoin booléen ("== null" => partie
# solo locale, un humain peut être invité à choisir une cible de trigger).
# En combat simulé Arena, aucune des deux "mains" n'est un humain devant son
# écran à cet instant précis (même en 1 joueur + 3 bots, le combat se résout
# hors interaction) : on force donc systématiquement le tirage aléatoire
# (_rng_pick) plutôt que d'appeler targeting_system.prompt_trigger_target,
# qui n'a pas d'équivalent headless.
var network_manager = true
var game_over: bool = false
var reconnecting: bool = false
var enemy_turn_active: bool = false
var waiting_for_target: bool = false
var counter_offensive: Dictionary = {true: false, false: false}
var game_rng := RandomNumberGenerator.new()

# Non utilisés en Arena v1 (pas de pioche/deck/enchantements pendant le combat
# simulé, voir README « Triggers en combat simulé » et « Contenu jouable v1 ») :
# stubs sans effet plutôt que des propriétés absentes, pour qu'un effet de
# carte inattendu (pioche, enchantement) se contente d'être inerte au lieu de
# planter le combat.
var hand = null
var deck: Array[CardData] = []
var hand_cards: Array[CardData] = []
var opponent := SimNoDrawOpponent.new()
var deck_system := SimNoDrawDeckSystem.new()
var ai_system := SimAiSystemStub.new()
var cost_system := SimCostSystemStub.new()
var enchantment_system := SimEnchantmentSystem.new()
var board_system: SimBoardSystemProxy

var combat_system := CombatSystem.new()
var death_system := DeathSystem.new()
var effect_manager := EffectManager.new()
var aura_system := AuraSystem.new()
var trigger_system := SimTriggerSystem.new()
var temp_effect_system := TempEffectSystem.new()
var hero_system: SimHeroSystem
var board_visual_system := SimBoardVisualSystem.new()
var card_popup_system := SimCardPopupSystem.new()
var animation_system := SimAnimationSystem.new()
var combat_log := SimCombatLog.new()
var _tree := SimSceneTree.new()
var _firing_on_summon: bool = false

func _init() -> void:
	hero_system = SimHeroSystem.new(self)
	board_system = SimBoardSystemProxy.new(self)
	combat_system.init(self)
	death_system.init(self)
	aura_system.init(self)
	temp_effect_system.init(self)

func get_tree() -> SimSceneTree:
	return _tree

func get_node(_path):
	return null

func get_node_or_null(_path):
	return null

func get_owner_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return player_minions
	return player_minions if minion.owner_is_player else enemy_minions

func get_enemy_minions(minion: Minion) -> Array[Minion]:
	if minion == null:
		return enemy_minions
	return enemy_minions if minion.owner_is_player else player_minions

func get_row_minions(is_player: bool, row: String) -> Array[Minion]:
	var source: Array[Minion] = player_minions if is_player else enemy_minions
	return source.filter(func(m: Minion): return m.board_row == row)

func get_front_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, "Front")

func get_back_minions(is_player: bool) -> Array[Minion]:
	return get_row_minions(is_player, "Back")

func can_summon_to_row(is_player: bool, row: String) -> bool:
	return get_row_minions(is_player, row).size() < ArenaConstants.BOARD_ROW_MAX

# Invocation en cours de combat simulé (ex: Dernier Souffle "SummonMinion").
# Version allégée de BoardSystem.summon_minion_return : pas de visuel/audio,
# et l'Arrivée (ONPLAY) du serviteur invoqué ne se déclenche JAMAIS ici (voir
# README « Triggers en combat simulé » : ONPLAY se déclenche uniquement à la
# pose réelle depuis la main, jamais pendant la simulation). `skip_onplay`
# n'a donc pas besoin d'être un paramètre : c'est le comportement systématique.
func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, _skip_onplay := false) -> void:
	await _summon_minion_return(card_data, is_player, row, insert_index)

# Utilisé par `board_system.summon_minion_return` (ex: SummonRandom — voir
# CLAUDE.md « Jetons » : SummonRandom pioche légitimement dans le pool de
# vraies cartes, comportement voulu, pas un cas à convertir en jeton).
func _summon_minion_return(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> Minion:
	if not can_summon_to_row(is_player, row):
		var alt_row: String = "Back" if row == "Front" else "Front"
		if can_summon_to_row(is_player, alt_row):
			row = alt_row
		else:
			return null  # les deux rangées sont pleines (20 serviteurs) : invocation perdue
	var minion := Minion.new(card_data, is_player, row)
	net_registry.register(minion)
	combat_log.card_played(card_data, is_player)
	_insert_minion(minion, is_player, row, insert_index)
	_apply_commandement_bonus(minion, is_player)
	_apply_chair_adaptative(minion)

	if not _firing_on_summon:
		_firing_on_summon = true
		var allies: Array[Minion] = (player_minions if is_player else enemy_minions).duplicate()
		for ally in allies:
			if ally != minion:
				await effect_manager.trigger_effects(self, ally, "OnSummon")
		await trigger_system.fire("OnSummon", minion, is_player)
		_firing_on_summon = false
	aura_system.recompute_all()
	await death_system.process_deaths()
	return minion

func _insert_minion(minion: Minion, is_player: bool, row: String, insert_index: int) -> void:
	var minions: Array[Minion] = player_minions if is_player else enemy_minions
	var row_count: int = minions.filter(func(m: Minion): return m.board_row == row).size()
	insert_index = clamp(insert_index, 0, row_count) if insert_index >= 0 else row_count
	var seen_in_row := 0
	for i in minions.size():
		if minions[i].board_row != row:
			continue
		if seen_in_row == insert_index:
			minions.insert(i, minion)
			return
		seen_in_row += 1
	minions.append(minion)

func _apply_commandement_bonus(minion: Minion, is_player: bool) -> void:
	if minion.card_data.race != Race.Type.HUMAN:
		return
	var allies: Array[Minion] = player_minions if is_player else enemy_minions
	for ally in allies:
		if ally != minion and ally.has_human_keyword(KeywordHuman.Type.COMMANDEMENT):
			minion.base_attack += 1

func _apply_chair_adaptative(minion: Minion) -> void:
	if not minion.has_abomination_keyword(KeywordAbomination.Type.CHAIR_ADAPTATIVE):
		return
	for adjacent in effect_manager._get_adjacent_minions(self, minion):
		if not adjacent.keywords.is_empty():
			minion.add_keyword(adjacent.keywords[0])
			return
		if not adjacent.human_keywords.is_empty():
			minion.add_human_keyword(adjacent.human_keywords[0])
			return
		if not adjacent.undead_keywords.is_empty():
			minion.undead_keywords.append(adjacent.undead_keywords[0])
			return
		if not adjacent.demon_keywords.is_empty():
			minion.add_demon_keyword(adjacent.demon_keywords[0])
			return
		for kw in adjacent.abomination_keywords:
			if kw != KeywordAbomination.Type.CHAIR_ADAPTATIVE:
				minion.add_abomination_keyword(kw)
				return

func race_mana_pool(_is_player: bool) -> Dictionary:
	return {}

func check_game_end() -> void:
	if game_over:
		return
	if enemy_hero.is_dead() or player_hero.is_dead():
		game_over = true

# ─── Combat Arena (voir ArenaTargeting pour le ciblage) ────────────────────────

class CombatResult:
	var player_won: bool
	var damage_dealt: int
	var log: Array[String] = []
	var player_survivors: Array[Minion] = []
	var enemy_survivors: Array[Minion] = []

# Résout un combat complet entre deux compositions figées (Avant puis Arrière
# de chaque camp). Alternance stricte entre camps, cycle indépendant par camp
# (README « Effectifs inégaux ») ; résolution instantanée (pas de vrai timer
# 30s : contrainte de jeu connecté sans objet ici, voir plan Arena).
# Coroutine : les systèmes réutilisés (CombatSystem/DeathSystem) contiennent
# des `await` (timers/animations, résolus immédiatement ici par SimTimer via
# call_deferred, voir plus bas) — l'appelant doit donc `await run_combat(...)`.
func run_combat(front_a: Array[Minion], back_a: Array[Minion], front_b: Array[Minion], back_b: Array[Minion]) -> CombatResult:
	player_minions = (front_a + back_a).duplicate()
	enemy_minions = (front_b + back_b).duplicate()
	# owner_is_player n'est pas un attribut permanent d'un participant Arena :
	# "joueur"/"ennemi" n'a de sens que pour la durée de CE combat précis (un
	# même Minion affrontera un adversaire différent au round suivant). Les
	# systèmes réutilisés (CombatSystem/DeathSystem/EffectManager) en dépendent
	# pour router cimetière/héros/camp — on le fixe donc ici à chaque combat.
	for m in player_minions:
		m.owner_is_player = true
		m.attacks_remaining = 1
	for m in enemy_minions:
		m.owner_is_player = false
		m.attacks_remaining = 1

	var order_a: Array[Minion] = front_a.duplicate() + back_a.duplicate()
	var order_b: Array[Minion] = front_b.duplicate() + back_b.duplicate()
	var idx_a := 0
	var idx_b := 0
	var turn_is_a := true
	var guard := 0
	var max_iterations := 500  # garde-fou anti-boucle infinie (ex: deux Rempart increvables)

	while guard < max_iterations:
		guard += 1
		var alive_a: Array[Minion] = player_minions.filter(func(m: Minion): return not m.is_dead())
		var alive_b: Array[Minion] = enemy_minions.filter(func(m: Minion): return not m.is_dead())
		if alive_a.is_empty() or alive_b.is_empty():
			break

		var attacker: Minion = null
		if turn_is_a:
			attacker = _next_alive_attacker(order_a, idx_a)
			idx_a = (order_a.find(attacker) + 1) if attacker else idx_a
		else:
			attacker = _next_alive_attacker(order_b, idx_b)
			idx_b = (order_b.find(attacker) + 1) if attacker else idx_b
		turn_is_a = not turn_is_a

		if attacker == null or attacker.is_dead():
			continue
		var defenders: Array[Minion] = enemy_minions if attacker.owner_is_player else player_minions
		var target: Minion = ArenaTargeting.pick_target(attacker, defenders, game_rng)
		if target == null:
			continue
		await combat_system.resolve_combat(attacker, target)

	var player_survivors: Array[Minion] = player_minions.filter(func(m: Minion): return not m.is_dead())
	var enemy_survivors: Array[Minion] = enemy_minions.filter(func(m: Minion): return not m.is_dead())

	var result := CombatResult.new()
	result.player_survivors = player_survivors
	result.enemy_survivors = enemy_survivors
	result.log = combat_log.lines
	if player_survivors.is_empty() and enemy_survivors.is_empty():
		result.damage_dealt = 0
	elif enemy_survivors.is_empty():
		result.player_won = true
		result.damage_dealt = _survivors_mana_value(player_survivors)
	else:
		result.player_won = false
		result.damage_dealt = _survivors_mana_value(enemy_survivors)
	return result

func _survivors_mana_value(survivors: Array[Minion]) -> int:
	var total := 0
	for m in survivors:
		total += m.card_data.cost
	return total

# Reprend le cycle du camp depuis idx (modulo sur ses survivants) : cycle
# indépendant par camp (README « Effectifs inégaux »).
func _next_alive_attacker(order: Array[Minion], start_idx: int) -> Minion:
	var alive: Array[Minion] = order.filter(func(m: Minion): return not m.is_dead())
	if alive.is_empty():
		return null
	for offset in order.size():
		var candidate: Minion = order[(start_idx + offset) % order.size()]
		if not candidate.is_dead():
			return candidate
	return null


class SimHeroSystem:
	var battle: SimulatedBattle
	var self_damage_reduction: Dictionary = {true: 0, false: 0}
	var self_damage_blocked: Dictionary = {true: false, false: false}
	func _init(_battle: SimulatedBattle) -> void:
		battle = _battle
	func get_owner_hero(minion: Minion) -> Hero:
		if minion == null:
			return battle.player_hero
		return battle.player_hero if minion.owner_is_player else battle.enemy_hero
	func get_enemy_hero(minion: Minion) -> Hero:
		if minion == null:
			return battle.enemy_hero
		return battle.enemy_hero if minion.owner_is_player else battle.player_hero
	func damage(hero: Hero, amount: int) -> void:
		hero.take_damage(amount)
	func self_damage(is_player: bool, amount: int) -> int:
		if amount <= 0:
			return 0
		var hero: Hero = battle.player_hero if is_player else battle.enemy_hero
		var dealt: int = min(amount, hero.health - 1)
		if dealt <= 0:
			return 0
		hero.take_damage(dealt)
		return dealt
	func update_ui() -> void:
		pass


class SimBoardVisualSystem:
	func get_visual(_minion: Minion):
		return null
	func find_visual(_minion: Minion):
		return null
	func remove_visual(_minion: Minion) -> void:
		pass
	func refresh_board() -> void:
		pass
	func reparent_minion_visual(_minion: Minion, _is_player: bool) -> void:
		pass


class SimCardPopupSystem:
	func show_card_popup(_card_data: CardData, _source_minion: Minion = null) -> void:
		pass
	func show_effect_arrows(_positions: Array, _hold: float = 0.35) -> void:
		pass
	func show_targeting_popup(_card_data: CardData) -> void:
		pass
	func hide_targeting_popup() -> void:
		pass


# Aucune animation en simulation (voir décision "résumé texte instantané" du
# plan Arena) : tous les appels sont des no-op.
class SimAnimationSystem:
	func play_attack_lunge(_a, _b) -> void:
		pass
	func play_aegis_break(_v) -> void:
		pass
	func play_deadly_poison(_v) -> void:
		pass
	func play_infection(_v) -> void:
		pass
	func play_corruption(_v) -> void:
		pass
	func play_terror(_v) -> void:
		pass
	func play_lifesteal(_a, _panel, _amount) -> void:
		pass
	func play_ravage_overkill(_a, _panel) -> void:
		pass
	func play_counter_attack(_a, _b) -> void:
		pass
	func play_revenant(_v) -> void:
		pass
	func play_death(_v) -> void:
		pass
	func play_necrophage(_v, _amount) -> void:
		pass
	func play_assimilation_buff(_v) -> void:
		pass
	func play_death_rage(_v) -> void:
		pass
	func play_mutation(_v, _outcome) -> void:
		pass
	func play_silence(_v) -> void:
		pass
	func play_freeze(_v) -> void:
		pass


# Aucune pioche pendant le combat simulé (README « Contenu jouable v1 » /
# « Triggers en combat simulé ») : un effet "pioche une carte" devient inerte
# plutôt que de planter le combat (limitation assumée, voir plan Arena).
class SimNoDrawOpponent:
	func draw_card() -> void:
		pass
	func get_deck_count() -> int:
		return 0


class SimNoDrawDeckSystem:
	func draw_card() -> void:
		pass


# battle.ai_system.hand : puits sans effet pour un "renvoi en main côté
# adverse" (ReturnToHand) — l'adversaire d'un combat simulé n'est pas une
# vraie IA de tour à tour, cette carte est simplement perdue pour ce combat.
class SimAiSystemStub:
	var hand: Array[CardData] = []


class SimCostSystemStub:
	func add_temp_discount(_card_data: CardData, _amount: int) -> void:
		pass


# Pas d'enchantements/rituels en Arena v1 (README « Contenu jouable v1 ») :
# le pool est toujours vide, donc tout effet ciblant un enchantement est
# systématiquement sans cible valide (comportement correct, pas une lacune).
class SimEnchantmentSystem:
	func get_enchantments(_is_player: bool) -> Array:
		return []
	func get_rituals(_is_player: bool) -> Array:
		return []
	func destroy_enchantment(_card_data: CardData, _is_player: bool) -> void:
		pass


class SimBoardSystemProxy:
	var battle: SimulatedBattle
	func _init(_battle: SimulatedBattle) -> void:
		battle = _battle
	func summon_minion_return(card_data: CardData, is_player: bool, row := "Front", insert_index := -1) -> Minion:
		return await battle._summon_minion_return(card_data, is_player, row, insert_index)


class SimTriggerSystem:
	var active_enchantments: Dictionary = {true: [], false: []}
	func get_active_enchantments(is_player: bool) -> Array:
		return active_enchantments.get(is_player, [])
	func fire(_trigger_name: String, _source: Minion = null, _is_player: bool = true, _extra: Dictionary = {}, _paced: bool = false, _already_acted: bool = false) -> bool:
		return false
	func activate_sacrifice_ritual(_card_data: CardData, _is_player: bool, _victims: Array) -> void:
		pass


# Résumé texte du combat (décision "pas de ralenti visuel" du plan Arena).
class SimCombatLog:
	var lines: Array[String] = []
	func card_played(_card_data: CardData, _is_player: bool) -> void:
		pass
	func attack(attacker: Minion, defender: Minion, dmg: int, attacker_dead: bool = false, defender_dead: bool = false) -> void:
		lines.append("%s attaque %s (%d dégâts)%s%s" % [
			attacker.card_data.card_name, defender.card_data.card_name, dmg,
			" [attaquant mort]" if attacker_dead else "",
			" [défenseur mort]" if defender_dead else "",
		])
	func attack_hero(attacker: Minion, target_is_player: bool, dmg: int) -> void:
		lines.append("%s attaque le héros %s (%d dégâts)" % [
			attacker.card_data.card_name, "joueur" if target_is_player else "adverse", dmg,
		])
	func minion_died(minion: Minion) -> void:
		lines.append("%s meurt" % minion.card_data.card_name)
	func infection_tick(_minion: Minion) -> void:
		pass
	func self_damage(_is_player: bool, _dmg: int) -> void:
		pass


class SimTimer:
	extends RefCounted
	signal timeout
	func _init() -> void:
		call_deferred("_fire")
	func _fire() -> void:
		timeout.emit()


class SimSceneTree:
	extends RefCounted
	func create_timer(_time: float = 0.0, _process_always: bool = true, _process_in_physics: bool = false, _ignore_time_scale: bool = false) -> SimTimer:
		return SimTimer.new()
