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

class FakeNetworkManager:
	extends Node
	signal command_received(command: Dictionary)
	var sent: Array[Dictionary] = []
	func send_command(command: Dictionary, _reliable: bool = true) -> void:
		sent.append(command)

class BattleStub:
	extends Node
	var card_popup_system
	var network_manager = null
	var enemy_turn_active: bool = false

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

# ─── Synchronisation réseau (resolve_trigger) ────────────────────────────────
# Couvre les 3 cas de scripts/systems/PactChoiceSystem.gd :
#  - notre propre carte (is_player=true) : décide localement, envoie sa
#    décision (ou consomme une réponse déjà donnée hors-tour — voir plus bas).
#  - carte du pair touchée par NOTRE action en direct (is_player=false, pas le
#    tour du pair) : doit demander (PACT_REQUEST) puisque le pair ne sait pas
#    encore qu'une décision est nécessaire.
#  - carte du pair rejouée depuis SON tour (is_player=false, tour du pair en
#    cours) : sa décision est déjà en route, pas de requête à émettre.

func _pact_card(value: int) -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_PACT_CARD"
	var kwd := KeywordChoiceDemon.new()
	kwd.keyword_type = KeywordDemon.Type.PACTE
	kwd.value = value
	data.demon_keywords = [kwd]
	return data

func test_resolve_trigger_cross_case_sends_request_then_awaits_reply() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	battle.enemy_turn_active = false  # notre action en direct
	var card := _pact_card(3)

	_result = "PENDING"
	_resolve_async(card, false)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(net.sent.size(), 1, "une carte du pair touchée par notre action en direct doit déclencher un PACT_REQUEST")
	assert_eq(NetCommand.type_of(net.sent[0]), NetCommand.PACT_REQUEST)
	assert_eq(int(net.sent[0].get("value", -1)), 3)
	assert_eq(_result, "PENDING", "doit rester en attente tant que le pair n'a pas répondu")

	net.command_received.emit(NetCommand.pact_choice(true))
	# _watch_remote_answer affiche d'abord la carte en attente (tween de
	# show_targeting_popup, 0.25s) avant même de consulter la réponse déjà
	# arrivée : il faut laisser cette animation se terminer, 2 frames ne
	# suffisent plus depuis l'ajout de cette preview.
	await get_tree().create_timer(0.4).timeout

	assert_eq(_result, true, "la réponse du pair doit débloquer resolve_trigger avec sa décision")

func test_resolve_trigger_replay_case_waits_without_sending_request() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	battle.enemy_turn_active = true  # rejeu du tour du pair
	var card := _pact_card(2)

	_result = "PENDING"
	_resolve_async(card, false)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(net.sent.is_empty(), "en rejeu, la décision du pair est déjà en route : aucune requête à émettre")

	net.command_received.emit(NetCommand.pact_choice(false))
	# Voir le commentaire équivalent dans le test ci-dessus (cross_case) :
	# _watch_remote_answer affiche d'abord la carte en attente avant de
	# consulter la réponse déjà arrivée.
	await get_tree().create_timer(0.4).timeout

	assert_eq(_result, false, "la décision déjà envoyée par le pair doit débloquer resolve_trigger")

func test_resolve_trigger_own_card_consumes_prefetched_answer_without_asking() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	battle.enemy_turn_active = true
	var prefetched: Array[bool] = [true]
	pact_choice_system._prefetched_own_answers = prefetched
	var card := _pact_card(4)

	_result = "PENDING"
	_resolve_async(card, true)
	# Si resolve_trigger appelait ask() ici, ce test resterait bloqué (aucun
	# clic simulé) : le fait qu'il se résolve prouve que la valeur déjà
	# transmise hors-tour a été consommée sans redemander.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_result, true, "doit consommer la décision déjà donnée hors-tour, sans redemander")
	assert_true(net.sent.is_empty(), "aucun nouvel envoi : la décision a déjà été transmise au moment de la requête distante")

func test_on_net_command_received_pact_request_asks_local_player_and_replies() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	battle.enemy_turn_active = true  # le pair résout SON tour, touche notre carte
	pact_choice_system._ensure_net_listener()

	net.command_received.emit(NetCommand.pact_request("res://resources/cards/demon/hellspawn-larva.tres", 1))
	await get_tree().create_timer(0.6).timeout

	var yes_button := _find_button(get_tree().root, SettingsManager.t("PACT_CONFIRM_YES"))
	assert_not_null(yes_button, "une requête distante doit afficher la popup au joueur local, même hors de son tour")
	yes_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(net.sent.size(), 1)
	assert_eq(NetCommand.type_of(net.sent[0]), NetCommand.PACT_CHOICE)
	assert_true(net.sent[0].get("paid", false), "doit répondre avec la décision du joueur local")
	assert_eq(pact_choice_system._prefetched_own_answers, [true], "la décision doit être mise en cache pour le rejeu ultérieur de cette même action")

