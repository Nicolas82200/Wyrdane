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

# ─── Présence continue (un serviteur posé après l'enchantement en profite) ────
# BoardSystem.summon_minion_return rejoue TOUS les Présence du camp à chaque
# arrivée : reapply_all_presence_effects() simule ce rejeu sans dépendre de la
# vraie BoardSystem (qui a besoin d'une scène).

func test_reapply_all_presence_effects_covers_both_camps() -> void:
	var ally := _ally()
	var enemy_data := CardData.new()
	enemy_data.card_name = "ENEMY_CARD"
	enemy_data.race = Race.Type.HUMAN
	var enemy := Minion.new(enemy_data, false, "Front")
	battle.enemy_minions.append(enemy)
	trigger_system.register_enchantment(_presence_enchantment(_grant_discipline()), true)
	trigger_system.register_enchantment(_presence_enchantment(_grant_discipline()), false)
	await trigger_system.reapply_all_presence_effects()
	assert_true(ally.has_human_keyword(KeywordHuman.Type.DISCIPLINE), "camp joueur couvert")
	assert_true(enemy.has_human_keyword(KeywordHuman.Type.DISCIPLINE), "camp ennemi couvert")

func test_reapply_all_presence_effects_is_idempotent_on_already_granted_keyword() -> void:
	var ally := _ally()
	trigger_system.register_enchantment(_presence_enchantment(_grant_discipline()), true)
	await trigger_system.reapply_all_presence_effects()
	# Un deuxième rejeu (ex: un second serviteur qui arrive juste après) ne doit
	# ni planter ni retirer/réappliquer le mot-clé en boucle.
	await trigger_system.reapply_all_presence_effects()
	assert_true(ally.has_human_keyword(KeywordHuman.Type.DISCIPLINE))
	assert_eq(ally.human_keywords.count(KeywordHuman.Type.DISCIPLINE), 1, "pas de doublon")

func test_grant_keyword_skips_already_granted_target_silently() -> void:
	# _grant_keyword doit écarter une cible déjà pourvue AVANT de dessiner ses
	# flèches : appeler deux fois le même octroi ne doit pas planter.
	var ally := _ally()
	ally.add_human_keyword(KeywordHuman.Type.DISCIPLINE)
	var effect := _grant_discipline()
	await battle.effect_manager.execute_effect(battle, null, effect)
	assert_true(ally.has_human_keyword(KeywordHuman.Type.DISCIPLINE))
	assert_eq(ally.human_keywords.count(KeywordHuman.Type.DISCIPLINE), 1)
