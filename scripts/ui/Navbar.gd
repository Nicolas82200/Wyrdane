extends Control
class_name Navbar

# Barre persistante réutilisable (solde de monnaie), destinée aux scènes
# atteintes par change_scene_to_file qui n'ont donc pas accès à la barre déjà
# présente sur MainMenu.tscn (DeckBuilder — MatchmakingOverlay est un autoload
# et n'en a pas besoin).

@onready var currency_label: Label = $Bar/HBox/CurrencyLabel

func _ready() -> void:
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_currency_label(new_balance))
	_update_currency_label(CurrencyManager.balance)

func _update_currency_label(new_balance: int) -> void:
	currency_label.text = str(new_balance)
