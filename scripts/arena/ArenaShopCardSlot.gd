extends Control
class_name ArenaShopCardSlot

# Enveloppe autour d'un `BoardMinion` (le même visuel qu'un serviteur déjà
# posé en 1v1/Arena — voir ArenaBoardMinionSlot) plutôt que la `Card` de main
# utilisée jusqu'ici : aucun texte visible sur la case boutique elle-même
# (demande explicite du joueur), le survol déclenche le même aperçu détaillé
# (Card agrandie) que n'importe quel serviteur posé — voir BoardMinion.
# _on_mouse_entered, qui sonde la position de la souris à chaque frame
# indépendamment de `mouse_filter` (voir plus bas). CE Control gère le drag
# pour acheter (API standard Godot _get_drag_data/set_drag_preview), sans
# dépendre du pipeline de jeu 1v1 (Card.gd/DropSystem.gd, pensé pour le mana/
# ciblage, pas pour une économie en or — voir plan Arena « Refonte visuelle »).

const BOARD_MINION_SCENE := preload("res://scenes/minion/BoardMinion.tscn")
# Même vocabulaire de lignes que ArenaBattle/Battle.gd.
const ROW_FRONT := "Front"

var card_data: CardData
var shop_index: int = -1

func setup(data: CardData, index: int) -> void:
	card_data = data
	shop_index = index
	for child in get_children():
		child.queue_free()
	if data == null:
		return
	var visual: BoardMinion = BOARD_MINION_SCENE.instantiate()
	add_child(visual)
	visual.set_minion(Minion.new(data, true, ROW_FRONT))
	if data.card_type != "Minion":
		visual.attack_label.visible = false
		visual.health_label.visible = false
	# PASS (ni le STOP par défaut posé par BoardMinion._ready(), ni IGNORE) :
	# laisse les événements souris remonter jusqu'à CE Control pour le drag
	# d'achat (_get_drag_data plus bas) SANS désactiver l'aperçu au survol de
	# BoardMinion. BoardMinion._process sonde lui-même la position de la
	# souris à chaque frame (pas via les signaux natifs mouse_entered/exited),
	# mais sa condition `mouse_filter != MOUSE_FILTER_IGNORE` exclut
	# explicitement IGNORE de ce sondage — l'utiliser ici désactivait donc le
	# survol au lieu de le préserver comme prévu. PASS reste différent
	# d'IGNORE pour ce test tout en laissant l'événement de drag continuer
	# vers le parent (STOP l'aurait bloqué avant qu'il n'atteigne ce Control).
	visual.mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = visual.custom_minimum_size

func _get_drag_data(_at_position: Vector2):
	if card_data == null:
		return null
	set_drag_preview(_build_preview())
	return {"arena_shop_index": shop_index}

func _build_preview() -> Control:
	var box := PanelContainer.new()
	box.modulate = Color(1.0, 1.0, 1.0, 0.85)
	var tex := TextureRect.new()
	tex.texture = card_data.texture
	tex.custom_minimum_size = Vector2(90, 135)
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	box.add_child(tex)
	return box
