extends RefCounted
class_name ShopBuyPacksPanel

# Onglet "Packs" de la Boutique (voir MainMenu.gd, _select_shop_tab) : achat
# de packs UNIQUEMENT, contre de l'or — aucune carte n'est jamais tirée ici
# (CurrencyManager.buy_packs crédite le stock CurrencyManager.free_packs sans
# ouvrir quoi que ce soit). Ouvrir les packs ainsi achetés se fait à part,
# depuis la vue Collection (voir ShopCollectionPanel.gd), qui consomme ce
# même stock. `on_purchased` est rappelé après un achat réussi pour que
# l'appelant (MainMenu) rafraîchisse le solde/stock affichés ailleurs.
#
# Un pack par race implémentée, plus le pack multirace (voir
# CurrencyManager.PACK_RACES), présentés dans un carrousel cliquable
# (PackCarousel.gd) : le pack acheté est celui au centre.

const BUY_QUANTITIES := [1, 5, 10]

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## titre du pack sélectionné, carrousel des packs (qui prend toute la place
## restante) et boutons de quantité, dont l'infobulle donne le prix.
static func build_into(parent: Control, on_purchased: Callable = Callable()) -> void:
	for child in parent.get_children():
		child.queue_free()

	var col := VBoxContainer.new()
	col.name = "BuyPacksColumn"
	col.add_theme_constant_override("separation", 16)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(col)

	var title := Label.new()
	title.name = "BuyPacksTitleLabel"
	title.add_theme_font_size_override("font_size", Typography.HEADER)
	title.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var carousel := PackCarousel.new()
	carousel.name = "BuyPacksCarousel"
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(carousel)
	# Après add_child : setup() lit `size`, qui n'a sa valeur de conteneur
	# qu'une fois le nœud dans l'arbre.
	carousel.setup(CurrencyManager.PACK_RACES, CurrencyManager.PACK_RACES.find(CurrencyManager.MULTIRACE_PACK))
	title.text = PackCarousel.title_for(carousel.selected_race())
	carousel.selection_changed.connect(func(race: String):
		if is_instance_valid(title):
			title.text = PackCarousel.title_for(race)
	)

	var status_label := Label.new()
	status_label.name = "BuyPacksStatusLabel"
	status_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.2, 1))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.hide()
	col.add_child(status_label)

	col.add_child(_make_buttons_row(carousel, status_label, on_purchased))

## Boutons de quantité, centrés sous le carrousel. Le prix n'est plus affiché
## en permanence : il vit dans l'infobulle de chaque bouton.
static func _make_buttons_row(carousel: PackCarousel, status_label: Label, on_purchased: Callable) -> Control:
	var buttons_row := HBoxContainer.new()
	buttons_row.name = "BuyPacksButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for quantity in BUY_QUANTITIES:
		buttons_row.add_child(_make_buy_button(quantity, buttons_row, carousel, status_label, on_purchased))
	return buttons_row

static func _make_buy_button(quantity: int, buttons_row: HBoxContainer,
		carousel: PackCarousel, status_label: Label, on_purchased: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(90, 52)
	button.text = str(quantity)
	button.tooltip_text = SettingsManager.t("shop_buy.price_tooltip") % (CurrencyManager.PACK_COST * quantity)
	button.pressed.connect(func():
		if not is_instance_valid(button) or not is_instance_valid(carousel):
			return
		status_label.hide()
		for child in buttons_row.get_children():
			(child as Button).disabled = true
		CurrencyManager.buy_packs(quantity, carousel.selected_race(), func(success: bool):
			if not is_instance_valid(buttons_row):
				return
			for child in buttons_row.get_children():
				(child as Button).disabled = false
			if success:
				if on_purchased.is_valid():
					on_purchased.call()
			elif is_instance_valid(status_label):
				status_label.text = SettingsManager.t("shop_buy.error")
				status_label.show()
		)
	)
	return button
