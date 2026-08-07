extends Node
class_name AnimationSystem

const SLASH_TEXTURE := preload("res://assets/media-effect/image-effect/slash.png")
const CLAW_TEXTURE := preload("res://assets/media-effect/image-effect/claw.png")

# Durée totale de play_death (coupe + chute des 2 moitiés) : DeathSystem
# attend ce délai avant de retirer le nœud du plateau.
const DEATH_ANIMATION_DURATION := 0.55

var battle

func init(_battle) -> void:
	battle = _battle

func play_summon(visual: BoardMinion) -> void:
	visual.scale = Vector2(0.2, 0.2)
	visual.modulate.a = 0.0
	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 1.0, 0.25)

## Mort d'un serviteur : l'illustration se déchire en deux moitiés selon une
## ligne diagonale irrégulière (pas une coupe nette), qui s'écartent à peine
## en tombant, pendant que le reste de la carte (bordures, stats, icônes)
## s'efface derrière elles.
func play_death(visual: BoardMinion) -> Tween:
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split_card_in_half(visual)
	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "modulate:a", 0.0, 0.2).set_delay(0.05)
	return tween

# Nombre de bandes horizontales utilisées pour approximer une ligne de coupe
# diagonale et irrégulière à partir de simples régions rectangulaires
# (AtlasTexture ne permet pas de région oblique sans shader/masque).
const _DEATH_CUT_BANDS := 5
# Dérive progressive du point de coupe d'une bande à l'autre (tendance
# diagonale), en fraction de la largeur de la texture.
const _DEATH_CUT_SLOPE := 0.09
# Aléa ajouté par bande pour que la ligne de coupe ne soit jamais nette.
const _DEATH_CUT_JITTER := 0.07

func _split_card_in_half(visual: BoardMinion) -> void:
	var art: TextureRect = visual.art
	if art == null or art.texture == null:
		return
	var texture: Texture2D = art.texture
	var art_rect: Rect2 = Rect2(art.global_position, art.size)
	if art_rect.size.x <= 0.0 or art_rect.size.y <= 0.0:
		return
	var tex_size: Vector2 = texture.get_size()
	var screen_scale: float = art_rect.size.x / tex_size.x

	var band_h_tex: float = tex_size.y / float(_DEATH_CUT_BANDS)
	var band_h_screen: float = art_rect.size.y / float(_DEATH_CUT_BANDS)

	for i in range(_DEATH_CUT_BANDS):
		var slope_offset: float = (i - (_DEATH_CUT_BANDS - 1) * 0.5) * _DEATH_CUT_SLOPE * tex_size.x
		var jitter: float = randf_range(-_DEATH_CUT_JITTER, _DEATH_CUT_JITTER) * tex_size.x
		var cut_x: float = clampf(tex_size.x * 0.5 + slope_offset + jitter, tex_size.x * 0.2, tex_size.x * 0.8)
		var band_y_tex: float = i * band_h_tex
		var band_y_screen: float = art_rect.position.y + i * band_h_screen

		# Éclair blanc bref sur ce segment de la ligne de coupe.
		var cut_seg := Panel.new()
		var cut_style := StyleBoxFlat.new()
		cut_style.bg_color = Color(1.0, 1.0, 1.0, 0.85)
		cut_seg.add_theme_stylebox_override("panel", cut_style)
		cut_seg.size = Vector2(3, band_h_screen)
		cut_seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cut_seg.z_index = 110
		battle.add_child(cut_seg)
		cut_seg.global_position = Vector2(art_rect.position.x + cut_x * screen_scale - 1.5, band_y_screen)
		var cut_tween: Tween = battle.create_tween()
		cut_tween.tween_property(cut_seg, "modulate:a", 0.0, 0.16).set_delay(0.04)
		cut_tween.tween_callback(cut_seg.queue_free)

		for side in range(2):
			var region_x: float = 0.0 if side == 0 else cut_x
			var region_w: float = cut_x if side == 0 else (tex_size.x - cut_x)
			if region_w <= 0.0:
				continue

			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(region_x, band_y_tex), Vector2(region_w, band_h_tex))

			var piece := TextureRect.new()
			piece.texture = atlas
			piece.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			piece.stretch_mode = TextureRect.STRETCH_SCALE
			piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
			piece.size = Vector2(region_w * screen_scale, band_h_screen)
			piece.z_index = 100
			var piece_pos := Vector2(art_rect.position.x + region_x * screen_scale, band_y_screen)
			piece.global_position = piece_pos
			piece.pivot_offset = piece.size * 0.5
			battle.add_child(piece)

			# Séparation discrète : un peu à l'écart et vers le bas, avec un
			# petit aléa pour que les deux moitiés ne bougent pas en bloc rigide.
			var dir: float = -1.0 if side == 0 else 1.0
			var travel := Vector2(dir * 18.0, 30.0) + Vector2(randf_range(-4.0, 4.0), randf_range(-3.0, 3.0))
			var spin: float = dir * randf_range(8.0, 16.0)

			var tween: Tween = battle.create_tween()
			tween.set_parallel(true)
			tween.tween_property(piece, "global_position", piece_pos + travel, 0.45)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(piece, "rotation_degrees", spin, 0.45)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tween.tween_property(piece, "modulate:a", 0.0, 0.3).set_delay(0.2)
			tween.chain().tween_callback(piece.queue_free)

