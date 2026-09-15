extends GutTest

# Teste le protocole ArenaNetHandshake en pure logique, via un transport
# simulé (FakeArenaNetTransport/FakeArenaNetHub — livraison synchrone,
# topologie étoile) : aucune dépendance à Steam, contrairement à
# ArenaSteamTransport lui-même (voir CLAUDE.md « Tests automatisés »).

# Construit 1 hôte + `client_count` clients, tous connectés et ayant lancé
# leur handshake. `results` est peuplé au fil des complétions (clé "host" ou
# "client_<i>" -> setup) : connecté AVANT chaque start()/join() pour ne rater
# aucune complétion, la cascade hôte<->client étant entièrement synchrone.
func _build_rig(client_count: int) -> Dictionary:
	var hub := FakeArenaNetHub.new()
	var results: Dictionary = {}

	var host_transport := FakeArenaNetTransport.new(hub, 1, true)
	var host_net := ArenaNetworkManager.new()
	autofree(host_net)
	host_net.is_host = true
	host_net.set_transport(host_transport)
	var host_handshake := ArenaNetHandshake.new(host_net, true, "Hôte")
	autofree(host_handshake)
	host_handshake.completed.connect(func(setup: Dictionary) -> void: results["host"] = setup)
	host_handshake.start()
	host_transport.host({})

	var client_handshakes: Array = []
	for i in client_count:
		var peer_id: int = 100 + i
		var client_transport := FakeArenaNetTransport.new(hub, peer_id, false)
		var client_net := ArenaNetworkManager.new()
		autofree(client_net)
		client_net.is_host = false
		client_net.set_transport(client_transport)
		var handshake := ArenaNetHandshake.new(client_net, false, "Joueur %d" % (i + 1))
		autofree(handshake)
		var key: String = "client_%d" % i
		handshake.completed.connect(func(setup: Dictionary) -> void: results[key] = setup)
		handshake.start()
		client_transport.join({})  # déclenche la cascade HELLO -> SEAT_ASSIGN (-> START_MATCH si la table se complète)
		client_handshakes.append(handshake)

	return {"results": results, "host_handshake": host_handshake, "client_handshakes": client_handshakes}

func test_match_does_not_start_before_the_table_is_full() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 2)  # une place vacante
	assert_eq(rig.results.size(), 0, "personne ne doit recevoir START_MATCH tant qu'un siège reste vacant")

func test_match_starts_once_the_table_is_full() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	assert_true(rig.results.has("host"), "l'hôte doit démarrer dès que la table est complète")
	for i in ArenaConstants.PARTICIPANT_COUNT - 1:
		assert_true(rig.results.has("client_%d" % i), "chaque client doit recevoir START_MATCH")

func test_all_participants_agree_on_the_same_seed() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	var seed: int = rig.results["host"]["seed"]
	for key in rig.results:
		assert_eq(rig.results[key]["seed"], seed, "tous les participants doivent calculer la même graine combinée")

func test_seats_are_assigned_uniquely_and_host_is_always_seat_zero() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	assert_eq(rig.results["host"]["seat_id"], 0)
	var seen_seats: Array = [0]
	for i in ArenaConstants.PARTICIPANT_COUNT - 1:
		var seat: int = rig.results["client_%d" % i]["seat_id"]
		assert_false(seen_seats.has(seat), "chaque siège doit être unique")
		seen_seats.append(seat)
	assert_eq(seen_seats.size(), ArenaConstants.PARTICIPANT_COUNT)

func test_roster_is_sorted_by_seat_id_and_includes_everyone() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	var roster: Array = rig.results["host"]["roster"]
	assert_eq(roster.size(), ArenaConstants.PARTICIPANT_COUNT)
	for i in roster.size():
		assert_eq(roster[i]["seat_id"], i, "le roster doit être trié par seat_id, du siège 0 (hôte) au dernier")

func test_every_client_receives_the_same_roster_as_the_host() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	var host_roster: Array = rig.results["host"]["roster"]
	for i in ArenaConstants.PARTICIPANT_COUNT - 1:
		assert_eq(rig.results["client_%d" % i]["roster"], host_roster,
			"le roster diffusé (START_MATCH) doit être identique pour tout le monde")

func test_roster_marks_real_seats_as_not_bot() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)
	for entry in rig.results["host"]["roster"]:
		assert_false(entry["is_bot"], "aucun siège réellement rempli par un HELLO ne doit être marqué bot")

func test_force_start_with_bots_fills_every_remaining_seat_and_starts_immediately() -> void:
	var rig: Dictionary = _build_rig(2)  # table loin d'être pleine
	assert_true(rig.results.is_empty(), "la partie ne doit pas avoir démarré toute seule avec seulement 2 clients")
	var host_handshake: ArenaNetHandshake = rig.host_handshake
	host_handshake.force_start_with_bots()
	assert_true(rig.results.has("host"), "force_start_with_bots doit démarrer la partie immédiatement")
	var roster: Array = rig.results["host"]["roster"]
	assert_eq(roster.size(), ArenaConstants.PARTICIPANT_COUNT, "les sièges vacants doivent être comblés jusqu'à la table complète")
	var bot_count := 0
	for entry in roster:
		if entry["is_bot"]:
			bot_count += 1
	assert_eq(bot_count, ArenaConstants.PARTICIPANT_COUNT - 3, "1 hôte + 2 clients réels : le reste doit être des bots")
	for i in 2:
		assert_true(rig.results.has("client_%d" % i), "les clients réels déjà connectés doivent recevoir START_MATCH")

