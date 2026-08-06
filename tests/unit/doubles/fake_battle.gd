extends RefCounted
class_name FakeBattle

# Double minimal de Battle pour tester EffectManager en isolation, sans scène
# ni autoloads (voir convention GUT dans CLAUDE.md). N'implémente que le sous-
# ensemble d'API réellement exercé par les effets couverts par les tests.

var player_hero: Hero = Hero.new()
var enemy_hero: Hero = Hero.new()
var player_minions: Array[Minion] = []
var enemy_minions: Array[Minion] = []

var hero_system: FakeHeroSystem = FakeHeroSystem.new(self)
var temp_effect_system: TempEffectSystem = TempEffectSystem.new()
var board_visual_system: FakeBoardVisualSystem = FakeBoardVisualSystem.new()
var card_popup_system: FakeCardPopupSystem = FakeCardPopupSystem.new()
var death_system: FakeDeathSystem = FakeDeathSystem.new()
var aura_system: FakeAuraSystem = FakeAuraSystem.new()
var trigger_system: FakeTriggerSystem = FakeTriggerSystem.new()
var fusion_system: FakeFusionSystem = FakeFusionSystem.new()
var network_manager = null
var hand: FakeHand = FakeHand.new()
var game_over: bool = false
var enemy_turn_active: bool = false
var waiting_for_target: bool = false
var game_rng := RandomNumberGenerator.new()

# ─── Ajouts pour tester DeathSystem / TriggersSystem / SacrificeSystem ────────
# EffectManager est sans état (méthodes prenant `battle` en paramètre) : une
# vraie instance ici évite de dupliquer son comportement dans un double.
var effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
# RefCounted, sans dépendance de scène : utiliser les vraies classes plutôt
# que de les doubler.
var net_registry := NetRegistry.new()
var player_graveyard := Graveyard.new()
var enemy_graveyard := Graveyard.new()
var combat_log: FakeCombatLog = FakeCombatLog.new()
var enchantment_system: FakeEnchantmentSystem = FakeEnchantmentSystem.new()
var targeting_system: FakeTargetingSystem = FakeTargetingSystem.new()
var reconnecting: bool = false
var net_emitter = null
var counter_offensive: Dictionary = {true: false, false: false}
var front_line_protected: Dictionary = {true: false, false: false}
var undead_ally_deaths_this_turn: Dictionary = {true: 0, false: 0}
var _fake_tree := FakeSceneTree.new()

# ─── Ajouts pour tester DeckSystem ─────────────────────────────────────────────
var deck: Array[CardData] = []
var hand_cards: Array[CardData] = []
var tutorial_active: bool = false
var deck_button: Button = Button.new()
var deck_count_label: Label = Label.new()
const MAX_STACK_VISUAL := 8
const CARD_BACK = preload("res://assets/card_back/card-back.png")

# ─── Ajouts pour tester HeroSystem / CombatSystem / TurnSystem ────────────────
const BOARD_MINION_SIZE := Vector2(100, 150)
var animation_system: FakeAnimationSystem = FakeAnimationSystem.new()
var vfx_manager: FakeVfxManager = FakeVfxManager.new()
var resource_played_this_turn: Dictionary = {true: false, false: false}
var cost_system: FakeCostSystem = FakeCostSystem.new()
var _player_hero_panel := Control.new()
var _enemy_hero_panel := Control.new()
var _player_health_label := Label.new()
var _enemy_health_label := Label.new()

# ─── Ajouts pour tester AISystem ───────────────────────────────────────────────
var deck_system: FakeDeckSystem = FakeDeckSystem.new()

# ─── Ajouts pour couvrir le reste d'EffectManager (Summon*/Resurrect*/combat
# bonus/mana/remise de pioche) sans dépendre de BoardSystem/CombatSystem réels
# (qui appellent AudioManager, non fiable en runner GUT -s, voir CLAUDE.md) ───
var board_system: FakeBoardSystem = FakeBoardSystem.new(self)
var combat_system: FakeCombatSystem = FakeCombatSystem.new()
var opponent: FakeOpponent = FakeOpponent.new()
var ai_system: FakeOpponent = opponent
var race_mana: Dictionary = {}
var enemy_race_mana: Dictionary = {}

# ─── Ajouts pour tester DropSystem ─────────────────────────────────────────────
const ROW_FRONT := "Front"
const ROW_BACK := "Back"
var player_front_container: Control = Control.new()
var player_back_container: Control = Control.new()
var enemy_front_container: Control = Control.new()
var enemy_back_container: Control = Control.new()