# ─── Annonce anticipée (PACT_ANNOUNCE) ────────────────────────────────────────
# Couvre le cas courant (déclencheur Arrivée résolu au moment même où la carte
# est posée, ex. Croc de Braise/Embermaw) : sans annonce préalable, le pair ne
# voit la carte qu'au rejeu de PLAY_CARD, à un moment où sa décision de Pacte
# est déjà connue (PACT_CHOICE envoyé juste après) — la popup d'attente
# n'aurait alors plus rien à attendre. Voir le commentaire d'en-tête du script.

func test_resolve_trigger_own_card_sends_announce_before_asking() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	var card := _pact_card(3)

	_result = "PENDING"
	_resolve_async(card, true)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(net.sent.size(), 1, "l'annonce doit partir avant même que le joueur local ait choisi")
	assert_eq(NetCommand.type_of(net.sent[0]), NetCommand.PACT_ANNOUNCE)
	assert_eq(int(net.sent[0].get("value", -1)), 3)

	await get_tree().create_timer(0.6).timeout
	var yes_button := _find_button(get_tree().root, SettingsManager.t("PACT_CONFIRM_YES"))
	assert_not_null(yes_button, "la popup de choix du joueur local doit s'afficher après l'annonce")
	yes_button.emit_signal("pressed")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_result, true)
	assert_eq(net.sent.size(), 2, "la décision doit être envoyée après l'annonce")
	assert_eq(NetCommand.type_of(net.sent[1]), NetCommand.PACT_CHOICE)

func test_handle_remote_announce_shows_waiting_popup_and_caches_answer_for_later_replay() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	battle.network_manager = net
	battle.enemy_turn_active = true  # rejeu du tour du pair
	pact_choice_system._ensure_net_listener()

	net.command_received.emit(NetCommand.pact_announce("res://resources/cards/demon/embermaw.tres", 2))
	# _watch_remote_answer affiche d'abord la carte en attente (tween de
	# show_targeting_popup, 0.25s) avant de consulter la réponse.
	await get_tree().create_timer(0.35).timeout

	net.command_received.emit(NetCommand.pact_choice(true))
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(pact_choice_system._prefetched_remote_answers, [true],
		"la réponse doit être mise en cache dès l'annonce, sans attendre le rejeu de PLAY_CARD")

	# Le rejeu réel (déclenché plus tard par PLAY_CARD) ne doit ni redemander
	# (PACT_REQUEST) ni réafficher de popup : juste consommer la valeur en cache.
	net.sent.clear()
	var card := _pact_card(2)
	_result = "PENDING"
	_resolve_async(card, false)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(_result, true, "doit consommer la réponse déjà obtenue par anticipation")
	assert_true(net.sent.is_empty(), "aucune nouvelle requête : la réponse était déjà en cache")

func _resolve_async(card: CardData, is_player: bool) -> void:
	_result = await pact_choice_system.resolve_trigger(card, is_player)

# Couvre le blocage "tour de l'adversaire" bloqué des deux côtés en partie
# réelle : la décision du propriétaire (PACT_CHOICE) peut arriver AVANT le
# tout premier appel local à resolve_trigger (elle est envoyée avant même la
# commande d'action qui la déclenchera chez le pair). Si le listener réseau de
# PactChoiceSystem ne se connecte que paresseusement au premier resolve_trigger
# (ancien comportement), ce tout premier message arrive dans le vide — signal
# perdu — et _await_remote_answer() attend indéfiniment une réponse déjà
# passée, bloquant tout le rejeu du tour adverse. Le listener doit donc être
# connecté dès init(), AVANT tout resolve_trigger — reproduit ici en émettant
# PACT_CHOICE avant même d'appeler resolve_trigger, avec network_manager déjà
# assigné avant init() (même ordre que Battle.gd : NetSessionSystem.setup()
# avant pact_choice_system.init()).
func test_init_connects_listener_before_first_resolve_trigger_so_early_answer_is_not_lost() -> void:
	var net := FakeNetworkManager.new()
	add_child_autofree(net)
	var early_battle := BattleStub.new()
	add_child_autofree(early_battle)
	early_battle.card_popup_system = load("res://scripts/systems/CardPopupSystem.gd").new()
	early_battle.card_popup_system.init(early_battle)
	early_battle.network_manager = net
	early_battle.enemy_turn_active = true  # rejeu du tour du pair, pas de PACT_REQUEST attendu
	var early_pact_system := PactChoiceSystem.new()
	early_pact_system.init(early_battle)  # network_manager déjà assigné : doit se connecter tout de suite

	# La décision du pair arrive AVANT tout resolve_trigger local.
	net.command_received.emit(NetCommand.pact_choice(true))

	var card := _pact_card(2)
	_result = "PENDING"
	_result = await early_pact_system.resolve_trigger(card, false)

	assert_eq(_result, true, "la décision arrivée avant le premier resolve_trigger ne doit pas être perdue (régression : blocage indéfini)")
