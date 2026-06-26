extends Node
class_name AnimationSystem

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
	tween.tween_property(attacker_visual, "position", start_pos + Vector2(0, -15), 0.05)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker_visual, "position", start_pos + direction * 0.95, 0.05)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if not is_instance_valid(target):
			return
		# Shake
		var hit_pos := target.position
		var shake: Tween = battle.create_tween()
		shake.tween_property(target, "position", hit_pos + Vector2(10, 0), 0.03)
		shake.tween_property(target, "position", hit_pos - Vector2(10, 0), 0.03)
		shake.tween_property(target, "position", hit_pos, 0.03)
		# Flash rouge
		var flash: Tween = battle.create_tween()
		flash.tween_property(target, "modulate", Color(1.8, 0.3, 0.3, 1.0), 0.04)
		flash.tween_property(target, "modulate", Color.WHITE, 0.18)
	)
	tween.tween_property(attacker_visual, "position", start_pos, 0.1)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	if is_instance_valid(attacker_visual):
		attacker_visual.z_index = 0
