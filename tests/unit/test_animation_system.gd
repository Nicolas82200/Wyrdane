extends GutTest

# Couvre AnimationSystem._stat_delta_text (scripts/systems/AnimationSystem.gd),
# seule logique pure du fichier — le reste (Tween, shaders, découpe de carte
# en 2, particules...) est du rendu visuel pur, hors scope (voir CLAUDE.md).
# Formate le texte flottant affiché lors d'un Buff/Debuff générique ("+1/+1",
# "+2 ATK", "-3 PV"...).

var animation_system: AnimationSystem

func before_each() -> void:
	animation_system = AnimationSystem.new()

func after_each() -> void:
	animation_system.free()

func test_stat_delta_text_shows_both_stats_when_both_change() -> void:
	assert_eq(animation_system._stat_delta_text(1, 1), "+1/+1")

func test_stat_delta_text_shows_negative_deltas() -> void:
	assert_eq(animation_system._stat_delta_text(-2, -3), "-2/-3")

func test_stat_delta_text_shows_mixed_sign_deltas() -> void:
	assert_eq(animation_system._stat_delta_text(3, -1), "+3/-1")

func test_stat_delta_text_shows_attack_only() -> void:
	assert_eq(animation_system._stat_delta_text(2, 0), "+2 ATK")

func test_stat_delta_text_shows_negative_attack_only() -> void:
	assert_eq(animation_system._stat_delta_text(-1, 0), "-1 ATK")

func test_stat_delta_text_shows_health_only() -> void:
	assert_eq(animation_system._stat_delta_text(0, 4), "+4 PV")

func test_stat_delta_text_shows_negative_health_only() -> void:
	assert_eq(animation_system._stat_delta_text(0, -5), "-5 PV")

func test_stat_delta_text_with_both_zero_falls_back_to_health_format() -> void:
	# Cas non censé se produire en jeu (play_generic_buff/debuff filtrent déjà
	# les deltas nuls), mais _stat_delta_text ne doit pas planter pour autant.
	assert_eq(animation_system._stat_delta_text(0, 0), "+0 PV")
