extends Control
class_name Navbar

# Barre persistante réutilisable (solde de monnaie), destinée aux scènes
# atteintes par change_scene_to_file qui n'ont donc pas accès à la barre déjà
# présente sur MainMenu.tscn (DeckBuilder — MatchmakingOverlay est un autoload
# et n'en a pas besoin).

@onready var currency_label: Label = $Bar/HBox/CurrencyLabel

func _ready() -> void:
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_currency_label(new_balance))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	# Cette instance de PackShop ne révèle jamais rien ici (voir _on_shop_pressed
	# ci-dessous) : son indice permanent Ctrl+clic/Maj+clic (CornerHintLabel,
	# jamais masqué par défaut dans PackShop.gd) n'a donc pas lieu d'être visible
	# hors de l'onglet Collection du menu principal, où la vraie instance vit.
	pack_shop.hide()

func _on_shop_pressed() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	# PackShop n'est plus un écran de boutique autonome (voir son
	# commentaire d'en-tête) : il ne révèle des cartes qu'à la demande,
	# ancré sur un pack précis passé par ShopCollectionPanel. Ce bouton,
	# hors de ce contexte (DeckBuilder), n'a donc plus rien à ouvrir ici.

func _update_currency_label(new_balance: int) -> void:
	currency_label.text = str(new_balance)
