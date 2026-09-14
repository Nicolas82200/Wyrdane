extends GutTest

# Couvre Graveyard (scripts/graveyard/Graveyard.gd) : classe pure sans
# dépendance, testée directement sans double (voir CLAUDE.md, convention GUT
# du projet). Pile LIFO des cartes mortes/jouées/défaussées d'un camp.

func _card(name: String = "TEST_CARD") -> CardData:
	var data := CardData.new()
	data.card_name = name
	return data

func test_new_graveyard_is_empty() -> void:
	var grave := Graveyard.new()
	assert_eq(grave.size(), 0)
	assert_null(grave.last_card_data())

func test_add_minion_increases_size_and_becomes_last() -> void:
	var grave := Graveyard.new()
	var card := _card("Squelette")
	grave.add_minion(card)
	assert_eq(grave.size(), 1)
	assert_eq(grave.last_card_data(), card)

func test_last_card_data_reflects_most_recent_addition() -> void:
	var grave := Graveyard.new()
	grave.add_minion(_card("Premier"))
	var last := _card("Dernier")
	grave.add_spell(last)
	assert_eq(grave.last_card_data(), last)

func test_add_minion_spell_discarded_all_increase_size() -> void:
	var grave := Graveyard.new()
	grave.add_minion(_card())
	grave.add_spell(_card())
	grave.add_discarded(_card())
	assert_eq(grave.size(), 3)

func test_get_minions_only_returns_minion_death_entries() -> void:
	var grave := Graveyard.new()
	var dead_minion := _card("Mort au combat")
	grave.add_minion(dead_minion)
	grave.add_spell(_card("Sort joué"))
	grave.add_discarded(_card("Défaussée"))
	var minions := grave.get_minions()
	assert_eq(minions.size(), 1)
	assert_eq(minions[0], dead_minion)

func test_is_face_down_true_only_for_discarded_entries() -> void:
	var grave := Graveyard.new()
	grave.add_minion(_card())
	grave.add_discarded(_card())
	assert_false(grave.is_face_down(grave.entries[0]))
	assert_true(grave.is_face_down(grave.entries[1]))

func test_remove_minion_removes_most_recent_matching_entry() -> void:
	var grave := Graveyard.new()
	var card := _card("Doublon")
	grave.add_minion(_card("Autre"))
	grave.add_minion(card)
	grave.add_minion(card)
	grave.remove_minion(card)
	assert_eq(grave.size(), 2, "une seule des deux occurrences doit être retirée")
	assert_eq(grave.entries[1]["card_data"], card, "la plus ancienne occurrence doit rester")

func test_remove_minion_does_not_remove_spell_or_discarded_entries() -> void:
	# remove_minion ne doit retirer qu'une entrée MINION_DEATH : une carte
	# revenue en main/jeu par résurrection ne doit jamais pouvoir "consommer"
	# la même CardData listée comme sort joué ou carte défaussée.
	var grave := Graveyard.new()
	var card := _card("Carte")
	grave.add_spell(card)
	grave.remove_minion(card)
	assert_eq(grave.size(), 1)

func test_remove_minion_with_no_match_is_a_no_op() -> void:
	var grave := Graveyard.new()
	grave.add_minion(_card("Présente"))
	grave.remove_minion(_card("Absente"))
	assert_eq(grave.size(), 1)

func test_graveyard_changed_emitted_on_add_and_remove() -> void:
	var grave := Graveyard.new()
	var card := _card()
	watch_signals(grave)
	grave.add_minion(card)
	assert_signal_emit_count(grave, "graveyard_changed", 1)
	grave.remove_minion(card)
	assert_signal_emit_count(grave, "graveyard_changed", 2)

func test_remove_minion_no_match_does_not_emit_signal() -> void:
	var grave := Graveyard.new()
	grave.add_minion(_card("Présente"))
	watch_signals(grave)
	grave.remove_minion(_card("Absente"))
	assert_signal_emit_count(grave, "graveyard_changed", 0)
