extends GutTest

# Couvre EnchantmentSystem (scripts/systems/EnchantmentSystem.gd), la partie
# testable sans dépendre de la scène EnchantmentCard (chargée dynamiquement
# par _add_card, hors scope GUT — voir CLAUDE.md) : le calcul de resserrement
# des zones (_relayout) et les listes Enchantement/Rituel/Ressource par camp.
# Pas de classe nommée dans le script source : chargé par chemin, comme dans
# Battle.gd.

var enchantment_system
var battle: FakeBattle

func before_each() -> void:
	enchantment_system = load("res://scripts/systems/EnchantmentSystem.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()
	enchantment_system.init(battle)

func after_each() -> void:
	# extends Node : jamais ajouté à l'arbre de scène ici.
	enchantment_system.free()

func _zone_with_children(count: int, width: float = 460.0) -> HBoxContainer:
	var zone := HBoxContainer.new()
	zone.custom_minimum_size = Vector2(width, 0)
	for i in count:
		zone.add_child(Control.new())
	return zone

# ─── Listes par camp (getters) ─────────────────────────────────────────────────

func test_get_enchantments_returns_player_or_enemy_list() -> void:
	var card := CardData.new()
	enchantment_system.player_enchantments.append(card)
	assert_eq(enchantment_system.get_enchantments(true), [card])
	assert_eq(enchantment_system.get_enchantments(false), [])

func test_get_rituals_returns_player_or_enemy_list() -> void:
	var card := CardData.new()
	enchantment_system.enemy_rituals.append(card)
	assert_eq(enchantment_system.get_rituals(false), [card])
	assert_eq(enchantment_system.get_rituals(true), [])

# ─── Resserrement des zones (_relayout) ────────────────────────────────────────

func test_relayout_uses_default_separation_for_a_single_card() -> void:
	var zone := _zone_with_children(1)
	enchantment_system._relayout(zone)
	assert_eq(zone.get_theme_constant("separation"), enchantment_system.DEFAULT_SEPARATION)

func test_relayout_shrinks_separation_as_more_cards_are_added() -> void:
	var zone_few := _zone_with_children(2)
	var zone_many := _zone_with_children(8)
	enchantment_system._relayout(zone_few)
	var sep_few: int = zone_few.get_theme_constant("separation")
	enchantment_system._relayout(zone_many)
	var sep_many: int = zone_many.get_theme_constant("separation")
	assert_lt(sep_many, sep_few, "plus de cartes doit resserrer davantage l'espacement")

func test_relayout_never_exceeds_default_separation() -> void:
	# Zone large avec peu de cartes : la formule pourrait suggérer un espacement
	# > DEFAULT_SEPARATION, mais _relayout doit le plafonner.
	var zone := _zone_with_children(2, 2000.0)
	enchantment_system._relayout(zone)
	assert_lte(zone.get_theme_constant("separation"), enchantment_system.DEFAULT_SEPARATION)

func test_relayout_never_lets_cards_overflow_the_zone_frame() -> void:
	# Zone étroite avec beaucoup de cartes : l'espacement (même très négatif)
	# doit rester borné pour ne jamais faire déborder les cartes du cadre.
	var zone := _zone_with_children(10, 300.0)
	enchantment_system._relayout(zone)
	var sep: int = zone.get_theme_constant("separation")
	assert_gte(sep, -int(enchantment_system.CARD_WIDTH) + 20)

func test_relayout_ignores_children_queued_for_deletion() -> void:
	var zone := _zone_with_children(1)
	var doomed := Control.new()
	zone.add_child(doomed)
	doomed.queue_free()
	enchantment_system._relayout(zone)
	# Un seul enfant "vivant" restant : espacement par défaut, comme test_relayout_uses_default_separation_for_a_single_card.
	assert_eq(zone.get_theme_constant("separation"), enchantment_system.DEFAULT_SEPARATION)
