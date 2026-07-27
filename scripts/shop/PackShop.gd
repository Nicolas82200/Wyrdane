extends Control
class_name PackShop

# Écran d'ouverture de packs (première itération du système de progression :
# monnaie gagnée en jouant, dépensée ici contre des cartes aléatoires
# pondérées par rareté — voir POST /api/packs/open côté wyrdane-backend).
#
# Reveal carte par carte en grand format au centre (StageContainer) : chaque
# carte s'affiche en gros, flippe, puis se réduit tandis qu'une miniature
# rejoint la pile de cartes déjà révélées (CollectedRow) en bas de la zone.
# Les tirages Épique/Légendaire ont un flourish renforcé (VFXManager, flash
# plein écran, secousse de caméra, son distinct).

@export var card_scene: PackedScene

const CARD_SIZE := Vector2(250, 375)
const STAGE_SCALE := 1.45
const COLLECTED_SCALE := 0.4
const FLIP_HALF_DURATION := 0.14
const FLIP_TILT_DEGREES := 7.0
const FIRST_REVEAL_DELAY := 0.2
const REVEAL_STAGGER := 0.55
const POST_FLOURISH_PAUSE := 0.3
const RETIRE_DURATION := 0.3
const RARE_RARITIES := ["Epic", "Legendary"]
const ODDS_TOOLTIP_DURATION := 4.0
const SHAKE_STRENGTH := {"Epic": 6.0, "Legendary": 13.0}
const FLASH_ALPHA := {"Epic": 0.22, "Legendary": 0.42}

@onready var balance_label: Label = $Panel/VBox/BalanceLabel
@onready var progress_label: Label = $Panel/VBox/ProgressLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var open_button: Button = $Panel/VBox/OpenRowMargin/OpenRow/OpenButton
@onready var odds_button: Button = $Panel/VBox/OpenRowMargin/OpenRow/OddsButton
@onready var free_button: Button = $Panel/VBox/FreeButtonMargin/FreeButton
@onready var close_button: Button = $Panel/VBox/CloseButtonMargin/CloseButton
@onready var skip_hint_label: Label = $Panel/VBox/SkipHintLabel
@onready var stage_container: CenterContainer = $Panel/VBox/RevealArea/StageContainer
@onready var collected_row: HBoxContainer = $Panel/VBox/RevealArea/CollectedMargin/CollectedRow
@onready var title_label: Label = $Panel/VBox/TitleMargin/Title
@onready var shake_target: Control = $Panel
@onready var flash_rect: ColorRect = $FlashRect

var _revealing: bool = false
var _skip_requested: bool = false
# Overlay VFX (impacts thématiques par race) réutilisé du combat pour le
# flourish des tirages rares — voir VFXManager.spawn_hit_impact.
var _vfx_manager: VFXManager

func _ready() -> void:
	hide()
	status_label.hide()
	skip_hint_label.hide()
	_vfx_manager = VFXManager.new()
	add_child(_vfx_manager)
	open_button.pressed.connect(_on_open_pressed)
	odds_button.pressed.connect(_on_odds_pressed)
	# Bouton d'ouverture gratuite : outil de test, réservé aux builds debug
	# (l'export release ne l'affiche pas) et refusé côté serveur (403) tant
	# que DEV_FREE_PACKS n'est pas activé sur le backend.
	free_button.get_parent().visible = OS.is_debug_build()
	free_button.pressed.connect(func(): _open_pack(true))
	close_button.pressed.connect(func(): AudioManager.play(AudioManager.CLOSE_MENU); hide())
	skip_hint_label.gui_input.connect(_on_skip_input)
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_balance_label(new_balance))
	CollectionManager.collection_loaded.connect(_update_progress_label)
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
	_show_placeholder()

func refresh() -> void:
	CurrencyManager.sync_from_backend()
	CollectionManager.sync_from_backend()
	_clear_cards()
	_show_placeholder()
	status_label.hide()

func _on_open_pressed() -> void:
	_open_pack(false)

func _open_pack(free: bool) -> void:
	open_button.disabled = true
	free_button.disabled = true
	status_label.hide()
	CurrencyManager.open_pack(func(code: int, cards: Array): _on_pack_opened(code, cards), free)

func _on_pack_opened(code: int, cards: Array) -> void:
	_clear_cards()

	if code != 200 or cards.is_empty():
		open_button.disabled = false
		free_button.disabled = false
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()
		_show_placeholder()
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

	_reveal_sequence(entries)

