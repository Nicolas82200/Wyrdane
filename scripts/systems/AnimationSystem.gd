extends Node
class_name AnimationSystem

const SLASH_TEXTURE := preload("res://assets/media-effect/image-effect/slash.png")
const CLAW_TEXTURE := preload("res://assets/media-effect/image-effect/claw.png")

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

func play_death(visual: BoardMinion) -> Tween:
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = battle.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector2.ZERO, 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "modulate:a", 0.0, 0.25)
	return tween

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
		flash.tween_property(target, "modulate", Color.WHITE, 0.18)
		play_hit_mark(attacker_visual, target)
	)
	tween.tween_property(attacker_visual, "position", start_pos, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(attacker_visual):
		attacker_visual.z_index = 0

## Absorption d'une carte-ressource jouée : la carte rétrécit et spirale vers
## le pool de mana de sa race (position `target`, teintée `color`), avec une
## traînée d'étincelles. Libère `card` (queue_free) une fois l'animation finie.
func play_resource_absorb(card: Control, target: Vector2, color: Color) -> void:
	if not is_instance_valid(card):
		return
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.z_index = 100
	card.pivot_offset = card.size / 2.0

	var start_pos: Vector2 = card.global_position
	var start_scale: Vector2 = card.scale
	var perp: Vector2 = (target - start_pos).orthogonal().normalized()
	var duration := 0.42

	_spawn_absorb_sparks(start_pos, target, color, duration)

	var step := func(t: float):
		if not is_instance_valid(card):
			return
		var pos_t: float = t * t * (3.0 - 2.0 * t) # smoothstep : trajectoire fluide
		var scale_t: float = t * t * t             # accélère : happe la carte sur la fin
		var wobble: float = sin(t * TAU * 2.2) * (1.0 - t) * 26.0
		card.global_position = start_pos.lerp(target, pos_t) + perp * wobble
		card.rotation_degrees = t * 640.0
		card.scale = (start_scale * 1.12).lerp(Vector2.ZERO, scale_t)
		var tinted: Color = Color.WHITE.lerp(color, t)
		tinted.a = 1.0 - scale_t
		card.modulate = tinted

	var tween: Tween = battle.create_tween()
	tween.tween_property(card, "scale", start_scale * 1.12, 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(step, 0.0, 1.0, duration)
	tween.tween_callback(func():
		if is_instance_valid(card):
			card.queue_free()
	)

func _spawn_absorb_sparks(start_pos: Vector2, target: Vector2, color: Color, duration: float) -> void:
	var count := 5
	for i in range(count):
		var delay: float = i * (duration / float(count)) * 0.6
		var spawn_t: float = float(i) / float(max(count - 1, 1))
		var spark_start: Vector2 = start_pos.lerp(target, spawn_t * 0.3)
		_travel_spark(spark_start, target, color, delay, duration * 0.55)

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
	tween.tween_callback(func(): spark.modulate.a = 1.0)
	tween.tween_property(spark, "global_position", target - spark.size / 2.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, duration)
	tween.tween_callback(spark.queue_free)

## Flash coloré bref sur `visual` (revient à blanc).
func _flash(visual: CanvasItem, color: Color, duration: float = 0.22) -> void:
	if not is_instance_valid(visual):
		return
	var tween: Tween = battle.create_tween()
	tween.tween_property(visual, "modulate", color, 0.05)
	tween.tween_property(visual, "modulate", Color.WHITE, duration)

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
	tween.parallel().tween_property(visual, "modulate", Color.WHITE, 0.25)
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
