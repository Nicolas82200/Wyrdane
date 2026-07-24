extends GutTest

# Couvre Hero (scripts/hero/Hero.gd) : classe pure sans dépendance, testée
# directement sans double (voir CLAUDE.md, convention GUT du projet).

func test_default_health_is_thirty() -> void:
	var hero := Hero.new()
	assert_eq(hero.health, 30)
	assert_eq(hero.max_health, 30)

func test_custom_start_health() -> void:
	var hero := Hero.new(15)
	assert_eq(hero.health, 15)
	assert_eq(hero.max_health, 15)

func test_take_damage_reduces_health() -> void:
	var hero := Hero.new(10)
	hero.take_damage(4)
	assert_eq(hero.health, 6)

func test_take_damage_can_go_below_zero() -> void:
	# Constat : take_damage() ne clampe pas à 0, contrairement à Minion.take_damage.
	var hero := Hero.new(5)
	hero.take_damage(8)
	assert_eq(hero.health, -3)

func test_heal_increases_health() -> void:
	var hero := Hero.new(10)
	hero.take_damage(6)
	hero.heal(3)
	assert_eq(hero.health, 7)

func test_heal_has_no_upper_clamp() -> void:
	# Constat : heal() n'est pas plafonné à max_health, contrairement à Minion.heal.
	var hero := Hero.new(10)
	hero.heal(5)
	assert_eq(hero.health, 15)

func test_heal_blocked_when_heal_block_turns_active() -> void:
	var hero := Hero.new(10)
	hero.take_damage(4)
	hero.heal_block_turns = 1
	hero.heal(3)
	assert_eq(hero.health, 6, "heal() doit être sans effet tant que heal_block_turns > 0")

func test_is_dead_at_zero() -> void:
	var hero := Hero.new(5)
	hero.take_damage(5)
	assert_true(hero.is_dead())

func test_is_dead_below_zero() -> void:
	var hero := Hero.new(5)
	hero.take_damage(9)
	assert_true(hero.is_dead())

func test_is_not_dead_above_zero() -> void:
	var hero := Hero.new(5)
	hero.take_damage(4)
	assert_false(hero.is_dead())
