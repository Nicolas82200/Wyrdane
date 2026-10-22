extends RefCounted
class_name ShopPreviewPanel

# Encart "Nouveautés" de la page d'accueil (NewsView, voir MainMenu.tscn
# NewsHomeRow/ShopPreviewColumn) : pagine le catalogue de dos de carte
# cosmétiques (CardBackShop.CARD_BACKS), à l'exclusion du dos par défaut
# (gratuit, prix 0 — pas une "nouveauté"). Réutilise entièrement les données
# déjà affichées dans l'onglet "Dos de cartes" de la Boutique, aucun nouveau
# système de "nouveauté" côté jeu/backend.

const CARD_BACK_TEXTURE := "res://assets/card_back/card-back.png"

static var _index: int = 0

static func render(menu) -> void:
	var items := _previewable_items()
	if items.is_empty():
		menu.shop_preview_swatch.texture = null
		menu.shop_preview_name_label.text = "-"
		menu.shop_preview_price_label.text = "-"
		menu.shop_preview_prev_button.disabled = true
		menu.shop_preview_next_button.disabled = true
		return
	_index = clampi(_index, 0, items.size() - 1)
	var cb: Dictionary = CardBackShop.CARD_BACKS[items[_index]]
	menu.shop_preview_swatch.texture = load(CARD_BACK_TEXTURE)
	menu.shop_preview_swatch.modulate = cb["tint"]
	menu.shop_preview_name_label.text = SettingsManager.t(cb["key"])
	menu.shop_preview_price_label.text = CardBackShop.price_label(items[_index])
	menu.shop_preview_prev_button.disabled = items.size() <= 1
	menu.shop_preview_next_button.disabled = items.size() <= 1

static func show_prev(menu) -> void:
	var items := _previewable_items()
	if items.is_empty():
		return
	_index = (_index - 1 + items.size()) % items.size()
	render(menu)

static func show_next(menu) -> void:
	var items := _previewable_items()
	if items.is_empty():
		return
	_index = (_index + 1) % items.size()
	render(menu)

static func _previewable_items() -> Array:
	var items: Array = []
	for i in CardBackShop.CARD_BACKS.size():
		if int(CardBackShop.CARD_BACKS[i].get("price_cents", 0)) > 0:
			items.append(i)
	return items
