extends Control
class_name PackShop

# Écran d'ouverture de packs : monnaie gagnée en jouant, dépensée ici contre
# des cartes aléatoires pondérées par rareté (voir POST /api/packs/open côté
# wyrdane-backend). Le joueur peut ouvrir plusieurs packs d'affilée (x1/x3/x5) :
# l'API n'ouvrant qu'un pack par requête, le client enchaîne les appels puis
# révèle toutes les cartes dans une seule séquence.

# Émis quand le joueur ferme l'écran via la croix (le nœud se contente de se
# masquer lui-même — voir close_x_button plus bas) : permet à l'appelant
# (MainMenu, quand PackShop est embarqué comme vue du panneau d'infos plutôt
# que comme overlay plein écran) de revenir sur une autre vue au lieu de
# laisser le panneau vide.
signal closed

@export var card_scene: PackedScene

const CARD_SIZE := Vector2(250, 375)
# Taille de repos maximale d'une carte révélée quand une seule est affichée,
# alignée sur le zoom de survol utilisé dans la main (voir Hand.gd,
# _on_card_hover, preview.scale = 1.1). Réduite dynamiquement si la grille de
# révélation contient plusieurs cartes (voir _compute_grid_slots).
const HOVER_SCALE := 1.1
const GRID_MIN_SCALE := 0.55
# Réduit (était 1.3) : la colonne du paquet est plus étroite (voir
# GRID_AREA_LEFT_RATIO) pour laisser plus de place à la grille de révélation —
# le paquet doit rester lisible sans déborder de sa colonne.
const PACK_SCALE := 1.1
const PACK_LAYER_COUNT := 4
const PACK_LAYER_OFFSET := 6.0
const PACK_FLIP_DURATION := 0.22
const CARD_FLY_DURATION := 0.45
const FIRST_REVEAL_DELAY := 0.2
# Délai entre deux révélations : part de REVEAL_STAGGER puis s'accélère de
# REVEAL_STAGGER_DECAY par carte déjà révélée dans CETTE séquence (x3/x5 ou
# plusieurs packs gratuits d'un coup), jusqu'au plancher REVEAL_STAGGER_MIN —
# ouvrir beaucoup de packs d'affilée devient progressivement plus rapide au
# lieu de garder un rythme fixe et lassant.
const REVEAL_STAGGER := 0.7
const REVEAL_STAGGER_DECAY := 0.05
const REVEAL_STAGGER_MIN := 0.3
const RARE_RARITIES := ["Epic", "Legendary"]
const ODDS_TOOLTIP_DURATION := 4.0

var _odds_panel: Control = null
const FLASH_ALPHA := {"Epic": 0.22, "Legendary": 0.42}
# Zone de révélation : partie droite de l'écran, à droite du paquet (voir
# PackCenter dans PackShop.tscn, ancré sur les ~22% gauches de l'écran —
# réduit depuis 34% pour laisser plus de place aux cartes révélées).
const GRID_AREA_LEFT_RATIO := 0.22
const GRID_AREA_SIDE_MARGIN := 40.0
const GRID_AREA_TOP := 150.0
# Doit rester au-dessus de la pile de boutons ancrée en bas de l'écran (voir
# OwnedButtonRow/BottomBar/SkipHintLabel dans PackShop.tscn, qui
# culmine à 186px du bas) pour que les cartes révélées ne les chevauchent pas.
const GRID_AREA_BOTTOM := 196.0
const GRID_MAX_COLUMNS := 5
# Fraction de chaque cellule de grille effectivement occupée par la carte (le
# reste forme l'espacement entre cartes).
const GRID_CELL_PADDING := 0.86

@onready var shake_layer: Control = $ShakeLayer
@onready var title_label: Label = $ShakeLayer/TitleLabel
@onready var balance_label: Label = $ShakeLayer/InfoRow/BalanceLabel
@onready var progress_label: Label = $ShakeLayer/InfoRow/ProgressLabel
@onready var status_label: Label = $ShakeLayer/StatusLabel
@onready var close_x_button: Button = $ShakeLayer/CloseXButton
@onready var pack_stage: Control = $ShakeLayer/PackStage
@onready var pack_center: CenterContainer = $ShakeLayer/PackStage/PackCenter
@onready var owned_button: Button = $ShakeLayer/OwnedButtonRow/OpenOwnedButton
@onready var open_x1_button: Button = $ShakeLayer/BottomBar/OpenX1Button
@onready var open_x3_button: Button = $ShakeLayer/BottomBar/OpenX3Button
@onready var open_x5_button: Button = $ShakeLayer/BottomBar/OpenX5Button
@onready var odds_button: Button = $ShakeLayer/BottomBar/OddsButton
@onready var skip_hint_label: Label = $ShakeLayer/SkipHintLabel
@onready var flash_rect: ColorRect = $FlashRect

