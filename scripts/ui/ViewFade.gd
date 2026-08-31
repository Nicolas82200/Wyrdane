# Utilitaire statique : bascule un groupe de vues mutuellement exclusives par
# fondu croisé plutôt qu'un `.visible` instantané (voir MainMenu._show_nav_view/
# _show_info_view). Sans état propre, pas d'autoload — appelé directement via
# le nom de la classe depuis n'importe quel script UI.
class_name ViewFade
extends RefCounted

const DURATION := 0.15

# views : toutes les vues du groupe (Array[Control]). active : celle à montrer,
# ou null pour tout masquer. owner_node : n'importe quel nœud vivant dans
# l'arbre, utilisé uniquement pour porter les Tween créés.
static func switch(owner_node: Node, views: Array, active: Control) -> void:
	var duration := DURATION * SettingsManager.motion_scale()
	for view in views:
		if view == active or not (view as Control).visible:
			continue
		var v: Control = view
		var tween := owner_node.create_tween()
		tween.tween_property(v, "modulate:a", 0.0, duration)
		tween.tween_callback(func():
			v.visible = false
			v.modulate.a = 1.0)
	if active != null and not active.visible:
		active.modulate.a = 0.0
		active.visible = true
		owner_node.create_tween().tween_property(active, "modulate:a", 1.0, duration)