func play_attack_lunge(attacker_visual: BoardMinion, target: Control) -> void:
	if not is_instance_valid(attacker_visual) or not is_instance_valid(target):
		return
	var start_pos := attacker_visual.position
	var direction := (target.global_position + target.size * 0.5) \
		- (attacker_visual.global_position + attacker_visual.size * 0.5)
	if direction.length() < 1.0:
		return
	attacker_visual.z_index = 50
	var tween: Tween = battle.create_tween()
	tween.tween_property(attacker_visual, "position", start_pos + Vector2(0, -15) - direction * 0.08, 0.15)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker_visual, "position", start_pos + direction * 0.95, 0.12)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if not is_instance_valid(target):
			return
		# Shake
		var hit_pos := target.position
		var shake: Tween = battle.create_tween()
		shake.tween_property(target, "position", hit_pos + Vector2(10, 0), 0.05)
		shake.tween_property(target, "position", hit_pos - Vector2(10, 0), 0.05)
		shake.tween_property(target, "position", hit_pos, 0.05)
		# Flash rouge
		var flash: Tween = battle.create_tween()
		flash.tween_property(target, "modulate", Color(1.8, 0.3, 0.3, 1.0), 0.04)
		flash.tween_property(target, "modulate", rest_tint(target), 0.18)
		flash.tween_callback(func(): reapply_status_tint(target))
		play_hit_mark(attacker_visual, target)
	)
	tween.tween_property(attacker_visual, "position", start_pos, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(attacker_visual):
		attacker_visual.z_index = 0

## Absorption d'une carte-ressource jouée : la carte se dissout simplement sur
## place (fondu + léger rétrécissement, teintée `color` en cours de route) au
## lieu de se déchirer. Libère `card` (queue_free) une fois dissoute.
func play_resource_absorb(card: Card, color: Color) -> void:
	if not is_instance_valid(card):
		return
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 100
	card.pivot_offset = card.size * 0.5

	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate", Color(color.r, color.g, color.b, 0.0), 0.35)
	tween.tween_property(card, "scale", card.scale * 0.75, 0.35)
	tween.chain().tween_callback(func():
		if is_instance_valid(card):
			card.queue_free()
	)

## SORT : projectile qui file de la popup d'effet (`from`) vers chaque cible
## touchée (`targets`), en suivant la même courbe que la flèche de ciblage
## (`ArrowOverlay`). Laisse une traînée d'étincelles et explose à l'impact.
## `color` vient de la race de la carte lancée (voir ManaDisplay.RACE_MANA_COLORS).
func play_spell_missile(from: Vector2, targets: Array, color: Color) -> void:
	for i in range(targets.size()):
		_fire_missile(from, targets[i], color, i * 0.05)

func _fire_missile(start: Vector2, target: Vector2, color: Color, delay: float) -> void:
	if delay > 0.0:
		await battle.get_tree().create_timer(delay).timeout
	if not is_instance_valid(battle):
		return
	var glow_color: Color = color.lightened(0.35)

	var bolt := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = glow_color
	style.set_corner_radius_all(5)
	bolt.add_theme_stylebox_override("panel", style)
	bolt.size = Vector2(22, 9)
	bolt.pivot_offset = bolt.size / 2.0
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bolt.z_index = 105
	bolt.modulate.a = 0.0
	battle.add_child(bolt)
	bolt.global_position = start - bolt.size / 2.0

	var duration: float = clampf(start.distance_to(target) / 1300.0, 0.18, 0.45)
	var perp: Vector2 = (target - start).orthogonal().normalized()
	var trail_spawned := {}

	var curve_pos := func(t: float) -> Vector2:
		var pos_t: float = t * t * (3.0 - 2.0 * t)
		return start.lerp(target, pos_t) + perp * sin(t * PI) * 14.0

	var step := func(t: float):
		if not is_instance_valid(bolt):
			return
		var pos: Vector2 = curve_pos.call(t)
		var ahead: Vector2 = curve_pos.call(minf(t + 0.03, 1.0))
		bolt.rotation = (ahead - pos).angle()
		bolt.global_position = pos - bolt.size / 2.0
		var step8: int = int(t * 8.0)
		if not trail_spawned.has(step8):
			trail_spawned[step8] = true
			_travel_spark(pos, pos, glow_color, 0.0, 0.22, 6.0)

	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bolt, "modulate:a", 1.0, 0.03)
	tween.tween_method(step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		if is_instance_valid(bolt):
			bolt.queue_free()
		_missile_impact(target, glow_color)
	)

