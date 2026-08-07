extends Control

# Nœud Boutique (CAMPAIGN.md « Boutique ») : 4 options contre de l'or de run —
# achat de carte (5 propositions, prix fixe par rareté), amélioration de carte
# (buff de stats, 50 or de base — hypothèse v1 : un seul type d'amélioration,
# le choix mot-clé vs stats reste un point ouvert de CAMPAIGN.md), soin (30 %
# des PV manquants, prix scalé), retrait (or croissant par retrait).

const CARD_SCENE := preload("res://scenes/card/Card.tscn")
const CARD_BASE_SIZE := Vector2(250, 375)
const CARD_DISPLAY_SCALE := 0.65
const CAMPAIGN_MAP_SCENE := "res://scenes/campaign/CampaignMapScreen.tscn"
const MAIN_MENU_SCENE := "res://scenes/mainMenu/MainMenu.tscn"

const BUY_COUNT := 5
const PRICE_BY_RARITY := {
	"Common": 25, "Rare": 75, "Epic": 125, "Legendary": 175,
}
const UPGRADE_COST := 50
const UPGRADE_ATTACK_BONUS := 1
const UPGRADE_HEALTH_BONUS := 1
const HEAL_PERCENT := 0.3
const HEAL_BASE_COST := 20
const HEAL_COST_TIER_INTERVAL := 5
const HEAL_COST_GROWTH := 1.25
const DISCARD_BASE_COST := 10
const DISCARD_COST_STEP := 10

var _run: CampaignRun
var _gold_label: Label
var _buy_box: HBoxContainer
var _bought_this_visit: Dictionary = {}

