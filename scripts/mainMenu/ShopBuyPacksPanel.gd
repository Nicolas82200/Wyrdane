extends RefCounted
class_name ShopBuyPacksPanel

# Onglet "Packs" de la Boutique (voir MainMenu.gd, _select_shop_tab) : achat
# de packs UNIQUEMENT, contre de l'or — aucune carte n'est jamais tirée ici
# (CurrencyManager.buy_packs crédite le stock CurrencyManager.free_packs sans
# ouvrir quoi que ce soit). Ouvrir les packs ainsi achetés se fait à part,
# depuis l'onglet Collection (voir ShopCollectionPanel.gd), qui consomme ce
# même stock. `on_purchased` est rappelé après un achat réussi pour que
# l'appelant (MainMenu) rafraîchisse le solde/stock affichés ailleurs.

const BUY_QUANTITIES := [1, 5, 10]

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit).
static func build_into(parent: Control, on_purchased: Callable = Callable()) -> void:
	for child in parent.get_children():
		child.queue_free()

	var balance_label := Label.new()
	balance_label.name = "BuyPacksBalanceLabel"
	balance_label.add_theme_font_size_override("font_size", 18)
	balance_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	balance_label.text = SettingsManager.t("shop_buy.balance") % CurrencyManager.balance
	parent.add_child(balance_label)

	var status_label := Label.new()
	status_label.name = "BuyPacksStatusLabel"
	status_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	status_label.hide()
	parent.add_child(status_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "BuyPacksButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	parent.add_child(buttons_row)

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