## Petite explosion radiale au point d'impact d'un projectile de sort.
func _missile_impact(pos: Vector2, color: Color) -> void:
	const BURST_COUNT := 8
	for i in range(BURST_COUNT):
		var angle: float = i * TAU / BURST_COUNT
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * 34.0
		_travel_spark(pos, pos + offset, color, 0.0, 0.22, 6.0)

	var flash := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(20)
	flash.add_theme_stylebox_override("panel", style)
	flash.size = Vector2(40, 40)
	flash.pivot_offset = flash.size / 2.0
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 106
	flash.modulate.a = 0.85
	battle.add_child(flash)
	flash.global_position = pos - flash.size / 2.0

	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.chain().tween_callback(flash.queue_free)

# ─── Primitives réutilisées par les animations de mots-clés ───────────────────

## Petit point coloré qui voyage de `start` à `target` en fondu, façon étincelle.
func _travel_spark(start: Vector2, target: Vector2, color: Color, delay: float = 0.0, duration: float = 0.3, size: float = 8.0) -> void:
	var spark := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(size / 2.0))
	spark.add_theme_stylebox_override("panel", style)
	spark.size = Vector2(size, size)
	spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spark.z_index = 99
	spark.modulate.a = 0.0
	battle.add_child(spark)
	spark.global_position = start - spark.size / 2.0

	var tween: Tween = battle.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	# Gardé (contrairement au reste de la traînée, déjà protégé) : cet appel
	# est le tout premier de la séquence, avant même que `duration`/`delay`
	# ne se soient écoulés — la fenêtre la plus longue pendant laquelle
	# `spark` peut être libéré ailleurs (ex. transition de manche Arena) avant
	# que ce callback ne s'exécute, provoquant sinon un crash "Lambda capture
	# ... was freed" en tentant d'accéder à `.modulate` sur une référence nulle.
	tween.tween_callback(func():
		if is_instance_valid(spark):
			spark.modulate.a = 1.0
	)
	tween.tween_property(spark, "global_position", target - spark.size / 2.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, duration)
	tween.tween_callback(spark.queue_free)

## Flash coloré bref sur `visual` (revient à sa teinte de statut, blanc sinon).
func _flash(visual: CanvasItem, color: Color, duration: float = 0.22) -> void:
	if not is_instance_valid(visual):
		return
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "modulate", color, 0.05)
	tween.tween_property(visual, "modulate", rest_tint(visual), duration)
	tween.tween_callback(func(): reapply_status_tint(visual))

