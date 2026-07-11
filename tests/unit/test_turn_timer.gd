extends GutTest

# Couvre la logique pure de décompte de TurnTimer (scripts/battle/TurnTimer.gd),
# indépendamment de l'arbre de scène (voir tick() dans TurnTimer.gd).

var timer

func before_each() -> void:
	timer = load("res://scripts/battle/TurnTimer.gd").new()

func after_each() -> void:
	timer.free()

func test_start_sets_time_left_and_running() -> void:
	timer.start(10.0)
	assert_eq(timer.time_left, 10.0)
	assert_true(timer.running)

func test_tick_decrements_time_left() -> void:
	timer.start(10.0)
	var timed_out: bool = timer.tick(3.0)
	assert_eq(timer.time_left, 7.0)
	assert_true(timer.running)
	assert_false(timed_out)

func test_tick_reaching_zero_stops_and_reports_timeout() -> void:
	timer.start(5.0)
	var timed_out: bool = timer.tick(5.0)
	assert_true(timed_out)
	assert_false(timer.running)

func test_tick_never_goes_negative() -> void:
	timer.start(2.0)
	timer.tick(10.0)
	assert_eq(timer.time_left, 0.0)

func test_tick_after_timeout_does_not_report_it_again() -> void:
	timer.start(1.0)
	timer.tick(2.0)
	var second_timed_out: bool = timer.tick(1.0)
	assert_false(second_timed_out)

func test_stop_marks_not_running() -> void:
	timer.start(10.0)
	timer.stop()
	assert_false(timer.running)
