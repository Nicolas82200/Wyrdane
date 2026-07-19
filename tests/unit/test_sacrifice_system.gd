extends GutTest

# Couvre SacrificeSystem (scripts/systems/SacrificeSystem.gd) : conditions
# d'activation d'un Rituel de Sacrifice (can_activate) et déroulement de
# l'activation (_execute, via la file interne remplie par try_begin/
# on_ally_minion_clicked en jeu réel). Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md).

var sacrifice_system: SacrificeSystem
var battle: FakeBattle

func before_each() -> void:
	sacrifice_system = load("res://scripts/systems/SacrificeSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	sacrifice_system.init(battle)

func after_each() -> void:
	# SacrificeSystem extends Node : jamais ajouté à l'arbre de scène ici, donc
	# jamais libéré automatiquement (sinon GUT le compte en nœud orphelin).
	sacrifice_system.free()

func _minion(health: int = 5, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_VICTIM"
	data.attack = 1
	data.health = health
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _ritual(sacrifice_count: int = 1, sacrifice_max_hp: int = -1) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_RITUAL"
	data.card_type = "Ritual"
	data.sacrifice_count = sacrifice_count
	data.sacrifice_max_hp = sacrifice_max_hp
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSacrifice"
	data.trigger_types = [trigger]
	return data

func _register(ritual: CardData, is_player: bool = true) -> void:
	battle.trigger_system.active_enchantments[is_player] = [{"card_data": ritual}]

func test_can_activate_false_for_null_card() -> void:
	assert_false(sacrifice_system.can_activate(null, true))

func test_can_activate_false_for_remote_player() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	assert_false(sacrifice_system.can_activate(ritual, false), "seul le joueur local peut activer un Sacrifice")

func test_can_activate_false_when_game_over() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	battle.game_over = true
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_when_enemy_turn_active() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	battle.enemy_turn_active = true
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_when_reconnecting() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	battle.reconnecting = true
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_when_already_targeting() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	battle.targeting_system.targeting = true
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_when_sacrifice_count_is_zero() -> void:
	var ritual := _ritual(0)
	_register(ritual)
	_minion()
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_when_ritual_not_registered() -> void:
	var ritual := _ritual()
	_minion()
	# Pas de _register() : le rituel n'est pas dans trigger_system.active_enchantments
	assert_false(sacrifice_system.can_activate(ritual, true))

func test_can_activate_false_without_enough_valid_victims() -> void:
	var ritual := _ritual(2)
	_register(ritual)
	_minion()
	assert_false(sacrifice_system.can_activate(ritual, true), "1 seul serviteur allié disponible pour un coût de 2")

func test_can_activate_true_with_enough_victims() -> void:
	var ritual := _ritual(2)
	_register(ritual)
	_minion()
	_minion()
	assert_true(sacrifice_system.can_activate(ritual, true))

func test_can_activate_respects_sacrifice_max_hp() -> void:
	var ritual := _ritual(1, 2)
	_register(ritual)
	_minion(5)  # 5 HP > 2 : ne compte pas comme victime valide
	assert_false(sacrifice_system.can_activate(ritual, true))
	_minion(2)  # 2 HP <= 2 : victime valide
	assert_true(sacrifice_system.can_activate(ritual, true))

func test_try_begin_activates_and_cancel_resets() -> void:
	var ritual := _ritual()
	_register(ritual)
	_minion()
	assert_false(sacrifice_system.is_active())
	await sacrifice_system.try_begin(ritual, true)
	assert_true(sacrifice_system.is_active())
	sacrifice_system.cancel()
	assert_false(sacrifice_system.is_active())

func test_try_begin_does_nothing_when_not_activatable() -> void:
	var ritual := _ritual()
	# Pas de _register() : can_activate() est faux.
	await sacrifice_system.try_begin(ritual, true)
	assert_false(sacrifice_system.is_active())

func test_execute_activates_ritual_with_selected_victims_and_resets_state() -> void:
	var ritual := _ritual()
	_register(ritual)
	var victim := _minion()
	sacrifice_system._pending_ritual = ritual
	sacrifice_system._selected = [victim]
	sacrifice_system._active = true
	await sacrifice_system._execute()
	assert_false(sacrifice_system.is_active(), "l'état interne doit être réinitialisé après exécution")
	assert_eq(battle.trigger_system.activated_rituals.size(), 1)
	assert_eq(battle.trigger_system.activated_rituals[0]["card_data"], ritual)
	assert_eq(battle.trigger_system.activated_rituals[0]["victims"], [victim])