# Même formule que Battle.get_allowed_rows_for_card.
func get_allowed_rows_for_card(card_data: CardData) -> Array[String]:
	if card_data == null or card_data.card_type != "Minion":
		return [ROW_FRONT, ROW_BACK]
	match card_data.board_position:
		ROW_FRONT: return [ROW_FRONT]
		ROW_BACK:  return [ROW_BACK]
		_:         return [ROW_FRONT, ROW_BACK]

func race_mana_pool(is_player: bool) -> Dictionary:
	return race_mana if is_player else enemy_race_mana

func update_mana_ui() -> void:
	pass

func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false) -> void:
	await board_system.summon_minion_return(card_data, is_player, row, insert_index, skip_onplay)

func _init() -> void:
	deck_system.battle = self

func update_enemy_hand_ui() -> void:
	pass

func update_enemy_mana_ui() -> void:
	pass

func get_tree() -> FakeSceneTree:
	return _fake_tree

# FakeBattle extends RefCounted (pas de vrai arbre de scène Godot) : dispatch
# manuel sur les chemins effectivement utilisés par HeroSystem/CombatSystem,
# pas une résolution de chemin réelle.
func get_node(path):
	var path_str: String = str(path)
	match path_str:
		"PlayerHeroPanel":
			return _player_hero_panel
		"EnemyHeroPanel":
			return _enemy_hero_panel
		"PlayerHeroPanel/HealthLabel":
			return _player_health_label
		"EnemyHeroPanel/HealthLabel":
			return _enemy_health_label
		_:
			push_error("FakeBattle.get_node : chemin non stubé : %s" % path_str)
			return null

func pace_actions() -> void:
	pass

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
	return get_row_minions(is_player, row).size() < 10

# Mêmes formules que Battle.gd (get_attackable_enemy_minions / _can_attack_hero) :
# priorité à la rangée Avant du camp défenseur, sauf INFILTRATION.
func get_attackable_enemy_minions(attacker: Minion) -> Array[Minion]:
	var defending_is_player: bool = attacker != null and not attacker.owner_is_player
	var defenders: Array[Minion] = player_minions if defending_is_player else enemy_minions
	if attacker and attacker.has_keyword(Keyword.Type.BLACK_WINGS):
		return defenders
	var front: Array[Minion] = get_front_minions(defending_is_player)
	if not front.is_empty():
		return front
	return defenders

func _can_attack_hero(attacker: Minion) -> bool:
	if attacker.card_data != null and attacker.card_data.cannot_attack_hero:
		return false
	var attackable: Array[Minion] = get_attackable_enemy_minions(attacker)
	for minion in attackable:
		if minion.has_keyword(Keyword.Type.TAUNT):
			return false
	var defending_is_player: bool = not attacker.owner_is_player
	return attacker.has_keyword(Keyword.Type.BLACK_WINGS) or get_front_minions(defending_is_player).is_empty()

func get_node_or_null(_path):
	return null

func check_game_end() -> void:
	pass


class FakeHeroSystem:
	var battle: FakeBattle
	var self_damage_reduction: Dictionary = {true: 0, false: 0}
	var self_damage_blocked: Dictionary = {true: false, false: false}
	func _init(_battle: FakeBattle) -> void:
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


class FakeBoardVisualSystem:
	var refresh_count: int = 0
	func get_visual(_minion: Minion):
		return null
	func find_visual(_minion: Minion):
		return null
	func remove_visual(_minion: Minion) -> void:
		pass
	func refresh_board() -> void:
		refresh_count += 1
	func reparent_minion_visual(_minion: Minion, _is_player: bool) -> void:
		pass
	func spawn_minion_visual(_minion: Minion, _is_player: bool) -> void:
		pass


class FakeCardPopupSystem:
	func show_card_popup(_card_data: CardData, _source_minion: Minion = null) -> void:
		pass
	func show_effect_arrows(_positions: Array, _hold: float = 0.35) -> void:
		pass
	func show_targeting_popup(_card_data: CardData) -> void:
		pass
	func hide_targeting_popup() -> void:
		pass


class FakeDeathSystem:
	func process_deaths(_silent: Array = []) -> void:
		pass


class FakeAuraSystem:
	func recompute_all() -> void:
		pass


class FakeTriggerSystem:
	var active_enchantments: Dictionary = {true: [], false: []}
	var activated_rituals: Array = []
	var fired_calls: Array = []
	func get_active_enchantments(is_player: bool) -> Array:
		return active_enchantments.get(is_player, [])
	func fire(trigger_name: String, source: Minion = null, is_player: bool = true, extra: Dictionary = {}, paced: bool = false, already_acted: bool = false) -> bool:
		fired_calls.append({"trigger_name": trigger_name, "source": source, "is_player": is_player, "extra": extra, "paced": paced, "already_acted": already_acted})
		return false
	func activate_sacrifice_ritual(card_data: CardData, is_player: bool, victims: Array) -> void:
		activated_rituals.append({"card_data": card_data, "is_player": is_player, "victims": victims})
	func reset_once_per_turn(_is_local_turn: bool) -> void:
		pass


