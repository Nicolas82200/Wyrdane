extends Control
class_name PackCarousel

# Carrousel des packs achetables de l'onglet "Packs" de la Boutique (voir
# ShopBuyPacksPanel.gd) : les 5 packs de CurrencyManager.PACK_RACES sont
# toujours visibles, celui du milieu étant le pack sélectionné. Cliquer sur
# un pack latéral fait tourner le carrousel jusqu'à l'amener au centre.
#
# Les EMPLACEMENTS sont fixes (voir _slot_transform) : cinq positions/échelles
# calculées une fois pour toutes depuis la taille du carrousel, symétriques
# autour du centre. Tourner ne déplace que les packs d'un emplacement à
# l'autre, jamais les emplacements eux-mêmes.
#
# C'est une correction d'une première version qui animait un décalage
# flottant commun à tous les packs : avec autant de packs que
# d'emplacements, à mi-animation l'ensemble se retrouvait décalé d'un
# demi-cran — un pack débordait d'un côté et il manquait un pack de l'autre,
# donc plus rien n'était symétrique le temps de la rotation.
#
# Le carrousel reste CYCLIQUE (le pack le plus à droite revient à gauche) :
# celui-là ne peut pas traverser tout l'écran pour rejoindre son nouvel
# emplacement, il est donc reposé directement à sa place et apparaît en
# fondu (voir _apply_slots).

signal selection_changed(race: String)

# Échelle du pack central, puis facteur appliqué par cran d'éloignement :
# 1 / 0.72 / 0.52, ce qui donne les trois tailles de la maquette.
const CENTER_SCALE := 1.0
const SIDE_FALLOFF := 0.72
# Ratio largeur/hauteur du dos de carte (980x1441).
const PACK_ASPECT := 0.68
# Écart entre deux emplacements voisins, en fraction de la largeur d'un pack :
# juste assez pour que le pack central (0.5) et son voisin (0.36 à l'échelle
# 0.72) ne se chevauchent pas.
const STEP_RATIO := 0.95
# Largeur totale occupée par les 5 packs, en largeurs de pack :
# 4 écarts plus la moitié des deux packs extérieurs.
const SPAN_RATIO := 4.0 * STEP_RATIO + SIDE_FALLOFF * SIDE_FALLOFF
const MIN_HEIGHT := 320.0
const ROTATE_DURATION := 0.35
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"

var _races: Array = []
var _index: int = 0
# Emplacement actuellement occupé par chaque pack (même indexation que
# _slots) : sert à repérer celui qui boucle d'un bord à l'autre.
var _slot_of: Array[int] = []
var _slots: Array[Control] = []
var _tween: Tween = null

func _init() -> void:
	# Pas de largeur minimale : les packs se dimensionnent sur la place
	# réellement disponible (voir _pack_size), le carrousel prend tout.
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	clip_contents = true

## Construit un pack par race de `races` et centre le carrousel sur `initial`
## (index dans cette liste).
func setup(races: Array, initial: int = 0) -> void:
	_races = races.duplicate()
	_index = clampi(initial, 0, max(_races.size() - 1, 0))
	for i in _races.size():
		var slot := _make_slot(_races[i], i)
		add_child(slot)
		_slots.append(slot)
		_slot_of.append(0)
	_apply_slots(false)

func selected_race() -> String:
	return _races[_index] if _index < _races.size() else CurrencyManager.MULTIRACE_PACK

## Amène le pack `index` au centre : chaque pack rejoint alors l'emplacement
## que lui vaut la nouvelle sélection (voir slot_index_for).
func select(index: int) -> void:
	if _races.is_empty() or index == _index:
		return
	_index = index
	_apply_slots(true)
	selection_changed.emit(selected_race())

## Emplacement occupé par le pack `pack_index` quand `selected` est au
## centre. Anneau : le pack juste après le dernier revient au premier, ce qui
## garde les 5 emplacements occupés quelle que soit la sélection.
static func slot_index_for(pack_index: int, selected: int, count: int) -> int:
	if count <= 0:
		return 0
	return posmod(pack_index - selected + (count - 1) / 2, count)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		# Les emplacements dépendent de la taille : on les recalcule, mais
		# sans animer (un redimensionnement n'est pas une rotation).
		_apply_slots(false)

## Taille du pack central : la plus grande qui tienne à la fois en hauteur
## (le pack central occupe toute la hauteur disponible) et en largeur (les 5
## packs, écarts compris, doivent rentrer dans le carrousel).
func _pack_size() -> Vector2:
	var width: float = minf(size.y * PACK_ASPECT, size.x / SPAN_RATIO)
	return Vector2(width, width / PACK_ASPECT)

