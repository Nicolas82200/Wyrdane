extends GutTest

# Couvre PackCarousel.slot_index_for (scripts/shop/PackCarousel.gd) :
# l'affectation pack -> emplacement du carrousel de packs de la Boutique. Les
# 5 emplacements sont fixes et doivent TOUS rester occupés, le pack
# sélectionné au centre, quelle que soit la sélection — c'est exactement ce
# qui manquait à la première version (un décalage flottant commun à tous les
# packs, qui laissait un trou d'un côté à mi-animation). Statique et sans
# dépendance d'autoload, donc testable en chargeant le script directement (le
# runner GUT en mode -s n'initialise pas les autoloads de façon fiable).

const PackCarouselScript = preload("res://scripts/shop/PackCarousel.gd")

func test_selected_pack_sits_in_the_middle_slot() -> void:
	for selected in 5:
		assert_eq(PackCarouselScript.slot_index_for(selected, selected, 5), 2,
			"le pack sélectionné (%d) doit occuper l'emplacement central" % selected)

func test_every_slot_is_occupied_exactly_once_for_any_selection() -> void:
	for count in [2, 3, 4, 5, 6, 8]:
		for selected in count:
			var occupied: Array[int] = []
			for pack in count:
				var slot: int = PackCarouselScript.slot_index_for(pack, selected, count)
				assert_true(slot >= 0 and slot < count,
					"emplacement %d hors des %d disponibles" % [slot, count])
				assert_false(occupied.has(slot),
					"emplacement %d occupé deux fois (sélection %d, %d packs)" % [slot, selected, count])
				occupied.append(slot)

func test_neighbours_keep_their_order_around_the_selection() -> void:
	# Sélection = pack 2 : l'ordre d'origine est conservé de gauche à droite.
	for pack in 5:
		assert_eq(PackCarouselScript.slot_index_for(pack, 2, 5), pack,
			"avec le pack 2 au centre, chaque pack garde sa place d'origine")
	# Sélection = pack 0 : les deux derniers packs bouclent à gauche.
	assert_eq(PackCarouselScript.slot_index_for(0, 0, 5), 2)
	assert_eq(PackCarouselScript.slot_index_for(1, 0, 5), 3)
	assert_eq(PackCarouselScript.slot_index_for(4, 0, 5), 1)
	assert_eq(PackCarouselScript.slot_index_for(3, 0, 5), 0)

func test_empty_carousel_does_not_divide_by_zero() -> void:
	assert_eq(PackCarouselScript.slot_index_for(0, 0, 0), 0)
