extends Control

# Visuel d'une carte Enchantement ou Rituel posée dans sa zone (à droite du board).
# Affiche le card art comme les unités sur le board ; le détail (nom, effet)
# est disponible en tooltip au survol.
# Les Rituels de Sacrifice du joueur sont cliquables : le clic demande leur
# activation (choix des victimes via SacrificeSystem).

signal activate_requested(card_data: CardData, is_player: bool)

const ACTIVATABLE_TINT := Color(1.25, 1.15, 0.75)

var card_data: CardData
var is_player: bool

func setup(new_data: CardData, new_is_player: bool) -> void:
	card_data = new_data
	is_player = new_is_player
	if card_data.texture:
		$Art.texture = card_data.texture
	$CostBadge.text = str(card_data.cost)
	tooltip_text = "%s\n%s" % [card_data.display_name(), card_data.display_description()]
	$TurnsLabel.visible = false

# Compteur de tours restants (Rituels à durée limitée uniquement)
func set_turns_left(turns: int) -> void:
	$TurnsLabel.visible = turns > 0
	if turns > 0:
		var fmt := SettingsManager.t("enchant.turns_many") if turns > 1 else SettingsManager.t("enchant.turns_one")
		$TurnsLabel.text = fmt % turns

# Surbrillance dorée quand le rituel est activable (Sacrifice disponible)
func set_activatable(on: bool) -> void:
	modulate = ACTIVATABLE_TINT if on else Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		activate_requested.emit(card_data, is_player)
		accept_event()
