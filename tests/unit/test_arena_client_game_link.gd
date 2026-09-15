extends GutTest

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"

# Le "hôte" y est réduit à un simple FakeArenaNetTransport (pas de vrai
# ArenaNetworkManager en face) : ArenaClientGameLink n'a besoin que d'un
# ArenaNetworkManager client pour être testé, ces tests n'ont donc rien à
# vérifier côté hôte au-delà de la bonne remise des octets (voir le test
# d'envoi, qui écoute packet_received directement).
func _build_client_net() -> ArenaNetworkManager:
	var hub := FakeArenaNetHub.new()
	var host_transport := FakeArenaNetTransport.new(hub, 1, true)
	autofree(host_transport)
	host_transport.host({})
	var client_transport := FakeArenaNetTransport.new(hub, 200, false)
	var client_net := ArenaNetworkManager.new()
	autofree(client_net)
	client_net.is_host = false
	client_net.set_transport(client_transport)
	client_transport.join({})
	return client_net

func _make_match() -> ArenaMatch:
	var pool := ArenaCardPool.new([])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("Hôte"), ArenaPlayerState.new("Moi")]
	return ArenaMatch.new(players, pool)  # seat 0 = hôte, 1 = moi

func test_send_request_forwards_to_the_network_manager() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var received_by_host: Array = []
	var hub: FakeArenaNetHub = net.transport.hub
	hub._host.packet_received.connect(func(_peer_id: int, bytes: PackedByteArray) -> void:
		received_by_host.append(bytes_to_var(bytes)))

	link.send_request(ArenaGameCommand.request_reroll())

	assert_eq(received_by_host.size(), 1)
	assert_eq(ArenaGameCommand.type_of(received_by_host[0]), ArenaGameCommand.REQUEST_REROLL)

func test_board_sync_is_mirrored_to_the_targeted_seat() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var command: Dictionary = ArenaGameCommand.board_sync(
		0, 17, [{"resource_path": REAL_CARD_PATH, "star_level": 1, "base_attack": 1, "base_max_health": 1, "damage_taken": 0}], [])
	net.command_received.emit(1, command)

	var host_player: ArenaPlayerState = m.find_by_seat(0)
	assert_eq(host_player.hero_hp, 17)
	assert_eq(host_player.board_front.size(), 1)

func test_private_state_sync_for_my_own_seat_is_applied() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var command: Dictionary = ArenaGameCommand.private_state_sync(1, 9, 2, 1, false, [], [], [])
	net.command_received.emit(1, command)

	var me: ArenaPlayerState = m.find_by_seat(1)
	assert_eq(me.gold, 9)

func test_private_state_sync_for_another_seat_is_never_applied_to_my_own_player() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var me: ArenaPlayerState = m.find_by_seat(1)
	var gold_before: int = me.gold
	# Ne devrait jamais arriver en pratique (l'hôte n'envoie le privé qu'au bon
	# peer_id), mais le lien doit rester défensif si c'était le cas.
	var command: Dictionary = ArenaGameCommand.private_state_sync(0, 999, 0, 1, false, [], [], [])
	net.command_received.emit(1, command)

	assert_eq(me.gold, gold_before, "un PRIVATE_STATE_SYNC destiné à un autre siège ne doit jamais toucher le mien")

func test_state_changed_fires_for_board_sync_and_private_state_sync() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	# Array plutôt qu'un int : une lambda GDScript capture un int par valeur
	# (copie figée au moment de la connexion), pas par référence — incrémenter
	# une variable locale scalaire depuis l'intérieur ne serait jamais visible
	# ici. Un Array, lui, est capturé par référence (même objet partagé).
	var fire_count: Array = [0]
	link.state_changed.connect(func() -> void: fire_count[0] += 1)

	net.command_received.emit(1, ArenaGameCommand.board_sync(0, 10, [], []))
	net.command_received.emit(1, ArenaGameCommand.private_state_sync(1, 5, 0, 1, false, [], [], []))

	assert_eq(fire_count[0], 2, "chaque BOARD_SYNC et PRIVATE_STATE_SYNC appliqué doit déclencher state_changed")

func test_state_changed_does_not_fire_for_a_private_state_sync_targeting_another_seat() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var fire_count: Array = [0]
	link.state_changed.connect(func() -> void: fire_count[0] += 1)

	net.command_received.emit(1, ArenaGameCommand.private_state_sync(0, 999, 0, 1, false, [], [], []))

	assert_eq(fire_count[0], 0, "un PRIVATE_STATE_SYNC ignoré (pas le mien) ne doit pas déclencher de rafraîchissement")

func test_round_advanced_updates_the_round_number_and_emits_the_combat_log() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var received: Array = []
	link.round_advanced.connect(func(round_number: int, combat_log: Array) -> void: received.append([round_number, combat_log]))

	net.command_received.emit(1, ArenaGameCommand.round_advanced(3, ["Hôte vs Client : égalité, aucun dégât"]))

	assert_eq(m.round_number, 3)
	assert_eq(received.size(), 1)
	assert_eq(received[0][0], 3)
	assert_eq(received[0][1], ["Hôte vs Client : égalité, aucun dégât"])

func test_game_over_emits_the_ranking() -> void:
	var net := _build_client_net()
	var m := _make_match()
	var link := ArenaClientGameLink.new(m, net, 1, 1)
	autofree(link)

	var received_ranking: Array = []
	link.game_over.connect(func(ranking: Array) -> void: received_ranking.append(ranking))

	var ranking: Array = [{"seat_id": 0, "display_name": "Hôte"}, {"seat_id": 1, "display_name": "Moi"}]
	net.command_received.emit(1, ArenaGameCommand.game_over(ranking))

	assert_eq(received_ranking.size(), 1)
	assert_eq(received_ranking[0], ranking)