## Révèle les cartes tirées une par une, en grand format au centre de la
## scène : flip -> flourish (renforcé sur Épique/Légendaire) -> réduction vers
## une miniature qui rejoint la pile de cartes déjà révélées. Cliquer sur
## l'indice "passer" affiché pendant la séquence saute directement le reste
## des cartes sans animation.
func _reveal_sequence(entries: Array) -> void:
	_revealing = true
	_skip_requested = false
	skip_hint_label.show()

	for i in range(entries.size()):
		var skip_now := _skip_requested
		if not skip_now:
			var delay := FIRST_REVEAL_DELAY if i == 0 else REVEAL_STAGGER
			await get_tree().create_timer(delay).timeout
			skip_now = _skip_requested
		if not is_instance_valid(self):
			return
		await _reveal_one(entries[i], skip_now)
		if not is_instance_valid(self):
			return

	skip_hint_label.hide()
	_revealing = false
	open_button.disabled = false
	free_button.disabled = false
	_update_progress_label()

func _on_skip_input(event: InputEvent) -> void:
	if _revealing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_requested = true

## Cycle complet d'une carte : affichage grand format face cachée, flip,
## flourish éventuel, puis réduction vers la pile de cartes collectées. En
## mode "skip", la miniature est ajoutée directement sans aucune animation.
func _reveal_one(entry: Dictionary, skip: bool) -> void:
	if skip:
		_add_collected_thumbnail(entry, false)
		return

	var card_instance := card_scene.instantiate()
	stage_container.add_child(card_instance)
	card_instance.set_non_interactive()
	card_instance.size = CARD_SIZE
	card_instance.pivot_offset = CARD_SIZE / 2.0
	card_instance.scale = Vector2(STAGE_SCALE, STAGE_SCALE)
	card_instance.show_back(true)

	await _flip_card_big(card_instance, entry, skip)
	if not is_instance_valid(self):
		return

	await get_tree().create_timer(POST_FLOURISH_PAUSE).timeout
	if not is_instance_valid(self):
		return

	await _retire_card(card_instance, entry)