## Couleur de retour après un flash : la teinte de statut persistante du
## serviteur (Gel bleuté, Infection verte...) plutôt qu'un blanc qui
## l'effacerait jusqu'au prochain update_display().
func rest_tint(visual: CanvasItem) -> Color:
	if is_instance_valid(visual) and visual.has_method("status_tint"):
		return visual.status_tint()
	return Color.WHITE

## Filet de sécurité en fin de flash : si le statut a changé pendant le tween
## (ex. Gel appliqué juste après le lancement du flash), la couleur cible
## calculée au départ est périmée — on resynchronise sur l'état réel.
func reapply_status_tint(visual: CanvasItem) -> void:
	if is_instance_valid(visual) and visual.has_method("status_tint"):
		visual.update_display()

## Petit shake horizontal (ex: peur, choc encaissé).
func _shake(visual: Control, amount: float = 8.0, step: float = 0.05) -> void:
	if not is_instance_valid(visual):
		return
	var base_pos := visual.position
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "position", base_pos + Vector2(amount, 0), step)
	tween.tween_property(visual, "position", base_pos - Vector2(amount, 0), step)
	tween.tween_property(visual, "position", base_pos, step)

## Petit pop d'échelle (buff/déclenchement ponctuel).
func _pulse_scale(visual: Control, factor: float = 1.15, duration: float = 0.16) -> void:
	if not is_instance_valid(visual):
		return
	visual.pivot_offset = visual.size / 2.0
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "scale", Vector2.ONE * factor, duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector2.ONE, duration * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Texte flottant (ex: "+1/+1", "-1 ATK") qui monte et s'efface au-dessus de `visual`.
func _floating_text(visual: Control, text: String, color: Color) -> void:
	if not is_instance_valid(visual):
		return
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.z_index = 120
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle.add_child(label)
	label.global_position = visual.global_position + Vector2(visual.size.x * 0.5 - 10, -6)

	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y - 40, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.45).set_delay(0.15)
	tween.chain().tween_callback(label.queue_free)

# ─── Mots-clés : Rempart/Aegis/Vol de vie/Venin/Ravage/Contre-attaque ─────────

## ÉGIDE : bloque une attaque puis se consomme.
func play_aegis_break(visual: Control) -> void:
	if not is_instance_valid(visual):
		return
	_pulse_scale(visual, 1.18, 0.22)
	_flash(visual, Color(0.6, 0.85, 1.0))
	_floating_text(visual, Keyword.get_keyword_name(Keyword.Type.AEGIS), Color(0.6, 0.85, 1.0))

## VOL DE VIE : petite traînée de particules rouges de l'attaquant vers le portrait du héros soigné.
func play_lifesteal(attacker_visual: Control, hero_panel: Control, amount: int) -> void:
	if not is_instance_valid(attacker_visual) or not is_instance_valid(hero_panel) or amount <= 0:
		return
	var start: Vector2 = attacker_visual.global_position + attacker_visual.size * 0.5
	var target: Vector2 = hero_panel.global_position + hero_panel.size * 0.5
	for i in range(3):
		_travel_spark(start, target, Color(0.9, 0.15, 0.2), i * 0.06, 0.35, 6.0)
	_floating_text(hero_panel, "+%d" % amount, Color(0.35, 1.0, 0.4))

## VENIN MORTEL : flash toxique sur la cible juste avant qu'elle ne meure.
func play_deadly_poison(target_visual: Control) -> void:
	_flash(target_visual, Color(0.55, 0.15, 0.85), 0.3)
	_shake(target_visual, 5.0)

## RAVAGE : pointe de dégâts qui gicle du serviteur tueur vers le héros ennemi.
func play_ravage_overkill(attacker_visual: Control, hero_panel: Control) -> void:
	if not is_instance_valid(attacker_visual) or not is_instance_valid(hero_panel):
		return
	var start: Vector2 = attacker_visual.global_position + attacker_visual.size * 0.5
	var target: Vector2 = hero_panel.global_position + hero_panel.size * 0.5
	_travel_spark(start, target, Color(1.0, 0.5, 0.1), 0.0, 0.25, 10.0)
	_shake(hero_panel, 6.0)

