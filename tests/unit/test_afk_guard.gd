extends GutTest

# Couvre AfkGuard (scripts/net/AfkGuard.gd) : timer de tour invisible par
# défaut, affiché seulement sur inactivité (IDLE_BEFORE_VISIBLE) ou plafond de
# tour (TURN_CAP_BEFORE_VISIBLE), tour "sans action possible" resserré à 10s,
# et forfait réseau après 3 tours AFK d'affilée. Utilise FakeBattle
# (tests/unit/doubles/fake_battle.gd), conformément à la convention GUT du projet.

var guard: AfkGuard
var battle: FakeBattle

func before_each() -> void:
	guard = load("res://scripts/net/AfkGuard.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	guard.init(battle)

func _make_network() -> void:
	battle.net_emitter = load("res://tests/unit/doubles/fake_battle.gd").FakeNetEmitter.new()

# ─── Début de tour : timer toujours masqué au départ (solo ET réseau) ────────

func test_begin_turn_never_starts_a_visible_timer_in_solo() -> void:
	guard.begin_turn()
	assert_eq(battle.turn_timer.start_calls, [], "solo : aucun timer visible au début du tour")

func test_begin_turn_never_starts_a_visible_timer_in_network() -> void:
	_make_network()
	guard.begin_turn()
	assert_eq(battle.turn_timer.start_calls, [], "réseau : aucun timer visible au début du tour")

# ─── Inactivité : le timer n'apparaît qu'après IDLE_BEFORE_VISIBLE secondes ───

func test_update_shows_timer_after_idle_threshold_in_solo() -> void:
	guard.begin_turn()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE - 1.0)
	assert_eq(battle.turn_timer.start_calls, [], "pas encore affiché avant le seuil")
	guard.update(1.0)
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.VISIBLE_DURATION])

func test_update_shows_timer_after_idle_threshold_in_network() -> void:
	_make_network()
	guard.begin_turn()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.VISIBLE_DURATION])

func test_local_action_hides_idle_triggered_timer_and_resets_countdown() -> void:
	guard.begin_turn()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)
	assert_true(battle.turn_timer.running, "timer affiché après inactivité")
	guard.notify_local_action()
	assert_false(battle.turn_timer.running, "une action locale referme le timer d'inactivité")
	# Le décompte d'inactivité repart de zéro : pas de nouvelle apparition avant
	# un nouveau plein seuil.
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE - 1.0)
	assert_false(battle.turn_timer.running)

func test_local_action_ignored_during_enemy_turn() -> void:
	battle.enemy_turn_active = true
	guard.notify_local_action()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)
	assert_eq(battle.turn_timer.start_calls, [], "pas de suivi pendant le tour adverse")

# ─── Plafond de tour : apparaît après TURN_CAP_BEFORE_VISIBLE, même actif ─────

func test_update_shows_timer_after_turn_cap_even_with_recent_action() -> void:
	guard.begin_turn()
	# Le joueur agit régulièrement, bien en-deçà du seuil d'inactivité...
	for i in range(6):
		guard.update(AfkGuard.IDLE_BEFORE_VISIBLE / 2.0)
		guard.notify_local_action()
	# ...mais le tour dépasse maintenant le plafond absolu (6 * 15s = 90s > 60s).
	assert_true(battle.turn_timer.running, "le plafond de tour force le timer même actif")

func test_local_action_does_not_cancel_turn_cap_timer() -> void:
	guard.begin_turn()
	# Le joueur agit régulièrement (idle jamais atteint) pour que ce soit bien
	# le plafond absolu de tour qui déclenche le timer, pas l'inactivité.
	for i in range(3):
		guard.update(AfkGuard.IDLE_BEFORE_VISIBLE - 1.0)
		guard.notify_local_action()
	assert_true(battle.turn_timer.running, "le plafond de tour (3*29s > 60s) a déclenché le timer")
	var calls_before: int = battle.turn_timer.start_calls.size()
	guard.notify_local_action()
	assert_true(battle.turn_timer.running, "le plafond de tour n'est jamais annulé par une action")
	assert_eq(battle.turn_timer.start_calls.size(), calls_before, "pas de redémarrage inutile")

# ─── Solo : jamais de forfait ──────────────────────────────────────────────

func test_solo_handle_timeout_never_forfeits() -> void:
	for i in range(10):
		var should_continue: bool = await guard.handle_timeout()
		assert_true(should_continue, "solo : jamais de forfait AFK")
	assert_eq(battle.net_session_system.close_calls, 0)

# ─── Série AFK et forfait réseau ────────────────────────────────────────────

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

# ─── Tour sans action possible : réseau uniquement, affiché/resserré à 10s ───
# En solo, le halo doré existant du bouton Fin du tour (indépendant d'AfkGuard)
# sert déjà de nudge visuel : pas de compte à rebours ici, pour ne jamais faire
# apparaître le timer avant le seuil normal de 30s d'inactivité.

func test_no_action_state_is_a_no_op_in_solo() -> void:
	guard.begin_turn()
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls, [], "solo : pas de timer forcé sur main sans jouable")

func test_no_action_state_shows_timer_immediately_at_ten_seconds_in_network() -> void:
	_make_network()
	guard.begin_turn()
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.NO_ACTION_TIMEOUT])

func test_no_action_state_shortens_an_already_running_timer_in_network() -> void:
	_make_network()
	guard.begin_turn()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)  # affiché à 30s
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls[-1], AfkGuard.NO_ACTION_TIMEOUT)

func test_no_action_state_does_not_extend_an_already_shorter_timer_in_network() -> void:
	_make_network()
	guard.begin_turn()
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)
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

func test_no_action_state_ignored_during_enemy_turn_in_network() -> void:
	_make_network()
	battle.enemy_turn_active = true
	guard.set_no_action_state(true)
	assert_eq(battle.turn_timer.start_calls, [], "pas de démarrage hors tour local en cours")

# ─── Reconnexion réseau ─────────────────────────────────────────────────────

func test_resume_turn_timer_shows_timer_immediately() -> void:
	_make_network()
	guard.resume_turn_timer()
	assert_eq(battle.turn_timer.start_calls, [AfkGuard.VISIBLE_DURATION])

func test_update_ignored_while_reconnecting() -> void:
	_make_network()
	guard.begin_turn()
	battle.reconnecting = true
	guard.update(AfkGuard.IDLE_BEFORE_VISIBLE)
	assert_eq(battle.turn_timer.start_calls, [], "pas de suivi pendant une coupure réseau")
