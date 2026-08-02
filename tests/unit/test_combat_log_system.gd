extends GutTest

# Couvre CombatLogSystem (scripts/systems/CombatLogSystem.gd) : construction
# des entrées du journal de combat (icône + segments) et la limite
# MAX_ENTRIES. Pas de dépendance à FakeBattle : ce système ne lit jamais
# `battle` dans son propre code (seul CombatLogPanel, non couvert ici, le fait).

var combat_log: CombatLogSystem

func before_each() -> void:
	combat_log = load("res://scripts/systems/CombatLogSystem.gd").new()

func after_each() -> void:
	# CombatLogSystem extends Node : jamais ajouté à l'arbre de scène ici.
	combat_log.free()

func _minion(is_player: bool = true) -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.card_type = "Minion"
	data.attack = 1
	data.health = 1
	return Minion.new(data, is_player)

func _spell() -> CardData:
	var data := CardData.new()
	data.card_name = "TEST_SPELL"
	data.card_type = "Instant"
	return data

func test_card_played_appends_one_entry() -> void:
	combat_log.card_played(_spell(), true)
	assert_eq(combat_log.entries.size(), 1)

func test_card_played_uses_plus_icon_for_minion_and_sparkle_for_others() -> void:
	var minion_data := CardData.new()
	minion_data.card_type = "Minion"
	combat_log.card_played(minion_data, true)
	combat_log.card_played(_spell(), true)
	assert_eq(combat_log.entries[0]["icon"], "➕")
	assert_eq(combat_log.entries[1]["icon"], "✨")

func test_attack_appends_entry_with_damage_segment() -> void:
	var attacker := _minion(true)
	var defender := _minion(false)
	combat_log.attack(attacker, defender, 3)
	assert_eq(combat_log.entries.size(), 1)
	var segments: Array = combat_log.entries[0]["segments"]
	assert_eq(segments[3]["text"], "-3")

func test_attack_with_zero_damage_and_no_deaths_is_skipped() -> void:
	var attacker := _minion(true)
	var defender := _minion(false)
	combat_log.attack(attacker, defender, 0)
	assert_eq(combat_log.entries.size(), 0, "une attaque sans dégâts ni mort ne mérite pas d'entrée")

func test_attack_with_zero_damage_but_a_death_is_still_logged() -> void:
	var attacker := _minion(true)
	var defender := _minion(false)
	combat_log.attack(attacker, defender, 0, false, true)
	assert_eq(combat_log.entries.size(), 1, "une mort doit être journalisée même sans dégâts (ex: Égide)")

func test_attack_hero_skips_when_no_damage() -> void:
	var attacker := _minion(true)
	combat_log.attack_hero(attacker, false, 0)
	assert_eq(combat_log.entries.size(), 0)

func test_attack_hero_logs_target_camp() -> void:
	var attacker := _minion(true)
	combat_log.attack_hero(attacker, false, 5)
	var segments: Array = combat_log.entries[0]["segments"]
	assert_eq(segments[2]["is_player"], false)
	assert_eq(segments[3]["text"], "-5")

func test_minion_died_appends_skull_icon() -> void:
	combat_log.minion_died(_minion(true))
	assert_eq(combat_log.entries[0]["icon"], "💀")

func test_infection_tick_appends_entry() -> void:
	combat_log.infection_tick(_minion(true))
	assert_eq(combat_log.entries[0]["icon"], "🧪")

func test_self_damage_skips_when_zero() -> void:
	combat_log.self_damage(true, 0)
	assert_eq(combat_log.entries.size(), 0)

func test_self_damage_logs_amount() -> void:
	combat_log.self_damage(true, 2)
	var segments: Array = combat_log.entries[0]["segments"]
	assert_eq(segments[1]["text"], "-2")

func test_entry_added_signal_emits_with_new_entry() -> void:
	var received: Array = []
	combat_log.entry_added.connect(func(entry: Dictionary): received.append(entry))
	combat_log.minion_died(_minion(true))
	assert_eq(received.size(), 1)
	assert_eq(received[0]["icon"], "💀")

func test_max_entries_evicts_oldest_entry() -> void:
	for i in CombatLogSystem.MAX_ENTRIES:
		combat_log.self_damage(true, 1)
	assert_eq(combat_log.entries.size(), CombatLogSystem.MAX_ENTRIES)
	combat_log.self_damage(true, 1)
	assert_eq(combat_log.entries.size(), CombatLogSystem.MAX_ENTRIES,
		"le journal ne doit jamais dépasser MAX_ENTRIES")

func test_seg_card_with_null_card_data_falls_back_to_text_segment() -> void:
	# minion_died avec une carte nulle ne doit pas planter (garde-fou de _seg_card).
	var data := CardData.new()
	data.card_name = "TEST"
	var minion := Minion.new(data, true)
	minion.card_data = null
	combat_log.minion_died(minion)
	var seg: Dictionary = combat_log.entries[0]["segments"][0]
	assert_eq(seg["type"], "text")
	assert_eq(seg["text"], "?")
