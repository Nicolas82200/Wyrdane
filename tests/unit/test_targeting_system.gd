extends GutTest

# Couvre TargetingSystem (scripts/systems/TargetingSystem.gd), la partie
# testable sans dépendance de scène : validation d'une cible (serviteur/
# enchantement) pour un effet, et disponibilité d'au moins une cible valide
# (has_any_valid_target). init() crée normalement une ArrowOverlay + un
# CanvasLayer ajoutés à `battle` (un vrai Node) : FakeBattle étant un
# RefCounted, on affecte `battle` directement plutôt que d'appeler init(),
# ce qui suffit puisque aucune des méthodes couvertes ici ne touche à la
# flèche de ciblage. Utilise FakeBattle (tests/unit/doubles/fake_battle.gd),
# conformément à la convention GUT du projet (voir CLAUDE.md).

var targeting_system: TargetingSystem
var battle: FakeBattle

func before_each() -> void:
	targeting_system = load("res://scripts/systems/TargetingSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	targeting_system.battle = battle

func after_each() -> void:
	targeting_system.free()

func _minion(is_player: bool, race: int = Race.Type.NONE, attack: int = 2, health: int = 3, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_TARGET"
	data.race = race
	data.attack = attack
	data.health = health
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func _card_with_effect(target: String, card_type: String = "Instant") -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_SPELL"
	data.card_type = card_type
	var effect := CardEffect.new()
	effect.target = target
	data.effects = [effect]
	return data

# ─── _is_valid_target_minion ────────────────────────────────────────────────────

func test_enemy_minion_target_rejects_own_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	var ally := _minion(true)
	assert_false(targeting_system._is_valid_target_minion(ally, card))

func test_enemy_minion_target_accepts_enemy_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	var enemy := _minion(false)
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

func test_ally_minion_target_rejects_enemy_minion() -> void:
	var card := _card_with_effect("AllyMinion")
	var enemy := _minion(false)
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_ally_minion_target_accepts_own_minion() -> void:
	var card := _card_with_effect("AllyMinion")
	var ally := _minion(true)
	assert_true(targeting_system._is_valid_target_minion(ally, card))

func test_any_minion_target_accepts_both_camps() -> void:
	var card := _card_with_effect("AnyMinion")
	assert_true(targeting_system._is_valid_target_minion(_minion(true), card))
	assert_true(targeting_system._is_valid_target_minion(_minion(false), card))

func test_target_type_not_matching_a_minion_pool_is_rejected() -> void:
	var card := _card_with_effect("EnemyHero")
	assert_false(targeting_system._is_valid_target_minion(_minion(false), card))

func test_null_card_data_is_never_a_valid_target() -> void:
	assert_false(targeting_system._is_valid_target_minion(_minion(false), null))

func test_card_with_no_effects_is_never_a_valid_target() -> void:
	var data := CardData.new()
	assert_false(targeting_system._is_valid_target_minion(_minion(false), data))

func test_spell_immune_enemy_minion_blocks_instant_spell() -> void:
	var card := _card_with_effect("EnemyMinion", "Instant")
	var enemy := _minion(false)
	enemy.spell_immune = true
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_spell_immune_enemy_minion_does_not_block_minion_effects() -> void:
	# spell_immune ne protège que des sorts/rituels, pas des effets de pose
	# de serviteur (ex : Invocation d'un allié qui cible aussi les ennemis).
	var card := _card_with_effect("EnemyMinion", "Minion")
	var enemy := _minion(false)
	enemy.spell_immune = true
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

func test_spell_immune_does_not_block_targeting_own_minion() -> void:
	# spell_immune ne bloque que les cibles ennemies.
	var card := _card_with_effect("AllyMinion", "Instant")
	var ally := _minion(true)
	ally.spell_immune = true
	assert_true(targeting_system._is_valid_target_minion(ally, card))

# ─── _matches_effect_conditions (via _is_valid_target_minion) ──────────────────

func test_race_filter_rejects_mismatched_race() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].race_filter = "Undead"
	var enemy := _minion(false, Race.Type.HUMAN)
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_race_filter_accepts_matching_race() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].race_filter = "Undead"
	var enemy := _minion(false, Race.Type.UNDEAD)
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