var _revealing: bool = false
var _skip_requested: bool = false
var _pack_visual: Control = null
# Les 4 dos de carte empilés en diagonale (voir _build_pack_visual). Animés
# individuellement (chacun autour de son propre centre) plutôt que le groupe
# entier, pour que la rotation garde leur décalage visible façon éventail au
# lieu de les aplatir tous sur une seule ligne au moment du profil.
var _pack_layers: Array = []
var _idle_spin_tween: Tween = null
# Échelle de repos utilisée pour la révélation en cours, recalculée à chaque
# séquence selon le nombre de cartes (voir _compute_grid_slots).
var _reveal_scale: float = HOVER_SCALE

signal _pack_request_completed(code: int, cards: Array)

func _ready() -> void:
	hide()
	status_label.hide()
	skip_hint_label.hide()
	_resize_shake_layer()
	# `resized` (pas seulement `get_viewport().size_changed`) : quand PackShop
	# est embarqué comme vue du panneau d'infos, sa taille finale n'est connue
	# qu'après la première passe de layout du conteneur parent, pas encore à
	# `_ready()` — sans quoi ShakeLayer reste bloqué à une taille de 0x0 tant
	# que la fenêtre du jeu n'est jamais redimensionnée.
	resized.connect(_resize_shake_layer)
	_pack_visual = _build_pack_visual(pack_center)
	_style_close_x_button()
	for btn in [open_x1_button, open_x3_button, open_x5_button, odds_button, owned_button]:
		_style_action_button(btn)
	open_x1_button.pressed.connect(func(): _open_pack(false, 1))
	open_x3_button.pressed.connect(func(): _open_pack(false, 3))
	open_x5_button.pressed.connect(func(): _open_pack(false, 5))
	odds_button.pressed.connect(_on_odds_pressed)
	# Packs gratuits gagnés (quêtes hebdo, parrainage — voir
	# docs/backend-contracts/weekly-quests-and-referral.md) : consomme
	# CurrencyManager.free_packs plutôt que l'or, visible seulement s'il y en
	# a au moins un.
	owned_button.pressed.connect(_open_owned_packs)
	CurrencyManager.free_packs_changed.connect(func(_n): _update_owned_button())
	close_x_button.set_meta("no_click_sound", true)
	close_x_button.pressed.connect(func(): AudioManager.play(AudioManager.CLOSE_MENU); hide(); closed.emit())
	skip_hint_label.gui_input.connect(_on_skip_input)
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_balance_label(new_balance))
	CollectionManager.collection_loaded.connect(_update_progress_label)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
	_update_owned_button()
	_start_idle_spin()

func refresh() -> void:
	_resize_shake_layer()
	CurrencyManager.sync_from_backend()
	CollectionManager.sync_from_backend()
	_clear_cards()
	status_label.hide()
	_start_idle_spin()

func _resize_shake_layer() -> void:
	if not is_instance_valid(shake_layer):
		return
	# `size`, pas `get_viewport_rect().size` : quand PackShop est embarqué
	# comme vue du panneau d'infos du menu principal (au lieu d'un overlay
	# plein écran, voir MainMenu.gd), son propre rect n'est qu'une partie de
	# la fenêtre — se baser sur le viewport ferait déborder tout le contenu.
	shake_layer.size = size

