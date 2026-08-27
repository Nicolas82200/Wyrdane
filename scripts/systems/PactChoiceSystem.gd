# PactChoiceSystem.gd
# Demande au joueur LOCAL s'il accepte de payer le coût en PV du mot-clé PACTE
# pour activer le bonus d'un effet (CardEffect.pact_bonus), à chaque
# déclenchement effectif du trigger concerné — Arrivée comprise, aucun
# traitement à part : `resolve_trigger()` est appelé identiquement par
# EffectManager.trigger_effects (serviteurs) et TriggerSystem
# (_fire_on_enchantments / activate_sacrifice_ritual / try_cancel_spell pour
# Rituels/Enchantements). Aucun canal réseau dédié n'existe pour ce choix
# répété : en partie réseau, les deux camps décident via la même heuristique
# déterministe que l'IA (`heuristic_decision`), pour rester synchronisés sans
# nouveau protocole. `ask()` n'affiche la popup que pour le joueur LOCAL hors
# partie réseau.
extends RefCounted
class_name PactChoiceSystem

const SAFE_HEALTH_MARGIN := 6

var battle

func init(_battle) -> void:
	battle = _battle

func resolve_trigger(card_data: CardData, is_player: bool) -> bool:
	var value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
	if value <= 0:
		return true
	if battle.network_manager != null:
		return heuristic_decision(is_player, value)
	if is_player:
		return await ask(card_data, value)
	return heuristic_decision(is_player, value)

# Décision déterministe (IA, ou joueur en partie réseau pour un choix de
# Rituel/Enchantement sans canal réseau dédié) : paie si la marge de PV restante
# après paiement reste confortable.
func heuristic_decision(is_player: bool, value: int) -> bool:
	var hero: Hero = battle.player_hero if is_player else battle.enemy_hero
	return hero.health - value >= SAFE_HEALTH_MARGIN

# Affiche la carte du Pacte via la popup persistante (CardPopupSystem, même
# emplacement que le ciblage), avec un panneau de choix Oui/Non ancré juste
# en dessous — pour que le joueur voie la carte (texte d'effet compris) en
# même temps que le choix qu'elle lui demande.
func ask(card_data: CardData, value: int) -> bool:
	await battle.card_popup_system.show_targeting_popup(card_data)
	var card: Card = battle.card_popup_system.get_persistent_card()
	var layer: CanvasLayer = battle.card_popup_system.get_popup_layer()

	# Bloqueur plein écran (mouse_filter STOP) : sans lui, un clic ailleurs
	# pendant l'attente (bouton Fin du tour, menu Échap...) reste possible et
	# peut mener à une fin de partie/changement de scène pendant que cette
	# popup attend encore le joueur — voir le garde-fou is_instance_valid(battle)
	# plus bas, qui protège contre ce cas mais ne devrait plus se produire une
	# fois l'interaction bloquée. Le panneau Oui/Non est ENFANT du bloqueur
	# (pas un frère) — même patron que FusionSystem._show_keyword_popup — pour
	# qu'il reçoive les clics en priorité sans dépendre de l'ordre des enfants
	# dans le calque.
	var blocker := Control.new()
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(blocker)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1a0e0eee")
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color("c9a227")
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var label := Label.new()
	label.text = SettingsManager.t("PACT_CONFIRM_TEXT") % value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(hbox)

	var yes_button := Button.new()
	yes_button.text = SettingsManager.t("PACT_CONFIRM_YES")
	hbox.add_child(yes_button)

	var no_button := Button.new()
	no_button.text = SettingsManager.t("PACT_CONFIRM_NO")
	hbox.add_child(no_button)

	blocker.add_child(panel)
	if card != null and is_instance_valid(card):
		panel.custom_minimum_size.x = card.size.x
		await panel.get_tree().process_frame
		panel.position = card.position + Vector2(0.0, card.size.y + 12.0)

	# ATTENTION : un Dictionary, PAS deux bool locaux. Une lambda GDScript
	# capture les variables locales PAR VALEUR (une copie), pas par référence —
	# `paid = true` / `done = true` dans les callbacks ci-dessous ne mutaient
	# donc RIEN dans la portée de cette fonction : la boucle d'attente plus bas
	# ne voyait jamais `done` passer à `true`, quel que soit le bouton cliqué.
	# C'est le bug "cliquer Oui/Non sur le Pacte ne fait rien" (confirmé par un
	# test isolé : voir la PR). Un Dictionary est un type par référence en
	# GDScript, donc `state["done"] = true` mute bien l'objet partagé — même
	# patron déjà utilisé (et fonctionnel) par FusionSystem._show_keyword_popup.
	var state := {"paid": false, "done": false}
	yes_button.pressed.connect(func() -> void:
		state["paid"] = true
		state["done"] = true
	)
	no_button.pressed.connect(func() -> void:
		state["paid"] = false
		state["done"] = true
	)
	# Garde-fou : si la scène de bataille est détruite pendant l'attente (ex. la
	# partie se termine puis le joueur retourne au menu, ou une reconnexion
	# échoue), `battle` devient une instance libérée — sans ce garde-fou,
	# `battle.get_tree()` plantait (voir le même correctif sur Hand.gd) et le
	# clic Oui/Non ne faisait alors plus rien de visible pour le joueur.
	while not state["done"] and is_instance_valid(battle):
		await battle.get_tree().process_frame
	if is_instance_valid(blocker):
		blocker.queue_free()  # libère aussi panel, qui en est désormais l'enfant
	if is_instance_valid(battle):
		battle.card_popup_system.hide_targeting_popup()
	return state["paid"]
