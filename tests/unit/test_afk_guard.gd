extends GutTest

# Couvre AfkGuard (scripts/net/AfkGuard.gd) : décompte d'inactivité réseau,
# tour "sans action possible" resserré à 10s, et forfait après 3 tours AFK
# d'affilée. Utilise FakeBattle (tests/unit/doubles/fake_battle.gd),
# conformément à la convention GUT du projet.

var guard: AfkGuard
var battle: FakeBattle

func before_each() -> void:
	guard = load("res://scripts/net/AfkGuard.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	guard.init(battle)

func _make_network() -> void:
	# Seule la non-nullité de net_emitter conditionne AfkGuard.active().
	battle.net_emitter = load("res://tests/unit/doubles/fake_battle.gd").FakeNetEmitter.new()

# ─── Solo (net_emitter == null) : comportement inchangé ──────────────────────

func test_inactive_in_solo_begin_turn_uses_default_duration() -> void:
	guard.begin_turn()
	assert_eq(battle.turn_timer.start_calls, [-1.0], "solo : start() sans argument (défaut TurnTimer)")

func test_inactive_in_solo_handle_timeout_never_forfeits() -> void:
	for i in range(10):
		var should_continue: bool = await guard.handle_timeout()
		assert_true(should_continue, "solo : jamais de forfait AFK")
	assert_eq(battle.net_session_system.close_calls, 0)

# ─── Réseau : décompte d'inactivité ────────────────────────────────────────

func test_begin_turn_starts_idle_timeout_in_network() -> void:
	_make_network()
	guard.begin_turn()
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.IDLE_TIMEOUT])

func test_local_action_resets_idle_timer() -> void:
	_make_network()
	guard.begin_turn()
	guard.notify_local_action()
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.IDLE_TIMEOUT, AfkGuard.IDLE_TIMEOUT])

func test_local_action_ignored_during_enemy_turn() -> void:
	_make_network()
	battle.enemy_turn_active = true
	guard.notify_local_action()
	assert_eq(battle.turn_timer.start_calls, [], "aucune action locale possible pendant le tour adverse")

# ─── Série AFK et forfait ───────────────────────────────────────────────────

func test_timeout_without_action_increments_streak_and_continues_turn() -> void:
	_make_network()
	guard.begin_turn()
	var should_continue: bool = await guard.handle_timeout()
	assert_true(should_continue)
	assert_eq(guard.consecutive_afk_turns, 1)

func test_timeout_after_local_action_does_not_count_as_afk() -> void:
	_make_network()
	guard.begin_turn()
	guard.notify_local_action()
	await guard.handle_timeout()
	assert_eq(guard.consecutive_afk_turns, 0)

func test_forfeit_after_three_consecutive_afk_turns() -> void:
	_make_network()
	for i in range(AfkGuard.MAX_AFK_STREAK - 1):
		guard.begin_turn()
		var should_continue: bool = await guard.handle_timeout()
		assert_true(should_continue, "pas encore de forfait avant le 3e tour AFK")
	guard.begin_turn()
	var final_continue: bool = await guard.handle_timeout()
	assert_false(final_continue, "le 3e tour AFK déclenche le forfait")
	assert_true(battle.game_over)
	assert_eq(battle.net_session_system.close_calls, 1, "prévient le pair (LEAVE_MATCH) sans attendre la reconnexion")
	assert_eq(battle.show_game_over_calls, ["defeat"])

func test_manual_end_turn_resets_afk_streak() -> void:
	_make_network()
	guard.begin_turn()
	await guard.handle_timeout()
	assert_eq(guard.consecutive_afk_turns, 1)
	guard.notify_manual_end_turn()
	assert_eq(guard.consecutive_afk_turns, 0)

# ─── Tour sans action possible : resserré à 10s, jamais compté AFK ───────────

func test_no_action_state_shortens_running_timer_to_ten_seconds() -> void:
	_make_network()
	guard.begin_turn()  # démarre à 30s
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls[-1], AfkGuard.NO_ACTION_TIMEOUT)

func test_no_action_state_does_not_extend_an_already_shorter_timer() -> void:
	_make_network()
	guard.begin_turn()
	battle.turn_timer.time_left = 5.0  # déjà plus court que 10s
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls.size(), 1, "pas de redémarrage si le décompte est déjà plus court")

func test_forced_no_action_timeout_does_not_count_as_afk() -> void:
	_make_network()
	guard.begin_turn()
	guard.set_no_action_state(true)
	var should_continue: bool = await guard.handle_timeout()
	assert_true(should_continue)
	assert_eq(guard.consecutive_afk_turns, 0, "à court de coups n'est pas de l'AFK")

func test_no_action_state_ignored_while_timer_not_running() -> void:
	_make_network()
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls, [], "pas de démarrage hors tour local en cours")