class FakeFusionSystem:
	var applied_fusions: Array = []
	func _collect_keyword_choices(victim: Minion) -> Array:
		var out: Array = []
		for kw in victim.keywords:
			out.append({"pool": "keywords", "keyword": kw, "label": ""})
		for kw in victim.human_keywords:
			out.append({"pool": "human_keywords", "keyword": kw, "label": ""})
		for kw in victim.undead_keywords:
			out.append({"pool": "undead_keywords", "keyword": kw, "label": ""})
		for kw in victim.demon_keywords:
			out.append({"pool": "demon_keywords", "keyword": kw, "label": ""})
		for kw in victim.abomination_keywords:
			out.append({"pool": "abomination_keywords", "keyword": kw, "label": ""})
		return out
	func apply_fusion(source: Minion, victim: Minion, pool: String, keyword: int) -> void:
		applied_fusions.append({"source": source, "victim": victim, "pool": pool, "keyword": keyword})


class FakeAnimationSystem:
	# No-op complet : couvre toutes les méthodes play_* de AnimationSystem.gd
	# réellement utilisées, pas seulement celles de CombatSystem/HeroSystem/
	# TurnSystem — EffectManager (instance réelle partagée par tous les tests
	# GUT du projet) y accède aussi (Damage/Heal/Buff/Debuff/Silence/Freeze/
	# Infection/StealMinion/DeathRage/Mutation).
	func play_summon(_visual) -> void:
		pass
	func play_death(_visual) -> Tween:
		return null
	func play_attack_lunge(_attacker_visual, _target) -> void:
		pass
	func play_resource_absorb(_card, _target: Vector2, _color: Color) -> void:
		pass
	func play_spell_missile(_from: Vector2, _targets: Array, _color: Color) -> void:
		pass
	func play_aegis_break(_visual) -> void:
		pass
	func play_lifesteal(_attacker_visual, _hero_panel, _amount: int) -> void:
		pass
	func play_deadly_poison(_target_visual) -> void:
		pass
	func play_ravage_overkill(_attacker_visual, _hero_panel) -> void:
		pass
	func play_counter_attack(_defender_visual, _attacker_visual) -> void:
		pass
	func play_necrophage(_visual, _amount: int) -> void:
		pass
	func play_revenant(_visual) -> void:
		pass
	func play_commandement_buff(_visual) -> void:
		pass
	func play_corruption(_target_visual) -> void:
		pass
	func play_terror(_target_visual) -> void:
		pass
	func play_pact_drain(_hero_panel, _minion_visual) -> void:
		pass
	func play_sang_noir_buff(_visual) -> void:
		pass
	func play_mutation(_visual, _outcome: String) -> void:
		pass
	func play_assimilation_buff(_visual) -> void:
		pass
	func play_chair_adaptative_copy(_source_visual, _target_visual) -> void:
		pass
	func play_charge_ready(_visual) -> void:
		pass
	func play_hit_mark(_attacker_visual, _target) -> void:
		pass
	func play_infection(_target_visual) -> void:
		pass
	func play_infection_tick(_visual, _amount: int) -> void:
		pass
	func play_freeze(_visual) -> void:
		pass
	func play_silence(_visual) -> void:
		pass
	func play_death_rage(_visual) -> void:
		pass
	func play_damage(_visual, _amount: int) -> void:
		pass
	func play_heal(_visual, _amount: int) -> void:
		pass
	func play_generic_buff(_visual, _attack_gain: int, _health_gain: int) -> void:
		pass
	func play_generic_debuff(_visual, _attack_loss: int, _health_loss: int) -> void:
		pass
	func play_appear(_visual) -> void:
		pass
	func play_disappear(_visual) -> Tween:
		return null


class FakeVfxManager:
	func spawn_hit_impact(_pos: Vector2, _race: int, _is_dead: bool) -> void:
		pass


class FakeCostSystem:
	var temp_discounts: Dictionary = {}
	func on_turn_started(_is_local_turn: bool) -> void:
		pass
	func expire_end_of_player_turn() -> void:
		pass
	func add_temp_discount(card_data: CardData, amount: int) -> void:
		if card_data == null or amount <= 0:
			return
		temp_discounts[card_data] = int(temp_discounts.get(card_data, 0)) + amount


