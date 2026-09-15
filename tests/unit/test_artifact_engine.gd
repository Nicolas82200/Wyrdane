extends GutTest

# Couvre les mécanismes moteur génériques introduits pour la race Artefact
# (scripts/EffectManager/EffectManager.gd) : AddCardToHand, MimicMinion,
# CardEffect.target_max_cost, CardData.echoed_trigger, target =
# "EnemyHeroOrMinion" et target = "LowestHPAlly". Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md). Les tests carte-par-carte (chargement des vraies
# ressources .tres) vivent dans tests/unit/test_artifact_cards.gd.

var effect_manager: EffectManager
var battle: FakeBattle

func before_each() -> void:
	effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()

func _minion(attack: int = 2, health: int = 5, is_player: bool = true, row: String = "Front", cost: int = 1) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = attack
	data.health = health
	data.cost = cost
	data.race = Race.Type.NONE
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _effect(effect_id: String, target: String, value: int = 0, value_2: int = 0) -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.target = target
	effect.value = value
	effect.value_2 = value_2
	return effect

func _card(name: String, attack: int = 1, health: int = 1, is_token: bool = true) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.attack = attack
	data.health = health
	data.is_token = is_token
	return data

# ─── AddCardToHand ──────────────────────────────────────────────────────────

func test_add_card_to_hand_appends_generated_card_to_owner_hand() -> void:
	var source := _minion(2, 4, true)
	var generated := _card("Jeton Généré")
	var effect := _effect("AddCardToHand", "Self")
	effect.generated_card = generated
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(generated in battle.hand_cards)

func test_add_card_to_hand_targets_enemy_hand_for_enemy_source() -> void:
	var source := _minion(2, 4, false)
	var generated := _card("Jeton Généré")
	var effect := _effect("AddCardToHand", "Self")
	effect.generated_card = generated
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(generated in battle.ai_system.hand, "un serviteur ennemi doit ajouter la carte à la main adverse")
	assert_false(generated in battle.hand_cards)

func test_add_card_to_hand_is_a_no_op_without_generated_card() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("AddCardToHand", "Self")
	await effect_manager.execute_effect(battle, source, effect)
	assert_true(battle.hand_cards.is_empty(), "generated_card non assignée : ne doit rien ajouter (no-op silencieux, comme SummonMinion sans summon_card)")

# ─── MimicMinion ────────────────────────────────────────────────────────────

func test_mimic_minion_copies_card_data_stats_and_keywords() -> void:
	var source := _minion(1, 1, true)
	var target := _minion(5, 6, true)
	target.add_keyword(Keyword.Type.TAUNT)
	var effect := _effect("MimicMinion", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(source.card_data, target.card_data)
	assert_eq(source.attack, 5)
	assert_eq(source.max_health, 6)
	assert_true(source.has_keyword(Keyword.Type.TAUNT))

func test_mimic_minion_respects_target_max_cost_restriction() -> void:
	var source := _minion(1, 1, true, "Front", 1)
	var expensive_ally := _minion(9, 9, true, "Front", 7)
	var effect := _effect("MimicMinion", "AllyMinion")
	effect.target_max_cost = 3
	await effect_manager.execute_effect(battle, source, effect, expensive_ally)
	assert_eq(source.attack, 1, "cible de coût 7 > target_max_cost=3 : le mimétisme ne doit pas s'appliquer")
	assert_ne(source.card_data, expensive_ally.card_data)

func test_mimic_minion_allows_target_within_cost_limit() -> void:
	var source := _minion(1, 1, true, "Front", 1)
	var cheap_ally := _minion(3, 2, true, "Front", 2)
	var effect := _effect("MimicMinion", "AllyMinion")
	effect.target_max_cost = 3
	await effect_manager.execute_effect(battle, source, effect, cheap_ally)
	assert_eq(source.card_data, cheap_ally.card_data)
	assert_eq(source.attack, 3)

# ─── Damage / EnemyHeroOrMinion ─────────────────────────────────────────────

func test_damage_enemy_hero_or_minion_hits_enemy_hero_when_no_target_selected() -> void:
	var source := _minion(2, 4, true)
	var effect := _effect("Damage", "EnemyHeroOrMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, null)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 2)

func test_damage_enemy_hero_or_minion_hits_selected_minion() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effect := _effect("Damage", "EnemyHeroOrMinion", 2)
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.health, 2)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health, "aucun dégât au héros quand un serviteur est ciblé")

# ─── LowestHPAlly ────────────────────────────────────────────────────────────

func test_lowest_hp_ally_selects_the_ally_with_the_least_current_hp() -> void:
	var source := _minion(2, 10, true)
	var mid := _minion(2, 6, true)
	mid.take_damage(2) # 4/6
	var lowest := _minion(2, 8, true)
	lowest.take_damage(7) # 1/8, le plus bas
	var effect := _effect("Heal", "LowestHPAlly", 2)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(lowest.health, 3, "le plus bas en HP actuels doit être soigné")
	assert_eq(mid.health, 4, "les autres alliés ne doivent pas être affectés")
	assert_eq(source.health, 10)

