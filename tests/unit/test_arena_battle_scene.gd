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
	# Achète tout ce qui est abordable, pose tout en Avant, puis lance le combat.
	for i in scene.human.shop_offer.size():
		if scene.human.shop_offer[i] != null and scene.human.shop_offer[i].cost <= scene.human.gold:
			scene._on_buy_pressed(i)
			break
	for minion in scene.human.hand.duplicate():
		scene._on_place_pressed(minion, true)
	await scene._on_ready_pressed()
	assert_true(scene.match_.round_number == 1, "le round n'avance qu'après le bouton 'round suivant'")
	if not scene.game_over:
		scene._on_next_round_pressed()
		assert_eq(scene.match_.round_number, 2)
