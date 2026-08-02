extends GutTest

# Couvre VFXManager._targets_enemy (scripts/systems/VFXManager.gd), seule
# logique pure du fichier — le reste (spawn_spell_projectile, overlays
# SubViewport/Camera3D...) est du rendu visuel pur, hors scope (voir
# CLAUDE.md). Détermine la couleur/direction du projectile de sort selon que
# la carte cible un ennemi.

var vfx_manager: VFXManager

func before_each() -> void:
	vfx_manager = VFXManager.new()

func after_each() -> void:
	vfx_manager.free()

func _card_with_effect_target(target: String) -> CardData:
	var data := CardData.new()
	var effect := CardEffect.new()
	effect.target = target
	data.effects = [effect]
	return data

func test_targets_enemy_true_for_enemy_hero() -> void:
	assert_true(vfx_manager._targets_enemy(_card_with_effect_target("EnemyHero")))

func test_targets_enemy_true_for_enemy_minion() -> void:
	assert_true(vfx_manager._targets_enemy(_card_with_effect_target("EnemyMinion")))

func test_targets_enemy_true_for_all_enemies() -> void:
	assert_true(vfx_manager._targets_enemy(_card_with_effect_target("AllEnemies")))

func test_targets_enemy_true_for_random_enemy() -> void:
	assert_true(vfx_manager._targets_enemy(_card_with_effect_target("RandomEnemy")))

func test_targets_enemy_false_for_ally_target() -> void:
	assert_false(vfx_manager._targets_enemy(_card_with_effect_target("AllyMinion")))

func test_targets_enemy_false_for_owner_hero() -> void:
	assert_false(vfx_manager._targets_enemy(_card_with_effect_target("OwnerHero")))

func test_targets_enemy_false_with_no_effects() -> void:
	assert_false(vfx_manager._targets_enemy(CardData.new()))

func test_targets_enemy_true_if_any_effect_among_several_targets_an_enemy() -> void:
	var data := CardData.new()
	var self_effect := CardEffect.new()
	self_effect.target = "Self"
	var enemy_effect := CardEffect.new()
	enemy_effect.target = "AllEnemies"
	data.effects = [self_effect, enemy_effect]
	assert_true(vfx_manager._targets_enemy(data))
