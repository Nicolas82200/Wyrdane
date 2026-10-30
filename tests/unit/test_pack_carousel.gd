extends GutTest

# Couvre PackCarousel._shortest_delta (scripts/shop/PackCarousel.gd) : le
# carrousel de packs de la Boutique est cyclique, donc amener au centre le
# dernier pack alors que le premier est sélectionné doit tourner d'UN cran à
# gauche, pas de quatre à droite. Statique et sans dépendance d'autoload, donc
# testable en chargeant le script directement (le runner GUT en mode -s
# n'initialise pas les autoloads de façon fiable).

const PackCarouselScript = preload("res://scripts/shop/PackCarousel.gd")

func test_takes_the_short_way_round_on_a_five_pack_ring() -> void:
	assert_eq(PackCarouselScript._shortest_delta(4, 0, 5), -1, "0 -> 4 doit valoir un cran en arrière")
	assert_eq(PackCarouselScript._shortest_delta(0, 4, 5), 1, "4 -> 0 doit valoir un cran en avant")
	assert_eq(PackCarouselScript._shortest_delta(3, 2, 5), 1)
	assert_eq(PackCarouselScript._shortest_delta(0, 2, 5), -2)
	assert_eq(PackCarouselScript._shortest_delta(2, 2, 5), 0)

func test_never_exceeds_half_the_ring() -> void:
	for count in [2, 3, 4, 5, 6, 8]:
		for from in count:
			for to in count:
				var d: int = PackCarouselScript._shortest_delta(to, from, count)
				assert_true(absi(d) <= count / 2 + count % 2,
					"écart %d trop grand pour un anneau de %d" % [d, count])
				assert_eq(posmod(from + d, count), to,
					"l'écart doit bien mener de %d à %d (anneau de %d)" % [from, to, count])

func test_empty_ring_does_not_divide_by_zero() -> void:
	assert_eq(PackCarouselScript._shortest_delta(0, 0, 0), 0)
