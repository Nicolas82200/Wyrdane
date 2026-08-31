extends RefCounted
class_name BoardMinionStatusVFX

# VFX de statut d'un serviteur (REMPART/ÉGIDE/CORRUPTION/IMMUNITÉ AUX SORTS,
# GEL/INFECTION/TERREUR) — extrait de BoardMinion.gd. Fonctions statiques
# prenant `bm` (le BoardMinion propriétaire) en paramètre, même pattern que
# ArenaUIBuilder. `setup(bm)` crée les nœuds une fois (BoardMinion._ready),
# `refresh(bm)` les montre/cache selon l'état du serviteur
# (BoardMinion.update_display), `update_pulse(bm, delta)` fait pulser
# l'opacité des halos actifs (BoardMinion._process).

static func setup(bm) -> void:
	# REMPART (TAUNT) : anneau façon bouclier autour de la carte, visible tant
	# que le mot-clé est présent (retiré uniquement par Silence/mort).
	bm._taunt_shield_style = StyleBoxFlat.new()
	bm._taunt_shield_style.bg_color            = Color.TRANSPARENT
	bm._taunt_shield_style.border_width_left   = 5
	bm._taunt_shield_style.border_width_right  = 5
	bm._taunt_shield_style.border_width_top    = 5
	bm._taunt_shield_style.border_width_bottom = 5
	bm._taunt_shield_style.border_color        = bm.TAUNT_SHIELD_COLOR
	bm._taunt_shield_style.corner_radius_top_left     = 20
	bm._taunt_shield_style.corner_radius_top_right    = 20
	bm._taunt_shield_style.corner_radius_bottom_left  = 20
	bm._taunt_shield_style.corner_radius_bottom_right = 20
	bm._taunt_shield = Panel.new()
	bm._taunt_shield.name = "TauntShield"
	bm._taunt_shield.position = Vector2(-8, -8)
	bm._taunt_shield.size = Vector2(116, 166)
	bm._taunt_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bm._taunt_shield.add_theme_stylebox_override("panel", bm._taunt_shield_style)
	bm._taunt_shield.visible = false
	bm.add_child(bm._taunt_shield)

	# ÉGIDE (AEGIS) : halo doré persistant tant que le bouclier n'a pas absorbé
	# de dégâts (retiré instantanément par Minion.take_damage).
	bm._aegis_glow_style = StyleBoxFlat.new()
	bm._aegis_glow_style.bg_color            = Color(bm.AEGIS_GLOW_COLOR.r, bm.AEGIS_GLOW_COLOR.g, bm.AEGIS_GLOW_COLOR.b, 0.12)
	bm._aegis_glow_style.border_width_left   = 4
	bm._aegis_glow_style.border_width_right  = 4
	bm._aegis_glow_style.border_width_top    = 4
	bm._aegis_glow_style.border_width_bottom = 4
	bm._aegis_glow_style.border_color        = bm.AEGIS_GLOW_COLOR
	bm._aegis_glow_style.corner_radius_top_left     = 12
	bm._aegis_glow_style.corner_radius_top_right    = 12
	bm._aegis_glow_style.corner_radius_bottom_left  = 12
	bm._aegis_glow_style.corner_radius_bottom_right = 12
	bm._aegis_glow = Panel.new()
	bm._aegis_glow.name = "AegisGlow"
	bm._aegis_glow.position = Vector2(-2, -2)
	bm._aegis_glow.size = Vector2(104, 154)
	bm._aegis_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bm._aegis_glow.add_theme_stylebox_override("panel", bm._aegis_glow_style)
	bm._aegis_glow.visible = false
	bm.add_child(bm._aegis_glow)

	# CORRUPTION (Démon) : liseré sombre permanent tant que corruption_stacks > 0,
	# jamais retiré (perte d'ATK définitive). Ne pulse pas : marque un état figé,
	# contrairement aux protections actives (Rempart/Égide/Immunité aux sorts).
	bm._corruption_border_style = StyleBoxFlat.new()
	bm._corruption_border_style.bg_color            = Color.TRANSPARENT
	bm._corruption_border_style.border_width_left   = 3
	bm._corruption_border_style.border_width_right  = 3
	bm._corruption_border_style.border_width_top    = 3
	bm._corruption_border_style.border_width_bottom = 3
	bm._corruption_border_style.border_color        = bm.CORRUPTION_BORDER_COLOR
	bm._corruption_border_style.corner_radius_top_left     = 8
	bm._corruption_border_style.corner_radius_top_right    = 8
	bm._corruption_border_style.corner_radius_bottom_left  = 8
	bm._corruption_border_style.corner_radius_bottom_right = 8
	bm._corruption_border = Panel.new()
	bm._corruption_border.name = "CorruptionBorder"
	bm._corruption_border.position = Vector2(-1, -1)
	bm._corruption_border.size = Vector2(102, 152)
	bm._corruption_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bm._corruption_border.add_theme_stylebox_override("panel", bm._corruption_border_style)
	bm._corruption_border.visible = false
	bm.add_child(bm._corruption_border)

	# IMMUNITÉ AUX SORTS (spell_immune) : voile chatoyant tant que la protection
	# n'a pas été levée par la 1ère attaque (Assassin Décharné) ou son expiration
	# (Éclaireur Infiltré, TempEffectSystem).
	bm._spell_ward_style = StyleBoxFlat.new()
	bm._spell_ward_style.bg_color            = Color.TRANSPARENT
	bm._spell_ward_style.border_width_left   = 3
	bm._spell_ward_style.border_width_right  = 3
	bm._spell_ward_style.border_width_top    = 3
	bm._spell_ward_style.border_width_bottom = 3
	bm._spell_ward_style.border_color        = bm.SPELL_WARD_COLOR
	bm._spell_ward_style.corner_radius_top_left     = 16
	bm._spell_ward_style.corner_radius_top_right    = 16
	bm._spell_ward_style.corner_radius_bottom_left  = 16
	bm._spell_ward_style.corner_radius_bottom_right = 16
	bm._spell_ward = Panel.new()
	bm._spell_ward.name = "SpellWard"
	bm._spell_ward.position = Vector2(-5, -5)
	bm._spell_ward.size = Vector2(110, 160)
	bm._spell_ward.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bm._spell_ward.add_theme_stylebox_override("panel", bm._spell_ward_style)
	bm._spell_ward.visible = false
	bm.add_child(bm._spell_ward)

	var pulsing_overlays: Array[Dictionary] = [
		{"panel": bm._taunt_shield, "style": bm._taunt_shield_style},
		{"panel": bm._aegis_glow,   "style": bm._aegis_glow_style},
		{"panel": bm._spell_ward,   "style": bm._spell_ward_style},
	]
	bm._pulsing_overlays = pulsing_overlays

	# GEL : flocons qui dérivent tant que frozen_turns > 0.
	bm._frost_particles = CPUParticles2D.new()
	bm._frost_particles.name = "FrostParticles"
	bm._frost_particles.position = Vector2(50, 75)
	bm._frost_particles.amount = 10
	bm._frost_particles.lifetime = 2.2
	bm._frost_particles.preprocess = 2.2
	bm._frost_particles.emitting = false
	bm._frost_particles.local_coords = true
	bm._frost_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bm._frost_particles.emission_rect_extents = Vector2(48, 73)
	bm._frost_particles.direction = Vector2(0, 1)
	bm._frost_particles.spread = 180.0
	bm._frost_particles.gravity = Vector2(0, 6)
	bm._frost_particles.initial_velocity_min = 2.0
	bm._frost_particles.initial_velocity_max = 8.0
	bm._frost_particles.angular_velocity_min = -60.0
	bm._frost_particles.angular_velocity_max = 60.0
	bm._frost_particles.scale_amount_min = 1.5
	bm._frost_particles.scale_amount_max = 3.0
	bm._frost_particles.color = Color(0.85, 0.93, 1.0, 0.85)
	bm.add_child(bm._frost_particles)

	# INFECTION : vapeurs toxiques qui montent tant que infected == true.
	bm._infection_particles = CPUParticles2D.new()
	bm._infection_particles.name = "InfectionParticles"
	bm._infection_particles.position = Vector2(50, 140)
	bm._infection_particles.amount = 7
	bm._infection_particles.lifetime = 1.8
	bm._infection_particles.preprocess = 1.8
	bm._infection_particles.emitting = false
	bm._infection_particles.local_coords = true
	bm._infection_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bm._infection_particles.emission_rect_extents = Vector2(45, 4)
	bm._infection_particles.direction = Vector2(0, -1)
	bm._infection_particles.spread = 20.0
	bm._infection_particles.gravity = Vector2(0, -14)
	bm._infection_particles.initial_velocity_min = 4.0
	bm._infection_particles.initial_velocity_max = 10.0
	bm._infection_particles.scale_amount_min = 1.0
	bm._infection_particles.scale_amount_max = 2.2
	bm._infection_particles.color = Color(0.4, 0.9, 0.4, 0.6)
	bm.add_child(bm._infection_particles)

	# TERREUR : volutes sombres qui s'échappent tant que terror_turns > 0.
	bm._terror_particles = CPUParticles2D.new()
	bm._terror_particles.name = "TerrorParticles"
	bm._terror_particles.position = Vector2(50, 75)
	bm._terror_particles.amount = 8
	bm._terror_particles.lifetime = 1.6
	bm._terror_particles.preprocess = 1.6
	bm._terror_particles.emitting = false
	bm._terror_particles.local_coords = true
	bm._terror_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bm._terror_particles.emission_rect_extents = Vector2(48, 73)
	bm._terror_particles.direction = Vector2(0, -1)
	bm._terror_particles.spread = 100.0
	bm._terror_particles.gravity = Vector2(0, -4)
	bm._terror_particles.initial_velocity_min = 3.0
	bm._terror_particles.initial_velocity_max = 9.0
	bm._terror_particles.scale_amount_min = 1.5
	bm._terror_particles.scale_amount_max = 3.2
	bm._terror_particles.color = Color(0.35, 0.1, 0.5, 0.5)
	bm.add_child(bm._terror_particles)