## Empilement de dos de carte façon paquet fermé, décalés en diagonale.
## Ajouté à "parent" en tout premier : les layers entrent ainsi dans l'arbre
## de scène et leur _ready() (donc les @onready de Card) s'exécute avant
## qu'on appelle show_back() dessus.
func _build_pack_visual(parent: Control) -> Control:
	var stack_size: Vector2 = CARD_SIZE + Vector2(PACK_LAYER_OFFSET, PACK_LAYER_OFFSET) * (PACK_LAYER_COUNT - 1)
	var visual := Control.new()
	visual.custom_minimum_size = stack_size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.pivot_offset = stack_size / 2.0
	visual.scale = Vector2(PACK_SCALE, PACK_SCALE)

	parent.add_child(visual)

	_pack_layers.clear()
	for i in PACK_LAYER_COUNT:
		var layer := card_scene.instantiate()
		visual.add_child(layer)
		layer.set_non_interactive()
		layer.size = CARD_SIZE
		layer.position = Vector2(i, i) * PACK_LAYER_OFFSET
		layer.pivot_offset = CARD_SIZE / 2.0
		layer.show_back(true)
		_pack_layers.append(layer)
	return visual

## Rotation d'ambiance retirée sur demande explicite de l'utilisateur (le
## paquet ne doit plus tourner sur lui-même au repos) — conservée comme no-op
## nommé plutôt que supprimée partout : _stop_spin()/_set_layers_scale_x(1.0)
## restent le point d'entrée qui garantit un paquet face visible et immobile
## avant/après une révélation, et _pulse_pack_flip (le tour ponctuel qui
## accompagne CHAQUE carte qui sort) reste inchangé — seule la boucle
## perpétuelle est retirée.
func _start_idle_spin() -> void:
	_stop_spin()

func _stop_spin() -> void:
	if _idle_spin_tween and _idle_spin_tween.is_valid():
		_idle_spin_tween.kill()
	_idle_spin_tween = null
	_set_layers_scale_x(1.0)

## Applique la même échelle horizontale aux 4 dos de carte (autour de leur
## propre centre, voir layer.pivot_offset) : à mi-parcours (valeur 0), leurs
## décalages en diagonale restent visibles côte à côte au lieu de se
## confondre en une seule ligne — l'effet se lit comme une petite pile de 4
## cartes vue par la tranche plutôt qu'une image plate qui disparaît.
func _set_layers_scale_x(value: float) -> void:
	for layer in _pack_layers:
		if is_instance_valid(layer):
			layer.scale.x = value

func _set_action_buttons_disabled(disabled: bool) -> void:
	open_x1_button.disabled = disabled
	open_x3_button.disabled = disabled
	open_x5_button.disabled = disabled
	owned_button.disabled = disabled

## Ouvre `quantity` packs d'affilée (l'API backend n'en ouvre qu'un par
## requête) puis révèle toutes les cartes tirées dans une seule séquence. Si
## un appel échoue en cours de route (solde épuisé après les premiers packs
## payés, par ex.), les cartes déjà obtenues sont tout de même révélées.
func _open_pack(free: bool, quantity: int) -> void:
	_set_action_buttons_disabled(true)
	status_label.hide()

	var all_cards: Array = []
	var last_code := 200
	for i in quantity:
		var result: Dictionary = await _request_single_pack(free)
		if not is_instance_valid(self):
			return
		last_code = result["code"]
		var cards: Array = result["cards"]
		if last_code != 200 or cards.is_empty():
			break
		all_cards.append_array(cards)

	_on_packs_opened(last_code, all_cards)

func _request_single_pack(free: bool) -> Dictionary:
	CurrencyManager.open_pack(func(code: int, cards: Array): _pack_request_completed.emit(code, cards), free)
	var result: Array = await _pack_request_completed
	return {"code": result[0], "cards": result[1]}

## Ouvre d'un coup tous les packs gratuits gagnés (quêtes hebdo, parrainage —
## voir CurrencyManager.free_packs), même séquence de révélation que x1/x3/x5
## mais débité du solde de packs plutôt que de l'or.
func _open_owned_packs() -> void:
	var quantity: int = CurrencyManager.free_packs
	if quantity <= 0:
		return
	_set_action_buttons_disabled(true)
	status_label.hide()

	var all_cards: Array = []
	var last_code := 200
	for i in quantity:
		var result: Dictionary = await _request_single_owned_pack()
		if not is_instance_valid(self):
			return
		last_code = result["code"]
		var cards: Array = result["cards"]
		if last_code != 200 or cards.is_empty():
			break
		all_cards.append_array(cards)

	_on_packs_opened(last_code, all_cards)

func _request_single_owned_pack() -> Dictionary:
	CurrencyManager.open_owned_pack(func(code: int, cards: Array): _pack_request_completed.emit(code, cards))
	var result: Array = await _pack_request_completed
	return {"code": result[0], "cards": result[1]}

