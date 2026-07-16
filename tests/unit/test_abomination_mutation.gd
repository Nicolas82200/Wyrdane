extends GutTest

# Couvre le système de MUTATION (Abomination) : EffectManager.roll_mutation
# et son déclenchement automatique via notify_damaged (voir CLAUDE.md,
# section « Système de Ressources par Race » et CARDS.md « Race Abomination »).
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), avec un RNG seedé
# pour forcer chaque branche de la Table de Mutation de façon déterministe.

var effect_manager: EffectManager
var battle: FakeBattle

func before_each() -> void:
	effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()

func _abomination_minion(attack: int = 3, health: int = 5, keyword: int = -1) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_ABOMINATION"
	data.race = Race.Type.ABOMINATION
	data.attack = attack
	data.health = health
	if keyword != -1:
		var kw := KeywordChoiceAbomination.new()
		kw.keyword_type = keyword
		data.abomination_keywords = [kw]
	var minion := Minion.new(data, true, "Front")
	battle.player_minions.append(minion)
	return minion

func test_roll_mutation_croissance_buffs_attack() -> void:
	battle.game_rng.seed = 6  # roll % 100 == 6 -> Croissance (< 40)
	var minion := _abomination_minion(3, 5)
	await effect_manager.roll_mutation(battle, minion)
	assert_eq(minion.base_attack, 5, "Croissance : +2 ATK permanent")
	assert_eq(minion.base_max_health, 5, "Croissance ne touche pas les HP")
	assert_eq(minion.mutation_stacks, 1)
	assert_eq(minion.mutations, ["Croissance"])

func test_roll_mutation_renforcement_buffs_health() -> void:
	battle.game_rng.seed = 2  # roll % 100 == 50 -> Renforcement (40-79)
	var minion := _abomination_minion(3, 5)
	await effect_manager.roll_mutation(battle, minion)
	assert_eq(minion.base_attack, 3, "Renforcement ne touche pas l'ATK")
	assert_eq(minion.base_max_health, 7, "Renforcement : +2 HP max permanent")
	assert_eq(minion.mutations, ["Renforcement"])

func test_roll_mutation_degenerescence_weakens_minion() -> void:
	battle.game_rng.seed = 1  # roll % 100 == 97 -> Dégénérescence (>= 80)
	var minion := _abomination_minion(3, 5)
	await effect_manager.roll_mutation(battle, minion)
	assert_eq(minion.base_attack, 2, "Dégénérescence : -1 ATK permanent")
	assert_eq(minion.max_health, 4, "Dégénérescence : -1 HP max permanent")
	assert_eq(minion.mutations, ["Dégénérescence"])

func test_roll_mutation_degenerescence_can_kill_at_low_health() -> void:
	battle.game_rng.seed = 1  # Dégénérescence
	# max_health est plancherée à 1 (comme Debuff) : Dégénérescence ne peut
	# donc tuer que si le serviteur a déjà encaissé des dégâts proches de son
	# maximum courant (ici 2 HP max, 1 déjà perdu -> 1 HP restant).
	var minion := _abomination_minion(1, 2)
	minion.take_damage(1)
	assert_eq(minion.health, 1)
	await effect_manager.roll_mutation(battle, minion)
	assert_true(minion.is_dead(), "réduire le HP max sous les dégâts déjà subis doit tuer le serviteur")

func test_roll_mutation_is_cumulative() -> void:
	var minion := _abomination_minion(3, 5)
	battle.game_rng.seed = 6
	await effect_manager.roll_mutation(battle, minion)
	battle.game_rng.seed = 6
	await effect_manager.roll_mutation(battle, minion)
	assert_eq(minion.base_attack, 7, "deux Croissances doivent cumuler (+2 puis +2)")
	assert_eq(minion.mutation_stacks, 2)

func test_notify_damaged_triggers_mutation_when_survives() -> void:
	battle.game_rng.seed = 6  # Croissance
	var minion := _abomination_minion(3, 5, KeywordAbomination.Type.MUTATION)
	minion.take_damage(1)
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.mutation_stacks, 1, "MUTATION doit se déclencher à chaque blessure survécue")

func test_notify_damaged_does_not_mutate_without_keyword() -> void:
	var minion := _abomination_minion(3, 5)
	minion.take_damage(1)
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.mutation_stacks, 0, "pas de MUTATION sans le mot-clé")

func test_notify_damaged_does_not_mutate_a_dead_minion() -> void:
	var minion := _abomination_minion(3, 5, KeywordAbomination.Type.MUTATION)
	minion.take_damage(5)
	assert_true(minion.is_dead())
	await effect_manager.notify_damaged(battle, minion)
	assert_eq(minion.mutation_stacks, 0, "un serviteur mort ne survit pas à la blessure : pas de mutation")

func test_instable_blocks_heal() -> void:
	var minion := _abomination_minion(3, 5, KeywordAbomination.Type.INSTABLE)
	minion.take_damage(3)
	minion.heal(3)
	assert_eq(minion.health, 2, "INSTABLE : ce serviteur ne peut pas être soigné")

func test_apply_mutation_effect_rolls_once_per_count() -> void:
	battle.game_rng.seed = 6  # Croissance à chaque tirage
	var minion := _abomination_minion(3, 5)
	var effect := CardEffect.new()
	effect.effect_id = "ApplyMutation"
	effect.target = "Self"
	effect.count = 2
	await effect_manager.execute_effect(battle, minion, effect)
	assert_eq(minion.mutation_stacks, 2, "count=2 doit déclencher 2 mutations")
