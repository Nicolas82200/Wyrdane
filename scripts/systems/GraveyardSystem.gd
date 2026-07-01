# GraveyardSystem.gd
extends Node
class_name GraveyardSystem

# [FIX] Type explicite
var battle: Node

func init(_battle: Node) -> void:
	battle = _battle
	# [FIX] Labels récupérés via @onready de GameBoard plutôt que par chemin string fragile
	_setup(
		battle.player_graveyard,
		battle.player_graveyard_btn,
		battle.player_graveyard_preview,
		battle.player_graveyard_btn.get_node("CountLabel") as Label
	)
	_setup(
		battle.enemy_graveyard,
		battle.enemy_graveyard_btn,
		battle.enemy_graveyard_preview,
		battle.enemy_graveyard_btn.get_node("CountLabel") as Label
	)

func _setup(graveyard: Graveyard, button: Button, preview: Card, label: Label) -> void:
	var scale := Vector2(120, 180) / Vector2(200, 300)
	preview.visible = false
	button.visible  = false
	preview.scale   = scale
	graveyard.graveyard_changed.connect(func(): update_btn(graveyard, preview, label))
	button.pressed.connect(func(): battle.graveyard_view.open(graveyard))
	if preview.has_method("set_non_interactive"):
		preview.set_non_interactive()

# [FIX] update_btn centralisé ici — _update_graveyard_btn dans GameBoard est mort-code, peut être supprimé
func update_btn(graveyard: Graveyard, preview: Card, label: Label) -> void:
	var last: CardData = graveyard.last_card_data()
	if last == null:
		preview.visible = false
		label.text = "0"
		return
	preview.visible = true
	preview.get_parent().visible = true
	preview.set_data(last)
	label.text = str(graveyard.size())
