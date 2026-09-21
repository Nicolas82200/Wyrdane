extends RefCounted
class_name ShopBuyPacksPanel

# Onglet "Packs" de la Boutique (voir MainMenu.gd, _select_shop_tab) : achat
# de packs UNIQUEMENT, contre de l'or — aucune carte n'est jamais tirée ici
# (CurrencyManager.buy_packs crédite le stock CurrencyManager.free_packs sans
# ouvrir quoi que ce soit). Ouvrir les packs ainsi achetés se fait à part,
# depuis la vue Collection (voir ShopCollectionPanel.gd), qui consomme ce
# même stock. `on_purchased` est rappelé après un achat réussi pour que
# l'appelant (MainMenu) rafraîchisse le solde/stock affichés ailleurs.

const BUY_QUANTITIES := [1, 5, 10]
const PACK_IMAGE_SIZE := Vector2(160, 240)
const PACK_BACK_TEXTURE := "res://assets/card_back/card-back.png"

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## image du dos de pack centrée, avec le solde au-dessus et les boutons
## d'achat (x1/x5/x10) centrés en dessous.
static func build_into(parent: Control, on_purchased: Callable = Callable()) -> void:
	for child in parent.get_children():
		child.queue_free()

	var center := CenterContainer.new()
	center.name = "BuyPacksCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(center)

	var col := VBoxContainer.new()
	col.name = "BuyPacksColumn"
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(col)

	var balance_label := Label.new()
	balance_label.name = "BuyPacksBalanceLabel"
	balance_label.add_theme_font_size_override("font_size", Typography.SECTION)
	balance_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balance_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	balance_label.text = SettingsManager.t("shop_buy.balance") % CurrencyManager.balance
	col.add_child(balance_label)

	var image := TextureRect.new()
	image.name = "BuyPacksImage"
	image.texture = load(PACK_BACK_TEXTURE)
	image.custom_minimum_size = PACK_IMAGE_SIZE
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(image)

	var status_label := Label.new()
	status_label.name = "BuyPacksStatusLabel"
	status_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	status_label.hide()
	col.add_child(status_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "BuyPacksButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons_row)

	for quantity in BUY_QUANTITIES:
		buttons_row.add_child(_make_buy_button(quantity, buttons_row, balance_label, status_label, on_purchased))

static func _make_buy_button(quantity: int, buttons_row: HBoxContainer, balance_label: Label, status_label: Label, on_purchased: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(140, 52)
	button.text = SettingsManager.t("shop_buy.buy_button") % [quantity, CurrencyManager.PACK_COST * quantity]
	button.pressed.connect(func():
		if not is_instance_valid(button):
			return
		status_label.hide()
		for child in buttons_row.get_children():
			(child as Button).disabled = true
		CurrencyManager.buy_packs(quantity, func(success: bool):
			if not is_instance_valid(buttons_row):
				return
			for child in buttons_row.get_children():
				(child as Button).disabled = false
			if success:
				if is_instance_valid(balance_label):
					balance_label.text = SettingsManager.t("shop_buy.balance") % CurrencyManager.balance
				if on_purchased.is_valid():
					on_purchased.call()
			elif is_instance_valid(status_label):
				status_label.text = SettingsManager.t("shop_buy.error")
				status_label.show()
		)
	)
	return button
