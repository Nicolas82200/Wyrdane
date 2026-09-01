extends GutTest

# Couvre CombatSystem (scripts/systems/CombatSystem.gd) : résolution de combat
# (dégâts mutuels, mort, AEGIS, VENIN MORTEL, LIFESTEAL, RAVAGE, CONTRE-ATTAQUE,
# PESTIFÉRÉ, CORRUPTION, TERREUR, Contre-Offensive) et perform_hero_attack().
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), étendu avec
# get_node()/animation_system/vfx_manager pour ce fichier.
#
# Point d'attention (voir CLAUDE.md) : _execute_damage() appelle
# AudioManager.play(AudioManager.HIT) directement (autoload réel, pas via
# `battle`). Test de fumée empirique : la suite complète passe sans erreur en
# mode `godot --headless -s .../gut_cmdln.gd`, l'autoload est donc bien
# disponible dans ce contexte — aucune limitation constatée.

var combat_system: CombatSystem
var battle: FakeBattle

func before_each() -> void:
	combat_system = load("res://scripts/systems/CombatSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	combat_system.init(battle)

# Note : Keyword.Type (kw) n'est PAS assignable via CardData.keywords ici, car
# KeywordChoice.keyword_type est une propriété calculée en lecture seule à
# partir de name_fr (pas de setter) — contrairement à KeywordChoiceUndead/
# Demon/Human/Abomination qui exposent un `keyword_type` @export réel. On pose
# donc les mots-clés de base directement sur le Minion via add_keyword(),
# comme le fait déjà tests/unit/test_minion.gd.
func _minion(attack: int = 2, health: int = 4, is_player: bool = true, race: int = Race.Type.UNDEAD, kw: int = -1, undead_kw: int = -1, demon_kw: int = -1, human_kw: int = -1) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.race = race
	data.attack = attack
	data.health = health
	if undead_kw != -1:
		var kwu := KeywordChoiceUndead.new()
		kwu.keyword_type = undead_kw
		data.undead_keywords = [kwu]
	if demon_kw != -1:
		var kwd := KeywordChoiceDemon.new()
		kwd.keyword_type = demon_kw
		data.demon_keywords = [kwd]
	if human_kw != -1:
		var kwh := KeywordChoiceHuman.new()
		kwh.keyword_type = human_kw
		data.human_keywords = [kwh]
	var minion := Minion.new(data, is_player)
	if kw != -1:
		minion.add_keyword(kw)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# Serviteur portant `trigger_name` + Buff(Self, +1/+0), pour vérifier
# concrètement qu'un hook de CombatSystem (OnAttack/OnExecution) s'est déclenché.
func _minion_with_trigger(trigger_name: String, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TRIGGER_CARD"
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
	data.effects = [effect]
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── Étape 0 : test de fumée (AudioManager) ─────────────────────────────────

func test_smoke_resolve_combat_does_not_crash() -> void:
	var attacker := _minion(2, 4, true)
	var defender := _minion(1, 3, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.health, 1)

# ─── Dégâts mutuels / mort ──────────────────────────────────────────────────

func test_mutual_damage_no_death() -> void:
	var attacker := _minion(3, 5, true)
	var defender := _minion(2, 4, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.health, 1, "défenseur perd 3 HP")
	assert_eq(attacker.health, 3, "attaquant perd 2 HP")
	assert_false(defender.is_dead())
	assert_false(attacker.is_dead())

func test_defender_dies_from_lethal_damage() -> void:
	var attacker := _minion(5, 5, true)
	var defender := _minion(2, 2, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())

# ─── AEGIS ───────────────────────────────────────────────────────────────────

func test_aegis_blocks_first_hit_then_breaks() -> void:
	var attacker := _minion(3, 5, true)
	var defender := _minion(2, 4, false, Race.Type.UNDEAD, Keyword.Type.AEGIS)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.health, 4, "AEGIS bloque intégralement le premier coup")
	assert_false(defender.has_keyword(Keyword.Type.AEGIS), "AEGIS est consommé")

# ─── VENIN MORTEL ────────────────────────────────────────────────────────────

func test_deadly_poison_kills_target_without_chair_morte() -> void:
	var attacker := _minion(1, 5, true, Race.Type.UNDEAD, Keyword.Type.DEADLY_POISON)
	var defender := _minion(1, 20, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.health, 0, "VENIN MORTEL tue malgré les HP restants")

func test_deadly_poison_kills_chair_morte_target() -> void:
	var attacker := _minion(1, 5, true, Race.Type.UNDEAD, Keyword.Type.DEADLY_POISON)
	var defender := _minion(1, 20, false, Race.Type.UNDEAD, -1, KeywordUndead.Type.CHAIR_MORTE)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.health, 0, "VENIN MORTEL n'est pas un effet néfaste racial : CHAIR MORTE ne l'immunise plus")