func _on_packs_opened(code: int, cards: Array) -> void:
	_clear_cards()

	if cards.is_empty():
		_set_action_buttons_disabled(false)
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()
		_start_idle_spin()
		return

	# Les cartes tirées viennent d'être octroyées côté serveur (grantCard) :
	# resynchronise la collection pour qu'elles soient utilisables tout de
	# suite dans le deckbuilder sans attendre le prochain redémarrage.
	CollectionManager.sync_from_backend()

	var entries: Array = []
	for card_row in cards:
		var card_data: CardData = CardLibrary.card_by_backend_id.get(card_row.get("id"), null)
		if card_data == null:
			continue
		entries.append({
			"data": card_data,
			"dusted": card_row.get("dusted", false),
			"gold": int(card_row.get("goldEarned", 0)),
		})

	if code != 200:
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()

	_reveal_sequence(entries)

## Calcule une grille de positions (côté droit de l'écran, à droite du
## paquet) pour `count` cartes, ainsi que l'échelle de repos à leur appliquer
## pour qu'elles restent toutes visibles sans déborder du cadre.
func _compute_grid_slots(count: int) -> Dictionary:
	var viewport_size: Vector2 = size
	var area_left: float = viewport_size.x * GRID_AREA_LEFT_RATIO + GRID_AREA_SIDE_MARGIN
	var area_right: float = viewport_size.x - GRID_AREA_SIDE_MARGIN
	var area_top: float = GRID_AREA_TOP
	var area_bottom: float = viewport_size.y - GRID_AREA_BOTTOM
	var area_size := Vector2(max(area_right - area_left, 1.0), max(area_bottom - area_top, 1.0))

	var columns: int = clamp(count, 1, GRID_MAX_COLUMNS)
	var rows: int = int(ceil(float(count) / columns))
	var cell_size := Vector2(area_size.x / columns, area_size.y / rows)

	var scale_x: float = cell_size.x * GRID_CELL_PADDING / CARD_SIZE.x
	var scale_y: float = cell_size.y * GRID_CELL_PADDING / CARD_SIZE.y
	var reveal_scale: float = clamp(min(scale_x, scale_y, HOVER_SCALE), GRID_MIN_SCALE, HOVER_SCALE)

	var cols_in_last_row: int = count - (rows - 1) * columns
	var slots: Array = []
	for i in count:
		var row: int = i / columns
		var cols_in_row: int = columns if row < rows - 1 else cols_in_last_row
		var row_left: float = area_left + (area_size.x - cols_in_row * cell_size.x) / 2.0
		var col: int = i % columns
		# + global_position : ces coordonnées sont ensuite consommées comme des
		# global_position par _fly_and_reveal/_place_card_instant, alors que tout
		# ci-dessus est calculé en LOCAL (relatif à ce Control, via `size`). Sans
		# ce décalage, une fois PackShop embarqué comme vue du panneau d'infos
		# (donc plus jamais à l'origine (0,0) de l'écran), les cartes révélées
		# volaient vers des coordonnées écran qui ignoraient la position réelle
		# du panneau — elles atterrissaient hors de son cadre.
		slots.append(Vector2(
			row_left + (col + 0.5) * cell_size.x,
			area_top + (row + 0.5) * cell_size.y
		) + global_position)

	return {"slots": slots, "scale": reveal_scale}

## Révèle les cartes tirées une par une : à chaque tour du paquet, une carte
## en jaillit et vole vers sa place en grille à droite en se retournant.
## Cliquer sur l'indice "passer" affiché pendant la séquence saute directement
## le reste des cartes sans animation.
func _reveal_sequence(entries: Array) -> void:
	_revealing = true
	_skip_requested = false
	skip_hint_label.show()
	_stop_spin()

	var grid: Dictionary = _compute_grid_slots(entries.size())
	var slots: Array = grid["slots"]
	_reveal_scale = grid["scale"]

	for i in range(entries.size()):
		var skip_now := _skip_requested
		if not skip_now:
			var delay := FIRST_REVEAL_DELAY if i == 0 \
				else maxf(REVEAL_STAGGER_MIN, REVEAL_STAGGER - REVEAL_STAGGER_DECAY * (i - 1))
			await get_tree().create_timer(delay).timeout
			skip_now = _skip_requested
		if not is_instance_valid(self):
			return
		await _reveal_one(entries[i], slots[i], skip_now)
		if not is_instance_valid(self):
			return

	skip_hint_label.hide()
	_revealing = false
	_set_action_buttons_disabled(false)
	_update_progress_label()
	_start_idle_spin()

