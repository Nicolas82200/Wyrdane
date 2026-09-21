extends GutTest

# Couvre NetRegistry (scripts/net/NetRegistry.gd) : attribution d'ids réseau
# stables (parité host/invité via configure()), résolution id -> Minion, et le
# mécanisme de capture/imposition d'ids qui garde les deux clients synchronisés
# lors du rejeu d'une action distante (voir NetCommand/TurnSystem).

var registry: NetRegistry

func before_each() -> void:
	registry = NetRegistry.new()

func _minion() -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	return Minion.new(data, true)

func test_register_assigns_sequential_ids_starting_at_one_by_default() -> void:
	var a := registry.register(_minion())
	var b := registry.register(_minion())
	assert_eq(a, 1)
	assert_eq(b, 2)

func test_register_sets_minion_net_id() -> void:
	var minion := _minion()
	var id := registry.register(minion)
	assert_eq(minion.net_id, id)

func test_configure_sets_start_id_and_stride_for_parity() -> void:
	registry.configure(2, 2)  # host : pairs
	var a := registry.register(_minion())
	var b := registry.register(_minion())
	assert_eq(a, 2)
	assert_eq(b, 4)

func test_resolve_returns_registered_minion() -> void:
	var minion := _minion()
	var id := registry.register(minion)
	assert_eq(registry.resolve(id), minion)

func test_resolve_returns_null_for_unknown_id() -> void:
	assert_null(registry.resolve(999))

func test_unregister_removes_minion_from_resolution() -> void:
	var minion := _minion()
	var id := registry.register(minion)
	registry.unregister(minion)
	assert_null(registry.resolve(id))

func test_unregister_handles_null_without_crashing() -> void:
	registry.unregister(null)
	assert_true(true, "ne doit pas planter")

func test_clear_resets_ids_and_resolution() -> void:
	var minion := _minion()
	var id := registry.register(minion)
	registry.clear()
	assert_null(registry.resolve(id), "le registre vidé ne doit plus résoudre les anciens ids")
	var next_minion := _minion()
	var next_id := registry.register(next_minion)
	assert_eq(next_id, 1, "clear() doit remettre le compteur à 1 (parité par défaut)")

func test_begin_end_capture_returns_ids_created_during_capture() -> void:
	var token := registry.begin_capture()
	var a := registry.register(_minion())
	var b := registry.register(_minion())
	var captured := registry.end_capture(token)
	assert_eq(captured, [a, b])

func test_capture_does_not_include_registrations_before_or_after() -> void:
	registry.register(_minion())  # avant la capture
	var token := registry.begin_capture()
	var captured_id := registry.register(_minion())
	var captured := registry.end_capture(token)
	registry.register(_minion())  # après la capture
	assert_eq(captured, [captured_id])

func test_end_capture_stops_capturing() -> void:
	var token := registry.begin_capture()
	registry.register(_minion())
	registry.end_capture(token)
	registry.register(_minion())  # après la capture : ne doit pas s'ajouter à _captured
	var next_token := registry.begin_capture()  # nouvelle capture : repart de zéro
	assert_eq(registry.end_capture(next_token), [], "une capture fraîchement commencée sans nouveau register() doit être vide")

func test_end_capture_with_unknown_token_returns_empty() -> void:
	assert_eq(registry.end_capture(999), [], "un jeton inconnu (déjà consommé ou jamais ouvert) ne doit rien retourner")

# Bug corrigé : deux captures qui se CHEVAUCHENT sans imbrication stricte
# (ex. deux attaques différentes lancées coup sur coup, voir CombatSystem
# .resolve_combat — seul le serviteur attaquant est verrouillé pendant sa
# résolution, un second attaquant différent peut démarrer une nouvelle
# capture avant que la première ne se termine). Avec une pile aveugle
# (avant ce fix), la capture qui se termine en premier volait le niveau de
# l'autre au lieu du sien.
func test_two_overlapping_captures_each_keep_their_own_ids() -> void:
	var token_a := registry.begin_capture()
	var id_a1 := registry.register(_minion())
	var token_b := registry.begin_capture()  # B démarre pendant que A est encore ouverte
	var id_shared := registry.register(_minion())  # visible par A ET B
	# A se termine EN PREMIER, alors que B (ouverte après A) est toujours active.
	var captured_a := registry.end_capture(token_a)
	var id_b_only := registry.register(_minion())  # après la fin de A : seule B doit le voir
	var captured_b := registry.end_capture(token_b)
	assert_eq(captured_a, [id_a1, id_shared], "A garde ses propres ids malgré la fermeture précoce")
	assert_eq(captured_b, [id_shared, id_b_only], "B garde les siens, non contaminés par la fermeture de A")

func test_set_imposed_ids_consumes_them_in_order_instead_of_generating() -> void:
	registry.set_imposed_ids([10, 20, 30])
	var a := registry.register(_minion())
	var b := registry.register(_minion())
	assert_eq(a, 10)
	assert_eq(b, 20)
	assert_eq(registry.resolve(30), null, "id imposé non encore consommé : pas encore enregistré")

func test_register_falls_back_to_sequential_ids_once_imposed_queue_is_exhausted() -> void:
	registry.configure(5, 1)
	registry.set_imposed_ids([10])
	registry.register(_minion())  # consomme l'id imposé 10
	var next_id := registry.register(_minion())
	assert_eq(next_id, 5, "file d'ids imposés épuisée : retombe sur la parité locale")
