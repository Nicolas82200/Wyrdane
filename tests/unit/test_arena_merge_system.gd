extends GutTest

func _make_card(name: String, cost: int, path: String, atk: int = 2, hp: int = 2) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	data.attack = atk
	data.health = hp
	return data

func test_three_identical_copies_merge_into_two_star() -> void:
	var card := _make_card("Grunt", 1, "res://fake/merge_grunt.tres", 2, 2)
	var player := ArenaPlayerState.new("Player")
	for i in 3:
		player.hand.append(Minion.new(card, true, "Front"))
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	assert_eq(player.hand.size(), 1, "les 3 copies doivent être remplacées par 1 seule carte 2★")
	var merged: Minion = player.hand[0]
	assert_eq(merged.star_level, 2)
	assert_eq(merged.base_attack, 6, "stats additionnées (2+2+2)")
	assert_eq(merged.base_max_health, 6)

func test_merge_sums_permanent_buffs_already_acquired() -> void:
	var card := _make_card("Grunt", 1, "res://fake/merge_buffed.tres", 2, 2)
	var player := ArenaPlayerState.new("Player")
	var buffed := Minion.new(card, true, "Front")
	buffed.base_attack += 3  # buff permanent type NÉCROPHAGE déjà acquis
	buffed.base_max_health += 3
	player.hand.append(buffed)
	player.hand.append(Minion.new(card, true, "Front"))
	player.hand.append(Minion.new(card, true, "Front"))
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	var merged: Minion = player.hand[0]
	assert_eq(merged.base_attack, 2 + 2 + 5, "le buff permanent déjà acquis doit être conservé dans la somme")

func test_merge_frees_board_slot_when_source_was_placed() -> void:
	var card := _make_card("Grunt", 1, "res://fake/merge_board.tres")
	var player := ArenaPlayerState.new("Player")
	var on_board := Minion.new(card, true, "Front")
	player.hand.append(on_board)
	player.place_on_board(on_board, true)
	player.hand.append(Minion.new(card, true, "Front"))
	player.hand.append(Minion.new(card, true, "Front"))
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	assert_true(player.board_front.is_empty(), "la case du plateau occupée par une source fusionnée doit être libérée")
	assert_eq(player.hand.size(), 1, "le résultat de la fusion va toujours en main")

func test_merge_respects_hand_suspension_when_full() -> void:
	var merge_card := _make_card("Grunt", 1, "res://fake/merge_over.tres")
	var player := ArenaPlayerState.new("Player")
	# Chaque "filler" a un chemin distinct pour ne pas déclencher lui-même
	# une fusion (seules les 3 copies de merge_card doivent fusionner ici).
	for i in ArenaConstants.HAND_MAX:
		player.hand.append(Minion.new(_make_card("Filler%d" % i, 1, "res://fake/merge_filler_%d.tres" % i)))
	player.hand.append(Minion.new(merge_card, true, "Front"))
	player.hand.append(Minion.new(merge_card, true, "Front"))
	player.hand.append(Minion.new(merge_card, true, "Front"))
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	assert_true(player.suspended.size() >= 1, "main pleine -> le résultat de fusion doit être mis en suspens")

func test_merge_detects_a_copy_sitting_in_suspended() -> void:
	# Une carte peut se retrouver en suspens (main pleine au moment de son
	# ajout, voir add_to_hand) avant même d'avoir pu fusionner — la détection
	# doit quand même la trouver, pas seulement main+plateau.
	var card := _make_card("Grunt", 1, "res://fake/merge_suspended.tres")
	var player := ArenaPlayerState.new("Player")
	player.hand.append(Minion.new(card, true, "Front"))
	player.hand.append(Minion.new(card, true, "Front"))
	player.suspended.append(Minion.new(card, true, "Front"))
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	assert_true(player.suspended.is_empty(), "la copie suspendue source doit être consommée par la fusion")
	var merged: Array[Minion] = player.hand.filter(func(m: Minion): return m.star_level == 2)
	assert_eq(merged.size(), 1, "les 3 copies (main+suspens) doivent fusionner en une carte 2★")

func test_three_copies_of_an_already_2_star_card_never_merge_further() -> void:
	# Pas de carte 3★ dans ce jeu : la 2★ dorée est déjà la version maximale.
	# Un cas rare (3 copies 2★ de la même carte réunies) ne doit jamais
	# produire une "3★" — elles restent 3 cartes 2★ séparées.
	var card := _make_card("Grunt", 1, "res://fake/merge_already_2star.tres")
	var player := ArenaPlayerState.new("Player")
	for i in 3:
		var m := Minion.new(card, true, "Front")
		m.star_level = 2
		player.hand.append(m)
	var merge := ArenaMergeSystem.new()
	merge.try_merge_all(player)
	assert_eq(player.hand.size(), 3, "3 copies déjà 2★ ne doivent jamais fusionner entre elles")
	for m in player.hand:
		assert_eq((m as Minion).star_level, 2, "aucune carte 3★ ne doit apparaître")
