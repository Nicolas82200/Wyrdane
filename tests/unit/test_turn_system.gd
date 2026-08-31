extends GutTest

# Couvre TurnSystem (scripts/systems/TurnSystem.gd), scope volontairement
# restreint (voir CLAUDE.md) : run_turn_end_triggers, run_turn_start_triggers,
# _apply_infection_damage — la logique de règles à forte valeur. On n'appelle
# jamais end_turn()/_begin_player_turn()/draw_card() en entier : ces méthodes
# tirent trop de dépendances d'orchestration UI/réseau (cost_system complet,
# pace_actions, hand, deck_system, turn_timer, opponent.take_turn,
# AudioManager.play côté draw_card) pour la valeur ajoutée d'un test unitaire.
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), conformément à la
# convention GUT du projet.

var turn_system: TurnSystem
var battle: FakeBattle

func before_each() -> void:
	turn_system = load("res://scripts/systems/TurnSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	turn_system.init(battle)

func _minion(is_player: bool = true, infected: bool = false) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = Race.Type.UNDEAD
	data.attack = 2
	data.health = 4
	var minion := Minion.new(data, is_player)
	minion.infected = infected
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── run_turn_end_triggers ───────────────────────────────────────────────────

func test_run_turn_end_triggers_decrements_active_hero_heal_block() -> void:
	battle.player_hero.heal_block_turns = 2
	battle.enemy_hero.heal_block_turns = 2
	await turn_system.run_turn_end_triggers(true)
	assert_eq(battle.player_hero.heal_block_turns, 1, "joueur actif : décrémente")
	assert_eq(battle.enemy_hero.heal_block_turns, 2, "camp adverse : inchangé")

func test_run_turn_end_triggers_heal_block_never_goes_below_zero() -> void:
	battle.player_hero.heal_block_turns = 0
	await turn_system.run_turn_end_triggers(true)
	assert_eq(battle.player_hero.heal_block_turns, 0)

func test_run_turn_end_triggers_applies_infection_damage() -> void:
	var infected_minion := _minion(true, true)
	await turn_system.run_turn_end_triggers(true)
	assert_eq(infected_minion.health, 3, "1 dégât d'Infection en fin de tour")

func test_run_turn_end_triggers_does_not_damage_uninfected_minions() -> void:
	var healthy := _minion(true, false)
	await turn_system.run_turn_end_triggers(true)
	assert_eq(healthy.health, 4)

func test_run_turn_end_triggers_infection_can_kill() -> void:
	var infected_minion := _minion(true, true)
	infected_minion.health = 1
	await turn_system.run_turn_end_triggers(true)
	assert_true(infected_minion.is_dead())

func test_run_turn_end_triggers_no_crash_without_infected_minions() -> void:
	_minion(true, false)
	_minion(false, false)
	await turn_system.run_turn_end_triggers(true)
	assert_eq(battle.player_minions.size(), 1)
	assert_eq(battle.enemy_minions.size(), 1)

# Serviteur portant `trigger_name` + Buff(Self, +1/+0), pour vérifier
# concrètement qu'Éveil/Déclin se sont déclenchés sur le bon camp.
func _minion_with_trigger(trigger_name: String, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TRIGGER_CARD"
	data.race = Race.Type.UNDEAD
	data.attack = 2
	data.health = 4
	var trigger := TriggerTypeChoice.new()
	trigger.type = trigger_name
	data.trigger_types = [trigger]
	var effect := CardEffect.new()
	effect.effect_id = "Buff"
	effect.target = "Self"
	effect.value = 1
	data.effects = [effect]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── run_turn_start_triggers ─────────────────────────────────────────────────

func test_run_turn_start_triggers_fires_on_awaken_for_the_active_camp() -> void:
	var active := _minion_with_trigger("OnAwaken", true)
	await turn_system.run_turn_start_triggers(true)
	assert_eq(active.base_attack, 3, "Éveil doit se déclencher pour le camp dont c'est le tour")

func test_run_turn_start_triggers_does_not_fire_on_awaken_for_the_inactive_camp() -> void:
	var inactive := _minion_with_trigger("OnAwaken", false)
	await turn_system.run_turn_start_triggers(true)
	assert_eq(inactive.base_attack, 2)

func test_run_turn_start_triggers_fires_on_decline_for_the_camp_whose_turn_just_ended() -> void:
	var declining := _minion_with_trigger("OnDecline", false)
	await turn_system.run_turn_start_triggers(true)
	assert_eq(declining.base_attack, 3, "Déclin vise le camp adverse (dont le tour vient de finir)")

func test_run_turn_start_triggers_does_not_fire_on_decline_for_the_active_camp() -> void:
	var active := _minion_with_trigger("OnDecline", true)
	await turn_system.run_turn_start_triggers(true)
	assert_eq(active.base_attack, 2)

func test_run_turn_start_triggers_refreshes_attacks_for_active_camp_only() -> void:
	var active := _minion(true)
	var inactive := _minion(false)
	active.attacks_remaining = 0
	inactive.attacks_remaining = 0
	await turn_system.run_turn_start_triggers(true)
	assert_eq(active.attacks_remaining, 1, "camp actif : refresh_attacks() appelé")
	assert_eq(inactive.attacks_remaining, 0, "camp adverse : pas de refresh ce tour")

func test_run_turn_start_triggers_resets_resource_played_this_turn() -> void:
	battle.resource_played_this_turn[true] = true
	await turn_system.run_turn_start_triggers(true)
	assert_false(battle.resource_played_this_turn[true])

func test_run_turn_start_triggers_does_not_crash_without_trigger_types() -> void:
	_minion(true)
	_minion(false)
	await turn_system.run_turn_start_triggers(true)
	assert_eq(battle.player_minions.size(), 1)

# ─── _apply_infection_damage ─────────────────────────────────────────────────

func test_apply_infection_damage_hits_all_infected_minions_both_camps() -> void:
	var player_infected := _minion(true, true)
	var enemy_infected := _minion(false, true)
	await turn_system._apply_infection_damage()
	assert_eq(player_infected.health, 3)
	assert_eq(enemy_infected.health, 3)

func test_apply_infection_damage_refreshes_board() -> void:
	_minion(true, true)
	var before: int = battle.board_visual_system.refresh_count
	await turn_system._apply_infection_damage()
	assert_gt(battle.board_visual_system.refresh_count, before)

func test_apply_infection_damage_no_crash_without_infected_minions() -> void:
	_minion(true, false)
	await turn_system._apply_infection_damage()
	assert_eq(battle.player_minions[0].health, 4)

func test_apply_infection_damage_scales_with_stacks() -> void:
	var minion := _minion(true, true)
	minion.infected = true
	minion.infected = true
	minion.infected = true
	# 4 marques au total (1 posée par _minion() + 3 ci-dessus) sur un 2/4 → mort,
	# la perte de vie doit refléter les 4 marques et non un dégât fixe de 1.
	await turn_system._apply_infection_damage()
	assert_true(minion.is_dead(), "4 marques d'Infection doivent tuer un serviteur à 4 PV max")
