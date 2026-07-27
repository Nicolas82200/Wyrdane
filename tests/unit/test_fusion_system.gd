extends GutTest

# Couvre FusionSystem (scripts/systems/FusionSystem.gd) : cœur rejouable de la
# fusion (apply_fusion, exécuté aussi bien localement que rejoué côté réseau
# via NetworkOpponent) et l'encodage/décodage du mot-clé absorbé
# (keyword_to_name/keyword_from_name), utilisé pour la transmission réseau.
# Utilise FakeBattle (tests/unit/doubles/fake_battle.gd), conformément à la
# convention GUT du projet (voir CLAUDE.md).

var fusion_system: FusionSystem
var battle: FakeBattle

func before_each() -> void:
	fusion_system = load("res://scripts/systems/FusionSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	fusion_system.init(battle)

func after_each() -> void:
	# FusionSystem extends Node : jamais ajouté à l'arbre de scène ici, donc
	# jamais libéré automatiquement (sinon GUT le compte en nœud orphelin).
	fusion_system.free()

func _minion(attack: int, health: int, is_player: bool = true) -> Minion:
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

# ─── apply_fusion : transfert de stats ────────────────────────────────────────

func test_apply_fusion_transfers_remaining_stats_to_source() -> void:
	var source := _minion(2, 3)
	var victim := _minion(4, 5)
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_eq(source.base_attack, 6, "le serviteur FUSION absorbe l'ATK restante du sacrifié")
	assert_eq(source.base_max_health, 8, "le serviteur FUSION absorbe les HP restants du sacrifié")

func test_apply_fusion_marks_victim_sacrificed_and_dead() -> void:
	var source := _minion(2, 3)
	var victim := _minion(4, 5)
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_true(victim.sacrificed, "la victime doit être marquée sacrifiée")
	assert_true(victim.is_dead(), "la victime doit mourir")

func test_apply_fusion_transfers_only_remaining_health_not_max() -> void:
	var source := _minion(1, 5)
	var victim := _minion(1, 6)
	victim.health = 2  # dégâts déjà encaissés : seul le restant (2) doit être transféré
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_eq(source.base_max_health, 7, "seuls les HP restants (pas le max) du sacrifié sont transférés")

func test_apply_fusion_without_keyword_choice_grants_nothing() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_eq(source.keywords.size(), 0)
	assert_eq(source.human_keywords.size(), 0)

# ─── apply_fusion : octroi du mot-clé choisi, par pool ────────────────────────

func test_apply_fusion_grants_base_keyword() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "keywords", Keyword.Type.FURY)
	assert_true(source.has_keyword(Keyword.Type.FURY))

func test_apply_fusion_grants_human_keyword() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "human_keywords", KeywordHuman.Type.DISCIPLINE)
	assert_true(source.has_human_keyword(KeywordHuman.Type.DISCIPLINE))

func test_apply_fusion_grants_undead_keyword() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "undead_keywords", KeywordUndead.Type.HORDE)
	assert_true(KeywordUndead.Type.HORDE in source.undead_keywords)

func test_apply_fusion_grants_demon_keyword() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "demon_keywords", KeywordDemon.Type.TERREUR)
	assert_true(source.has_demon_keyword(KeywordDemon.Type.TERREUR))

func test_apply_fusion_grants_abomination_keyword() -> void:
	var source := _minion(2, 3)
	var victim := _minion(1, 1)
	await fusion_system.apply_fusion(source, victim, "abomination_keywords", KeywordAbomination.Type.VIRULENT)
	assert_true(source.has_abomination_keyword(KeywordAbomination.Type.VIRULENT))

# ─── apply_fusion : garde-fous ─────────────────────────────────────────────────

func test_apply_fusion_noop_if_source_already_dead() -> void:
	var source := _minion(2, 3)
	source.health = 0
	var victim := _minion(4, 5)
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_false(victim.sacrificed, "aucun effet si la source FUSION est déjà morte")
	assert_eq(source.base_attack, 2)

func test_apply_fusion_noop_if_victim_already_dead() -> void:
	var source := _minion(2, 3)
	var victim := _minion(4, 5)
	victim.health = 0
	await fusion_system.apply_fusion(source, victim, "", -1)
	assert_eq(source.base_attack, 2, "aucun effet si la victime est déjà morte")
	assert_eq(source.base_max_health, 3, "aucun effet si la victime est déjà morte")

# ─── Encodage réseau du mot-clé absorbé ────────────────────────────────────────

func test_keyword_name_round_trip_for_every_pool() -> void:
	var cases := [
		["keywords", Keyword.Type.RAVAGE],
		["human_keywords", KeywordHuman.Type.FORMATION],
		["undead_keywords", KeywordUndead.Type.REVENANT],
		["demon_keywords", KeywordDemon.Type.PACTE],
		["abomination_keywords", KeywordAbomination.Type.MUTATION],
	]
	for pair in cases:
		var pool: String = pair[0]
		var keyword: int = pair[1]
		var kw_name: String = FusionSystem.keyword_to_name(pool, keyword)
		assert_ne(kw_name, "", "%s : nom vide pour le mot-clé %d" % [pool, keyword])
		assert_eq(FusionSystem.keyword_from_name(pool, kw_name), keyword,
			"%s : round-trip cassé pour %s" % [pool, kw_name])

func test_keyword_to_name_unknown_pool_returns_empty_string() -> void:
	assert_eq(FusionSystem.keyword_to_name("bogus_pool", 0), "")

func test_keyword_from_name_unknown_pool_returns_minus_one() -> void:
	assert_eq(FusionSystem.keyword_from_name("bogus_pool", "Anything"), -1)
