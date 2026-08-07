extends GutTest

# Couvre DeathSystem (scripts/systems/DeathSystem.gd) : retrait du plateau,
# routage au cimetière (avec exile_on_death), REVENANT, NÉCROPHAGE,
# ASSIMILATION (une fois par vague de morts, pas par mort individuelle) et
# les hooks Deuil (OnGrief) / Sacrifice (OnSacrifice). Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md).

var death_system: DeathSystem
var battle: FakeBattle

func before_each() -> void:
	death_system = load("res://scripts/systems/DeathSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	death_system.init(battle)

func _minion(attack: int = 2, health: int = 4, is_player: bool = true, race: int = Race.Type.UNDEAD, undead_kw: int = -1, abomination_kw: int = -1) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = race
	data.attack = attack
	data.health = health
	if undead_kw != -1:
		var kw := KeywordChoiceUndead.new()
		kw.keyword_type = undead_kw
		data.undead_keywords = [kw]
	if abomination_kw != -1:
		var kw2 := KeywordChoiceAbomination.new()
		kw2.keyword_type = abomination_kw
		data.abomination_keywords = [kw2]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# Serviteur survivant portant un trigger + Buff(Self, +1/+1), pour vérifier
# concrètement qu'un hook de DeathSystem (OnGrief/OnSacrifice/OnCarnage/
# OnDevoration) s'est déclenché.
func _survivor_with_trigger(trigger_name: String, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "SURVIVOR"
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
	effect.value_2 = 1
	data.effects = [effect]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func test_process_deaths_sends_dead_minion_to_graveyard() -> void:
	var dying := _minion()
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(battle.player_graveyard.get_minions().size(), 1)
	assert_eq(battle.player_graveyard.get_minions()[0], dying.card_data)

func test_process_deaths_respects_exile_on_death() -> void:
	var dying := _minion()
	dying.card_data.exile_on_death = true
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(battle.player_graveyard.get_minions().size(), 0, "un serviteur exile_on_death ne doit pas rejoindre le cimetière")

func test_dead_minion_removed_from_battle_lists() -> void:
	var dying := _minion()
	dying.health = 0
	await death_system.process_deaths()
	assert_false(dying in battle.player_minions)

func test_revenant_revives_once() -> void:
	var minion := _minion(2, 4, true, Race.Type.UNDEAD, KeywordUndead.Type.REVENANT)
	minion.health = 0
	await death_system.process_deaths()
	assert_eq(minion.health, 1, "REVENANT doit relever le serviteur à 1 HP")
	assert_true(minion.revenant_triggered)
	assert_true(minion in battle.player_minions, "le serviteur relevé doit rester en jeu")

func test_revenant_alone_still_refreshes_board() -> void:
	# Régression : si REVENANT relève le seul mort de la vague, process_deaths
	# sortait en avance sans refresh — le visuel restait figé à 0 HP.
	var minion := _minion(2, 4, true, Race.Type.UNDEAD, KeywordUndead.Type.REVENANT)
	minion.health = 0
	await death_system.process_deaths()
	assert_gt(battle.board_visual_system.refresh_count, 0, "le plateau doit être rafraîchi après une relève REVENANT sans autre mort")

func test_revenant_does_not_apply_when_sacrificed() -> void:
	var minion := _minion(2, 4, true, Race.Type.UNDEAD, KeywordUndead.Type.REVENANT)
	minion.sacrificed = true
	minion.health = 0
	await death_system.process_deaths()
	assert_false(minion in battle.player_minions, "un Sacrifice volontaire n'est pas relevé par REVENANT")

func test_revenant_only_once_per_game() -> void:
	var minion := _minion(2, 4, true, Race.Type.UNDEAD, KeywordUndead.Type.REVENANT)
	minion.revenant_triggered = true
	minion.health = 0
	await death_system.process_deaths()
	assert_false(minion in battle.player_minions, "REVENANT déjà consommé : le serviteur doit mourir normalement")

func test_necrophage_gains_stats_per_ally_death() -> void:
	var survivor := _minion(2, 4, true, Race.Type.UNDEAD, KeywordUndead.Type.NECROPHAGE)
	var dying_a := _minion(1, 1, true)
	var dying_b := _minion(1, 1, true)
	dying_a.health = 0
	dying_b.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 4, "NÉCROPHAGE : +1/+1 par allié mort (2 ici)")
	assert_eq(survivor.base_max_health, 6)

func test_assimilation_gains_stats_once_per_wave_not_per_kill() -> void:
	var survivor := _minion(2, 4, true, Race.Type.ABOMINATION, -1, KeywordAbomination.Type.ASSIMILATION)
	var dying_a := _minion(1, 1, true)
	var dying_b := _minion(1, 1, true)
	dying_a.health = 0
	dying_b.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3, "ASSIMILATION : +1/+1 par VAGUE de morts, pas par mort individuelle")
	assert_eq(survivor.base_max_health, 5)

