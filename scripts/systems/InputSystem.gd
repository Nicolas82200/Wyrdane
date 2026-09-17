extends RefCounted
class_name InputSystem

# Routage des inputs non consommés par l'UI (souris/clavier) : priorité aux
# contextes de choix actifs (sacrifice, fusion, ciblage) avant les raccourcis
# clavier généraux. Appelé depuis Battle._unhandled_input.

var battle

func init(_battle) -> void:
	battle = _battle

func handle_unhandled_input(event: InputEvent) -> void:
	if battle.sacrifice_system.is_active():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			battle.sacrifice_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			battle.sacrifice_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return

	if battle.fusion_system.is_active():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			battle.fusion_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			battle.fusion_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return

	if battle.targeting_system.is_targeting() and not battle.targeting_system.is_trigger_targeting():
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			battle.targeting_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_cancel"):
			battle.targeting_system.cancel()
			battle.get_viewport().set_input_as_handled()
			return

	# Raccourcis clavier (fin de tour, cimetières, Échap)
	if _handle_shortcut(event):
		battle.get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed \
			and not Input.is_key_pressed(KEY_CTRL):
		if battle.selection_system.is_multi_selecting:
			battle.selection_system.clear_multi_selection()

# Traite un raccourci clavier. Retourne true si l'événement a été consommé.
func _handle_shortcut(event: InputEvent) -> bool:
	# Échap "intelligent" : annule/ferme le contexte prioritaire ouvert
	if event.is_action_pressed("ui_cancel"):
		return _handle_cancel()

	# Fin de tour
	if event.is_action_pressed("end_turn"):
		battle._on_end_turn_pressed()
		return true

	if event.is_action_pressed("toggle_graveyard"):
		battle._toggle_graveyard(battle.player_graveyard)
		return true
	if event.is_action_pressed("toggle_enemy_graveyard"):
		battle._toggle_graveyard(battle.enemy_graveyard)
		return true

	return false

# Échap : ferme un overlay ouvert par ordre de priorité, sinon ouvre les réglages.
func _handle_cancel() -> bool:
	# L'écran de fin ne se ferme pas : le joueur doit choisir Rejouer ou Menu.
	if battle.game_over_screen.visible:
		return true
	if battle.graveyard_view.visible:
		battle.graveyard_view.close()
		return true
	if battle.settings_menu.visible:
		battle.settings_menu.close()
		return true
	battle.settings_menu.open()
	return true
