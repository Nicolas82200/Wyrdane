extends GutTest

func _build_pair() -> Dictionary:
	var hub := FakeArenaNetHub.new()

	var host_transport := FakeArenaNetTransport.new(hub, 1, true)
	var host_net := ArenaNetworkManager.new()
	autofree(host_net)
	host_net.is_host = true
	host_net.set_transport(host_transport)
	host_transport.host({})

	var client_transport := FakeArenaNetTransport.new(hub, 200, false)
	var client_net := ArenaNetworkManager.new()
	autofree(client_net)
	client_net.is_host = false
	client_net.set_transport(client_transport)
	client_transport.join({})

	return {"host_net": host_net, "client_net": client_net}

func _make_card(name: String, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.card_type = "Minion"
	data.resource_path = path
	return data

# ─── broadcast_combat_result ──────────────────────────────────────────────────

func test_broadcast_combat_result_sends_a_board_sync_for_every_seat() -> void:
	var rig := _build_pair()
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))
	m.find_by_seat(0).hero_hp = 12
	m.find_by_seat(1).hero_hp = 8

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	ArenaHostRoundSync.broadcast_combat_result(m, rig.host_net)

	var board_syncs: Array = received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.BOARD_SYNC)
	assert_eq(board_syncs.size(), 2, "un BOARD_SYNC doit être diffusé pour chaque siège, pas seulement un émetteur")
	var hp_by_seat: Dictionary = {}
	for command in board_syncs:
		hp_by_seat[command["seat_id"]] = command["hero_hp"]
	assert_eq(hp_by_seat[0], 12)
	assert_eq(hp_by_seat[1], 8)

func test_broadcast_combat_result_sends_no_game_over_when_the_match_continues() -> void:
	var rig := _build_pair()
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	ArenaHostRoundSync.broadcast_combat_result(m, rig.host_net)

	assert_true(received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.GAME_OVER).is_empty())

func test_broadcast_combat_result_sends_game_over_when_only_one_player_remains() -> void:
	var rig := _build_pair()
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))
	m.find_by_seat(1).hero_hp = 0
	m.find_by_seat(1).is_eliminated = true
	m.elimination_order = [m.find_by_seat(1)]

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	ArenaHostRoundSync.broadcast_combat_result(m, rig.host_net)

	var game_over_messages: Array = received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.GAME_OVER)
	assert_eq(game_over_messages.size(), 1)
	assert_eq(game_over_messages[0]["ranking"][0]["seat_id"], 0, "le survivant doit arriver premier au classement")

# ─── broadcast_new_round ──────────────────────────────────────────────────────

func test_broadcast_new_round_sends_the_round_number_and_combat_log_to_everyone() -> void:
	var rig := _build_pair()
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))
	m.round_number = 3

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	var log: Array = ["Hôte vs Client : Hôte gagne, 3 dégâts"]
	ArenaHostRoundSync.broadcast_new_round(m, rig.host_net, func(_seat_id: int) -> int: return 200, log)

	var round_messages: Array = received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.ROUND_ADVANCED)
	assert_eq(round_messages.size(), 1)
	assert_eq(round_messages[0]["round_number"], 3)
	assert_eq(round_messages[0]["combat_log"], log)

func test_broadcast_new_round_sends_a_private_state_sync_to_each_real_seat_via_its_peer_id() -> void:
	var rig := _build_pair()
	var card := _make_card("C1", "res://fake/round_sync_c1.tres")
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")]
	players[1].gold = 5
	players[1].shop_offer = [card, null, null, null, null]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	ArenaHostRoundSync.broadcast_new_round(m, rig.host_net, func(seat_id: int) -> int: return 200 if seat_id == 1 else -1, [])

	var private_syncs: Array = received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.PRIVATE_STATE_SYNC)
	assert_eq(private_syncs.size(), 1, "seul le siège 1 (le client réel de ce test) a un peer_id réel")
	assert_eq(private_syncs[0]["gold"], 5)
	assert_eq(private_syncs[0]["shop_offer"][0], "res://fake/round_sync_c1.tres")

func test_broadcast_new_round_skips_bot_seats_even_if_a_peer_id_would_resolve() -> void:
	var rig := _build_pair()
	var players: Array[ArenaPlayerState] = [
		ArenaPlayerState.new("Hôte"),
		ArenaPlayerState.new("Bot 1", true),
		ArenaPlayerState.new("Client"),
	]
	var m := ArenaMatch.new(players, ArenaCardPool.new([]))

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	# Volontairement piégeuse : renvoie un peer_id "valide" même pour le siège
	# bot (1) — is_bot doit être vérifié AVANT tout appel à peer_for_seat, sans
	# quoi ce test laisserait passer un PRIVATE_STATE_SYNC erroné pour un bot.
	ArenaHostRoundSync.broadcast_new_round(m, rig.host_net, func(seat_id: int) -> int: return 200 if seat_id != 0 else -1, [])

	var private_syncs: Array = received.filter(func(c): return ArenaGameCommand.type_of(c) == ArenaGameCommand.PRIVATE_STATE_SYNC)
	assert_eq(private_syncs.size(), 1, "seul le vrai client (siège 2) doit recevoir un PRIVATE_STATE_SYNC, jamais le bot")
	assert_eq(private_syncs[0]["seat_id"] if private_syncs.size() > 0 else -1, 2)
