extends GutTest

# Couvre TurnSystem (scripts/systems/TurnSystem.gd), scope volontairement
# restreint (voir CLAUDE.md) : run_turn_end_triggers, run_turn_start_triggers,
# _tick_infection — la logique de règles à forte valeur. On n'appelle
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

# run_turn_end_triggers n'est plus une coroutine depuis que l'Infection ne fait
# plus de dégâts (plus de process_deaths à attendre) : l'appeler sans `await`.
func run_turn_end_triggers_sync(is_local_turn: bool) -> void:
	turn_system.run_turn_end_triggers(is_local_turn)

func _minion(is_player: bool = true, infection_turns: int = 0) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = Race.Type.UNDEAD
	data.attack = 2
	data.health = 4
	var minion := Minion.new(data, is_player)
	if infection_turns > 0:
		minion.apply_infection(infection_turns, not is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── run_turn_end_triggers ───────────────────────────────────────────────────

func test_run_turn_end_triggers_decrements_active_hero_heal_block() -> void:
	battle.player_hero.heal_block_turns = 2
	battle.enemy_hero.heal_block_turns = 2
	run_turn_end_triggers_sync(true)
	assert_eq(battle.player_hero.heal_block_turns, 1, "joueur actif : décrémente")
	assert_eq(battle.enemy_hero.heal_block_turns, 2, "camp adverse : inchangé")

func test_run_turn_end_triggers_heal_block_never_goes_below_zero() -> void:
	battle.player_hero.heal_block_turns = 0
	run_turn_end_triggers_sync(true)
	assert_eq(battle.player_hero.heal_block_turns, 0)

func test_run_turn_end_triggers_ticks_infection_of_the_active_camp() -> void:
	var infected_minion := _minion(true, 3)
	run_turn_end_triggers_sync(true)
	assert_eq(infected_minion.infection_turns, 2, "la marque perd 1 tour à la fin du tour de son contrôleur")
	assert_eq(infected_minion.health, 4, "l'Infection n'infligeant plus de dégâts, les PV sont intacts")

func test_run_turn_end_triggers_leaves_uninfected_minions_alone() -> void:
	var healthy := _minion(true, 0)
	run_turn_end_triggers_sync(true)
	assert_eq(healthy.infection_turns, 0)
	assert_eq(healthy.health, 4)

func test_infection_expires_without_converting_when_the_counter_runs_out() -> void:
	var infected_minion := _minion(true, 1)
	run_turn_end_triggers_sync(true)
	assert_false(infected_minion.infected, "à 0 tour, la marque s'efface")
	assert_true(battle.player_minions.has(infected_minion), "l'expiration ne tue rien et ne convertit rien")

# Le décrément suit le CONTRÔLEUR : un round complet appelle
# run_turn_end_triggers deux fois (fin du tour local, is_local_turn=true, puis
# fin du tour adverse via AISystem/NetworkOpponent, is_local_turn=false), donc
# chaque marque ne perd qu'un seul tour par round.
func test_enemy_turn_end_does_not_tick_player_minions() -> void:
	var infected_minion := _minion(true, 3)
	run_turn_end_triggers_sync(false)
	assert_eq(infected_minion.infection_turns, 3, "le tour adverse ne touche pas les serviteurs du joueur")

func test_enemy_turn_end_ticks_enemy_minions() -> void:
	var infected_enemy := _minion(false, 3)
	run_turn_end_triggers_sync(false)
	assert_eq(infected_enemy.infection_turns, 2)

func test_infection_loses_exactly_one_turn_per_full_round() -> void:
	var infected_minion := _minion(true, 3)
	run_turn_end_triggers_sync(true)
	run_turn_end_triggers_sync(false)
	assert_eq(infected_minion.infection_turns, 2, "1 seul décrément sur le round complet, pas 2")

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

# ─── _tick_infection ─────────────────────────────────────────────────────────

func test_tick_infection_refreshes_the_board() -> void:
	_minion(true, 2)
	var before: int = battle.board_visual_system.refresh_count
	turn_system._tick_infection(true)
	assert_gt(battle.board_visual_system.refresh_count, before)

func test_tick_infection_never_goes_below_zero() -> void:
	var minion := _minion(true, 1)
	turn_system._tick_infection(true)
	turn_system._tick_infection(true)
	assert_eq(minion.infection_turns, 0)