# ─── LIFESTEAL ───────────────────────────────────────────────────────────────

func test_lifesteal_heals_owner_hero() -> void:
	battle.player_hero.health = 20
	var attacker := _minion(4, 5, true, Race.Type.UNDEAD, Keyword.Type.LIFESTEAL)
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(battle.player_hero.health, 24, "LIFESTEAL soigne le héros propriétaire des dégâts infligés")

func test_lifesteal_does_not_heal_when_heal_blocked() -> void:
	battle.player_hero.health = 20
	battle.player_hero.heal_block_turns = 1
	var attacker := _minion(4, 5, true, Race.Type.UNDEAD, Keyword.Type.LIFESTEAL)
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(battle.player_hero.health, 20)

# ─── RAVAGE ──────────────────────────────────────────────────────────────────

func test_ravage_deals_excess_to_enemy_hero() -> void:
	battle.enemy_hero.health = 20
	var attacker := _minion(6, 5, true, Race.Type.UNDEAD, Keyword.Type.RAVAGE)
	var defender := _minion(1, 2, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())
	assert_eq(battle.enemy_hero.health, 16, "excédent = attaque(6) - max_health(2) = 4")

func test_ravage_excess_uses_health_before_hit_not_max_health() -> void:
	battle.enemy_hero.health = 20
	var attacker := _minion(6, 5, true, Race.Type.UNDEAD, Keyword.Type.RAVAGE)
	var defender := _minion(1, 10, false)
	defender.health = 2
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())
	assert_eq(battle.enemy_hero.health, 16, "excédent = attaque(6) - PV avant le coup(2) = 4, pas attaque - max_health(10)")

func test_ravage_blocked_by_blocks_overkill() -> void:
	battle.enemy_hero.health = 20
	var attacker := _minion(6, 5, true, Race.Type.UNDEAD, Keyword.Type.RAVAGE)
	var defender := _minion(1, 2, false)
	defender.card_data.blocks_overkill = true
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())
	assert_eq(battle.enemy_hero.health, 20, "blocks_overkill empêche l'excédent RAVAGE")

# ─── CONTRE-ATTAQUE ──────────────────────────────────────────────────────────

func test_contre_attaque_deals_counter_damage_to_attacker() -> void:
	var attacker := _minion(2, 10, true)
	var defender := _minion(3, 10, false, Race.Type.HUMAN, -1, -1, -1, KeywordHuman.Type.CONTRE_ATTAQUE)
	await combat_system.resolve_combat(attacker, defender)
	# attaquant subit 3 (combat) + 3 (riposte) = 6
	assert_eq(attacker.health, 4)

# Symétrique : un ATTAQUANT avec CONTRE-ATTAQUE qui survit aux dégâts reçus en
# attaquant riposte aussi, pas seulement le défenseur.
func test_contre_attaque_also_triggers_for_surviving_attacker() -> void:
	var attacker := _minion(2, 10, true, Race.Type.HUMAN, -1, -1, -1, KeywordHuman.Type.CONTRE_ATTAQUE)
	var defender := _minion(3, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	# défenseur subit 2 (combat) + 2 (riposte de l'attaquant) = 4
	assert_eq(defender.health, 6)

# ─── PESTIFÉRÉ ───────────────────────────────────────────────────────────────

func test_pestifere_infects_surviving_defender() -> void:
	var attacker := _minion(1, 5, true, Race.Type.UNDEAD, -1, KeywordUndead.Type.PESTIFERE)
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.infected)