## CONTRE-ATTAQUE : riposte immédiate du défenseur vers l'attaquant.
func play_counter_attack(defender_visual: BoardMinion, attacker_visual: BoardMinion) -> void:
	if not is_instance_valid(defender_visual) or not is_instance_valid(attacker_visual):
		return
	_flash(defender_visual, Color(1.0, 0.85, 0.3), 0.18)
	play_hit_mark(defender_visual, attacker_visual)

# ─── Mots-clés Mort-Vivant ──────────────────────────────────────────────────

## NÉCROPHAGE : absorption verte + texte de buff quand un allié meurt.
func play_necrophage(visual: Control, amount: int) -> void:
	if amount <= 0:
		return
	_pulse_scale(visual, 1.12)
	_flash(visual, Color(0.4, 0.9, 0.55))
	_floating_text(visual, "+%d/+%d" % [amount, amount], Color(0.4, 0.9, 0.55))

## REVENANT : au lieu de mourir, le serviteur s'effondre puis se relève brutalement.
func play_revenant(visual: Control) -> void:
	if not is_instance_valid(visual):
		return
	visual.pivot_offset = visual.size / 2.0
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "scale", Vector2(0.85, 0.6), 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate", Color(0.6, 1.0, 0.9, 0.5), 0.1)
	tween.tween_property(visual, "scale", Vector2(1.2, 1.2), 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual, "modulate", Color(0.6, 1.0, 0.9, 1.0), 0.12)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(visual, "modulate", rest_tint(visual), 0.25)
	tween.chain().tween_callback(func(): reapply_status_tint(visual))
	_floating_text(visual, "%s !" % KeywordUndead.get_keyword_name(KeywordUndead.Type.REVENANT), Color(0.6, 1.0, 0.9))

# ─── Mots-clés Humain ───────────────────────────────────────────────────────

## COMMANDEMENT : le nouveau-venu Humain reçoit son bonus d'ATK permanent.
func play_commandement_buff(visual: Control) -> void:
	_pulse_scale(visual, 1.12)
	_flash(visual, Color(0.9, 0.75, 0.3))
	_floating_text(visual, "+1 ATK", Color(0.9, 0.75, 0.3))

# ─── Mots-clés Démon ────────────────────────────────────────────────────────

## CORRUPTION : marque sombre + perte d'ATK affichée sur la cible touchée.
func play_corruption(target_visual: Control) -> void:
	_flash(target_visual, Color(0.75, 0.15, 0.2))
	_floating_text(target_visual, "-1 ATK", Color(0.85, 0.25, 0.3))

## TERREUR : la cible tremble, saisie par la peur.
func play_terror(target_visual: Control) -> void:
	_flash(target_visual, Color(0.35, 0.1, 0.5), 0.25)
	_shake(target_visual, 6.0)

## PACTE : le héros invocateur transfère une part de ses HP au serviteur qui arrive.
func play_pact_drain(hero_panel: Control, minion_visual: Control) -> void:
	if not is_instance_valid(hero_panel) or not is_instance_valid(minion_visual):
		return
	var start: Vector2 = hero_panel.global_position + hero_panel.size * 0.5
	var target: Vector2 = minion_visual.global_position + minion_visual.size * 0.5
	for i in range(3):
		_travel_spark(start, target, Color(0.6, 0.1, 0.15), i * 0.05, 0.3, 7.0)
	_flash(hero_panel, Color(0.6, 0.1, 0.15), 0.25)
	_flash(minion_visual, Color(0.6, 0.1, 0.15), 0.2)

## SANG NOIR : le serviteur se renforce à chaque dégât auto-infligé au héros.
func play_sang_noir_buff(visual: Control) -> void:
	_pulse_scale(visual, 1.1)
	_flash(visual, Color(0.55, 0.05, 0.1))
	_floating_text(visual, "+1 ATK", Color(0.85, 0.25, 0.3))

# ─── Mots-clés Abomination ──────────────────────────────────────────────────

