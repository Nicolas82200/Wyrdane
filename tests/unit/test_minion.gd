extends GutTest

func _make_data(attack: int = 2, health: int = 3, damage_reduction: int = 0) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = attack
	data.health = health
	data.damage_reduction = damage_reduction
	return data

func test_take_damage_reduces_health() -> void:
	var minion := Minion.new(_make_data(2, 5))
	var dealt: int = minion.take_damage(3)
	assert_eq(dealt, 3)
	assert_eq(minion.health, 2)

func test_take_damage_cannot_go_below_zero() -> void:
	var minion := Minion.new(_make_data(2, 5))
	var dealt: int = minion.take_damage(99)
	assert_eq(dealt, 5)
	assert_eq(minion.health, 0)
	assert_true(minion.is_dead())

func test_damage_reduction_floors_at_one_damage() -> void:
	var minion := Minion.new(_make_data(2, 10, 5))
	var dealt: int = minion.take_damage(2)
	assert_eq(dealt, 1, "damage_reduction ne doit jamais annuler totalement un coup")

func test_aegis_blocks_next_hit_then_falls() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.add_keyword(Keyword.Type.AEGIS)
	var dealt: int = minion.take_damage(3)
	assert_eq(dealt, 0, "AEGIS annule les premiers dégâts")
	assert_false(minion.has_keyword(Keyword.Type.AEGIS), "AEGIS se consomme après avoir bloqué")
	dealt = minion.take_damage(3)
	assert_eq(dealt, 3, "sans AEGIS restant, les dégâts suivants passent normalement")

func test_heal_cannot_exceed_max_health() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.take_damage(3)
	minion.heal(99)
	assert_eq(minion.health, minion.max_health)

func test_charge_grants_immediate_attack() -> void:
	var data := _make_data(2, 5)
	var charge_choice := KeywordChoice.new()
	charge_choice.name_fr = "Assaut"
	data.keywords = [charge_choice]
	var minion := Minion.new(data)
	assert_eq(minion.attacks_remaining, 1, "ASSAUT (CHARGE) doit permettre d'attaquer dès la pose")

func test_no_charge_means_no_attack_on_summon() -> void:
	var minion := Minion.new(_make_data(2, 5))
	assert_eq(minion.attacks_remaining, 0)

func test_refresh_attacks_grants_two_with_fury() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.add_keyword(Keyword.Type.FURY)
	minion.refresh_attacks()
	assert_eq(minion.attacks_remaining, 2, "FRÉNÉSIE (FURY) doit accorder deux attaques par tour")

func test_refresh_attacks_frozen_skips_attacks_and_decrements() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.frozen_turns = 2
	minion.refresh_attacks()
	assert_eq(minion.attacks_remaining, 0, "un serviteur gelé ne peut pas attaquer")
	assert_eq(minion.frozen_turns, 1, "le compteur de gel doit décroître d'un tour")

func test_consume_attack_never_goes_negative() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.consume_attack()
	assert_eq(minion.attacks_remaining, 0)

func test_apply_corruption_reduces_base_attack_and_stacks() -> void:
	var minion := Minion.new(_make_data(4, 5))
	minion.apply_corruption(2)
	assert_eq(minion.attack, 2)
	assert_eq(minion.corruption_stacks, 2)
	minion.apply_corruption(5)
	assert_eq(minion.attack, 0, "l'attaque ne doit jamais devenir négative")

func test_corruption_immune_keyword_blocks_corruption() -> void:
	var minion := Minion.new(_make_data(4, 5))
	minion.add_demon_keyword(KeywordDemon.Type.CHAIR_DE_SOUFRE)
	minion.apply_corruption(2)
	assert_eq(minion.attack, 4, "CHAIR DE SOUFRE doit immuniser contre la Corruption")
	assert_eq(minion.corruption_stacks, 0)

func test_infected_blocked_by_chair_morte() -> void:
	var minion := Minion.new(_make_data(2, 5))
	minion.undead_keywords.append(KeywordUndead.Type.CHAIR_MORTE)
	minion.infected = true
	assert_false(minion.infected, "CHAIR MORTE doit bloquer l'Infection")

func test_apply_infection_sets_duration_and_infector() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(3, true)
	assert_eq(minion.infection_turns, 3, "la durée posée doit être conservée telle quelle")
	assert_true(minion.infection_infector_is_player, "l'infecteur doit être mémorisé")
	assert_true(minion.infected)

func test_reapplying_infection_takes_the_longest_duration_never_adds() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(3, true)
	minion.apply_infection(2, true)
	assert_eq(minion.infection_turns, 3, "une durée plus courte ne doit pas raccourcir la marque en place")
	minion.apply_infection(5, true)
	assert_eq(minion.infection_turns, 5, "une durée plus longue remplace la durée restante (jamais additive)")

func test_reapplying_infection_changes_the_infector() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(2, true)
	minion.apply_infection(4, false)
	assert_false(minion.infection_infector_is_player, "l'infecteur devient celui de la dernière application")

func test_infected_false_clears_the_whole_mark() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(4, true)
	minion.infected = false
	assert_eq(minion.infection_turns, 0, "la guérison efface tout le compteur d'un coup")
	assert_false(minion.infected)

func test_chair_morte_blocks_new_infection_but_not_an_existing_one() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(2, true)
	minion.undead_keywords.append(KeywordUndead.Type.CHAIR_MORTE)
	minion.apply_infection(5, true)
	assert_eq(minion.infection_turns, 2, "CHAIR MORTE ne doit bloquer que les NOUVELLES marques")

func test_apply_infection_ignores_a_zero_or_negative_duration() -> void:
	var minion := Minion.new(_make_data(2, 40), false)
	minion.apply_infection(0, true)
	assert_false(minion.infected, "une durée nulle ne pose aucune marque")
