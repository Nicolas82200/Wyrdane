extends Control
class_name PackShop

# Écran d'ouverture de packs (première itération du système de progression :
# monnaie gagnée en jouant, dépensée ici contre des cartes aléatoires
# pondérées par rareté — voir POST /api/packs/open côté wyrdane-backend).

@export var card_scene: PackedScene

@onready var balance_label: Label = $Panel/VBox/BalanceLabel
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var open_button: Button = $Panel/VBox/OpenButtonMargin/OpenButton
@onready var free_button: Button = $Panel/VBox/FreeButtonMargin/FreeButton
@onready var close_button: Button = $Panel/VBox/CloseButtonMargin/CloseButton
@onready var cards_grid: HBoxContainer = $Panel/VBox/CardsScroll/CardsGrid
@onready var title_label: Label = $Panel/VBox/TitleMargin/Title

func _ready() -> void:
	hide()
	status_label.hide()
	open_button.pressed.connect(_on_open_pressed)
	# Bouton d'ouverture gratuite : outil de test, réservé aux builds debug
	# (l'export release ne l'affiche pas) et refusé côté serveur (403) tant
	# que DEV_FREE_PACKS n'est pas activé sur le backend.
	free_button.get_parent().visible = OS.is_debug_build()
	free_button.pressed.connect(func(): _open_pack(true))
	close_button.pressed.connect(func(): AudioManager.play(AudioManager.CLOSE_MENU); hide())
	CurrencyManager.balance_changed.connect(func(new_balance: int): _update_balance_label(new_balance))
	SettingsManager.language_changed.connect(func(_l): _retranslate())
	_retranslate()
	_update_balance_label(CurrencyManager.balance)

func refresh() -> void:
	CurrencyManager.sync_from_backend()
	_clear_cards()
	status_label.hide()

func _on_open_pressed() -> void:
	_open_pack(false)

func _open_pack(free: bool) -> void:
	open_button.disabled = true
	free_button.disabled = true
	status_label.hide()
	CurrencyManager.open_pack(func(code: int, cards: Array): _on_pack_opened(code, cards), free)

func _on_pack_opened(code: int, cards: Array) -> void:
	open_button.disabled = false
	free_button.disabled = false
	_clear_cards()

	if code != 200 or cards.is_empty():
		status_label.text = SettingsManager.t("pack_shop.error")
		status_label.show()
		return

	# Les cartes tirées viennent d'être octroyées côté serveur (grantCard) :
	# resynchronise la collection pour qu'elles soient utilisables tout de
	# suite dans le deckbuilder sans attendre le prochain redémarrage.
	CollectionManager.sync_from_backend()

	for card_row in cards:
		var card_data: CardData = CardLibrary.card_by_backend_id.get(card_row.get("id"), null)
		if card_data == null:
			continue
		var card_instance := card_scene.instantiate()
		cards_grid.add_child(card_instance)
		card_instance.set_data(card_data)
		card_instance.set_non_interactive()

func _clear_cards() -> void:
	for child in cards_grid.get_children():
		child.queue_free()

func _update_balance_label(new_balance: int) -> void:
	balance_label.text = SettingsManager.t("pack_shop.balance") % new_balance

func _retranslate() -> void:
	title_label.text = SettingsManager.t("pack_shop.title")
	open_button.text = SettingsManager.t("pack_shop.open_button") % CurrencyManager.PACK_COST
	free_button.text = SettingsManager.t("pack_shop.open_free_button")
	close_button.text = SettingsManager.t("pack_shop.close")
	status_label.text = SettingsManager.t("pack_shop.error")
	_update_balance_label(CurrencyManager.balance)
