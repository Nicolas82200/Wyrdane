extends GutTest

# Vérifie que ArenaBattle._start_network_match() construit correctement les
# sièges (hôte ET client) à partir d'un vrai résultat de handshake — via le
# transport simulé (FakeArenaNetTransport/FakeArenaNetHub), jamais Steam réel.
#
# ArenaNetContext est STATIQUE (survit entre les tests du même run GUT) :
# chaque test doit le remettre à zéro après usage, sous peine de contaminer
# tous les tests suivants (y compris test_arena_battle_scene.gd, qui suppose
# ArenaNetContext.active == false par défaut pour rester en solo).

func after_each() -> void:
	ArenaNetContext.reset()

# Construit un hôte + `client_count` clients réels, puis comble le reste avec
# des bots (force_start_with_bots) pour ne pas avoir à réunir 7 vrais pairs.
#
# Ne libère JAMAIS les ArenaNetworkManager construits ici (ni host_net ni les
# client_nets) : ArenaBattle._start_network_match() rattache lui-même celui
# qu'il consomme (ArenaNetContext.net) dans son propre arbre de scène via
# add_child() — l'appelant du test doit donc explicitement `autofree()` le
# SEUL réseau qu'il n'aura pas donné à une scène ArenaBattle (voir les deux
# tests ci-dessous), sous peine de le libérer deux fois.
func _build_completed_handshake(client_count: int) -> Dictionary:
	var hub := FakeArenaNetHub.new()

	var host_transport := FakeArenaNetTransport.new(hub, 1, true)
	var host_net := ArenaNetworkManager.new()
	host_net.is_host = true
	host_net.set_transport(host_transport)
	var host_handshake := ArenaNetHandshake.new(host_net, true, "Hôte")
	autofree(host_handshake)
	# Holder Array plutôt qu'un Dictionary réassigné : une lambda GDScript
	# capture une variable locale par valeur (la référence est figée au
	# moment de la connexion), pas par référence vivante — `setup = s` dans
	# la lambda ne mettrait jamais à jour cette variable-ci (voir le même
	# piège déjà rencontré dans test_arena_client_game_link.gd). Un Array,
	# lui, est capturé par référence (même objet partagé).
	var host_setup_holder: Array = [{}]
	host_handshake.completed.connect(func(setup: Dictionary) -> void: host_setup_holder[0] = setup)
	host_transport.host({})

	var client_nets: Array = []
	var client_setup_holders: Array = []
	for i in client_count:
		var peer_id: int = 100 + i
		var client_transport := FakeArenaNetTransport.new(hub, peer_id, false)
		var client_net := ArenaNetworkManager.new()
		client_net.is_host = false
		client_net.set_transport(client_transport)
		var handshake := ArenaNetHandshake.new(client_net, false, "Joueur %d" % (i + 1))
		autofree(handshake)
		var setup_holder: Array = [{}]
		handshake.completed.connect(func(s: Dictionary) -> void: setup_holder[0] = s)
		client_nets.append(client_net)
		client_transport.join({})
		client_setup_holders.append(setup_holder)

	# Complète la table (1 hôte + `client_count` vrais clients, le reste en
	# bots) : c'est CE déclencheur qui fait réellement émettre `completed`
	# partout (voir ArenaNetHandshake._start_match), jamais le join() seul —
	# les holders ci-dessus ne sont donc lus qu'à partir d'ici.
	host_handshake.force_start_with_bots()

	var client_setups: Array = []
	for holder in client_setup_holders:
		client_setups.append(holder[0])

	return {
		"host_net": host_net,
		"host_handshake": host_handshake,
		"host_setup": host_setup_holder[0],
		"client_nets": client_nets,
		"client_setups": client_setups,
	}

func test_host_builds_a_real_authoritative_match_with_bots_and_a_router() -> void:
	var rig: Dictionary = _build_completed_handshake(1)
	autofree(rig.client_nets[0])  # non consommé par cette scène (voir _build_completed_handshake)
	ArenaNetContext.active = true
	ArenaNetContext.is_host = true
	ArenaNetContext.net = rig.host_net
	ArenaNetContext.handshake = rig.host_handshake
	ArenaNetContext.setup = rig.host_setup

	var scene: Control = load("res://scenes/arena/ArenaBattle.tscn").instantiate()
	add_child_autofree(scene)

	assert_eq(scene.human.seat_id, 0, "l'hôte occupe toujours le siège 0")
	assert_eq(scene.match_.players.size(), ArenaConstants.PARTICIPANT_COUNT)
	assert_gt(scene.bot_seats.size(), 0, "les sièges vacants (1 seul vrai client ici) doivent avoir été comblés par des bots")
	assert_not_null(scene.match_.pool, "l'hôte doit exécuter un ArenaMatch réel, avec un vrai pool de cartes")
	assert_eq(scene.match_.round_number, 1)

func test_client_builds_a_mirror_match_with_no_pool_and_the_right_own_seat() -> void:
	var rig: Dictionary = _build_completed_handshake(1)
	autofree(rig.host_net)  # non consommé par cette scène (voir _build_completed_handshake)
	var client_setup: Dictionary = rig.client_setups[0]
	ArenaNetContext.active = true
	ArenaNetContext.is_host = false
	ArenaNetContext.net = rig.client_nets[0]
	ArenaNetContext.handshake = null
	ArenaNetContext.setup = client_setup

	var scene: Control = load("res://scenes/arena/ArenaBattle.tscn").instantiate()
	add_child_autofree(scene)

	assert_eq(scene.human.seat_id, client_setup["seat_id"])
	assert_eq(scene.match_.players.size(), ArenaConstants.PARTICIPANT_COUNT)
	assert_true(scene.bots.size() > 0, "les sièges bot du roster doivent être reconnus côté client aussi (affichage)")

func test_arena_net_context_inactive_by_default_keeps_the_scene_fully_solo() -> void:
	# Garde-fou explicite : sans jamais passer par le lobby réseau,
	# ArenaNetContext.active doit rester false (valeur par défaut) et la scène
	# doit démarrer exactement comme avant ce chantier — voir _start_match().
	assert_false(ArenaNetContext.active)
	var scene: Control = load("res://scenes/arena/ArenaBattle.tscn").instantiate()
	add_child_autofree(scene)
	assert_false(scene._is_network)
	assert_eq(scene.bots.size(), ArenaConstants.PARTICIPANT_COUNT - 1, "en solo, tous les autres sièges restent des bots ArenaBotDriver classiques")
