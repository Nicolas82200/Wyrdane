extends GutTest

# Test de fumée : instancie la scène Arena headless et déroule un round
# complet via les mêmes handlers que les boutons UI, pour vérifier que la
# scène ne plante pas de bout en bout (achat, pose, combat, round suivant).

var scene: Control

func before_each() -> void:
	var packed: PackedScene = load("res://scenes/arena/ArenaBattle.tscn")
	scene = packed.instantiate()
	add_child_autofree(scene)

func test_scene_builds_ui_and_starts_a_shop_phase() -> void:
	assert_not_null(scene.match_)
	assert_eq(scene.match_.round_number, 1)
	assert_eq(scene.human.shop_offer.size(), ArenaConstants.SHOP_SIZE)
	assert_eq(scene.shop_row.get_child_count(), ArenaConstants.SHOP_SIZE)

func test_full_round_loop_does_not_crash() -> void:
	# Simule un drag & drop d'achat (ArenaShopCardSlot -> ArenaBoardRow), pose
	# le reste de la main en Avant, puis lance le combat.
	for i in scene.human.shop_offer.size():
		if scene.human.shop_offer[i] != null and scene.human.shop_offer[i].cost <= scene.human.gold:
			scene._on_shop_card_dropped(i, true)
			break
	for minion in scene.human.hand.duplicate():
		scene._on_place_pressed(minion, true)
	await scene._on_ready_pressed()
	assert_true(scene.match_.round_number == 1, "le round n'avance qu'après le bouton 'round suivant'")
	if not scene.game_over:
		scene._on_next_round_pressed()
		assert_eq(scene.match_.round_number, 2)

func test_shop_card_drop_buys_into_hand_without_placing() -> void:
	var affordable_index := -1
	for i in scene.human.shop_offer.size():
		if scene.human.shop_offer[i] != null and scene.human.shop_offer[i].cost <= scene.human.gold:
			affordable_index = i
			break
	assert_gte(affordable_index, 0, "au round 1 (or=1), au moins une carte à 1⬡ doit être proposée")
	var gold_before: int = scene.human.gold
	scene._on_shop_card_dropped(affordable_index, true)
	assert_lt(scene.human.gold, gold_before, "le drop doit débiter l'or (achat)")
	assert_eq(scene.human.hand.size(), 1, "la carte achetée doit rejoindre la main")
	assert_true(scene.human.board_front.is_empty(), "la pose reste une action séparée, pas automatique au drop")