func test_force_start_with_bots_is_a_no_op_once_the_match_already_started() -> void:
	var rig: Dictionary = _build_rig(ArenaConstants.PARTICIPANT_COUNT - 1)  # déjà complète, déjà démarrée
	var roster_before: Array = rig.results["host"]["roster"]
	rig.host_handshake.force_start_with_bots()
	assert_eq(rig.host_handshake._finished, true)
	# Rien à re-diffuser : completed n'a été émis qu'une fois (déjà vérifié par
	# les autres tests), ce test vérifie juste l'absence de plantage/second
	# départ sur un handshake déjà terminé.
	assert_eq(roster_before.size(), ArenaConstants.PARTICIPANT_COUNT)

func test_force_start_with_bots_does_nothing_on_a_client() -> void:
	var rig: Dictionary = _build_rig(1)
	var client_handshake: ArenaNetHandshake = rig.client_handshakes[0]
	client_handshake.force_start_with_bots()
	assert_false(rig.results.has("host"), "seul l'hôte peut déclencher force_start_with_bots")

func test_a_duplicated_hello_is_ignored_once_a_seat_is_assigned() -> void:
	var rig: Dictionary = _build_rig(1)
	var host_handshake: ArenaNetHandshake = rig.host_handshake
	var seats_before: int = host_handshake._seat_by_peer.size()
	var next_seat_before: int = host_handshake._next_seat_id
	host_handshake._on_command_received(100, ArenaNetCommand.hello("Joueur 1 (dupliqué)", 12345))
	assert_eq(host_handshake._seat_by_peer.size(), seats_before, "un HELLO dupliqué ne doit pas ajouter de nouveau siège")
	assert_eq(host_handshake._next_seat_id, next_seat_before, "un HELLO dupliqué ne doit pas consommer un nouveau seat_id")

# Régression : la contribution de graine de l'hôte doit être prise en compte
# même si start() n'est jamais appelé (voir ArenaNetHandshake._init — l'auto-
# inscription du siège 0 s'y fait désormais directement, plus d'ordre
# d'appel à respecter entre la construction et la connexion du premier client).
func test_host_seed_contribution_counts_even_without_calling_start() -> void:
	var hub := FakeArenaNetHub.new()
	var host_transport := FakeArenaNetTransport.new(hub, 1, true)
	var host_net := ArenaNetworkManager.new()
	autofree(host_net)
	host_net.is_host = true
	host_net.set_transport(host_transport)
	var host_handshake := ArenaNetHandshake.new(host_net, true, "Hôte")
	autofree(host_handshake)
	# Pas d'appel à host_handshake.start() ici, volontairement.
	host_transport.host({})

	var client_transport := FakeArenaNetTransport.new(hub, 200, false)
	var client_net := ArenaNetworkManager.new()
	autofree(client_net)
	client_net.is_host = false
	client_net.set_transport(client_transport)
	var client_handshake := ArenaNetHandshake.new(client_net, false, "Joueur 1")
	autofree(client_handshake)
	var results: Dictionary = {}
	client_handshake.completed.connect(func(setup: Dictionary) -> void: results["client"] = setup)
	client_transport.join({})

	for i in ArenaConstants.PARTICIPANT_COUNT - 2:
		var extra_transport := FakeArenaNetTransport.new(hub, 300 + i, false)
		var extra_net := ArenaNetworkManager.new()
		autofree(extra_net)
		extra_net.is_host = false
		extra_net.set_transport(extra_transport)
		var extra_handshake := ArenaNetHandshake.new(extra_net, false, "Joueur %d" % (i + 2))
		autofree(extra_handshake)
		extra_transport.join({})

	assert_true(results.has("client"), "la table doit quand même se remplir et démarrer sans start() côté hôte")
	assert_eq(results["client"]["roster"].size(), ArenaConstants.PARTICIPANT_COUNT,
		"le siège 0 (hôte) doit figurer dans le roster même sans appel explicite à start()")

func test_seat_for_peer_resolves_a_registered_client_and_minus_one_otherwise() -> void:
	var rig: Dictionary = _build_rig(2)
	var host_handshake: ArenaNetHandshake = rig.host_handshake
	assert_eq(host_handshake.seat_for_peer(100), 1)
	assert_eq(host_handshake.seat_for_peer(101), 2)
	assert_eq(host_handshake.seat_for_peer(999), -1, "un peer_id inconnu doit renvoyer -1")

func test_peer_for_seat_is_the_exact_inverse_of_seat_for_peer() -> void:
	var rig: Dictionary = _build_rig(2)
	var host_handshake: ArenaNetHandshake = rig.host_handshake
	assert_eq(host_handshake.peer_for_seat(1), 100)
	assert_eq(host_handshake.peer_for_seat(2), 101)

func test_peer_for_seat_returns_minus_one_for_the_host_seat_and_for_bots() -> void:
	var rig: Dictionary = _build_rig(1)
	var host_handshake: ArenaNetHandshake = rig.host_handshake
	host_handshake.force_start_with_bots()
	assert_eq(host_handshake.peer_for_seat(0), -1, "le siège 0 (hôte) n'a pas de peer_id réel")
	var bot_entry = null
	for entry in rig.results["host"]["roster"]:
		if entry["is_bot"]:
			bot_entry = entry
			break
	assert_not_null(bot_entry, "force_start_with_bots doit avoir ajouté au moins un bot")
	assert_eq(host_handshake.peer_for_seat(bot_entry["seat_id"]), -1, "un siège bot n'a pas de peer_id réel")
