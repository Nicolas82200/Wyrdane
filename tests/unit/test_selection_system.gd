extends GutTest

# Couvre SelectionSystem (scripts/systems/SelectionSystem.gd) : tri des
# attaquants (ordre de résolution gauche → droite) ET, depuis le passage au
# système de déclaration puis verrouillage des attaques (façon MTG Arena), la
# déclaration de paires (attaquant, cible) et leur résolution séquentielle par
# `lock_attacks()` — y compris la revalidation REMPART/FRÉNÉSIE, le point le
# plus risqué de ce système.
#
# Les clics passent un `board_minion: BoardMinion` que SelectionSystem ne
# déréférence QUE via `is_instance_valid()` (surbrillance) — jamais pour la
# logique de déclaration/résolution elle-même — donc tous les tests
# ci-dessous passent `null` à la place d'un vrai BoardMinion (scène hors
# scope GUT, voir CLAUDE.md). Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du
# projet.

var selection_system: SelectionSystem
var battle: FakeBattle

func before_each() -> void:
	selection_system = load("res://scripts/systems/SelectionSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	selection_system.init(battle)

func after_each() -> void:
	selection_system.free()

func _minion() -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_ATTACKER"
	var minion := Minion.new(data, true)
	battle.player_minions.append(minion)
	return minion

# Attaquant/cible avec stats de combat réelles (attaque/PV) pour les tests de
# déclaration + verrouillage ci-dessous.
func _make_minion(is_player: bool, atk: int, hp: int, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_MINION"
	data.attack = atk
	data.health = hp
	var minion := Minion.new(data, is_player, row)
	minion.attacks_remaining = 1
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

func test_sort_attackers_left_to_right_matches_board_order() -> void:
	var first := _minion()
	var second := _minion()
	var third := _minion()
	var unsorted: Array[Minion] = [third, first, second]
	var sorted := selection_system._sort_attackers_left_to_right(unsorted)
	assert_eq(sorted, [first, second, third])

func test_sort_attackers_left_to_right_does_not_mutate_input_array() -> void:
	var first := _minion()
	var second := _minion()
	var unsorted: Array[Minion] = [second, first]
	selection_system._sort_attackers_left_to_right(unsorted)
	assert_eq(unsorted, [second, first], "le tableau d'origine ne doit pas être modifié en place")

func test_sort_attackers_left_to_right_handles_single_attacker() -> void:
	var only := _minion()
	var sorted := selection_system._sort_attackers_left_to_right([only])
	assert_eq(sorted, [only])

# ─── Déclaration + verrouillage ─────────────────────────────────────────────────

func test_lock_resolves_heterogeneous_pairs_in_declaration_order() -> void:
	var a1 := _make_minion(true, 2, 5)
	var a2 := _make_minion(true, 2, 5)
	var a3 := _make_minion(true, 2, 5)
	# Rangée Arrière ennemie, Avant vide : les deux serviteurs restent des
	# cibles légales ET le héros ennemi reste attaquable en même temps.
	var t1 := _make_minion(false, 1, 5, "Back")
	var t2 := _make_minion(false, 1, 5, "Back")

	selection_system.on_player_minion_clicked(a1, null)
	selection_system.on_enemy_minion_clicked(t1, null)
	selection_system.on_player_minion_clicked(a2, null)
	selection_system.on_enemy_minion_clicked(t2, null)
	selection_system.on_player_minion_clicked(a3, null)
	selection_system.on_enemy_hero_clicked()

	assert_eq(selection_system.declared_pairs.size(), 3, "les 3 paires doivent être déclarées avant tout verrouillage")

	await selection_system.lock_attacks()

	assert_eq(battle.combat_system.resolved.size(), 2)
	assert_eq(battle.combat_system.resolved[0], {"attacker": a1, "defender": t1})
	assert_eq(battle.combat_system.resolved[1], {"attacker": a2, "defender": t2})
	assert_eq(battle.combat_system.hero_attacks, [a3])
	assert_true(selection_system.declared_pairs.is_empty(), "le verrouillage doit vider les paires déclarées")

func test_taunt_death_skips_later_pair_still_targeting_it() -> void:
	var rempart := _make_minion(false, 1, 3)
	rempart.keywords.append(Keyword.Type.TAUNT)
	var a1 := _make_minion(true, 5, 5)
	var a2 := _make_minion(true, 5, 5)

	selection_system.on_player_minion_clicked(a1, null)
	selection_system.on_enemy_minion_clicked(rempart, null)
	selection_system.on_player_minion_clicked(a2, null)
	selection_system.on_enemy_minion_clicked(rempart, null)
	assert_eq(selection_system.declared_pairs.size(), 2)

	await selection_system.lock_attacks()

	# a1 tue le REMPART (5 dégâts contre 3 PV) : la paire suivante qui le
	# ciblait encore doit être sautée silencieusement, sans planter.
	assert_true(rempart.is_dead())
	assert_eq(battle.combat_system.resolved.size(), 1)
	assert_eq(battle.combat_system.resolved[0]["attacker"], a1)

func test_fury_second_pair_skipped_when_first_attack_is_fatal() -> void:
	var fury_attacker := _make_minion(true, 2, 1)
	fury_attacker.keywords.append(Keyword.Type.FURY)
	fury_attacker.attacks_remaining = 2
	var target := _make_minion(false, 10, 20)

	selection_system.on_player_minion_clicked(fury_attacker, null)
	selection_system.on_enemy_minion_clicked(target, null)
	# Re-cliquer sur l'attaquant FRÉNÉSIE : il lui reste une charge d'attaque
	# déclarable (1 paire déjà déclarée < 2 attaques), donc une 2e paire est
	# déclarable plutôt qu'une annulation de la 1ère.
	selection_system.on_player_minion_clicked(fury_attacker, null)
	selection_system.on_enemy_minion_clicked(target, null)
	assert_eq(selection_system.declared_pairs.size(), 2)

	await selection_system.lock_attacks()

	# La 1ère attaque (10 dégâts subis contre 1 PV max) tue l'attaquant :
	# la 2e paire doit être sautée proprement.
	assert_true(fury_attacker.is_dead())
	assert_eq(battle.combat_system.resolved.size(), 1)

func test_removing_declared_pair_before_lock_prevents_its_resolution() -> void:
	var attacker := _make_minion(true, 3, 5)
	var target := _make_minion(false, 1, 5)

	selection_system.on_player_minion_clicked(attacker, null)
	selection_system.on_enemy_minion_clicked(target, null)
	assert_eq(selection_system.declared_pairs.size(), 1)

	# L'attaquant a déjà déclaré toute sa charge d'attaque (1/1) : re-cliquer
	# dessus retire la paire au lieu d'en déclarer une nouvelle.
	selection_system.on_player_minion_clicked(attacker, null)
	assert_true(selection_system.declared_pairs.is_empty(), "la paire doit être retirée avant tout verrouillage")

	await selection_system.lock_attacks()

	assert_true(battle.combat_system.resolved.is_empty(), "aucune attaque ne doit se résoudre pour un batch vidé avant verrouillage")