static func refresh(bm) -> void:
	if bm.minion == null or bm._taunt_shield == null:
		return
	bm._taunt_shield.visible      = bm.minion.has_keyword(Keyword.Type.TAUNT)
	bm._aegis_glow.visible        = bm.minion.has_keyword(Keyword.Type.AEGIS)
	bm._spell_ward.visible        = bm.minion.spell_immune
	bm._corruption_border.visible = bm.minion.corruption_stacks > 0
	if bm._corruption_border.visible:
		bm._corruption_border_style.border_color.a = clampf(0.3 + bm.minion.corruption_stacks * 0.15, 0.3, 0.9)
	bm._frost_particles.emitting      = bm.minion.frozen_turns > 0
	bm._infection_particles.emitting  = bm.minion.infected
	bm._terror_particles.emitting     = bm.minion.terror_turns > 0

static func update_pulse(bm, delta: float) -> void:
	if bm._pulsing_overlays.is_empty():
		return
	var any_visible := false
	for entry in bm._pulsing_overlays:
		if entry["panel"].visible:
			any_visible = true
			break
	if not any_visible:
		return
	bm._status_pulse += delta * 2.0
	var alpha := 0.65 + sin(bm._status_pulse) * 0.3
	for entry in bm._pulsing_overlays:
		var panel: Panel = entry["panel"]
		if not panel.visible:
			continue
		var style: StyleBoxFlat = entry["style"]
		style.border_color.a = alpha
		panel.queue_redraw()
