extends GutTest

# Couvre AuraSystem (scripts/systems/AuraSystem.gd) : recalcul complet des
# bonus d'aura (FORMATION, HORDE, RANG INFERNAL) et des auras posées par
# Enchantements/Rituels (AuraBuffRow, AuraDamageReduction,
# AuraInfectionImmunity, AuraSelfDamageReduction, AuraDebuffEnemiesExceptRace).
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), conformément à la
# convention GUT du projet (voir CLAUDE.md).

var aura_system: AuraSystem
var battle: FakeBattle

func before_each() -> void:
	aura_system = load("res://scripts/systems/AuraSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	aura_system.init(battle)

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

func _with_human_keyword(minion: Minion, keyword: int) -> Minion:
	minion.human_keywords.append(keyword)
	return minion

func _with_undead_keyword(minion: Minion, keyword: int) -> Minion:
	minion.undead_keywords.append(keyword)
	return minion

func _with_demon_keyword(minion: Minion, keyword: int) -> Minion:
	minion.demon_keywords.append(keyword)
	return minion

func _enchantment(effect_id: String, target: String, value: int = 0, value_2: int = 0, race_filter: String = "", row_filter: String = "") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_ENCHANT"
	data.card_type = "Enchantment"
	var trigger := TriggerTypeChoice.new()
	trigger.type = "OnAura"
	data.trigger_types = [trigger]
	var effect := CardEffect.new()
	effect.effect_id = effect_id
	effect.target = target
	effect.value = value
	effect.value_2 = value_2
	effect.race_filter = race_filter
	effect.row_filter = row_filter
	data.effects = [effect]
	return data

func test_recompute_all_resets_stale_bonuses() -> void:
	var minion := _minion()
	minion.aura_attack_bonus = 5
	minion.aura_health_bonus = 5
	minion.aura_damage_reduction = 3
	minion.infection_immune_aura = true
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 0)
	assert_eq(minion.aura_health_bonus, 0)
	assert_eq(minion.aura_damage_reduction, 0)
	assert_false(minion.infection_immune_aura)

func test_formation_gives_no_bonus_when_alone_in_row() -> void:
	var minion := _with_human_keyword(_minion(2, 4, true, "Front"), KeywordHuman.Type.FORMATION)
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 0)
	assert_eq(minion.aura_health_bonus, 0)

func test_formation_gives_bonus_when_ally_present_in_row() -> void:
	var minion := _with_human_keyword(_minion(2, 4, true, "Front"), KeywordHuman.Type.FORMATION)
	_minion(2, 4, true, "Front")
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 1)
	assert_eq(minion.aura_health_bonus, 1)

func test_horde_requires_at_least_three_undead_allies() -> void:
	var minion := _with_undead_keyword(_minion(2, 4, true), KeywordUndead.Type.HORDE)
	_minion(1, 1, true, "Front", Race.Type.UNDEAD)
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 0, "2 Morts-Vivants (dont lui-même) : pas encore de HORDE")

func test_horde_applies_attack_only_bonus_with_three_undead() -> void:
	var minion := _with_undead_keyword(_minion(2, 4, true), KeywordUndead.Type.HORDE)
	_minion(1, 1, true, "Front", Race.Type.UNDEAD)
	_minion(1, 1, true, "Back", Race.Type.UNDEAD)
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 1)
	assert_eq(minion.aura_health_bonus, 0, "HORDE ne donne que de l'ATK, pas de HP")

func test_infernal_rank_scales_with_missing_hero_hp() -> void:
	var minion := _with_demon_keyword(_minion(2, 4, true), KeywordDemon.Type.RANG_INFERNAL)
	battle.player_hero.health = battle.player_hero.max_health - 25
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 2, "25 HP manquants / 10 = +2 ATK (arrondi au palier inférieur)")

func test_infernal_rank_gives_no_bonus_at_full_health() -> void:
	var minion := _with_demon_keyword(_minion(2, 4, true), KeywordDemon.Type.RANG_INFERNAL)
	aura_system.recompute_all()
	assert_eq(minion.aura_attack_bonus, 0)

func test_aura_buff_row_only_affects_targeted_row() -> void:
	var front := _minion(2, 4, true, "Front")
	var back := _minion(2, 4, true, "Back")
	var enchant := _enchantment("AuraBuffRow", "AllAlliesFront", 1, 2)
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	aura_system.recompute_all()
	assert_eq(front.aura_attack_bonus, 1)
	assert_eq(front.aura_health_bonus, 2)
	assert_eq(back.aura_attack_bonus, 0, "l'aura ne cible que la rangée Avant")

func test_aura_damage_reduction_respects_race_filter() -> void:
	var undead := _minion(2, 4, true, "Front", Race.Type.UNDEAD)
	var human := _minion(2, 4, true, "Back", Race.Type.HUMAN)
	var enchant := _enchantment("AuraDamageReduction", "AllAllies", 1, 0, "Undead")
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	aura_system.recompute_all()
	assert_eq(undead.aura_damage_reduction, 1)
	assert_eq(human.aura_damage_reduction, 0, "le filtre de race doit exclure les non Mort-Vivants")

func test_aura_infection_immunity_clears_existing_infection() -> void:
	var minion := _minion(2, 4, true)
	minion.infected = true
	var enchant := _enchantment("AuraInfectionImmunity", "AllAllies", 0, 0)
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	aura_system.recompute_all()
	assert_true(minion.infection_immune_aura)
	assert_false(minion.infected, "l'immunité d'aura doit aussi lever une infection déjà en place")

func test_aura_self_damage_reduction_accumulates_on_hero_system() -> void:
	var enchant := _enchantment("AuraSelfDamageReduction", "Self", 2)
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	aura_system.recompute_all()
	assert_eq(battle.hero_system.self_damage_reduction[true], 2)
	assert_eq(battle.hero_system.self_damage_reduction[false], 0)

func test_aura_debuff_enemies_except_race_spares_excluded_race() -> void:
	var undead_enemy := _minion(3, 5, false, "Front", Race.Type.UNDEAD)
	var human_enemy := _minion(3, 5, false, "Back", Race.Type.HUMAN)
	var enchant := _enchantment("AuraDebuffEnemiesExceptRace", "AllEnemies", 1, 1, "Undead")
	battle.trigger_system.active_enchantments[true] = [{"card_data": enchant}]
	aura_system.recompute_all()
	assert_eq(undead_enemy.aura_attack_bonus, 0, "les Morts-Vivants ennemis sont exclus du débuff")
	assert_eq(human_enemy.aura_attack_bonus, -1)
	assert_eq(human_enemy.aura_health_bonus, -1)