## Flip 3D "wobble" (léger tilt combiné au scale:x) puis flourish renforcé
## (VFX thématique, flash, secousse) sur Épique/Légendaire.
func _flip_card_big(card_instance: Control, entry: Dictionary, skip: bool) -> void:
	var card_data: CardData = entry["data"]
	var rare: bool = RARE_RARITIES.has(card_data.rarity) and not skip
	var half_duration := 0.0 if skip else FLIP_HALF_DURATION
	var tilt := 0.0 if skip else FLIP_TILT_DEGREES

	var tween := create_tween()
	tween.tween_property(card_instance, "scale:x", 0.0, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if tilt > 0.0:
		tween.parallel().tween_property(card_instance, "rotation_degrees", -tilt, half_duration)
	tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(card_data)
		card_instance.set_non_interactive()
		card_instance.pivot_offset = CARD_SIZE / 2.0
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	tween.tween_property(card_instance, "scale:x", STAGE_SCALE, half_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if tilt > 0.0:
		tween.parallel().tween_property(card_instance, "rotation_degrees", 0.0, half_duration)
	await tween.finished

	if not is_instance_valid(self) or not is_instance_valid(card_instance):
		return
	if rare:
		await _play_rare_flourish(card_instance, entry)

## Flourish de tirage rare : impact VFX thématique par race (réutilise le
## système déjà employé en combat), flash plein écran, secousse de caméra et
## son distinct, plus marqués sur Légendaire que sur Épique.
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
	_shake_stage(SHAKE_STRENGTH.get(rarity, 6.0))
	if is_instance_valid(_vfx_manager):
		_vfx_manager.spawn_hit_impact(card_instance.get_global_rect().get_center(), card_data.race, legendary)

	var final_modulate: Color = Color(0.6, 0.6, 0.6, 1) if entry["dusted"] else Color.WHITE
	card_instance.modulate = Color(glow_color.r * 1.6, glow_color.g * 1.6, glow_color.b * 1.6, 1.0)

	var flourish := create_tween()
	flourish.tween_property(card_instance, "scale", Vector2(STAGE_SCALE, STAGE_SCALE) * 1.18, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.4)
	flourish.tween_property(card_instance, "scale", Vector2(STAGE_SCALE, STAGE_SCALE), 0.14).set_trans(Tween.TRANS_LINEAR)
	await flourish.finished

## Flash coloré plein écran (teinte de la rareté), léger et bref.
func _flash_screen(color: Color, peak_alpha: float) -> void:
	if not is_instance_valid(flash_rect):
		return
	flash_rect.color = Color(color.r, color.g, color.b, 0.0)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", peak_alpha, 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash_rect, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Secousse de caméra rudimentaire : quelques décalages aléatoires
## décroissants du panneau principal, revenant à sa position d'origine.
func _shake_stage(strength: float) -> void:
	if not is_instance_valid(shake_target):
		return
	var base_pos: Vector2 = shake_target.position
	var tween := create_tween()
	var shakes := 6
	for i in shakes:
		var falloff := 1.0 - float(i) / shakes
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) * falloff
		tween.tween_property(shake_target, "position", base_pos + offset, 0.035)
	tween.tween_property(shake_target, "position", base_pos, 0.035)

## Réduit la carte en grand format jusqu'à disparition, puis fait apparaître
## sa miniature dans la pile de cartes déjà révélées.
func _retire_card(card_instance: Control, entry: Dictionary) -> void:
	if not is_instance_valid(card_instance):
		_add_collected_thumbnail(entry, true)
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_instance, "scale", card_instance.scale * 0.1, RETIRE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(card_instance, "modulate:a", 0.0, RETIRE_DURATION)
	await tween.finished
	if is_instance_valid(card_instance):
		card_instance.queue_free()
	_add_collected_thumbnail(entry, true)

## Miniature statique dans la pile de cartes déjà révélées (bas de l'écran).
## `animate` déclenche un petit pop d'apparition ; en mode "skip" les
## miniatures apparaissent directement sans transition.
func _add_collected_thumbnail(entry: Dictionary, animate: bool) -> void:
	if not is_instance_valid(collected_row):
		return
	var card_data: CardData = entry["data"]

	var slot := Control.new()
	slot.custom_minimum_size = CARD_SIZE * COLLECTED_SCALE
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	collected_row.add_child(slot)

	var thumb := card_scene.instantiate()
	slot.add_child(thumb)
	thumb.set_non_interactive()
	thumb.size = CARD_SIZE
	thumb.pivot_offset = Vector2.ZERO
	thumb.position = Vector2.ZERO
	thumb.scale = Vector2(COLLECTED_SCALE, COLLECTED_SCALE)
	thumb.show_back(false)
	thumb.set_data(card_data)
	if entry["dusted"]:
		_add_dust_badge(thumb, entry["gold"])

	if animate:
		thumb.modulate.a = 0.0
		thumb.scale = Vector2(COLLECTED_SCALE, COLLECTED_SCALE) * 0.5
		var tween := create_tween()
		tween.tween_property(thumb, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(thumb, "scale", Vector2(COLLECTED_SCALE, COLLECTED_SCALE), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Vignette face cachée décorative affichée quand aucun pack n'est en cours
## d'ouverture (écran sinon vide avant le premier achat / après un refresh).
func _show_placeholder() -> void:
	if not is_instance_valid(card_scene):
		return
	var placeholder := card_scene.instantiate()
	stage_container.add_child(placeholder)
	placeholder.set_non_interactive()
	placeholder.size = CARD_SIZE
	placeholder.pivot_offset = CARD_SIZE / 2.0
	placeholder.scale = Vector2(STAGE_SCALE, STAGE_SCALE)
	placeholder.show_back(true)
	placeholder.modulate = Color(1, 1, 1, 0.5)

## Petit panneau flottant listant les probabilités de tirage par rareté
## (miroir client de RARITY_WEIGHTS côté backend, purement indicatif).
func _on_odds_pressed() -> void:
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
	await get_tree().process_frame
	if not is_instance_valid(panel) or not is_instance_valid(odds_button):
		return
	panel.global_position = odds_button.global_position + Vector2((odds_button.size.x - panel.size.x) / 2.0, odds_button.size.y + 6.0)
	await get_tree().create_timer(ODDS_TOOLTIP_DURATION).timeout
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

func _clear_cards() -> void:
	for child in stage_container.get_children():
		child.queue_free()
	for child in collected_row.get_children():
		child.queue_free()

func _update_balance_label(new_balance: int) -> void:
	balance_label.text = SettingsManager.t("pack_shop.balance") % new_balance

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

func _retranslate() -> void:
	title_label.text = SettingsManager.t("pack_shop.title")
	open_button.text = SettingsManager.t("pack_shop.open_button") % CurrencyManager.PACK_COST
	odds_button.text = SettingsManager.t("pack_shop.odds_button")
	free_button.text = SettingsManager.t("pack_shop.open_free_button")
	close_button.text = SettingsManager.t("pack_shop.close")
	skip_hint_label.text = SettingsManager.t("pack_shop.skip_hint")
	status_label.text = SettingsManager.t("pack_shop.error")
	_update_balance_label(CurrencyManager.balance)
	_update_progress_label()