## Table de Mutation : couleur/texte selon l'issue (Croissance/Renforcement/Dégénérescence).
func play_mutation(visual: Control, outcome: String) -> void:
	if not is_instance_valid(visual):
		return
	var color: Color
	var text: String
	match outcome:
		"Croissance":
			color = Color(0.3, 0.85, 0.35)
			text  = "+2 ATK"
		"Renforcement":
			color = Color(0.3, 0.55, 0.9)
			text  = "+2 PV"
		_:
			color = Color(0.6, 0.15, 0.7)
			text  = "-1/-1"
	_pulse_scale(visual, 1.15, 0.22)
	_flash(visual, color, 0.3)
	_floating_text(visual, text, color)

## ASSIMILATION : absorption verte après une mort (n'importe quel camp).
func play_assimilation_buff(visual: Control) -> void:
	_pulse_scale(visual, 1.1)
	_flash(visual, Color(0.45, 0.85, 0.3))
	_floating_text(visual, "+1/+1", Color(0.45, 0.85, 0.3))

## CHAIR ADAPTATIVE : le mot-clé copié voyage du serviteur source vers le nouveau-venu.
func play_chair_adaptative_copy(source_visual: Control, target_visual: Control) -> void:
	if not is_instance_valid(source_visual) or not is_instance_valid(target_visual):
		return
	var start: Vector2 = source_visual.global_position + source_visual.size * 0.5
	var target: Vector2 = target_visual.global_position + target_visual.size * 0.5
	_travel_spark(start, target, Color(0.55, 0.85, 0.35), 0.0, 0.3, 8.0)
	_flash(target_visual, Color(0.55, 0.85, 0.35), 0.25)

## ASSAUT : glint doré au moment où le serviteur arrive prêt à attaquer immédiatement.
func play_charge_ready(visual: Control) -> void:
	_flash(visual, Color(0.95, 0.8, 0.3), 0.2)

func play_hit_mark(attacker_visual: BoardMinion, target: Control) -> void:
	if not is_instance_valid(attacker_visual) or not is_instance_valid(target):
		return
	var race: int = Race.Type.NONE
	if attacker_visual.minion != null:
		race = attacker_visual.minion.card_data.race
	var texture: Texture2D = SLASH_TEXTURE if race == Race.Type.HUMAN else CLAW_TEXTURE

	var mark := TextureRect.new()
	mark.texture = texture
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.modulate = Color(3.0, 0.1, 0.1, 0.0)
	mark.z_index = 100
	mark.size = target.size * 1.3
	mark.position = -target.size * 0.15
	target.add_child(mark)

	var tween: Tween = battle.create_tween()
	tween.tween_property(mark, "modulate:a", 1.0, 0.05)
	tween.tween_interval(0.05)
	tween.tween_property(mark, "modulate:a", 0.0, 0.15)
	tween.tween_callback(mark.queue_free)

# ─── États (indépendants des mots-clés) : Infection, Gel, Silence, Mort-rage ──

## INFECTION : marque toxique verte à la pose (Pestiféré, Infecter, Infecter Adjacent...).
func play_infection(target_visual: Control) -> void:
	_flash(target_visual, Color(0.4, 0.9, 0.55), 0.3)

## Tic d'Infection en début de tour : petite pulsation verte + dégât affiché.
func play_infection_tick(visual: Control, amount: int) -> void:
	if amount <= 0:
		return
	_flash(visual, Color(0.35, 0.75, 0.45), 0.25)
	_floating_text(visual, "-%d" % amount, Color(0.45, 0.9, 0.55))

## GEL : le serviteur se fige d'un coup, saisi par le givre.
func play_freeze(visual: Control) -> void:
	if not is_instance_valid(visual):
		return
	visual.pivot_offset = visual.size / 2.0
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "scale", Vector2(0.9, 1.06), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.14)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flash(visual, Color(0.55, 0.85, 1.0), 0.35)
	for i in range(4):
		var angle: float = i * TAU / 4.0
		var offset := Vector2(cos(angle), sin(angle)) * 40.0
		var center: Vector2 = visual.global_position + visual.size * 0.5
		_travel_spark(center + offset, center, Color(0.7, 0.92, 1.0), i * 0.02, 0.22, 5.0)

