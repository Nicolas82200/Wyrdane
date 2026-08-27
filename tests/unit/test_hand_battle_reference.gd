extends GutTest

# Couvre Hand.set_battle (scripts/hand/Hand.gd) : Battle._init_systems()
# l'appelle explicitement pour garantir une référence _battle correcte, plutôt
# que de dépendre uniquement de la résolution via get_tree().current_scene à
# _ready() — Hand étant un enfant STATIQUE de Battle.tscn (contrairement à
# BoardMinion, instancié dynamiquement), cette auto-résolution pouvait
# capturer une mauvaise scène selon le timing de la transition, laissant
# _battle invalide toute la partie (soulèvement au survol OK, mais aucun
# tooltip de mot-clé ne s'affichait jamais, sans erreur visible).

const HAND_SCENE := preload("res://scenes/hand/Hand.tscn")

func test_set_battle_overrides_the_self_resolved_reference() -> void:
	var hand: Hand = HAND_SCENE.instantiate()
	add_child_autofree(hand)
	var fake_battle := Node.new()
	add_child_autofree(fake_battle)
	hand.set_battle(fake_battle)
	assert_eq(hand._battle, fake_battle)
