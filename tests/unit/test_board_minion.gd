extends GutTest

# Régression : un `BoardMinion` détruit pendant qu'il affiche son aperçu de
# survol (Card agrandie, ajoutée à `_battle` — pas un enfant de ce nœud)
# laissait l'aperçu affiché indéfiniment, orphelin. Cas réel : en boutique
# Arena, glisser-déposer une carte pour l'acheter reconstruit entièrement la
# boutique (voir ArenaBattle._refresh_shop) — y compris la case qu'on vient de
# survoler/glisser, détruite avant qu'aucun signal de sortie de survol ne
# puisse la nettoyer elle-même.

const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")
const CARD_SCENE := preload("res://scenes/card/Card.tscn")

func test_freeing_a_minion_mid_hover_hides_and_clears_its_preview() -> void:
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	add_child(visual)

	var preview: Card = CARD_SCENE.instantiate()
	add_child_autofree(preview)
	preview.visible = true
	visual._hover_preview = preview

	visual.free()

	assert_false(preview.visible,
		"l'aperçu doit être masqué même si le BoardMinion qui l'a créé est détruit pendant qu'il était affiché")