func test_pestifere_does_not_infect_chair_morte() -> void:
	var attacker := _minion(1, 5, true, Race.Type.UNDEAD, -1, KeywordUndead.Type.PESTIFERE)
	var defender := _minion(1, 10, false, Race.Type.UNDEAD, -1, KeywordUndead.Type.CHAIR_MORTE)
	await combat_system.resolve_combat(attacker, defender)
	assert_false(defender.infected)

# ─── CORRUPTION ──────────────────────────────────────────────────────────────

func test_corruption_reduces_defender_base_attack() -> void:
	var attacker := _minion(1, 5, true, Race.Type.DEMON, -1, -1, KeywordDemon.Type.CORRUPTION)
	var defender := _minion(3, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.base_attack, 2)

func test_corruption_has_no_effect_on_chair_de_soufre() -> void:
	var attacker := _minion(1, 5, true, Race.Type.DEMON, -1, -1, KeywordDemon.Type.CORRUPTION)
	var defender := _minion(3, 10, false, Race.Type.DEMON, -1, -1, KeywordDemon.Type.CHAIR_DE_SOUFRE)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(defender.base_attack, 3, "CHAIR DE SOUFRE immunise contre CORRUPTION")

# ─── TERREUR ─────────────────────────────────────────────────────────────────

func test_terror_sets_terror_turns_on_surviving_defender() -> void:
	var attacker := _minion(1, 5, true, Race.Type.DEMON, -1, -1, KeywordDemon.Type.TERREUR)
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_gt(defender.terror_turns, 0)

# ─── Contre-Offensive ────────────────────────────────────────────────────────

func test_counter_offensive_grants_extra_attack_on_kill() -> void:
	battle.counter_offensive[true] = true
	var attacker := _minion(5, 5, true, Race.Type.HUMAN)
	attacker.attacks_remaining = 1
	var defender := _minion(1, 2, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())
	assert_eq(attacker.attacks_remaining, 1, "attacks_remaining incrémenté par la mise à mort puis décrémenté par consume_attack : net 0")

# ─── Triggers de combat (OnAttack / OnExecution) ────────────────────────────

func test_on_attack_fires_on_attacker_when_attacking_a_minion() -> void:
	var attacker := _minion_with_trigger("OnAttack")
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(attacker.base_attack, 3, "OnAttack doit se déclencher sur l'attaquant à chaque attaque")

func test_on_execution_fires_on_attacker_when_it_kills_the_defender() -> void:
	var attacker := _minion_with_trigger("OnExecution")
	var defender := _minion(1, 1, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_true(defender.is_dead())
	assert_eq(attacker.base_attack, 3)

func test_on_execution_does_not_fire_when_defender_survives() -> void:
	var attacker := _minion_with_trigger("OnExecution")
	var defender := _minion(1, 10, false)
	await combat_system.resolve_combat(attacker, defender)
	assert_eq(attacker.base_attack, 2, "le défenseur survit : OnExecution ne doit pas se déclencher")

# ─── perform_hero_attack ─────────────────────────────────────────────────────

func test_perform_hero_attack_deals_damage_to_enemy_hero() -> void:
	battle.enemy_hero.health = 20
	var attacker := _minion(4, 5, true)
	attacker.attacks_remaining = 1
	await combat_system.perform_hero_attack(attacker)
	assert_eq(battle.enemy_hero.health, 16)
	assert_eq(attacker.attacks_remaining, 0, "consume_attack() décrémente attacks_remaining")

func test_perform_hero_attack_with_lifesteal_heals_owner() -> void:
	battle.player_hero.health = 20
	battle.enemy_hero.health = 20
	var attacker := _minion(4, 5, true, Race.Type.UNDEAD, Keyword.Type.LIFESTEAL)
	attacker.attacks_remaining = 1
	await combat_system.perform_hero_attack(attacker)
	assert_eq(battle.player_hero.health, 24)

func test_perform_hero_attack_fires_on_attack_trigger() -> void:
	var attacker := _minion_with_trigger("OnAttack")
	attacker.attacks_remaining = 1
	await combat_system.perform_hero_attack(attacker)
	assert_eq(attacker.base_attack, 3, "OnAttack doit aussi se déclencher en attaquant directement le héros")
