extends GutTest

# Couvre TriggerSystem (scripts/systems/TriggersSystem.gd), le moteur
# d'enchantements/rituels : enregistrement, filtrage par camp/trigger
# (_enchantment_reacts), gating "une fois par tour" et conditions, décompte
# des charges de rituel, activation de Sacrifice et annulation de sort.
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), conformément à la
# convention GUT du projet (voir CLAUDE.md).

var trigger_system: TriggerSystem
var battle: FakeBattle

func before_each() -> void:
	trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	trigger_system.init(battle)

func after_each() -> void:
	# TriggerSystem extends Node : jamais ajouté à l'arbre de scène ici, donc
	# jamais libéré automatiquement (sinon GUT le compte en nœud orphelin).
	trigger_system.free()

func _minion(attack: int = 2, health: int = 5, is_player: bool = true, row: String = "Front", race: int = Race.Type.UNDEAD) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = race
	data.attack = attack
	data.health = health
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

# Enchantement dont l'unique effet inflige `value` dégâts au héros ennemi du
# camp propriétaire (utile pour vérifier concrètement qu'un fire() a agi).
func _damage_enchantment(trigger_name: String, value: int = 3, race: int = Race.Type.NONE) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_ENCHANT"
	data.card_type = "Enchantment"
	data.race = race
	var trigger := TriggerTypeChoice.new()
	trigger.type = trigger_name
	data.trigger_types = [trigger]
	data.effects = [_effect("Damage", "EnemyHero", value)]
	return data

func test_register_and_get_active_enchantments() -> void:
	var card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(card, true)
	assert_eq(trigger_system.get_active_enchantments(true).size(), 1)
	assert_eq(trigger_system.get_active_enchantments(false).size(), 0)

func test_unregister_enchantment_removes_entry() -> void:
	var card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(card, true)
	trigger_system.unregister_enchantment(card, true)
	assert_eq(trigger_system.get_active_enchantments(true).size(), 0)

func test_fire_on_summon_only_reacts_for_matching_camp() -> void:
	var player_card := _damage_enchantment("OnSummon")
	var enemy_card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(player_card, true)
	trigger_system.register_enchantment(enemy_card, false)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 3, "seul l'enchantement du camp qui invoque doit réagir")
	assert_eq(battle.player_hero.health, battle.player_hero.max_health, "l'enchantement adverse ne doit pas réagir à un OnSummon du camp local")

func test_fire_on_spell_only_reacts_for_opposing_camp() -> void:
	# OnSpell est inversé : un rituel de riposte réagit au sort de l'ADVERSAIRE.
	var defender_card := _damage_enchantment("OnSpell")
	trigger_system.register_enchantment(defender_card, false)
	await trigger_system.fire("OnSpell", null, true)
	assert_eq(battle.player_hero.health, battle.player_hero.max_health - 3, "le rituel adverse doit réagir au sort du camp local")

func test_fire_on_spell_does_not_react_to_own_camp() -> void:
	var own_card := _damage_enchantment("OnSpell")
	trigger_system.register_enchantment(own_card, true)
	await trigger_system.fire("OnSpell", null, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health, "un rituel OnSpell ne doit pas réagir aux sorts de son propre camp")

func test_fire_on_resonance_requires_matching_camp_and_race() -> void:
	var card := _damage_enchantment("OnResonance", 3, Race.Type.UNDEAD)
	trigger_system.register_enchantment(card, true)
	var undead_source := _minion(2, 5, true, "Front", Race.Type.UNDEAD)
	await trigger_system.fire("OnResonance", undead_source, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 3, "même camp, même race : la Résonance doit réagir")

func test_fire_on_resonance_ignores_mismatched_race() -> void:
	var card := _damage_enchantment("OnResonance", 3, Race.Type.UNDEAD)
	trigger_system.register_enchantment(card, true)
	var human_source := _minion(2, 5, true, "Front", Race.Type.HUMAN)
	await trigger_system.fire("OnResonance", human_source, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health, "race différente de l'enchantement : pas de Résonance")

func test_trigger_once_per_turn_gates_repeated_fires() -> void:
	var card := _damage_enchantment("OnSummon")
	card.trigger_once_per_turn = true
	trigger_system.register_enchantment(card, true)
	await trigger_system.fire("OnSummon", null, true)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 3, "une seule charge doit avoir été consommée sur les deux fire() du même tour")

func test_reset_once_per_turn_allows_it_to_fire_again() -> void:
	var card := _damage_enchantment("OnSummon")
	card.trigger_once_per_turn = true
	trigger_system.register_enchantment(card, true)
	await trigger_system.fire("OnSummon", null, true)
	trigger_system.reset_once_per_turn(true)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 6, "après reset_once_per_turn, l'enchantement doit pouvoir se redéclencher")