## SILENCE : les mots-clés du serviteur sont étouffés (flash grisé, terne).
func play_silence(visual: Control) -> void:
	_flash(visual, Color(0.5, 0.5, 0.55), 0.3)

## MORT-RAGE : déclenchement (une fois par serviteur) en passant sous 50% HP.
func play_death_rage(visual: Control) -> void:
	if not is_instance_valid(visual):
		return
	_pulse_scale(visual, 1.22, 0.3)
	_flash(visual, Color(0.85, 0.15, 0.1), 0.35)
	_floating_text(visual, TranslationServer.translate("TRIG_ONDEATHRAGE_NAME"), Color(0.9, 0.25, 0.2))

# ─── Feedback générique : dégâts / soin / buff / debuff bruts ────────────────
# Utilisé par les effets "Damage"/"Heal"/"Buff"/"Debuff" qui n'ont pas de
# mot-clé dédié (donc pas d'animation spécifique ci-dessus) — serviteur ou
# héros, `visual` étant dans les deux cas un simple Control.

## Dégâts génériques : flash rouge (toujours, même bloqué à 0) + texte "-X"
## si des dégâts ont réellement été infligés.
func play_damage(visual: Control, amount: int) -> void:
	if not is_instance_valid(visual):
		return
	_flash(visual, Color(1.8, 0.3, 0.3, 1.0), 0.18)
	if amount > 0:
		_floating_text(visual, "-%d" % amount, Color(1.0, 0.35, 0.3))

## Soin générique : flash vert + texte "+X".
func play_heal(visual: Control, amount: int) -> void:
	if not is_instance_valid(visual) or amount <= 0:
		return
	_flash(visual, Color(0.4, 1.0, 0.5, 1.0), 0.22)
	_floating_text(visual, "+%d" % amount, Color(0.45, 1.0, 0.55))

## Buff stat générique (effet "Buff" brut, hors mot-clé dédié) : pulse doré +
## texte récapitulatif du delta ATK/PV.
func play_generic_buff(visual: Control, attack_gain: int, health_gain: int) -> void:
	if not is_instance_valid(visual) or (attack_gain <= 0 and health_gain <= 0):
		return
	_pulse_scale(visual, 1.12)
	_flash(visual, Color(0.9, 0.8, 0.35), 0.2)
	_floating_text(visual, _stat_delta_text(attack_gain, health_gain), Color(0.4, 0.95, 0.4))

## Debuff stat générique (effet "Debuff" brut, hors mot-clé dédié) : flash
## sombre + texte récapitulatif du delta ATK/PV.
func play_generic_debuff(visual: Control, attack_loss: int, health_loss: int) -> void:
	if not is_instance_valid(visual) or (attack_loss <= 0 and health_loss <= 0):
		return
	_flash(visual, Color(0.55, 0.15, 0.6), 0.25)
	_floating_text(visual, _stat_delta_text(-attack_loss, -health_loss), Color(0.95, 0.35, 0.35))

func _stat_delta_text(attack_delta: int, health_delta: int) -> String:
	if attack_delta != 0 and health_delta != 0:
		return "%+d/%+d" % [attack_delta, health_delta]
	if attack_delta != 0:
		return "%+d ATK" % attack_delta
	return "%+d PV" % health_delta

# ─── Apparition / disparition génériques (Enchantements, Rituels) ────────────

## Apparition générique : léger scale-in + fade-in (Enchantement/Rituel posé).
func play_appear(visual: Control) -> void:
	if not is_instance_valid(visual):
		return
	visual.pivot_offset = visual.size / 2.0
	visual.scale = Vector2(0.3, 0.3)
	visual.modulate.a = 0.0
	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visual, "modulate:a", 1.0, 0.22)

## Disparition générique : fade-out + léger repli d'échelle (Enchantement/
## Rituel détruit). Retourne le Tween pour enchaîner sa destruction réelle.
func play_disappear(visual: Control) -> Tween:
	var tween: Tween = battle.create_tween()
	if not is_instance_valid(visual):
		return tween
	visual.pivot_offset = visual.size / 2.0
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2(0.6, 0.6), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate:a", 0.0, 0.25)
	return tween
