extends GutTest

# Couvre TempEffectSystem (scripts/systems/TempEffectSystem.gd) : effets à
# durée limitée (stats, mots-clés, immunité, silence, destruction différée)
# et leur expiration en fin de tour joueur/adverse. Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet (voir CLAUDE.md).

var temp_effect_system: TempEffectSystem
var battle: FakeBattle

func before_each() -> void:
	temp_effect_system = load("res://scripts/systems/TempEffectSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	temp_effect_system.init(battle)

func _minion(attack: int = 2, health: int = 4, is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = attack
	data.health = health
	var minion := Minion.new(data, is_player)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── Enregistrement / lecture ─────────────────────────────────────────────────

func test_add_temp_stat_change_is_reflected_in_get_temp_stat_delta() -> void:
	var minion := _minion()
	temp_effect_system.add_temp_stat_change(minion, 2, 3, "UntilEndOfTurn")
	assert_eq(temp_effect_system.get_temp_stat_delta(minion), Vector2i(2, 3))

func test_get_temp_stat_delta_sums_multiple_entries() -> void:
	var minion := _minion()
	temp_effect_system.add_temp_stat_change(minion, 1, 1, "UntilEndOfTurn")
	temp_effect_system.add_temp_stat_change(minion, 2, -1, "UntilEndOfEnemyTurn")
	assert_eq(temp_effect_system.get_temp_stat_delta(minion), Vector2i(3, 0))

func test_get_temp_stat_delta_ignores_other_minions() -> void:
	var minion_a := _minion()
	var minion_b := _minion()
	temp_effect_system.add_temp_stat_change(minion_a, 5, 5, "UntilEndOfTurn")
	assert_eq(temp_effect_system.get_temp_stat_delta(minion_b), Vector2i.ZERO)

func test_permanent_duration_registers_nothing() -> void:
	var minion := _minion()
	temp_effect_system.add_temp_stat_change(minion, 3, 3, "Permanent")
	assert_eq(temp_effect_system.get_temp_stat_delta(minion), Vector2i.ZERO,
		"une durée Permanent ne doit jamais être suivie par TempEffectSystem")

func test_null_minion_does_not_crash() -> void:
	temp_effect_system.add_temp_stat_change(null, 1, 1, "UntilEndOfTurn")
	temp_effect_system.add_temp_keyword(null, Keyword.Type.FURY, false, "UntilEndOfTurn")
	# Aucune assertion nécessaire : le test réussit s'il n'y a pas de crash.
	pass_test("pas de crash avec un minion null")

# ─── Expiration : stats ────────────────────────────────────────────────────────

func test_expire_end_of_player_turn_reverts_matching_stat_change() -> void:
	var minion := _minion(2, 4)
	temp_effect_system.add_temp_stat_change(minion, 3, 2, "UntilEndOfTurn")
	assert_eq(minion.base_attack, 2)
	minion.base_attack += 3
	minion.base_max_health += 2
	await temp_effect_system.expire_end_of_player_turn()
	assert_eq(minion.base_attack, 2, "le buff temporaire doit être retiré à l'expiration")
	assert_eq(minion.base_max_health, 4, "le buff temporaire doit être retiré à l'expiration")

func test_expire_end_of_player_turn_does_not_revert_enemy_turn_duration() -> void:
	var minion := _minion(2, 4)
	minion.base_attack += 3
	temp_effect_system.add_temp_stat_change(minion, 3, 0, "UntilEndOfEnemyTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_eq(minion.base_attack, 5, "UntilEndOfEnemyTurn ne doit expirer qu'en fin de tour adverse")

func test_expire_end_of_enemy_turn_reverts_matching_duration() -> void:
	var minion := _minion(2, 4)
	minion.base_attack += 3
	temp_effect_system.add_temp_stat_change(minion, 3, 0, "UntilEndOfEnemyTurn")
	await temp_effect_system.expire_end_of_enemy_turn()
	assert_eq(minion.base_attack, 2)

func test_expired_entry_is_not_reapplied_twice() -> void:
	var minion := _minion(2, 4)
	minion.base_attack += 3
	temp_effect_system.add_temp_stat_change(minion, 3, 0, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	await temp_effect_system.expire_end_of_player_turn()
	assert_eq(minion.base_attack, 2, "une entrée déjà expirée ne doit pas être revert une seconde fois")

# ─── Expiration : mots-clés ────────────────────────────────────────────────────

func test_expire_reverts_temp_keyword_non_human() -> void:
	var minion := _minion()
	minion.add_keyword(Keyword.Type.FURY)
	temp_effect_system.add_temp_keyword(minion, Keyword.Type.FURY, false, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.has_keyword(Keyword.Type.FURY))

func test_expire_reverts_temp_keyword_human() -> void:
	var minion := _minion()
	minion.add_human_keyword(KeywordHuman.Type.DISCIPLINE)
	temp_effect_system.add_temp_keyword(minion, KeywordHuman.Type.DISCIPLINE, true, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.has_human_keyword(KeywordHuman.Type.DISCIPLINE))

func test_expire_reverts_temp_demon_keyword() -> void:
	var minion := _minion()
	minion.add_demon_keyword(KeywordDemon.Type.TERREUR)
	temp_effect_system.add_temp_demon_keyword(minion, KeywordDemon.Type.TERREUR, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.has_demon_keyword(KeywordDemon.Type.TERREUR))

func test_expire_reverts_temp_abomination_keyword() -> void:
	var minion := _minion()
	minion.add_abomination_keyword(KeywordAbomination.Type.VIRULENT)
	temp_effect_system.add_temp_abomination_keyword(minion, KeywordAbomination.Type.VIRULENT, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.has_abomination_keyword(KeywordAbomination.Type.VIRULENT))

# ─── Expiration : immunité aux sorts / silence / destruction ──────────────────

func test_expire_reverts_temp_spell_immunity() -> void:
	var minion := _minion()
	minion.spell_immune = true
	temp_effect_system.add_temp_spell_immunity(minion, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.spell_immune)

func test_expire_restores_keywords_after_temp_silence() -> void:
	var minion := _minion()
	minion.add_keyword(Keyword.Type.TAUNT)
	minion.add_human_keyword(KeywordHuman.Type.FORTIFICATION)
	temp_effect_system.add_temp_silence(minion, "UntilEndOfTurn")
	# EffectManager viderait normalement les tableaux au moment du Silence ;
	# on simule ce même effet ici pour vérifier la restauration.
	minion.keywords.clear()
	minion.human_keywords.clear()
	minion.silenced = true
	await temp_effect_system.expire_end_of_player_turn()
	assert_true(minion.has_keyword(Keyword.Type.TAUNT), "les mots-clés capturés avant le Silence doivent être restaurés")
	assert_true(minion.has_human_keyword(KeywordHuman.Type.FORTIFICATION))
	assert_false(minion.silenced)

func test_add_temp_silence_with_permanent_duration_captures_nothing() -> void:
	var minion := _minion()
	minion.add_keyword(Keyword.Type.TAUNT)
	temp_effect_system.add_temp_silence(minion, "Permanent")
	minion.keywords.clear()
	await temp_effect_system.expire_end_of_player_turn()
	assert_false(minion.has_keyword(Keyword.Type.TAUNT), "un Silence Permanent ne doit jamais être restauré")

func test_expire_destroys_minion_registered_via_add_destroy_at_expiry() -> void:
	var minion := _minion(2, 4)
	temp_effect_system.add_destroy_at_expiry(minion, "UntilEndOfTurn")
	await temp_effect_system.expire_end_of_player_turn()
	assert_true(minion.is_dead(), "le serviteur emprunté temporairement doit mourir à l'expiration")

# ─── Garde-fou : minion mort ou retiré du plateau ─────────────────────────────

func test_revert_is_skipped_for_minion_no_longer_on_board() -> void:
	var minion := _minion(2, 4)
	minion.base_attack += 3
	temp_effect_system.add_temp_stat_change(minion, 3, 0, "UntilEndOfTurn")
	battle.player_minions.erase(minion)
	await temp_effect_system.expire_end_of_player_turn()
	assert_eq(minion.base_attack, 5, "un serviteur retiré du plateau (mort/volé) ne doit pas être revert")

func test_revert_is_skipped_for_already_dead_minion() -> void:
	var minion := _minion(2, 4)
	minion.base_attack += 3
	temp_effect_system.add_temp_stat_change(minion, 3, 0, "UntilEndOfTurn")
	minion.health = 0
	await temp_effect_system.expire_end_of_player_turn()
	assert_eq(minion.base_attack, 5, "un serviteur déjà mort ne doit pas être revert")