func test_fire_skips_effect_when_condition_unmet() -> void:
	var card := _damage_enchantment("OnSummon")
	card.effects[0].condition_type = "AlliesInPlay"
	card.effects[0].condition_op = "GreaterOrEqual"
	card.effects[0].condition_count = 2
	trigger_system.register_enchantment(card, true)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health, "condition non remplie (0 allié, 2 requis) : l'effet ne doit pas s'exécuter")

func test_fire_returns_false_when_nothing_reacted() -> void:
	var acted: bool = await trigger_system.fire("OnSummon", null, true)
	assert_false(acted)

func test_fire_returns_true_when_something_reacted() -> void:
	trigger_system.register_enchantment(_damage_enchantment("OnSummon"), true)
	var acted: bool = await trigger_system.fire("OnSummon", null, true)
	assert_true(acted)

func test_ritual_charge_decrements_and_updates_turns_left() -> void:
	var card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(card, true, 2)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enchantment_system.turns_updates.size(), 1)
	assert_eq(battle.enchantment_system.turns_updates[0]["turns"], 1, "2 charges de départ - 1 consommée = 1 restante")
	assert_eq(battle.enchantment_system.destroyed.size(), 0, "il reste une charge : le rituel ne doit pas être détruit")

func test_ritual_is_destroyed_when_charges_reach_zero() -> void:
	var card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(card, true, 1)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enchantment_system.destroyed.size(), 1, "dernière charge consommée : le rituel doit être détruit")

func test_permanent_enchantment_never_loses_charges() -> void:
	var card := _damage_enchantment("OnSummon")
	trigger_system.register_enchantment(card, true, -1)
	await trigger_system.fire("OnSummon", null, true)
	await trigger_system.fire("OnSummon", null, true)
	assert_eq(battle.enchantment_system.turns_updates.size(), 0)
	assert_eq(battle.enchantment_system.destroyed.size(), 0, "un enchantement permanent (turns_left = -1) ne doit jamais être détruit par l'usure")

func test_activate_sacrifice_ritual_kills_victims_and_executes_effect() -> void:
	var ritual := _damage_enchantment("OnSacrifice", 4)
	trigger_system.register_enchantment(ritual, true, 1)
	var victim := _minion(1, 3, true)
	await trigger_system.activate_sacrifice_ritual(ritual, true, [victim])
	assert_true(victim.sacrificed, "la victime doit être marquée sacrifiée (pas de REVENANT)")
	assert_true(victim.is_dead())
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 4, "l'effet du rituel doit s'exécuter")
	assert_eq(battle.enchantment_system.destroyed.size(), 1, "1 charge de départ consommée : le rituel doit être détruit")

func test_try_cancel_spell_cancels_matching_race_target() -> void:
	var card := CardData.new()
	card.card_name = "CANCEL_RITUAL"
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSpell"
	card.trigger_types = [trigger]
	var cancel_effect := _effect("CancelSpellOnRaceTarget", "Self")
	cancel_effect.race_filter = "Undead"
	card.effects = [cancel_effect]
	trigger_system.register_enchantment(card, false, 1)  # possédé par l'adversaire du lanceur

	var target := _minion(2, 5, false, "Front", Race.Type.UNDEAD)  # doit appartenir au camp du rituel
	var cancelled: bool = await trigger_system.try_cancel_spell(true, target)
	assert_true(cancelled)
	assert_eq(battle.enchantment_system.destroyed.size(), 1, "1 charge de départ consommée")

func test_try_cancel_spell_ignores_race_mismatch() -> void:
	var card := CardData.new()
	card.card_name = "CANCEL_RITUAL"
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSpell"
	card.trigger_types = [trigger]
	var cancel_effect := _effect("CancelSpellOnRaceTarget", "Self")
	cancel_effect.race_filter = "Undead"
	card.effects = [cancel_effect]
	trigger_system.register_enchantment(card, false, 1)

	var target := _minion(2, 5, false, "Front", Race.Type.HUMAN)
	var cancelled: bool = await trigger_system.try_cancel_spell(true, target)
	assert_false(cancelled, "race de la cible différente du filtre : le sort ne doit pas être annulé")

func test_try_cancel_spell_ignores_target_owned_by_caster() -> void:
	var card := CardData.new()
	card.card_name = "CANCEL_RITUAL"
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnSpell"
	card.trigger_types = [trigger]
	card.effects = [_effect("CancelSpellOnRaceTarget", "Self")]
	trigger_system.register_enchantment(card, false, 1)

	# La cible appartient au lanceur lui-même : le rituel adverse ne doit jamais s'appliquer.
	var own_target := _minion(2, 5, true)
	var cancelled: bool = await trigger_system.try_cancel_spell(true, own_target)
	assert_false(cancelled)
