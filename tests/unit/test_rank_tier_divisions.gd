extends GutTest

# Couvre le découpage en divisions de RankTier (scripts/data/RankTier.gd).
# Le score Elo brut du backend n'est plus jamais montré au joueur (demande
# utilisateur 2026-10-30) : tout passe par un rang « Palier Division », donc la
# conversion score -> division est la seule chose qui tient l'affichage du
# classement. Deux propriétés comptent et sont figées ici : les paliers
# ordinaires sont bornés à 4 divisions (un score en haut de Bronze ne doit
# jamais produire « Bronze V » au lieu de passer Argent), et Légende n'a
# AUCUN plafond (Légende 150 est un rang valide).
# Méthodes statiques : script chargé directement, sans autoload (le runner GUT
# en mode -s ne les initialise pas de façon fiable). display_name() n'est pas
# testée ici, elle dépend de SettingsManager.t() pour le nom du palier.

const RankTierScript = preload("res://scripts/data/RankTier.gd")

func test_bronze_starts_at_division_one() -> void:
	assert_eq(RankTierScript.from_mmr(0), RankTierScript.Type.BRONZE)
	assert_eq(RankTierScript.division(0), 1, "tout nouveau joueur démarre en division I")
	assert_eq(RankTierScript.division_label(0), "I")

func test_each_fifty_points_advances_one_division() -> void:
	assert_eq(RankTierScript.division(49), 1, "49 points reste en division I")
	assert_eq(RankTierScript.division(50), 2)
	assert_eq(RankTierScript.division(100), 3)
	assert_eq(RankTierScript.division(150), 4)
	assert_eq(RankTierScript.division_label(150), "IV")

func test_an_ordinary_tier_never_exceeds_four_divisions() -> void:
	# 199 est le dernier point de Bronze : la division suivante est Argent I,
	# jamais un « Bronze V ».
	assert_eq(RankTierScript.division(199), 4)
	assert_eq(RankTierScript.from_mmr(200), RankTierScript.Type.SILVER)
	assert_eq(RankTierScript.division(200), 1)
	assert_eq(RankTierScript.division_label(200), "I")

func test_legend_has_no_division_cap() -> void:
	assert_eq(RankTierScript.from_mmr(1200), RankTierScript.Type.LEGEND)
	assert_eq(RankTierScript.division(1200), 1)
	assert_eq(RankTierScript.division(1250), 2)
	# Le rang terminal doit pouvoir monter indéfiniment : 1200 + 149 * 50.
	assert_eq(RankTierScript.division(8650), 150, "Légende 150 doit être atteignable")

func test_legend_divisions_are_written_in_arabic_numerals() -> void:
	# Les chiffres romains s'arrêtent à IV : au-delà ils seraient illisibles
	# (Légende CL), et il n'y en a que quatre de définis.
	assert_eq(RankTierScript.division_label(1250), "2")
	assert_eq(RankTierScript.division_label(8650), "150")

func test_points_to_next_counts_down_to_the_next_division() -> void:
	assert_eq(RankTierScript.points_to_next(0), 50)
	assert_eq(RankTierScript.points_to_next(49), 1)
	assert_eq(RankTierScript.points_to_next(50), 50)
	assert_eq(RankTierScript.points_to_next(199), 1, "1 point avant de passer Argent")

func test_points_to_next_stays_defined_at_legend() -> void:
	# Il n'y a plus de cas « palier maximal atteint » à afficher : Légende a
	# toujours une division au-dessus.
	assert_eq(RankTierScript.points_to_next(1200), 50)
	assert_eq(RankTierScript.points_to_next(8649), 1)

func test_a_negative_score_is_treated_as_the_bottom_of_bronze() -> void:
	# Le backend borne déjà à 0 (eloHelper), mais une réponse abîmée ou un
	# champ manquant ne doit pas produire une division négative.
	assert_eq(RankTierScript.division(-100), 1)
	assert_eq(RankTierScript.division_label(-100), "I")