func test_row_filter_rejects_mismatched_row() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].row_filter = "Back"
	var enemy := _minion(false, Race.Type.NONE, 2, 3, "Front")
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_max_hp_threshold_rejects_minion_above_threshold() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].target_max_hp = 3
	var enemy := _minion(false, Race.Type.NONE, 2, 5)
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_max_hp_threshold_accepts_minion_at_or_below_threshold() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].target_max_hp = 3
	var enemy := _minion(false, Race.Type.NONE, 2, 3)
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

func test_max_atk_threshold_rejects_minion_above_threshold() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].target_max_atk = 2
	var enemy := _minion(false, Race.Type.NONE, 5, 3)
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_max_cost_threshold_rejects_minion_above_threshold() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].target_max_cost = 2
	var enemy := _minion(false, Race.Type.NONE, 2, 3)
	enemy.card_data.cost = 3
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_max_cost_threshold_accepts_minion_at_or_below_threshold() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].target_max_cost = 2
	var enemy := _minion(false, Race.Type.NONE, 2, 3)
	enemy.card_data.cost = 2
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

func test_requires_resurrected_target_rejects_non_resurrected_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].requires_resurrected_target = true
	var enemy := _minion(false)
	assert_false(targeting_system._is_valid_target_minion(enemy, card))

func test_requires_resurrected_target_accepts_resurrected_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	card.effects[0].requires_resurrected_target = true
	var enemy := _minion(false)
	enemy.was_resurrected = true
	assert_true(targeting_system._is_valid_target_minion(enemy, card))

# ─── _is_valid_target_enchantment ──────────────────────────────────────────────

func test_enemy_enchantment_target_accepts_only_enemy_side() -> void:
	var pending := _card_with_effect("EnemyEnchantment")
	assert_true(targeting_system._is_valid_target_enchantment(null, false, pending))
	assert_false(targeting_system._is_valid_target_enchantment(null, true, pending))

func test_ally_enchantment_target_accepts_only_own_side() -> void:
	var pending := _card_with_effect("AllyEnchantment")
	assert_true(targeting_system._is_valid_target_enchantment(null, true, pending))
	assert_false(targeting_system._is_valid_target_enchantment(null, false, pending))

func test_any_enchantment_target_accepts_both_sides() -> void:
	var pending := _card_with_effect("AnyEnchantment")
	assert_true(targeting_system._is_valid_target_enchantment(null, true, pending))
	assert_true(targeting_system._is_valid_target_enchantment(null, false, pending))

func test_enchantment_target_rejects_non_enchantment_effect() -> void:
	var pending := _card_with_effect("EnemyMinion")
	assert_false(targeting_system._is_valid_target_enchantment(null, false, pending))

func test_enchantment_target_rejects_null_pending_card() -> void:
	assert_false(targeting_system._is_valid_target_enchantment(null, true, null))

# ─── has_any_valid_target ───────────────────────────────────────────────────────

func test_has_any_valid_target_true_for_card_without_effects() -> void:
	assert_true(targeting_system.has_any_valid_target(CardData.new()))

func test_has_any_valid_target_false_with_no_matching_enemy_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	assert_false(targeting_system.has_any_valid_target(card))

func test_has_any_valid_target_true_with_one_matching_enemy_minion() -> void:
	var card := _card_with_effect("EnemyMinion")
	_minion(false)
	assert_true(targeting_system.has_any_valid_target(card))

func test_has_any_valid_target_false_when_enemy_enchantment_zone_is_empty() -> void:
	var card := _card_with_effect("EnemyEnchantment")
	assert_false(targeting_system.has_any_valid_target(card))

func test_has_any_valid_target_true_when_enemy_enchantment_present() -> void:
	var card := _card_with_effect("EnemyEnchantment")
	battle.enchantment_system.enemy_enchantments.append(CardData.new())
	assert_true(targeting_system.has_any_valid_target(card))

func test_has_any_valid_target_true_for_hero_target_without_board_check() -> void:
	var card := _card_with_effect("EnemyHero")
	assert_true(targeting_system.has_any_valid_target(card))