func _ready() -> void:
	if not CampaignContext.active or CampaignContext.run == null:
		get_tree().change_scene_to_file(MAIN_MENU_SCENE)
		return
	_run = CampaignContext.run
	add_child(CampaignUI.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := CampaignUI.make_title_label(SettingsManager.t("CAMPAIGN_SHOP_TITLE"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_gold_label = CampaignUI.make_body_label("")
	header.add_child(_gold_label)
	_refresh_gold_label()

	vbox.add_child(CampaignUI.make_body_label(SettingsManager.t("CAMPAIGN_SHOP_BODY")))

	_buy_box = HBoxContainer.new()
	_buy_box.add_theme_constant_override("separation", 14)
	_buy_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_buy_box)
	_populate_buy_offers()

	var actions_box := HBoxContainer.new()
	actions_box.add_theme_constant_override("separation", 14)
	actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(actions_box)
	actions_box.add_child(_make_action_button(
		SettingsManager.t("CAMPAIGN_SHOP_UPGRADE") % UPGRADE_COST, _on_upgrade_pressed))
	actions_box.add_child(_make_action_button(
		SettingsManager.t("CAMPAIGN_SHOP_HEAL") % _heal_cost(), _on_heal_pressed))
	actions_box.add_child(_make_action_button(
		SettingsManager.t("CAMPAIGN_SHOP_DISCARD") % _discard_cost(), _on_discard_pressed))

	var leave_button := Button.new()
	leave_button.text = SettingsManager.t("CAMPAIGN_SHOP_LEAVE")
	CampaignUI.style_button(leave_button)
	leave_button.pressed.connect(func():
		_run.mark_node_cleared(_run.current_node_id)
		get_tree().change_scene_to_file(CAMPAIGN_MAP_SCENE))
	vbox.add_child(leave_button)

func _make_action_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	CampaignUI.style_button(btn)
	btn.pressed.connect(callback)
	return btn

func _refresh_gold_label() -> void:
	_gold_label.text = "%s : %d" % [SettingsManager.t("CAMPAIGN_GOLD_LABEL"), _run.gold]

func _heal_cost() -> int:
	var tier: int = max(0, _run.depth - 1) / HEAL_COST_TIER_INTERVAL
	var cost: float = HEAL_BASE_COST
	for i in range(tier):
		cost = ceil(cost * HEAL_COST_GROWTH)
	return int(cost)

func _discard_cost() -> int:
	return DISCARD_BASE_COST + _run.discard_count * DISCARD_COST_STEP

# ─── Achat de carte ────────────────────────────────────────────────────────
func _populate_buy_offers() -> void:
	for child in _buy_box.get_children():
		child.queue_free()
	_bought_this_visit.clear()
	var candidates := CampaignRewardPicker.pick_three(_run.race, _run.rng)
	# pick_three ne tire que 3 : complète jusqu'à BUY_COUNT avec des tirages
	# supplémentaires indépendants (même logique de pondération par rareté).
	while candidates.size() < BUY_COUNT:
		var extra := CampaignRewardPicker.pick_three(_run.race, _run.rng)
		if extra.is_empty():
			break
		candidates.append(extra[0])
	for card in candidates:
		_add_buy_option(card)

func _add_buy_option(card: CardData) -> void:
	var option_vbox := VBoxContainer.new()
	option_vbox.add_theme_constant_override("separation", 6)
	_buy_box.add_child(option_vbox)

	var wrapper := Control.new()
	wrapper.custom_minimum_size = CARD_BASE_SIZE * CARD_DISPLAY_SCALE
	option_vbox.add_child(wrapper)

	var card_visual: Card = CARD_SCENE.instantiate()
	wrapper.add_child(card_visual)
	card_visual.set_non_interactive()
	card_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_visual.scale = Vector2(CARD_DISPLAY_SCALE, CARD_DISPLAY_SCALE)
	card_visual.set_data(card)

	var price: int = PRICE_BY_RARITY.get(card.rarity, 999)
	var buy_button := Button.new()
	buy_button.text = "%s (%d)" % [SettingsManager.t("CAMPAIGN_SHOP_BUY"), price]
	CampaignUI.style_button(buy_button)
	buy_button.pressed.connect(func(): _on_buy_pressed(card, price, buy_button))
	option_vbox.add_child(buy_button)

func _on_buy_pressed(card: CardData, price: int, button: Button) -> void:
	if _bought_this_visit.has(card) or _run.gold < price:
		return
	_run.gold -= price
	_run.add_card_to_board(card)
	_bought_this_visit[card] = true
	button.disabled = true
	button.text = SettingsManager.t("CAMPAIGN_SHOP_SOLD")
	AudioManager.play(AudioManager.CONFIRM)
	_refresh_gold_label()

# ─── Amélioration : buff de stats fixe sur une carte du plateau ───────────────
func _on_upgrade_pressed() -> void:
	if _run.gold < UPGRADE_COST or _run.board.is_empty():
		return
	var minions: Array[CardData] = _run.board.filter(func(c: CardData) -> bool: return c.card_type == "Minion")
	if minions.is_empty():
		return
	var card: CardData = minions[_run.rng.randi_range(0, minions.size() - 1)]
	_run.gold -= UPGRADE_COST
	# duplicate() : une CardData est une Resource partagée (chargée une seule
	# fois depuis son .tres, référencée aussi par CardLibrary.all_cards) — la
	# modifier en place corromprait la carte pour toute la partie, pas
	# seulement l'exemplaire de cette run.
	var upgraded: CardData = card.duplicate()
	upgraded.attack += UPGRADE_ATTACK_BONUS
	upgraded.health += UPGRADE_HEALTH_BONUS
	_run.board[_run.board.find(card)] = upgraded
	AudioManager.play(AudioManager.CONFIRM)
	_refresh_gold_label()

# ─── Soin ──────────────────────────────────────────────────────────────────
func _on_heal_pressed() -> void:
	var cost := _heal_cost()
	if _run.gold < cost:
		return
	_run.gold -= cost
	var missing := _run.hero_max_health - _run.hero_health
	_run.heal(int(ceil(missing * HEAL_PERCENT)))
	AudioManager.play(AudioManager.CONFIRM)
	_refresh_gold_label()

# ─── Retrait (désengorgement) ─────────────────────────────────────────────────
func _on_discard_pressed() -> void:
	var cost := _discard_cost()
	if _run.gold < cost or _run.board.is_empty():
		return
	_run.gold -= cost
	var card: CardData = _run.board[_run.rng.randi_range(0, _run.board.size() - 1)]
	_run.remove_card_from_board(card)
	_run.discard_count += 1
	AudioManager.play(AudioManager.CONFIRM)
	_refresh_gold_label()
