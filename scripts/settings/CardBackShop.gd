extends RefCounted
class_name CardBackShop

# Catalogue de dos de carte cosmétiques vendus en argent réel (voir l'onglet
# "Dos de cartes" de la Boutique, MainMenu.gd/ShopCardBacksPanel.gd) — remplace
# l'ancien système de déblocage par niveau de compte (retiré du jeu, voir
# git log 4e6bc72f). Purement cosmétique, aucun impact gameplay.
#
# Aucun paiement réel n'est câblé (nécessiterait Steamworks Micro-Transactions
# + une route backend de vérification de commande, voir SupporterPackPanel.gd
# pour le même constat) : seul le dos par défaut (prix 0) est "possédé", les
# autres n'existent ici que pour peupler/tester l'écran de vente — le bouton
# d'achat reste désactivé (volontairement PAS simulé, aucun octroi de dos sans
# paiement réel).
#
# `price_cents` est un prix d'affichage indicatif, pas encore relié à un vrai
# produit Steamworks (aucun `def_id` créé côté dashboard partenaire).
const CARD_BACKS := [
	{"key": "SHOP_CARD_BACK_DEFAULT", "tint": Color(1.0, 1.0, 1.0, 1.0), "price_cents": 0},
	{"key": "SHOP_CARD_BACK_GOLD",    "tint": Color(1.25, 1.05, 0.55, 1.0), "price_cents": 199},
	{"key": "SHOP_CARD_BACK_CRIMSON", "tint": Color(1.35, 0.55, 0.55, 1.0), "price_cents": 299},
	{"key": "SHOP_CARD_BACK_EMERALD", "tint": Color(0.55, 1.35, 0.75, 1.0), "price_cents": 399},
	{"key": "SHOP_CARD_BACK_VIOLET",  "tint": Color(0.85, 0.6, 1.4, 1.0), "price_cents": 499},
]

static func is_owned(index: int) -> bool:
	if index < 0 or index >= CARD_BACKS.size():
		return false
	return int(CARD_BACKS[index]["price_cents"]) == 0

static func price_label(index: int) -> String:
	var cents: int = int(CARD_BACKS[index]["price_cents"])
	return "%d,%02d €" % [cents / 100, cents % 100]

# Teinte à appliquer à la texture de dos de carte pour le choix courant du
# joueur — Color.WHITE (aucune teinte) si le choix sauvegardé n'est pas/plus
# possédé (aucun achat réel possible aujourd'hui, mais reste défensif en vue
# d'un vrai système de possession plus tard).
static func card_back_tint() -> Color:
	var index: int = SettingsManager.selected_card_back
	if not is_owned(index):
		return Color.WHITE
	return CARD_BACKS[index]["tint"]

static func select_card_back(index: int) -> void:
	if not is_owned(index):
		return
	SettingsManager.set_selected_card_back(index)
