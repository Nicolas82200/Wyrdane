extends GutTest

# Couvre les quatre changements de moteur de la passe de corrections de cartes
# du 2026-10-01 (voir devlogs/) :
#  - CardEffect.mutation_outcome : mutation forcée (Rituel de la Chair Qui Recoud)
#  - CardEffect.prompt_target    : l'effet demande sa propre cible (Faucheur des Abysses)
#  - GroupAttackImmediate        : count_race filtre les ATTAQUANTS (Frappe Coordonnée)
#  - Resurrect                   : ne ramène jamais la source (Commandant des Derniers)

var effect_manager: EffectManager
var battle: FakeBattle

func before_each() -> void:
	effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()

func _card(name: String, race: int, attack: int = 2, health: int = 2) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.race = race
	data.attack = attack
	data.health = health
	return data

func _minion(name: String, race: int, is_player: bool = true, attack: int = 2, health: int = 2) -> Minion:
	var minion := Minion.new(_card(name, race, attack, health), is_player, "Front")
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── mutation_outcome ─────────────────────────────────────────────────────────

func test_forced_mutation_outcome_ignores_the_roll() -> void:
	# Graine qui donnerait Dégénérescence sans forçage (voir test_abomination_mutation).
	battle.game_rng.seed = 1
	var minion := _minion("MUTANT", Race.Type.ABOMINATION, true, 3, 5)
	await effect_manager.roll_mutation(battle, minion, "Renforcement")
	assert_eq(minion.base_attack, 3, "Renforcement forcé ne touche pas l'ATK")
	assert_eq(minion.base_max_health, 7, "Renforcement forcé : +2 HP max")
	assert_eq(minion.mutations, ["Renforcement"])

func test_apply_mutation_passes_the_forced_outcome() -> void:
	battle.game_rng.seed = 1  # Dégénérescence si non forcé
	var minion := _minion("MUTANT", Race.Type.ABOMINATION, true, 3, 5)
	var effect := CardEffect.new()
	effect.effect_id = "ApplyMutation"
	effect.target = "RandomAlly"
	effect.race_filter = "Abomination"
	effect.mutation_outcome = "Renforcement"
	await effect_manager.execute_effect(battle, null, effect)
	assert_eq(minion.mutations, ["Renforcement"])

# ─── prompt_target ────────────────────────────────────────────────────────────

func test_prompt_target_effect_asks_for_its_own_target() -> void:
	var source := _minion("SOURCE", Race.Type.DEMON)
	var already_chosen := _minion("DEJA_CIBLE", Race.Type.UNDEAD, false)
	var second := _minion("SECONDE_CIBLE", Race.Type.UNDEAD, false)
	battle.targeting_system.next_prompt_target = second

	var effect := CardEffect.new()
	effect.effect_id = "Destroy"
	effect.target = "EnemyMinion"
	effect.prompt_target = true
	await effect_manager.execute_effect(battle, source, effect, already_chosen)

	assert_eq(battle.targeting_system.prompt_calls.size(), 1, "une demande de cible")
	assert_true(second.is_dead(), "la cible demandée est détruite")
	assert_false(already_chosen.is_dead(), "la cible déjà choisie est ignorée")

func test_prompt_target_without_any_valid_target_does_nothing() -> void:
	var source := _minion("SOURCE", Race.Type.DEMON)
	var effect := CardEffect.new()
	effect.effect_id = "Destroy"
	effect.target = "EnemyMinion"
	effect.prompt_target = true
	await effect_manager.execute_effect(battle, source, effect)
	assert_eq(battle.targeting_system.prompt_calls.size(), 0, "aucun ennemi : pas de demande")

# ─── GroupAttackImmediate ─────────────────────────────────────────────────────

func test_group_attack_filters_attackers_not_the_target() -> void:
	var human_a := _minion("HUMAIN_A", Race.Type.HUMAN, true, 3, 5)
	var human_b := _minion("HUMAIN_B", Race.Type.HUMAN, true, 3, 5)
	_minion("MORT_VIVANT_ALLIE", Race.Type.UNDEAD, true, 9, 9)
	# Cible NON Humaine : c'est tout l'intérêt du correctif (race_filter la
	# rendait invalide et la carte injouable).
	var target := _minion("CIBLE", Race.Type.DEMON, false, 0, 10)

	var effect := CardEffect.new()
	effect.effect_id = "GroupAttackImmediate"
	effect.target = "EnemyMinion"
	effect.count = 2
	effect.count_race = "Human"
	await effect_manager.execute_effect(battle, null, effect, target)

	var resolved: Array = battle.combat_system.resolved
	assert_eq(resolved.size(), 2, "exactement 2 attaquants")
	assert_eq(resolved[0]["attacker"], human_a)
	assert_eq(resolved[1]["attacker"], human_b)
	assert_eq(target.health, 4, "10 - 3 - 3")

# ─── Resurrect : jamais la source ─────────────────────────────────────────────

func test_resurrect_never_brings_back_its_own_source() -> void:
	var commander_card := _card("COMMANDANT", Race.Type.HUMAN)
	var other_card := _card("SOLDAT", Race.Type.HUMAN)
	# Comme en jeu, la source est déjà au cimetière quand son Dernier Souffle
	# se déclenche (DeathSystem._send_to_graveyards précède _trigger_deathrattle).
	battle.player_graveyard.add_minion(other_card)
	battle.player_graveyard.add_minion(commander_card)
	var source := Minion.new(commander_card, true, "Front")

	var effect := CardEffect.new()
	effect.effect_id = "Resurrect"
	effect.count = 3
	effect.race_filter = "Human"
	effect.revive_with_one_hp = true
	await effect_manager.execute_effect(battle, source, effect)

	var names: Array = battle.player_minions.map(func(m: Minion): return m.card_data.card_name)
	assert_eq(names, ["SOLDAT"], "seul l'autre Humain revient")
