extends Control
class_name Navbar

# Barre persistante réutilisable (solde + accès boutique de packs), destinée
# aux scènes atteintes par change_scene_to_file qui n'ont donc pas accès à la
# barre déjà présente sur MainMenu.tscn (DeckBuilder, NetLobby) — voir
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
	pack_shop.visible = true
	pack_shop.refresh()

func _update_currency_label(new_balance: int) -> void:
	currency_label.text = SettingsManager.t("MENU_CURRENCY") % new_balance

func _retranslate() -> void:
	shop_button.text = SettingsManager.t("MENU_PACKS")
	_update_currency_label(CurrencyManager.balance)
