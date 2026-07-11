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
