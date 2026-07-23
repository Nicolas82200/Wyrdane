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
var network_manager = null
var hand = null
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
var _fake_tree := FakeSceneTree.new()

# ─── Ajouts pour tester DeckSystem ─────────────────────────────────────────────
var deck: Array[CardData] = []
var hand_cards: Array[CardData] = []
var tutorial_active: bool = false
var deck_button: Button = Button.new()
var deck_count_label: Label = Label.new()
const MAX_STACK_VISUAL := 8
const CARD_BACK = preload("res://assets/card_back/card-back.png")

func get_tree() -> FakeSceneTree:
	return _fake_tree

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
	func get_active_enchantments(is_player: bool) -> Array:
		return active_enchantments.get(is_player, [])
	func fire(_trigger_name: String, _source: Minion = null, _is_player: bool = true, _extra: Dictionary = {}, _paced: bool = false, _already_acted: bool = false) -> bool:
		return false
	func activate_sacrifice_ritual(card_data: CardData, is_player: bool, victims: Array) -> void:
		activated_rituals.append({"card_data": card_data, "is_player": is_player, "victims": victims})


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
	func destroy_enchantment(card_data: CardData, is_player: bool) -> void:
		destroyed.append({"card_data": card_data, "is_player": is_player})
	func update_turns_left(card_data: CardData, is_player: bool, turns: int) -> void:
		turns_updates.append({"card_data": card_data, "is_player": is_player, "turns": turns})


class FakeTargetingSystem:
	var targeting: bool = false
	func is_targeting() -> bool:
		return targeting


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
