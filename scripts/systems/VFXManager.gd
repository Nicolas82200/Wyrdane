extends Control
class_name VFXManager

## Overlay de VFX 3D (packs Binbun3D) affichés par-dessus le board 2D via
## SubViewport + Camera3D. Créé entièrement en code par Battle (aucun nœud
## dans Battle.tscn), comme TurnBanner/CombatLogPanel/ReconnectOverlay.
##
## Les mêmes scènes d'effet sont réutilisées pour toutes les races : seule la
## palette de couleurs change (exports primary/secondary/tertiary/light_color
## des scripts partagés du pack), pour rester cohérent avec le thème sonore
## par race déjà en place dans AudioManager.

const PROJECTILE_SIZE := Vector2(210, 210)
const IMPACT_SIZE := Vector2(180, 180)
const PROJECTILE_CAMERA_SIZE := 1.5
const IMPACT_CAMERA_SIZE := 5.0
const BIG_IMPACT_CAMERA_SIZE := 8.0
const PROJECTILE_FLIGHT_TIME := 0.35

const _PROJECTILE_SCENES := {
	Race.Type.UNDEAD: preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_wave/mprojectile_wave_vfx_01.tscn"),
	Race.Type.DEMON: preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_javelin/mprojectile_javelin_vfx_01.tscn"),
	Race.Type.HUMAN: preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_01.tscn"),
	Race.Type.ABOMINATION: preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_wave/mprojectile_wave_vfx_02.tscn"),
	Race.Type.NONE: preload("res://assets/BinbunVFX/magic_projectiles/effects/mprojectile_basic/mprojectile_basic_vfx_02.tscn"),
}

const _IMPACT_SCENE := preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/impact/vfx_impact_01.tscn")
const _BIG_IMPACT_SCENE := preload("res://assets/BinbunVFX_Vol2/StylizedHitFX/effects/big_impact/vfx_big_impact_01.tscn")