func _on_skip_input(event: InputEvent) -> void:
	if _revealing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_requested = true

## Cycle complet d'une carte : tour du paquet, puis envol+retournement vers sa
## place. En mode "skip", la carte apparaît directement à sa place sans
## animation.
func _reveal_one(entry: Dictionary, slot_pos: Vector2, skip: bool) -> void:
	if skip:
		_place_card_instant(entry, slot_pos)
		return

	await _pulse_pack_flip()
	if not is_instance_valid(self):
		return

	var card_instance := _spawn_pack_card()
	await _fly_and_reveal(card_instance, entry, slot_pos)

## Un tour complet du paquet (dos toujours visible), accompagné du son de
## mélange — le geste qui "fait sortir" la prochaine carte.
func _pulse_pack_flip() -> void:
	if _pack_layers.is_empty():
		return
	AudioManager.play(AudioManager.SHUFFLE)
	var tween := create_tween()
	tween.tween_method(_set_layers_scale_x, 1.0, 0.0, PACK_FLIP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_method(_set_layers_scale_x, 0.0, 1.0, PACK_FLIP_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished

## Carte face cachée qui apparaît au centre du paquet, prête à s'envoler.
func _spawn_pack_card() -> Control:
	var card_instance := card_scene.instantiate()
	pack_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = CARD_SIZE
	card_instance.pivot_offset = CARD_SIZE / 2.0
	card_instance.scale = Vector2(PACK_SCALE, PACK_SCALE)
	card_instance.show_back(true)
	var center: Vector2 = _pack_visual.get_global_rect().get_center()
	card_instance.global_position = center - CARD_SIZE / 2.0
	return card_instance

## Envol vers la place assignée en grille, avec un flip (façon pièce qui
## tourne) au passage qui révèle la carte à mi-chemin.
func _fly_and_reveal(card_instance: Control, entry: Dictionary, slot_pos: Vector2) -> void:
	var card_data: CardData = entry["data"]
	var target_position: Vector2 = slot_pos - CARD_SIZE / 2.0

	var move_tween := create_tween()
	move_tween.tween_property(card_instance, "global_position", target_position, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	move_tween.parallel().tween_property(card_instance, "scale:y", _reveal_scale, CARD_FLY_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var flip_tween := create_tween()
	flip_tween.tween_property(card_instance, "scale:x", 0.0, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	flip_tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(card_data)
		card_instance.set_non_interactive()
		_make_card_hoverable(card_instance, _reveal_scale)
		card_instance.pivot_offset = CARD_SIZE / 2.0
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	flip_tween.tween_property(card_instance, "scale:x", _reveal_scale, CARD_FLY_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await move_tween.finished
	if not is_instance_valid(self) or not is_instance_valid(card_instance):
		return

	if RARE_RARITIES.has(card_data.rarity):
		await _play_rare_flourish(card_instance, entry)

## Flourish de tirage rare : flash plein écran et son distinct, plus marqués
## sur Légendaire que sur Épique. Volontairement discret (pas de particules ni
## de secousse d'écran).
func _play_rare_flourish(card_instance: Control, entry: Dictionary) -> void:
	if not is_instance_valid(card_instance):
		return
	var card_data: CardData = entry["data"]
	var rarity: String = card_data.rarity
	var legendary: bool = rarity == "Legendary"
	var glow_color: Color = Card.RARITY_COLORS.get(rarity, Color.WHITE)

	if legendary:
		AudioManager.play_with_pitch(AudioManager.CONFIRM, 0.85, 0.95)
	else:
		AudioManager.play_with_pitch(AudioManager.CONFIRM, 0.98, 1.08)
	if legendary:
		await get_tree().create_timer(0.12).timeout
		if is_instance_valid(card_instance):
			AudioManager.play_with_pitch(AudioManager.CONFIRM, 1.05, 1.15)

	_flash_screen(glow_color, FLASH_ALPHA.get(rarity, 0.2))

	var final_modulate: Color = Color(0.6, 0.6, 0.6, 1) if entry["dusted"] else Color.WHITE
	card_instance.modulate = Color(glow_color.r * 1.6, glow_color.g * 1.6, glow_color.b * 1.6, 1.0)

	var flourish := create_tween()
	flourish.tween_property(card_instance, "scale", Vector2(_reveal_scale, _reveal_scale) * 1.18, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.4)
	flourish.tween_property(card_instance, "scale", Vector2(_reveal_scale, _reveal_scale), 0.14).set_trans(Tween.TRANS_LINEAR)
	await flourish.finished

## Flash coloré plein écran (teinte de la rareté), léger et bref.
func _flash_screen(color: Color, peak_alpha: float) -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", peak_alpha, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Miniature statique placée directement à sa place en grille, sans
## animation (mode "passer").
func _place_card_instant(entry: Dictionary, slot_pos: Vector2) -> void:
	var card_data: CardData = entry["data"]
	var card_instance := card_scene.instantiate()
	pack_stage.add_child(card_instance)
	card_instance.set_non_interactive()
	_make_card_hoverable(card_instance, _reveal_scale)
	card_instance.size = CARD_SIZE
	card_instance.pivot_offset = CARD_SIZE / 2.0
	card_instance.scale = Vector2(_reveal_scale, _reveal_scale)
	card_instance.global_position = slot_pos - CARD_SIZE / 2.0
	card_instance.show_back(false)
	card_instance.set_data(card_data)
	if entry["dusted"]:
		_add_dust_badge(card_instance, entry["gold"])

## Petit panneau flottant listant les probabilités de tirage par rareté
## (miroir client de RARITY_WEIGHTS côté backend, purement indicatif).
func _on_odds_pressed() -> void:
	# Clics répétés avant l'expiration du panneau précédent (ODDS_TOOLTIP_DURATION) :
	# sans ça, chaque clic empilait un nouveau panneau identique au même endroit.
	if is_instance_valid(_odds_panel):
		_odds_panel.queue_free()
		_odds_panel = null

	var weights: Dictionary = CurrencyManager.RARITY_WEIGHTS_DISPLAY
	var total := 0
	for w in weights.values():
		total += w

	var lines: PackedStringArray = []
	for rarity in ["Common", "Rare", "Epic", "Legendary"]:
		var percent: float = 100.0 * float(weights.get(rarity, 0)) / total
		lines.append("%s : %.0f%%" % [SettingsManager.t("rarity.%s" % rarity.to_lower()), percent])

	var panel := TooltipData.make_tooltip_panel(SettingsManager.t("pack_shop.odds_title"), "\n".join(lines))
	panel.position = Vector2(-9999, -9999)
	add_child(panel)
	_odds_panel = panel
	await get_tree().process_frame
	if not is_instance_valid(panel) or not is_instance_valid(odds_button) or panel != _odds_panel:
		return
	panel.global_position = odds_button.global_position + Vector2((odds_button.size.x - panel.size.x) / 2.0, odds_button.size.y + 6.0)
	await get_tree().create_timer(ODDS_TOOLTIP_DURATION).timeout
	if panel == _odds_panel:
		_odds_panel = null
	if is_instance_valid(panel):
		panel.queue_free()

## Badge affiché sur les cartes en double (déjà à MAX_COPIES) : le pack a
## converti cet exemplaire en or plutôt que de l'ajouter à la collection
## (voir packModel.openPack côté wyrdane-backend).
func _add_dust_badge(card_instance: Control, gold_earned: int) -> void:
	card_instance.modulate = Color(0.6, 0.6, 0.6, 1)

	var badge_bg := StyleBoxFlat.new()
	badge_bg.bg_color = Color(0.05, 0.04, 0.02, 0.9)
	badge_bg.set_corner_radius_all(4)
	badge_bg.content_margin_left   = 6
	badge_bg.content_margin_right  = 6
	badge_bg.content_margin_top    = 2
	badge_bg.content_margin_bottom = 2

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", badge_bg)
	badge_panel.anchor_left   = 0.0
	badge_panel.anchor_right  = 1.0
	badge_panel.anchor_top    = 1.0
	badge_panel.anchor_bottom = 1.0
	badge_panel.offset_top    = -30
	badge_panel.offset_bottom = -6
	badge_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE

	var badge_label := Label.new()
	badge_label.text = SettingsManager.t("pack_shop.dust_format") % gold_earned
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.40, 1))
	badge_panel.add_child(badge_label)

	card_instance.add_child(badge_panel)

## Léger agrandissement au survol pour mieux voir la carte gagnée, sans
## réintroduire le drag-and-drop (set_non_interactive() reste appelé avant,
## seul mouse_filter est réouvert au survol). base_scale : échelle de repos de
## la carte (_reveal_scale), pour que le hover reste relatif à sa taille réelle
## dans la grille plutôt que d'écraser une valeur absolue.
const PACK_HOVER_ZOOM := 1.15
const PACK_HOVER_DURATION := 0.12

func _make_card_hoverable(card_instance: Control, base_scale: float) -> void:
	card_instance.mouse_filter = Control.MOUSE_FILTER_STOP
	card_instance.mouse_entered.connect(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.z_index = 50
		var t := create_tween()
		t.tween_property(card_instance, "scale", Vector2.ONE * base_scale * PACK_HOVER_ZOOM, PACK_HOVER_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	card_instance.mouse_exited.connect(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.z_index = 0
		var t := create_tween()
		t.tween_property(card_instance, "scale", Vector2.ONE * base_scale, PACK_HOVER_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	)

func _clear_cards() -> void:
	for child in pack_stage.get_children():
		if child == pack_center:
			continue
		child.queue_free()

func _update_balance_label(new_balance: int) -> void:
	balance_label.text = str(new_balance)

## Visible seulement si le joueur a au moins un pack gratuit à ouvrir (quêtes
## hebdo, parrainage) — CurrencyManager.free_packs, séparé du solde d'or.
func _update_owned_button() -> void:
	var count: int = CurrencyManager.free_packs
	owned_button.get_parent().visible = count > 0
	owned_button.text = SettingsManager.t("pack_shop.open_owned") % count

## Teaser de complétion de collection : cartes obtenues (>=1 exemplaire) sur
## le total de cartes collectionnables (exclut les cartes-ressource, jamais
## octroyées par un pack — voir packModel.fetchDrawablePool côté backend).
func _update_progress_label() -> void:
	var total := 0
	var owned := 0
	for card_data: CardData in CardLibrary.all_cards:
		if card_data.card_type == "Resource":
			continue
		total += 1
		if CollectionManager.is_owned(card_data):
			owned += 1
	progress_label.text = SettingsManager.t("pack_shop.progress") % [owned, total]

func _style_close_x_button() -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(6)
	close_x_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("8b1a1a55")
	close_x_button.add_theme_stylebox_override("hover", hover)

## Habille un bouton d'action (x1/x3/x5, ?, packs gagnés) dans le même style
## parchemin/or que le reste des popups custom du jeu (voir
## DeckBuilder._make_popup_overlay : fond sombre, bordure or, coins arrondis)
## au lieu du thème Godot par défaut — aucun Theme global n'est configuré
## pour le projet, donc rien d'autre ne l'aurait fait pour nous.
func _style_action_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.12, 0.06, 0.95)
	normal.border_color = Color(0.6, 0.45, 0.15, 0.85)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.18, 0.08, 0.95)
	hover.border_color = Color(0.85, 0.65, 0.20, 1.0)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.10, 0.08, 0.04, 0.95)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.10, 0.09, 0.08, 0.6)
	disabled.border_color = Color(0.4, 0.35, 0.25, 0.5)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.98, 0.88, 0.5, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.5, 0.45, 0.7))

func _retranslate() -> void:
	title_label.text = SettingsManager.t("pack_shop.title")
	open_x1_button.text = SettingsManager.t("pack_shop.open_x1") % (CurrencyManager.PACK_COST * 1)
	open_x3_button.text = SettingsManager.t("pack_shop.open_x3") % (CurrencyManager.PACK_COST * 3)
	open_x5_button.text = SettingsManager.t("pack_shop.open_x5") % (CurrencyManager.PACK_COST * 5)
	odds_button.text = SettingsManager.t("pack_shop.odds_button")
	close_x_button.tooltip_text = SettingsManager.t("pack_shop.close")
	skip_hint_label.text = SettingsManager.t("pack_shop.skip_hint")
	status_label.text = SettingsManager.t("pack_shop.error")
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
	_update_owned_button()
