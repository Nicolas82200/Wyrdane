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
	func get_active_enchantments(is_player: bool) -> Array:
		return active_enchantments.get(is_player, [])
	func fire(_trigger_name: String, _source: Minion = null, _is_player: bool = true, _extra: Dictionary = {}, _paced: bool = false, _already_acted: bool = false) -> bool:
		return false