class FakeCombatLog:
	func card_played(_card_data: CardData, _is_player: bool) -> void:
		pass
	func attack(_attacker: Minion, _defender: Minion, _dmg: int, _attacker_dead: bool = false, _defender_dead: bool = false) -> void:
		pass
	func attack_hero(_attacker: Minion, _target_is_player: bool, _dmg: int) -> void:
		pass
	func minion_died(_minion: Minion) -> void:
		pass
	func infection_tick(_minion: Minion) -> void:
		pass
	func self_damage(_is_player: bool, _dmg: int) -> void:
		pass


class FakeEnchantmentSystem:
	var destroyed: Array = []
	var turns_updates: Array = []
	var player_enchantments: Array[CardData] = []
	var enemy_enchantments: Array[CardData] = []
	var player_rituals: Array[CardData] = []
	var enemy_rituals: Array[CardData] = []
	func destroy_enchantment(card_data: CardData, is_player: bool) -> void:
		destroyed.append({"card_data": card_data, "is_player": is_player})
	func update_turns_left(card_data: CardData, is_player: bool, turns: int) -> void:
		turns_updates.append({"card_data": card_data, "is_player": is_player, "turns": turns})
	func get_enchantments(is_player: bool) -> Array[CardData]:
		return player_enchantments if is_player else enemy_enchantments
	func get_rituals(is_player: bool) -> Array[CardData]:
		return player_rituals if is_player else enemy_rituals
	func find_visual(_card_data: CardData, _is_player: bool):
		return null


class FakeDeckSystem:
	var battle: FakeBattle
	func update_enemy_deck_ui() -> void:
		pass
	func draw_card() -> void:
		if battle == null or battle.deck.is_empty():
			return
		battle.hand_cards.append(battle.deck.pop_back())
		battle.hand.set_hand(battle.hand_cards)


# Reproduit uniquement la mécanique de plateau (insertion + limite de rangée)
# de BoardSystem.summon_minion_return, sans AudioManager ni triggers ONPLAY/
# OnSummon (hors-scope des tests d'effets individuels ; ces enchaînements sont
# couverts par test_trigger_system.gd / test_board_system.gd).
class FakeBoardSystem:
	var battle: FakeBattle
	func _init(_battle: FakeBattle) -> void:
		battle = _battle
	func summon_minion_return(card_data: CardData, is_player: bool, row := "Front", _insert_index := -1, _skip_onplay := false) -> Minion:
		if not battle.can_summon_to_row(is_player, row):
			return null
		var minion := Minion.new(card_data, is_player, row)
		if is_player:
			battle.player_minions.append(minion)
		else:
			battle.enemy_minions.append(minion)
		return minion
	func summon_minion(card_data: CardData, is_player: bool, row := "Front", insert_index := -1, skip_onplay := false) -> void:
		await summon_minion_return(card_data, is_player, row, insert_index, skip_onplay)


# Échange de dégâts symétrique minimal (attaquant <-> défenseur), sans le
# pipeline complet de mots-clés de combat (poison, contre-attaque...) déjà
# couvert par test_combat_system.gd — suffisant pour vérifier qu'AttackImmediate
# / GroupAttackImmediate ciblent et déclenchent bien un combat.
class FakeCombatSystem:
	var resolved: Array = []
	func resolve_combat(attacker: Minion, defender: Minion) -> void:
		resolved.append({"attacker": attacker, "defender": defender})
		defender.take_damage(attacker.attack)
		attacker.take_damage(defender.attack)


class FakeOpponent:
	var hand: Array[CardData] = []
	var deck: Array[CardData] = []
	func draw_card() -> void:
		if not deck.is_empty():
			hand.append(deck.pop_back())
	func get_deck_count() -> int:
		return deck.size()
	func get_hand_count() -> int:
		return hand.size()


class FakeHand:
	extends Node
	var last_set: Array[CardData] = []
	func set_hand(cards: Array, _animate: bool = false, _from_pos: Vector2 = Vector2.ZERO) -> void:
		last_set = cards
	func refresh_costs() -> void:
		pass
	func refresh_playable_highlights() -> void:
		pass


class FakeTargetingSystem:
	var targeting: bool = false
	var has_valid_target: bool = true
	func is_targeting() -> bool:
		return targeting
	func has_any_valid_target(_card_data: CardData) -> bool:
		return has_valid_target


class FakeTimer:
	extends RefCounted
	signal timeout
	func _init() -> void:
		call_deferred("_fire")
	func _fire() -> void:
		timeout.emit()


class FakeSceneTree:
	extends RefCounted
	func create_timer(_time: float = 0.0, _process_always: bool = true, _process_in_physics: bool = false, _ignore_time_scale: bool = false) -> FakeTimer:
		return FakeTimer.new()