func test_assimilation_buff_expires_at_start_of_next_turn() -> void:
	var survivor := _minion(2, 4, true, Race.Type.ABOMINATION, -1, KeywordAbomination.Type.ASSIMILATION)
	var dying := _minion(1, 1, true)
	dying.health = 0
	battle.enemy_turn_active = false
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3, "ASSIMILATION : +1/+1 accordé à la mort")
	await battle.temp_effect_system.expire_end_of_player_turn()
	assert_eq(survivor.base_attack, 2, "ASSIMILATION : le buff n'est plus permanent, il expire au tour suivant")
	assert_eq(survivor.base_max_health, 4)

func test_assimilation_buff_granted_on_enemy_turn_expires_end_of_enemy_turn() -> void:
	var survivor := _minion(2, 4, false, Race.Type.ABOMINATION, -1, KeywordAbomination.Type.ASSIMILATION)
	var dying := _minion(1, 1, false)
	dying.health = 0
	battle.enemy_turn_active = true
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3)
	await battle.temp_effect_system.expire_end_of_player_turn()
	assert_eq(survivor.base_attack, 3, "granté pendant le tour adverse : ne doit pas expirer sur la fin du tour du joueur")
	await battle.temp_effect_system.expire_end_of_enemy_turn()
	assert_eq(survivor.base_attack, 2, "expire au début du prochain tour du joueur (fin du tour adverse)")

func test_on_grief_fires_for_surviving_allies_when_ally_dies() -> void:
	var survivor := _survivor_with_trigger("OnGrief")
	var dying := _minion(1, 1, true)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3, "OnGrief doit se déclencher pour chaque survivant à la mort d'un allié")
	assert_eq(survivor.base_max_health, 5)

func test_on_sacrifice_fires_only_when_a_sacrificed_minion_died() -> void:
	var survivor := _survivor_with_trigger("OnSacrifice")
	var dying := _minion(1, 1, true)
	dying.sacrificed = true
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3)

func test_on_sacrifice_does_not_fire_for_a_normal_death() -> void:
	var survivor := _survivor_with_trigger("OnSacrifice")
	var dying := _minion(1, 1, true)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 2, "sans victime marquée sacrifiée, OnSacrifice ne doit pas se déclencher")

# ─── DEATHRATTLE (Dernier Souffle) ───────────────────────────────────────────

func test_deathrattle_fires_on_the_dying_minion_itself() -> void:
	var data := CardData.new()
	data.card_name = "DYING"
	data.race = Race.Type.UNDEAD
	var trigger := TriggerTypeChoice.new()
	trigger.type = "DEATHRATTLE"
	data.trigger_types = [trigger]
	var effect := CardEffect.new()
	effect.effect_id = "Damage"
	effect.target = "EnemyHero"
	effect.value = 3
	data.effects = [effect]
	var dying := Minion.new(data, true)
	battle.player_minions.append(dying)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 3)

# ─── OnCarnage (n'importe quelle mort, vue par le camp opposé) ──────────────

func test_on_carnage_fires_for_the_opposing_camp_survivors() -> void:
	var survivor := _survivor_with_trigger("OnCarnage", false)
	var dying := _minion(1, 1, true)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 3, "un serviteur du camp adverse meurt : Carnage réagit côté opposé")

func test_on_carnage_does_not_fire_for_the_same_camp_survivor() -> void:
	var survivor := _survivor_with_trigger("OnCarnage", true)
	var dying := _minion(1, 1, true)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(survivor.base_attack, 2, "Carnage ne réagit pas quand c'est son propre camp qui perd un serviteur")

# ─── OnDevoration (n'importe quelle mort, tout camp confondu) ───────────────

func test_on_devoration_fires_for_survivors_in_both_camps() -> void:
	var player_survivor := _survivor_with_trigger("OnDevoration", true)
	var enemy_survivor := _survivor_with_trigger("OnDevoration", false)
	var dying := _minion(1, 1, true)
	dying.health = 0
	await death_system.process_deaths()
	assert_eq(player_survivor.base_attack, 3, "Dévoration réagit quel que soit le camp du survivant")
	assert_eq(enemy_survivor.base_attack, 3)