func test_lowest_hp_ally_ignores_enemies() -> void:
	var source := _minion(2, 10, true)
	var enemy := _minion(1, 1, false) # HP le plus bas, mais ennemi : ne doit jamais être ciblé
	var effect := _effect("Heal", "LowestHPAlly", 2)
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(enemy.health, 1, "LowestHPAlly ne doit jamais viser un ennemi")
	assert_eq(source.health, 10, "seul allié en jeu : reçoit le soin (déjà au max, plafonné par Minion.take_heal)")

# ─── echoed_trigger (Écho de trigger) ───────────────────────────────────────

# Serviteur portant `trigger_name` + Buff(Self, +1/+0) une fois par déclenchement,
# pour observer concrètement combien de fois l'effet de base a été rejoué.
func _minion_with_trigger(trigger_name: String, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "ECHOED_TRIGGER_CARD"
	data.race = Race.Type.NONE
	data.attack = 2
	data.health = 10
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

func _echo_carrier(echoed_trigger: String, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "ECHO_CARRIER"
	data.race = Race.Type.NONE
	data.attack = 1
	data.health = 1
	data.echoed_trigger = echoed_trigger
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func test_echoed_trigger_matching_the_trigger_name_replays_base_effects_once_more() -> void:
	var minion := _minion_with_trigger("DEATHRATTLE")
	_echo_carrier("DEATHRATTLE")
	await effect_manager.trigger_effects(battle, minion, "DEATHRATTLE")
	assert_eq(minion.base_attack, 4, "2 déclenchements (base + 1 écho) x +1 ATK")

func test_echoed_trigger_any_replays_any_trigger_once_more() -> void:
	var deathrattle_minion := _minion_with_trigger("DEATHRATTLE")
	var onplay_minion := _minion_with_trigger("ONPLAY")
	_echo_carrier("Any")
	await effect_manager.trigger_effects(battle, deathrattle_minion, "DEATHRATTLE")
	await effect_manager.trigger_effects(battle, onplay_minion, "ONPLAY")
	assert_eq(deathrattle_minion.base_attack, 4, "écho universel : DEATHRATTLE aussi doublé")
	assert_eq(onplay_minion.base_attack, 4, "écho universel : ONPLAY aussi doublé")

func test_echoed_trigger_does_not_affect_non_matching_trigger() -> void:
	var minion := _minion_with_trigger("ONPLAY")
	_echo_carrier("DEATHRATTLE") # écho ciblé sur un autre trigger
	await effect_manager.trigger_effects(battle, minion, "ONPLAY")
	assert_eq(minion.base_attack, 3, "un seul déclenchement : l'écho ne concerne pas ONPLAY")

func test_echoed_trigger_stacks_with_two_carriers() -> void:
	var minion := _minion_with_trigger("DEATHRATTLE")
	_echo_carrier("DEATHRATTLE")
	_echo_carrier("DEATHRATTLE")
	await effect_manager.trigger_effects(battle, minion, "DEATHRATTLE")
	assert_eq(minion.base_attack, 5, "2 porteurs d'écho = 2 déclenchements supplémentaires (3 au total) : +3 ATK")

func test_echoed_trigger_carrier_does_not_double_its_own_trigger() -> void:
	var carrier := _echo_carrier("DEATHRATTLE")
	carrier.card_data.trigger_types = [TriggerTypeChoice.new()]
	carrier.card_data.trigger_types[0].type = "DEATHRATTLE"
	var effect := CardEffect.new()
	effect.effect_id = "Buff"
	effect.target = "Self"
	effect.value = 1
	carrier.card_data.effects = [effect]
	await effect_manager.trigger_effects(battle, carrier, "DEATHRATTLE")
	assert_eq(carrier.base_attack, 2, "un porteur exclu de son propre décompte d'écho : un seul déclenchement (+1 ATK)")

# ─── RetriggerAllTriggers ───────────────────────────────────────────────────

func test_retrigger_all_triggers_replays_every_trigger_present_on_target() -> void:
	var target := _minion(2, 10, true)
	var t1 := TriggerTypeChoice.new()
	t1.type = "ONPLAY"
	var t2 := TriggerTypeChoice.new()
	t2.type = "DEATHRATTLE"
	target.card_data.trigger_types = [t1, t2]
	var e1 := CardEffect.new()
	e1.effect_id = "Buff"
	e1.target = "Self"
	e1.value = 1
	e1.trigger = "ONPLAY"
	var e2 := CardEffect.new()
	e2.effect_id = "Buff"
	e2.target = "Self"
	e2.value = 10
	e2.trigger = "DEATHRATTLE"
	target.card_data.effects = [e1, e2]
	var source := _minion(1, 1, true)
	var effect := _effect("RetriggerAllTriggers", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.base_attack, 13, "les deux triggers de la cible (ONPLAY et DEATHRATTLE) doivent tous les deux avoir été rejoués")

func test_retrigger_all_triggers_is_a_no_op_when_target_has_no_triggers() -> void:
	var target := _minion(3, 10, true)
	var source := _minion(1, 1, true)
	var effect := _effect("RetriggerAllTriggers", "AllyMinion")
	await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.base_attack, 3, "cible sans aucun trigger : rien à rejouer, aucune erreur")

func test_retrigger_all_triggers_respects_target_max_cost_restriction() -> void:
	var source := _minion(1, 1, true, "Front", 1)
	var expensive_ally := _minion(2, 10, true, "Front", 7)
	var t1 := TriggerTypeChoice.new()
	t1.type = "ONPLAY"
	expensive_ally.card_data.trigger_types = [t1]
	var e1 := CardEffect.new()
	e1.effect_id = "Buff"
	e1.target = "Self"
	e1.value = 5
	expensive_ally.card_data.effects = [e1]
	var effect := _effect("RetriggerAllTriggers", "AllyMinion")
	effect.target_max_cost = 3
	await effect_manager.execute_effect(battle, source, effect, expensive_ally)
	assert_eq(expensive_ally.base_attack, 2, "cible de coût 7 > target_max_cost=3 : la réactivation ne doit pas s'appliquer")

# ─── DamageAllMinionsRecurring ──────────────────────────────────────────────

# Double de DeathSystem qui, contrairement à FakeDeathSystem (no-op), retire
# réellement les morts des tableaux du plateau — nécessaire pour observer le
# comportement "une vague de plus seulement si un mort est survenu à CETTE
# vague", puisque EffectManager._damage_all_minions_recurring recalcule ses
# cibles depuis battle.player_minions/enemy_minions à chaque itération.
class RecurringDeathSystem extends FakeBattle.FakeDeathSystem:
	var battle: FakeBattle
	func _init(b: FakeBattle) -> void:
		battle = b
	func process_deaths(_silent: Array = []) -> void:
		battle.player_minions = battle.player_minions.filter(func(m: Minion): return not m.is_dead())
		battle.enemy_minions = battle.enemy_minions.filter(func(m: Minion): return not m.is_dead())

func test_damage_all_minions_recurring_loops_while_an_enemy_dies_and_stops_once_none_does() -> void:
	battle.death_system = RecurringDeathSystem.new(battle)
	var enemy_low := _minion(1, 2, false)   # meurt vague 1 (2 dégâts)
	var enemy_mid := _minion(1, 4, false)   # meurt vague 2
	var enemy_tough := _minion(1, 100, false) # ne meurt jamais : stoppe la boucle à la vague 3
	var ally := _minion(1, 100, true)
	var effect := CardEffect.new()
	effect.effect_id = "DamageAllMinionsRecurring"
	effect.value = 2
	await effect_manager.execute_effect(battle, null, effect)
	assert_true(enemy_low.is_dead())
	assert_true(enemy_mid.is_dead())
	assert_eq(enemy_tough.health, 94, "3 vagues avant l'arrêt (2+2+2=6 dégâts), la 3e ne tue personne donc la boucle s'arrête")
	assert_eq(ally.health, 94, "les alliés sont aussi touchés par chaque vague (dégâts de zone)")

func test_damage_all_minions_recurring_is_bounded_even_if_deaths_are_never_cleared() -> void:
	# Avec le FakeDeathSystem par défaut (no-op, ne retire jamais les morts du
	# plateau), un ennemi mort resterait indéfiniment détecté comme "mort à
	# cette vague" sans le plafond défensif : vérifie que la boucle s'arrête
	# bien après 20 vagues plutôt que de tourner indéfiniment.
	var counting := CountingDeathSystem.new()
	battle.death_system = counting
	_minion(1, 1, false) # meurt dès la vague 1, jamais retiré du plateau (no-op)
	var effect := CardEffect.new()
	effect.effect_id = "DamageAllMinionsRecurring"
	effect.value = 2
	await effect_manager.execute_effect(battle, null, effect)
	# 20 appels venant de la boucle bornée + 1 appel final systématique fait par
	# execute_effect() après le match sur effect_id (voir EffectManager.gd).
	assert_eq(counting.calls, 21, "doit s'arrêter au plafond défensif de 20 vagues plutôt que boucler indéfiniment")

class CountingDeathSystem extends FakeBattle.FakeDeathSystem:
	var calls: int = 0
	func process_deaths(_silent: Array = []) -> void:
		calls += 1
