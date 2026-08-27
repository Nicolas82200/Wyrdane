extends GutTest

# Couvre PactChoiceSystem.ask() (scripts/systems/PactChoiceSystem.gd) : le
# bug "cliquer Oui/Non sur la popup de Pacte ne fait rien". Root cause : les
# callbacks yes_button.pressed/no_button.pressed mutaient deux variables
# LOCALES (paid/done) — une lambda GDScript capture les locales par VALEUR,
# pas par référence, donc la boucle d'attente de ask() ne voyait jamais le
# changement. Corrigé en remplaçant les deux bool locaux par un Dictionary
# (type par référence), même patron que FusionSystem._show_keyword_popup.
#
# Nécessite une VRAIE scène (add_child_autofree) : ask() attend
# battle.get_tree().process_frame en boucle jusqu'au clic, ce que FakeBattle
# (RefCounted, FakeSceneTree sans vrai traitement de frame) ne peut pas
# simuler fidèlement — voir la convention pour les tests dépendant du
# scheduler réel (test_card_type_label_fit.gd).

class BattleStub:
	extends Node
	var card_popup_system
	var network_manager = null

var pact_choice_system: PactChoiceSystem
var battle: BattleStub

func before_each() -> void:
	battle = BattleStub.new()
	add_child_autofree(battle)
	var player_hero_panel := Control.new()
	player_hero_panel.name = "PlayerHeroPanel"
	battle.add_child(player_hero_panel)
	var enemy_hero_panel := Control.new()
	enemy_hero_panel.name = "EnemyHeroPanel"
	battle.add_child(enemy_hero_panel)
	battle.card_popup_system = load("res://scripts/systems/CardPopupSystem.gd").new()
	battle.card_popup_system.init(battle)
	pact_choice_system = PactChoiceSystem.new()
	pact_choice_system.init(battle)

func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found != null:
			return found
	return null

var _result = "PENDING"

func _run_ask(data: CardData) -> void:
	_result = await pact_choice_system.ask(data, 3)

func test_clicking_yes_resolves_ask_with_true() -> void:
	var data := CardData.new()
	data.card_name = "TEST_PACT_CARD"
	_result = "PENDING"
	_run_ask(data)
	await get_tree().create_timer(0.6).timeout

	var yes_button := _find_button(get_tree().root, SettingsManager.t("PACT_CONFIRM_YES"))
	assert_not_null(yes_button, "le bouton Oui doit exister dans l'arbre")
	yes_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_result, true, "cliquer Oui doit résoudre ask() à true (régression : restait bloqué sur PENDING)")

func test_clicking_no_resolves_ask_with_false() -> void:
	var data := CardData.new()
	data.card_name = "TEST_PACT_CARD"
	_result = "PENDING"
	_run_ask(data)
	await get_tree().create_timer(0.6).timeout

	var no_button := _find_button(get_tree().root, SettingsManager.t("PACT_CONFIRM_NO"))
	assert_not_null(no_button, "le bouton Non doit exister dans l'arbre")
	no_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_result, false, "cliquer Non doit résoudre ask() à false (régression : restait bloqué sur PENDING)")
