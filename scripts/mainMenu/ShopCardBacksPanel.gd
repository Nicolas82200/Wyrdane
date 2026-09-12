extends RefCounted
class_name ShopCardBacksPanel

# Grille de dos de carte de l'onglet "Dos de cartes" de la Boutique (voir
# MainMenu.gd, _select_shop_tab) — vendus en argent réel (CardBackShop),
# contrairement à l'ancien système par niveau de compte retiré du jeu. Le
# bouton d'achat reste désactivé : un vrai achat nécessite l'intégration des
# microtransactions Steamworks (produit à créer côté dashboard partenaire) et
# une route backend de vérification de commande, ni l'un ni l'autre
# disponibles aujourd'hui — volontairement PAS simulé (même logique que
# SupporterPackPanel : aucun octroi de cosmétique sans paiement réel).

const SWATCH_SIZE := Vector2(56, 84)

## Construit la grille dans `parent` (vidée d'abord), avec `on_selection_changed`
## rappelé après chaque sélection pour que l'appelant se reconstruise (état
## "sélectionné" à jour) sans dépendre de son conteneur d'origine.
static func build_into(parent: Control, on_selection_changed: Callable) -> void:
	for child in parent.get_children():
		if child.name == "ShopCardBacksRow":
			child.queue_free()

	var row := HBoxContainer.new()
	row.name = "ShopCardBacksRow"
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var card_back_tex: Texture2D = load("res://assets/card_back/card-back.png")
	for i in CardBackShop.CARD_BACKS.size():
		row.add_child(_make_swatch(i, card_back_tex, on_selection_changed))

static func _make_swatch(index: int, card_back_tex: Texture2D, on_selection_changed: Callable) -> VBoxContainer:
	var cb: Dictionary = CardBackShop.CARD_BACKS[index]
	var owned: bool = CardBackShop.is_owned(index)
	var is_selected: bool = SettingsManager.selected_card_back == index

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var swatch := TextureRect.new()
	swatch.texture = card_back_tex
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	swatch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	swatch.modulate = cb["tint"] if owned else Color(0.3, 0.3, 0.3, 0.6)
	col.add_child(swatch)

	var name_label := Label.new()
	name_label.text = SettingsManager.t(cb["key"])
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(SWATCH_SIZE.x, 0)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.87, 0.78, 1))
	col.add_child(name_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(SWATCH_SIZE.x, 30)
	if not owned:
		action_button.text = CardBackShop.price_label(index)
		action_button.disabled = true
		action_button.tooltip_text = SettingsManager.t("SHOP_CARD_BACK_BUY_UNAVAILABLE")
	elif is_selected:
		action_button.text = SettingsManager.t("SHOP_CARD_BACK_SELECTED")
		action_button.disabled = true
	else:
		action_button.text = SettingsManager.t("SHOP_CARD_BACK_SELECT")
		action_button.pressed.connect(func():
			CardBackShop.select_card_back(index)
			on_selection_changed.call()
		)
	col.add_child(action_button)

	return col
