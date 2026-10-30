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
const GOLD_ICON := "res://assets/icons/crown-coin.svg"

## Construit le panneau dans `parent` (VBoxContainer, vidé puis reconstruit) :
## titre du pack sélectionné, carrousel des packs, boutons de quantité et
## prix total en bas à droite.
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

	col.add_child(_make_bottom_row(carousel, status_label, on_purchased))

## Boutons de quantité centrés, prix total aligné à droite : les deux
## extrémités (espaceur à gauche, prix à droite) ont le même facteur
## d'expansion pour que les boutons restent centrés sur le panneau.
static func _make_bottom_row(carousel: PackCarousel, status_label: Label, on_purchased: Callable) -> Control:
	var row := HBoxContainer.new()
	row.name = "BuyPacksBottomRow"
	row.add_theme_constant_override("separation", 10)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var buttons_row := HBoxContainer.new()
	buttons_row.name = "BuyPacksButtonsRow"
	buttons_row.add_theme_constant_override("separation", 10)
	row.add_child(buttons_row)

	var price_row := HBoxContainer.new()
	price_row.name = "BuyPacksPriceRow"
	price_row.add_theme_constant_override("separation", 6)
	price_row.alignment = BoxContainer.ALIGNMENT_END
	price_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(price_row)

	var price_label := Label.new()
	price_label.name = "BuyPacksPriceLabel"
	price_label.add_theme_font_size_override("font_size", Typography.SECTION)
	price_label.add_theme_color_override("font_color", Color(0.91, 0.835, 0.639, 1))
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.text = str(CurrencyManager.PACK_COST)
	price_row.add_child(price_label)

	var gold_icon := TextureRect.new()
	gold_icon.name = "BuyPacksGoldIcon"
	gold_icon.texture = load(GOLD_ICON)
	gold_icon.custom_minimum_size = Vector2(24, 24)
	gold_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gold_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gold_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	price_row.add_child(gold_icon)

	for quantity in BUY_QUANTITIES:
		buttons_row.add_child(_make_buy_button(quantity, buttons_row, price_label, carousel, status_label, on_purchased))
	return row

static func _make_buy_button(quantity: int, buttons_row: HBoxContainer, price_label: Label,
		carousel: PackCarousel, status_label: Label, on_purchased: Callable) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(90, 52)
	button.text = str(quantity)
	# Le prix affiché en bas à droite suit le bouton survolé (il n'y a pas de
	# quantité "sélectionnée" : un clic achète directement).
	button.mouse_entered.connect(func():
		if is_instance_valid(price_label):
			price_label.text = str(CurrencyManager.PACK_COST * quantity)
	)
	button.mouse_exited.connect(func():
		if is_instance_valid(price_label):
			price_label.text = str(CurrencyManager.PACK_COST)
	)
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
