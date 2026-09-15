extends GutTest

# Teste le relais réseau côté hôte (ArenaHostGameRouter) via le transport
# simulé (FakeArenaNetTransport/FakeArenaNetHub, livraison synchrone) — une
# vraie commande REQUEST_* est envoyée par un client via son ArenaNetworkManager
# réel, traverse la sérialisation réelle (var_to_bytes), et on vérifie ce que
# le client reçoit effectivement en retour.

func _make_card(name: String, cost: int, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	return data

# Construit un hôte et un client déjà connectés (topologie étoile simulée),
# prêts à échanger des commandes de PARTIE (le handshake d'ouverture n'est
# pas nécessaire ici : la correspondance peer_id -> seat_id est fournie
# directement au routeur via une Callable, voir ArenaHostGameRouter).
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

func test_a_request_from_a_known_peer_is_applied_and_both_syncs_reach_the_client() -> void:
	var rig := _build_pair()
	var card := _make_card("C1", 1, "res://fake/router_c1.tres")
	var pool := ArenaCardPool.new([card])
	var host_player := ArenaPlayerState.new("Hôte")
	var client_player := ArenaPlayerState.new("Client")
	client_player.gold = 1
	client_player.shop_offer = [card, null, null, null, null]
	var m := ArenaMatch.new([host_player, client_player], pool)  # seat 0 = hôte, 1 = client

	var router := ArenaHostGameRouter.new(m, rig.host_net, func(peer_id: int) -> int: return 1 if peer_id == 200 else -1)
	autofree(router)

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	rig.client_net.send_command(1, ArenaGameCommand.request_buy(0))

	assert_eq(client_player.hand.size(), 1, "la requête doit avoir été réellement appliquée à l'ArenaMatch autoritaire")
	var public_count := 0
	var private_count := 0
	for command in received:
		if ArenaGameCommand.type_of(command) == ArenaGameCommand.BOARD_SYNC:
			public_count += 1
		elif ArenaGameCommand.type_of(command) == ArenaGameCommand.PRIVATE_STATE_SYNC:
			private_count += 1
			assert_eq(command["hand"].size(), 1, "le PRIVATE_STATE_SYNC doit refléter la carte reçue")
	assert_eq(public_count, 1, "le client doit recevoir le BOARD_SYNC diffusé")
	assert_eq(private_count, 1, "le client doit recevoir SON PROPRE PRIVATE_STATE_SYNC (c'est lui l'émetteur)")

func test_a_request_from_an_unmapped_peer_is_ignored() -> void:
	var rig := _build_pair()
	var m := ArenaMatch.new([ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")], ArenaCardPool.new([]))
	var client_player: ArenaPlayerState = m.find_by_seat(1)
	var gold_before: int = client_player.gold

	var router := ArenaHostGameRouter.new(m, rig.host_net, func(_peer_id: int) -> int: return -1)
	autofree(router)

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	rig.client_net.send_command(1, ArenaGameCommand.request_reroll())

	assert_eq(client_player.gold, gold_before, "sans correspondance de siège, aucune action ne doit être appliquée")
	assert_true(received.is_empty(), "sans correspondance de siège, rien ne doit être renvoyé au client")

func test_an_unknown_command_type_produces_no_response() -> void:
	var rig := _build_pair()
	var m := ArenaMatch.new([ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Client")], ArenaCardPool.new([]))
	var router := ArenaHostGameRouter.new(m, rig.host_net, func(_peer_id: int) -> int: return 1)
	autofree(router)

	var received: Array = []
	rig.client_net.command_received.connect(func(_peer_id: int, command: Dictionary) -> void: received.append(command))

	rig.client_net.send_command(1, {"type": "NOT_A_REAL_REQUEST"})

	assert_true(received.is_empty())