const _RACE_COLORS := {
	Race.Type.UNDEAD: {
		"primary": Color(0.55, 0.85, 0.55), "secondary": Color(0.15, 0.35, 0.2),
		"tertiary": Color(0.05, 0.15, 0.1), "light": Color(0.4, 0.9, 0.5),
	},
	Race.Type.DEMON: {
		"primary": Color(1.0, 0.3, 0.15), "secondary": Color(0.9, 0.6, 0.1),
		"tertiary": Color(0.4, 0.05, 0.05), "light": Color(1.0, 0.35, 0.1),
	},
	Race.Type.HUMAN: {
		"primary": Color(1.0, 0.92, 0.6), "secondary": Color(0.7, 0.85, 1.0),
		"tertiary": Color(1.0, 1.0, 1.0), "light": Color(1.0, 0.9, 0.6),
	},
	Race.Type.ABOMINATION: {
		"primary": Color(0.65, 0.8, 0.25), "secondary": Color(0.35, 0.25, 0.1),
		"tertiary": Color(0.2, 0.3, 0.05), "light": Color(0.6, 0.75, 0.2),
	},
	Race.Type.NONE: {
		"primary": Color(0.7, 0.85, 1.0), "secondary": Color(1.0, 1.0, 1.0),
		"tertiary": Color(0.5, 0.7, 1.0), "light": Color(0.6, 0.8, 1.0),
	},
}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Projectile magique entre deux points écran (coordonnées globales, déjà
## centrées sur la cible/le lanceur), thémé par race, suivi d'un impact à
## l'arrivée. Si `from` == `to` (sort sans cible ennemie, ex. buff/soin), un
## simple éclat de lancer est affiché sur place, sans trajet.
func spawn_spell_projectile(from: Vector2, to: Vector2, race: int) -> void:
	if from.distance_to(to) < 1.0:
		spawn_hit_impact(from, race, false)
		return
	var scene: PackedScene = _PROJECTILE_SCENES.get(race, _PROJECTILE_SCENES[Race.Type.NONE])
	var overlay := _make_overlay(scene, PROJECTILE_SIZE, PROJECTILE_CAMERA_SIZE, race, true, false)
	add_child(overlay)
	# Le modèle 3D pointe vers +X locale par défaut (traînée à l'arrière du
	# noyau) ; la caméra le rend donc "vers la droite" par défaut. On tourne
	# l'overlay 2D entier (image déjà rendue) pour l'aligner sur la vraie
	# direction de vol, plutôt que de manipuler la scène 3D.
	overlay.pivot_offset = PROJECTILE_SIZE / 2.0
	overlay.rotation = (to - from).angle()
	overlay.global_position = from - PROJECTILE_SIZE / 2.0
	var tween := create_tween()
	tween.tween_property(overlay, "global_position", to - PROJECTILE_SIZE / 2.0, PROJECTILE_FLIGHT_TIME)
	await tween.finished
	overlay.queue_free()
	spawn_hit_impact(to, race, false)


## Impact ponctuel à une position écran donnée (coordonnées globales déjà
## centrées) ; `big` bascule sur l'effet plus imposant (ex. coup fatal).
func spawn_hit_impact(at: Vector2, race: int, big: bool) -> void:
	var scene: PackedScene = _BIG_IMPACT_SCENE if big else _IMPACT_SCENE
	var cam_size := BIG_IMPACT_CAMERA_SIZE if big else IMPACT_CAMERA_SIZE
	var overlay := _make_overlay(scene, IMPACT_SIZE, cam_size, race, true, true)
	add_child(overlay)
	overlay.global_position = at - IMPACT_SIZE / 2.0


## Détermine l'origine (la popup de la carte jouée, glissée depuis le bord
## gauche de l'écran par CardPopupSystem ; repli sur le portrait du héros si
## aucune popup n'est affichée, ex. rituel à durée qui rejoint sa zone sans
## reveal) et la destination (cible unique, camp ennemi, ou origine elle-même
## pour un sort sans cible ennemie) d'un sort, puis déclenche le projectile
## thémé par race. `target` est le Minion visé si le sort a une cible unique
## déjà résolue (Ephémère/Rituel ciblé), sinon null.
func spawn_for_spell(battle, card_data: CardData, caster_is_player: bool, target: Minion) -> void:
	var from: Vector2 = battle.card_popup_system.get_effect_popup_tip()
	if from == Vector2.ZERO:
		var caster_panel: Control = battle.get_node("PlayerHeroPanel" if caster_is_player else "EnemyHeroPanel")
		from = caster_panel.global_position + caster_panel.size / 2.0
	var to: Vector2 = from
	if target != null:
		var target_visual: BoardMinion = battle.board_visual_system.find_visual(target)
		if target_visual:
			to = target_visual.global_position + battle.BOARD_MINION_SIZE / 2.0
	elif _targets_enemy(card_data):
		var enemy_panel: Control = battle.get_node("EnemyHeroPanel" if caster_is_player else "PlayerHeroPanel")
		to = enemy_panel.global_position + enemy_panel.size / 2.0
	spawn_spell_projectile(from, to, card_data.race)


func _targets_enemy(card_data: CardData) -> bool:
	for effect in card_data.effects:
		if effect.target in ["EnemyHero", "EnemyMinion", "AllEnemies", "RandomEnemy"]:
			return true
	return false


func _make_overlay(scene: PackedScene, size: Vector2, cam_size: float, race: int, one_shot: bool, auto_free_on_finish: bool) -> SubViewportContainer:
	var colors: Dictionary = _RACE_COLORS.get(race, _RACE_COLORS[Race.Type.NONE])

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.size = size
	container.custom_minimum_size = size

	var viewport := SubViewport.new()
	viewport.size = Vector2i(size)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	container.add_child(viewport)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_size
	camera.position = Vector3(0, 0, 4)
	viewport.add_child(camera)

	var effect := scene.instantiate()
	effect.set("primary_color", colors["primary"])
	effect.set("secondary_color", colors["secondary"])
	effect.set("tertiary_color", colors["tertiary"])
	effect.set("light_color", colors["light"])
	effect.set("one_shot", one_shot)
	viewport.add_child(effect)
	if effect.has_method("play"):
		effect.call_deferred("play")
	if auto_free_on_finish and effect.has_signal("finished"):
		effect.finished.connect(container.queue_free)

	return container