## Position et échelle de l'emplacement `slot_index` (0 = le plus à gauche).
## Ne dépend que de la taille du carrousel : un emplacement ne bouge jamais
## pendant une rotation.
func _slot_transform(slot_index: int, pack_size: Vector2) -> Array:
	var center_slot: float = (_slots.size() - 1) / 2.0
	var d: float = float(slot_index) - center_slot
	var factor: float = CENTER_SCALE * pow(SIDE_FALLOFF, absf(d))
	var pos: Vector2 = size / 2.0 + Vector2(d * pack_size.x * STEP_RATIO, 0.0) - pack_size * factor / 2.0
	return [pos, factor]

## Replace chaque pack sur l'emplacement que lui vaut la sélection courante.
## `animate` : les packs glissent d'un emplacement à l'autre, sauf celui qui
## boucle d'un bord à l'autre (il traverserait tout le carrousel) — reposé
## directement à sa place, en fondu.
func _apply_slots(animate: bool) -> void:
	if _slots.is_empty():
		return
	var count: int = _slots.size()
	var pack_size: Vector2 = _pack_size()
	var center_slot: int = (count - 1) / 2
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if animate:
		_tween = create_tween().set_parallel(true)
		_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var duration: float = ROTATE_DURATION * SettingsManager.motion_scale()

	for i in count:
		var slot: Control = _slots[i]
		var slot_index: int = slot_index_for(i, _index, count)
		var target: Array = _slot_transform(slot_index, pack_size)
		var target_pos: Vector2 = target[0]
		var target_scale: Vector2 = Vector2.ONE * float(target[1])
		# Le pack central passe par-dessus ses voisins, eux-mêmes par-dessus
		# les suivants.
		slot.z_index = count - absi(slot_index - center_slot)
		slot.size = pack_size

		# Un pack qui change de bord (distance parcourue plus grande que la
		# rotation demandée) n'est pas glissé : il est reposé à sa place.
		var wrapped: bool = absi(slot_index - _slot_of[i]) > count / 2
		_slot_of[i] = slot_index

		if not animate or wrapped:
			slot.position = target_pos
			slot.scale = target_scale
			if animate:
				slot.modulate.a = 0.0
				_tween.tween_property(slot, "modulate:a", 1.0, duration)
			else:
				slot.modulate.a = 1.0
			continue

		slot.modulate.a = 1.0
		_tween.tween_property(slot, "position", target_pos, duration)
		_tween.tween_property(slot, "scale", target_scale, duration)

## Un pack du carrousel : le cadre coloré de la race, contenant le dos de
## pack. Sa taille, sa position et son échelle sont posées par _apply_slots ;
## son pivot reste en haut à gauche pour que `position` désigne directement
## son coin visuel quelle que soit l'échelle.
func _make_slot(race: String, index: int) -> Control:
	var slot := PanelContainer.new()
	slot.name = "PackSlot" + race
	slot.pivot_offset = Vector2.ZERO
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slot.add_theme_stylebox_override("panel", _make_frame_style(race))
	slot.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select(index)
	)

	var image := TextureRect.new()
	image.name = "PackImage"
	image.texture = load(PACK_BACK_TEXTURE)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Teinte de race, appliquée en multiplicatif clair sur le dos générique :
	# pas d'illustration dédiée par race pour l'instant.
	image.modulate = accent_for(race).lerp(Color.WHITE, 0.45)
	slot.add_child(image)
	return slot

func _make_frame_style(race: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.05, 0.95)
	style.border_color = accent_for(race)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style

## Couleur d'accent du pack d'une race (bordure, teinte) — partagée avec
## l'inventaire de la vue Collection (ShopCollectionPanel).
static func accent_for(race: String) -> Color:
	if race == CurrencyManager.MULTIRACE_PACK:
		return Color(0.85, 0.72, 0.38, 1)
	return DeckList.RACE_ACCENTS.get(Race.from_string(race), DeckList.NEUTRAL_ACCENT)

## Libellé traduit du pack ("Pack multirace" / "Pack Mort-Vivant").
static func title_for(race: String) -> String:
	if race == CurrencyManager.MULTIRACE_PACK:
		return SettingsManager.t("shop_buy.pack_multirace")
	return SettingsManager.t("shop_buy.pack_race") % SettingsManager.t("RACE_" + race.to_upper())
