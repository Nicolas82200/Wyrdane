extends Control
class_name PackShop

# Écran d'ouverture de packs (première itération du système de progression :
# monnaie gagnée en jouant, dépensée ici contre des cartes aléatoires
# pondérées par rareté — voir POST /api/packs/open côté wyrdane-backend).

@export var card_scene: PackedScene

const FLIP_HALF_DURATION := 0.12
const FIRST_REVEAL_DELAY := 0.15
const REVEAL_STAGGER := 0.45
const RARE_RARITIES := ["Epic", "Legendary"]
const ODDS_TOOLTIP_DURATION := 4.0

@onready var balance_label: Label = $Panel/VBox/BalanceLabel
@onready var progress_label: Label = $Panel/VBox/ProgressLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var open_button: Button = $Panel/VBox/OpenRowMargin/OpenRow/OpenButton
@onready var odds_button: Button = $Panel/VBox/OpenRowMargin/OpenRow/OddsButton
@onready var free_button: Button = $Panel/VBox/FreeButtonMargin/FreeButton
@onready var close_button: Button = $Panel/VBox/CloseButtonMargin/CloseButton
@onready var skip_hint_label: Label = $Panel/VBox/SkipHintLabel
@onready var cards_grid: HBoxContainer = $Panel/VBox/CardsScroll/CardsGrid
@onready var title_label: Label = $Panel/VBox/TitleMargin/Title

var _revealing: bool = false
var _skip_requested: bool = false

func _ready() -> void:
	hide()
	status_label.hide()
	skip_hint_label.hide()
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

## Révèle les cartes tirées une par une (face cachée -> flip en cascade),
## avec un flourish distinct sur les raretés élevées (Épique/Légendaire).
## Cliquer sur l'indice "passer" affiché pendant la séquence saute
## directement le reste des cartes sans animation.
func _reveal_sequence(entries: Array) -> void:
	_revealing = true
	_skip_requested = false
	skip_hint_label.show()

	var card_instances: Array = []
	for entry in entries:
		var card_instance := card_scene.instantiate()
		cards_grid.add_child(card_instance)
		card_instance.set_non_interactive()
		card_instance.show_back(true)
		card_instances.append(card_instance)

	for i in range(entries.size()):
		if not _skip_requested:
			var delay := FIRST_REVEAL_DELAY if i == 0 else REVEAL_STAGGER
			await get_tree().create_timer(delay).timeout
		if not is_instance_valid(self):
			return
		_flip_card(card_instances[i], entries[i])

	skip_hint_label.hide()
	_revealing = false
	open_button.disabled = false
	free_button.disabled = false
	_update_progress_label()

func _on_skip_input(event: InputEvent) -> void:
	if _revealing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_requested = true

func _flip_card(card_instance: Control, entry: Dictionary) -> void:
	var card_data: CardData = entry["data"]
	var rare: bool = RARE_RARITIES.has(card_data.rarity) and not _skip_requested
	var half_duration := 0.0 if _skip_requested else FLIP_HALF_DURATION

	var tween := create_tween()
	tween.tween_property(card_instance, "scale:x", 0.0, half_duration).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		if not is_instance_valid(card_instance):
			return
		card_instance.show_back(false)
		card_instance.set_data(card_data)
		card_instance.set_non_interactive()
		if entry["dusted"]:
			_add_dust_badge(card_instance, entry["gold"])
		AudioManager.play(AudioManager.DRAW)
	)
	tween.tween_property(card_instance, "scale:x", 1.0, half_duration).set_trans(Tween.TRANS_LINEAR)
	if rare:
		tween.tween_callback(_play_rare_flourish.bind(card_instance, entry))

## Flash coloré (teinte de la rareté) + pop + son distinct : met en valeur un
## tirage Épique/Légendaire dans la séquence de reveal.
func _play_rare_flourish(card_instance: Control, entry: Dictionary) -> void:
	if not is_instance_valid(card_instance):
		return
	AudioManager.play(AudioManager.CONFIRM)
	var rarity: String = entry["data"].rarity
	var final_modulate: Color = Color(0.6, 0.6, 0.6, 1) if entry["dusted"] else Color.WHITE
	var glow_color: Color = Card.RARITY_COLORS.get(rarity, Color.WHITE)
	card_instance.modulate = Color(glow_color.r * 1.6, glow_color.g * 1.6, glow_color.b * 1.6, 1.0)

	var flourish := create_tween()
	flourish.tween_property(card_instance, "scale", Vector2(1.15, 1.15), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flourish.parallel().tween_property(card_instance, "modulate", final_modulate, 0.35)
	flourish.tween_property(card_instance, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_LINEAR)

## Vignette face cachée décorative affichée quand aucun pack n'est en cours
## d'ouverture (écran sinon vide avant le premier achat / après un refresh).
func _show_placeholder() -> void:
	if not is_instance_valid(card_scene):
		return
	var placeholder := card_scene.instantiate()
	cards_grid.add_child(placeholder)
	placeholder.set_non_interactive()
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
	for child in cards_grid.get_children():
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
