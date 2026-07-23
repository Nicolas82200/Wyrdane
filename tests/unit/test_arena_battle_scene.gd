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
	# le reste de la main en Avant, puis résout le combat (normalement déclenché
	# par l'expiration du minuteur de phase, voir _on_phase_timer_timeout).
	for i in scene.human.shop_offer.size():
		if scene.human.shop_offer[i] != null and scene.human.shop_offer[i].cost <= scene.human.gold:
			scene._on_shop_card_dropped(i, true)
			break
	for minion in scene.human.hand.duplicate():
		scene._on_place_pressed(minion, true)
	await scene._resolve_combat_phase()
	assert_true(scene.match_.round_number == 1, "le round n'avance qu'après la phase Combat")
	if not scene.game_over:
		scene._advance_round()
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

func test_dragging_a_board_minion_reorders_it_within_its_own_row() -> void:
	var card_a := CardData.new()
	card_a.card_name = "A"
	var card_b := CardData.new()
	card_b.card_name = "B"
	var minion_a := Minion.new(card_a, true, "Front")
	var minion_b := Minion.new(card_b, true, "Front")
	scene.human.board_front.append(minion_a)
	scene.human.board_front.append(minion_b)
	scene._on_board_minion_dropped(minion_b, true, 0)
	assert_eq(scene.human.board_front, [minion_b, minion_a], "le serviteur doit changer de place au sein de sa ligne")

func test_a_board_minion_cannot_be_dropped_on_the_other_row() -> void:
	var card := CardData.new()
	card.card_name = "Filler"
	var minion := Minion.new(card, true, "Front")
	scene.human.board_front.append(minion)
	assert_false(scene.back_row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}),
		"un serviteur de l'Avant ne doit pas pouvoir être lâché sur l'Arrière")
	assert_true(scene.front_row._can_drop_data(Vector2.ZERO, {"arena_board_minion": minion}),
		"un serviteur de l'Avant doit pouvoir être lâché sur sa propre ligne")

func test_dragging_a_board_minion_onto_the_shop_sells_it() -> void:
	var card := CardData.new()
	card.card_name = "Filler"
	card.cost = 4
	var minion := Minion.new(card, true, "Front")
	scene.human.board_front.append(minion)
	var gold_before: int = scene.human.gold
	scene._on_board_minion_sold(minion)
	assert_false(scene.human.board_front.has(minion), "le serviteur vendu doit quitter le plateau")
	assert_gt(scene.human.gold, gold_before, "vendre doit rapporter de l'or")

func test_ghost_board_is_never_shown_as_a_clickable_portrait() -> void:
	scene.match_.ghost_board = GhostBoard.new()
	scene._refresh_ui()
	await get_tree().process_frame
	assert_eq(scene.portraits_column.get_child_count(), scene.match_.players.size(),
		"le Fantôme ne doit jamais apparaître comme un portrait cliquable")

func test_shop_is_only_interactable_during_the_shop_phase() -> void:
	assert_eq(scene.reroll_button.disabled, scene.human.gold < ArenaConstants.REROLL_COST,
		"en phase Boutique, seul l'or manquant doit désactiver le reroll")
	await scene._resolve_combat_phase()
	if not scene.game_over:
		assert_true(scene.reroll_button.disabled, "la boutique doit être désactivée pendant l'affichage du combat")

func test_hand_contains_both_minions_and_purchased_spells_together() -> void:
	# Une seule main : pas de zone séparée pour les Incantations achetées.
	var minion_card := CardData.new()
	minion_card.card_name = "Filler"
	scene.human.hand.append(Minion.new(minion_card, true, "Front"))
	var spell_card := CardData.new()
	spell_card.card_name = "Buff"
	spell_card.card_type = "Instant"
	scene.human.spell_hand.append(spell_card)
	scene._refresh_ui()
	await get_tree().process_frame
	assert_eq(scene.hand.container.get_child_count(), 2,
		"la main doit afficher le serviteur et l'Incantation ensemble")

func test_dropping_a_purchased_spell_onto_the_board_casts_it() -> void:
	var spell_card := CardData.new()
	spell_card.card_name = "Buff"
	spell_card.card_type = "Instant"
	spell_card.effects = []
	scene.human.spell_hand.append(spell_card)
	await scene._on_hand_card_played(spell_card, scene.ROW_FRONT, -1)
	assert_false(scene.human.spell_hand.has(spell_card), "l'Incantation lancée doit quitter la main")

func test_dropping_a_purchased_spell_onto_the_shop_sells_it() -> void:
	var spell_card := CardData.new()
	spell_card.card_name = "Buff"
	spell_card.card_type = "Instant"
	spell_card.cost = 3
	scene.human.spell_hand.append(spell_card)
	var gold_before: int = scene.human.gold
	scene._on_hand_card_played(spell_card, ArenaDropSystem.ROW_SHOP, -1)
	assert_false(scene.human.spell_hand.has(spell_card), "l'Incantation vendue doit quitter la main")
	assert_gt(scene.human.gold, gold_before, "vendre l'Incantation doit rapporter de l'or")
