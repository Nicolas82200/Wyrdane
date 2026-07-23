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
	var shown_cards: int = scene.shop_front_row.get_child_count() + scene.shop_back_row.get_child_count()
	assert_eq(shown_cards, ArenaConstants.SHOP_SIZE, "chaque carte proposée doit être visible dans la rangée Avant ou Arrière de la boutique")

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

func test_shop_cards_are_routed_to_the_row_matching_their_board_position() -> void:
	# Laisse d'abord le premier queue_free() (déclenché par _start_match() dans
	# before_each) se terminer, sinon les enfants de la boutique initiale sont
	# encore comptés en plus des nouveaux (queue_free() est différé).
	await get_tree().process_frame
	var front_card := CardData.new()
	front_card.card_name = "FrontOffer"
	front_card.card_type = "Minion"
	front_card.board_position = "Front"
	var back_card := CardData.new()
	back_card.card_name = "BackOffer"
	back_card.card_type = "Minion"
	back_card.board_position = "Back"
	var offer: Array[CardData] = [front_card, back_card, null, null, null]
	scene.human.shop_offer = offer
	scene._refresh_ui()
	await get_tree().process_frame
	assert_eq(scene.shop_front_row.get_child_count(), 1, "une carte board_position=Front doit apparaître dans la rangée Avant de la boutique")
	assert_eq(scene.shop_back_row.get_child_count(), 1, "une carte board_position=Back doit apparaître dans la rangée Arrière de la boutique")

func test_clicking_a_bot_portrait_switches_the_displayed_board_read_only() -> void:
	assert_eq(scene.viewed_target, scene.human, "par défaut, on consulte son propre plateau")
	var bot: ArenaPlayerState = scene.bots[0]
	scene._on_view_board_pressed(bot)
	assert_eq(scene.viewed_target, bot)
	assert_eq(scene.front_row.on_drop, Callable(), "le plateau d'un autre joueur ne doit pas accepter d'achat par drop")

	scene._on_view_board_pressed(scene.human)
	assert_eq(scene.viewed_target, scene.human)
	assert_true(scene.front_row.on_drop.is_valid(), "revenir sur son propre plateau doit réactiver le drop d'achat")

func test_viewed_target_resets_to_self_if_eliminated() -> void:
	var bot: ArenaPlayerState = scene.bots[0]
	scene._on_view_board_pressed(bot)
	bot.is_eliminated = true
	scene._refresh_ui()
	assert_eq(scene.viewed_target, scene.human, "consulter un plateau qui vient d'être éliminé doit revenir sur le sien")
