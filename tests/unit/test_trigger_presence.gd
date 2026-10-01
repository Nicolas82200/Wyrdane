extends GutTest

# Couvre TriggerSystem.apply_presence_effects (Présence / OnAura) : les effets
# continus (AuraXxx) sont l'affaire d'AuraSystem, mais un effet ponctuel porté
# par un OnAura (Aegis de l'Empire : GrantKeyword) n'était exécuté par personne
# — il s'applique désormais à la pose de l'enchantement/rituel.
# Utilise FakeBattle, conformément à la convention GUT du projet (voir CLAUDE.md).

var trigger_system: TriggerSystem
var battle: FakeBattle

func before_each() -> void:
	trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	trigger_system.init(battle)

func after_each() -> void:
	# TriggerSystem extends Node, jamais ajouté à l'arbre : à libérer à la main
	# (sinon GUT le compte en nœud orphelin).
	trigger_system.free()

func _ally() -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = Race.Type.HUMAN
	data.attack = 2
	data.health = 5
	var minion := Minion.new(data, true, "Front")
	battle.player_minions.append(minion)
	return minion

func _presence_enchantment(effect: CardEffect, trigger_name: String = "OnAura") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_PRESENCE"
	data.card_type = "Enchantment"
	var trigger := TriggerTypeChoice.new()
	trigger.type = trigger_name
	data.trigger_types = [trigger]
	data.effects = [effect]
	return data

func _grant_discipline() -> CardEffect:
	var effect := CardEffect.new()
	effect.effect_id = "GrantKeyword"
	effect.target = "AllAlliesFront"
	effect.granted_keyword = "DISCIPLINE"
	effect.granted_keyword_is_human = true
	return effect

func test_presence_applies_one_shot_effect_on_placement() -> void:
	var ally := _ally()
	await trigger_system.apply_presence_effects(_presence_enchantment(_grant_discipline()), true)
	assert_true(ally.has_human_keyword(KeywordHuman.Type.DISCIPLINE))

func test_presence_leaves_continuous_aura_effects_to_aura_system() -> void:
	var ally := _ally()
	var aura := CardEffect.new()
	aura.effect_id = "AuraBuffRow"
	aura.target = "AllAlliesFront"
	aura.value = 1
	aura.value_2 = 1
	await trigger_system.apply_presence_effects(_presence_enchantment(aura), true)
	assert_eq(ally.attack, 2, "un effet AuraXxx n'est pas appliqué une seconde fois à la pose")

func test_presence_ignores_enchantment_without_on_aura() -> void:
	var ally := _ally()
	var card := _presence_enchantment(_grant_discipline(), "OnSummon")
	await trigger_system.apply_presence_effects(card, true)
	assert_false(ally.has_human_keyword(KeywordHuman.Type.DISCIPLINE))
