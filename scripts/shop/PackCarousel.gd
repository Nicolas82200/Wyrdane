extends Control
class_name PackCarousel

# Carrousel des packs achetables de l'onglet "Packs" de la Boutique (voir
# ShopBuyPacksPanel.gd) : les 5 packs de CurrencyManager.PACK_RACES sont
# toujours visibles, celui du milieu étant le pack sélectionné. Cliquer sur
# un pack latéral fait tourner le carrousel jusqu'à l'amener au centre.
#
# Le carrousel est CYCLIQUE : avec autant de packs que d'emplacements, c'est
# ce qui garantit qu'aucun pack ne disparaisse quelle que soit la sélection
# (une liste non cyclique laisserait deux trous dès qu'on sélectionne un pack
# d'un bout). Tout le placement découle d'un unique `_offset` flottant
# (position courante, animée entre deux indices entiers) : rien n'est
# repositionné à la main pendant l'animation.

signal selection_changed(race: String)

# Échelle du pack central, puis facteur appliqué par cran d'éloignement :
# 1 / 0.72 / 0.52, ce qui donne les trois tailles de la maquette.
const CENTER_SCALE := 1.0
const SIDE_FALLOFF := 0.72
# Ratio largeur/hauteur du dos de carte (980x1441).
const PACK_ASPECT := 0.68
# Écart entre deux packs voisins, en fraction de la largeur d'un pack : juste
# assez pour que le pack central (0.5) et son voisin (0.36 à l'échelle 0.72)
# ne se chevauchent pas.
const STEP_RATIO := 0.95
# Largeur totale occupée par les 5 packs, en largeurs de pack :
# 4 écarts plus la moitié des deux packs extérieurs.
const SPAN_RATIO := 4.0 * STEP_RATIO + SIDE_FALLOFF * SIDE_FALLOFF
const MIN_HEIGHT := 320.0
const ROTATE_DURATION := 0.35
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"

var _races: Array = []
var _index: int = 0
var _offset: float = 0.0
var _slots: Array[Control] = []
var _tween: Tween = null

func _init() -> void:
	# Pas de largeur minimale : les packs se dimensionnent sur la place
	# réellement disponible (voir _pack_size), le carrousel prend tout.
	custom_minimum_size = Vector2(0, MIN_HEIGHT)
	clip_contents = true

## Construit un emplacement par race de `races` et centre le carrousel sur
## `initial` (index dans cette liste).
func setup(races: Array, initial: int = 0) -> void:
	_races = races.duplicate()
	_index = clampi(initial, 0, max(_races.size() - 1, 0))
	_offset = float(_index)
	for i in _races.size():
		var slot := _make_slot(_races[i], i)
		add_child(slot)
		_slots.append(slot)
	_layout()

func selected_race() -> String:
	return _races[_index] if _index < _races.size() else CurrencyManager.MULTIRACE_PACK

## Amène le pack `index` au centre par le chemin le plus court (le carrousel
## étant cyclique, aller de l'avant-dernier au premier doit tourner d'un cran
## à droite, pas de trois crans à gauche).
func select(index: int) -> void:
	if _races.is_empty() or index == _index:
		return
	var target: float = _offset + float(_shortest_delta(index, _index, _races.size()))
	_index = index
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, target, ROTATE_DURATION * SettingsManager.motion_scale()) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	selection_changed.emit(selected_race())

## Écart signé le plus court de `from` vers `to` sur un anneau de `count`
## éléments (ex. 4 -> 0 sur 5 éléments vaut +1, pas -4).
static func _shortest_delta(to: int, from: int, count: int) -> int:
	if count <= 0:
		return 0
	var d: int = posmod(to - from, count)
	if d > count / 2:
		d -= count
	return d

func _set_offset(value: float) -> void:
	_offset = value
	_layout()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

## Taille du pack central : la plus grande qui tienne à la fois en hauteur
## (le pack central occupe toute la hauteur disponible) et en largeur (les 5
## packs, écarts compris, doivent rentrer dans le carrousel).
func _pack_size() -> Vector2:
	var width: float = minf(size.y * PACK_ASPECT, size.x / SPAN_RATIO)
	return Vector2(width, width / PACK_ASPECT)

## Place chaque emplacement selon sa distance (flottante, donc continue
## pendant l'animation) au centre du carrousel.
func _layout() -> void:
	if _slots.is_empty():
		return
	var count: int = _slots.size()
	var center: Vector2 = size / 2.0
	var pack_size: Vector2 = _pack_size()
	var step: float = pack_size.x * STEP_RATIO
	for i in count:
		var slot: Control = _slots[i]
		var d: float = fposmod(float(i) - _offset + count / 2.0, float(count)) - count / 2.0
		var factor: float = CENTER_SCALE * pow(SIDE_FALLOFF, absf(d))
		slot.size = pack_size
		slot.scale = Vector2.ONE * factor
		slot.position = center + Vector2(d * step, 0.0) - pack_size * factor / 2.0
		# Le pack central doit passer par-dessus ses voisins, eux-mêmes
		# par-dessus les suivants.
		slot.z_index = count - int(round(absf(d)))
		slot.modulate.a = 1.0 if absf(d) < 2.5 else 0.0

## Un emplacement du carrousel : le cadre coloré de la race, contenant le dos
## de pack. Sa taille et son échelle sont posées par _layout (le pack suit la
## place disponible), son pivot reste en haut à gauche pour que `position`
## désigne directement son coin visuel quelle que soit l'échelle.
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
