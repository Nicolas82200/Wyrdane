extends RefCounted
class_name ArenaStarOverlay

# Étoile dorée de fusion (README « Affichage et déclenchement de la fusion » :
# overlay coin haut sur BoardMinion/Card) — fabrique un petit badge (icône
# étoile + niveau) réutilisable partout où un serviteur fusionné (star_level
# > 1) doit l'afficher (plateau et main, voir ArenaBoardMinionSlot/
# ArenaBattle._refresh_hand), sans jamais toucher BoardMinion.gd/Card.gd
# (scripts 1v1 partagés, qui ne connaissent pas ce concept propre à l'Arena).

static func add_to(target: Control, star_level: int) -> void:
	var badge := HBoxContainer.new()
	badge.anchor_left = 0.0
	badge.anchor_top = 0.0
	badge.offset_left = 2.0
	badge.offset_top = 2.0
	badge.add_theme_constant_override("separation", 1)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 50
	target.add_child(badge)

	var star := ArenaIcon.make(ArenaIcon.Kind.STAR, 16.0)
	star.line_color = Color(0.95, 0.82, 0.35, 1)
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(star)

	var count := Label.new()
	count.text = str(star_level)
	count.add_theme_font_size_override("font_size", 14)
	count.add_theme_color_override("font_color", Color(0.95, 0.82, 0.35, 1))
	count.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	count.add_theme_constant_override("outline_size", 4)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(count)
