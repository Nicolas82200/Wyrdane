extends Control
class_name Navbar

# Barre persistante réutilisable (solde + accès boutique de packs), destinée
# aux scènes atteintes par change_scene_to_file qui n'ont donc pas accès à la
# barre déjà présente sur MainMenu.tscn (DeckBuilder — MatchmakingOverlay est un autoload et n'en a pas besoin) — voir
# MainMenu._on_packs_button_pressed pour le pendant historique de ce pattern.

@onready var currency_label: Label = $Bar/HBox/CurrencyLabel
@onready var shop_button: Button = $Bar/HBox/ShopButton
@onready var pack_shop: Control = $ShopLayer/PackShop

func _ready() -> void:
	shop_button.pressed.connect(_on_shop_pressed)
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_currency_label(new_balance))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()

func _on_shop_pressed() -> void:
	AudioManager.play(AudioManager.OPEN_MENU)
	# PackShop n'est plus un écran de boutique autonome (voir son
	# commentaire d'en-tête) : il ne révèle des cartes qu'à la demande,
	# ancré sur un pack précis passé par ShopCollectionPanel. Ce bouton,
	# hors de ce contexte (DeckBuilder), n'a donc plus rien à ouvrir ici.

func _update_currency_label(new_balance: int) -> void:
	currency_label.text = str(new_balance)

func _retranslate() -> void:
	shop_button.text = SettingsManager.t("MENU_PACKS")
	_update_currency_label(CurrencyManager.balance)
