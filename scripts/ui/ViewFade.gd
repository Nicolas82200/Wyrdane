# Utilitaire statique : bascule un groupe de vues mutuellement exclusives par
# un enchaînement glissé (voir MainMenu._show_nav_view/_show_info_view) plutôt
# qu'un `.visible` instantané. La vue active sort entièrement vers la gauche,
# puis la nouvelle vue entre depuis la droite — même sens à chaque bascule,
# façon "défilement" plutôt qu'un fondu croisé simultané. Sans état propre,
# pas d'autoload — appelé directement via le nom de la classe depuis
# n'importe quel script UI.
class_name ViewFade
extends RefCounted

const DURATION := 0.18

# views : toutes les vues du groupe (Array[Control]). active : celle à montrer,
# ou null pour tout masquer. owner_node : n'importe quel nœud vivant dans
# l'arbre, utilisé uniquement pour porter les Tween créés.
static func switch(owner_node: Node, views: Array, active: Control) -> void:
	var duration := DURATION * SettingsManager.motion_scale()
	var closing_tweens: Array[Tween] = []
	for view in views:
		if view == active or not (view as Control).visible:
			continue
		var v: Control = view
		var base_x := v.position.x
		var tween := owner_node.create_tween()
		tween.tween_property(v, "position:x", base_x - v.size.x, duration)
		tween.tween_callback(func():
			v.visible = false
			v.position.x = base_x)
		closing_tweens.append(tween)
	if active == null or active.visible:
		return
	for closing_tween in closing_tweens:
		if closing_tween.is_valid():
			await closing_tween.finished
	var active_base_x := active.position.x
	active.position.x = active_base_x + active.size.x
	active.visible = true
	owner_node.create_tween().tween_property(active, "position:x", active_base_x, duration)
