# HandDiscardSystem.gd
extends RefCounted
class_name HandDiscardSystem

## Limite de 10 cartes en main en fin de tour (joueur local uniquement — voir
## README « Limite de main »). Si le joueur a plus de 10 cartes quand il
## termine son tour, il doit en défausser l'excédent : la main passe en mode
## sélection (voir Hand.set_discard_mode), un décompte de DISCARD_TIMER_DURATION
## secondes démarre, et dès que le nombre requis de cartes est sélectionné (ou
## que le temps expire — sélection aléatoire du reste), les cartes choisies
## partent au cimetière face cachée (Graveyard.Origin.CARD_DISCARDED) et le
## tour peut réellement se terminer. Appelé depuis TurnSystem.end_turn() avant
## toute autre résolution de fin de tour.

const MAX_HAND_SIZE := 10
const DISCARD_TIMER_DURATION := 15.0

var battle

var _required: int = 0
var _selected_indices: Array[int] = []
var _resolved: bool = false
var _timer: TurnTimer = null

func init(_battle) -> void:
	battle = _battle

# Ne fait rien (retourne immédiatement) si la main est déjà à 10 ou moins.
func run_if_needed() -> void:
	var excess: int = battle.hand_cards.size() - MAX_HAND_SIZE
	if excess <= 0:
		return
	_required = excess
	_selected_indices.clear()
	_resolved = false

	# Le décompte normal de fin de tour n'a plus lieu d'être pendant cette
	# sous-phase bloquante — resynchronisé sur le tour suivant par
	# TurnSystem._begin_player_turn comme d'habitude.
	battle.turn_timer.stop()

	battle.hand.set_discard_mode(true)
	if not battle.hand.discard_card_clicked.is_connected(_on_card_clicked):
		battle.hand.discard_card_clicked.connect(_on_card_clicked)
	battle.turn_banner.show_banner_persistent(
		SettingsManager.t("discard.banner") % _required, SettingsManager.t("discard.hint"))

	_timer = TurnTimer.new()
	battle.add_child(_timer)
	_timer.timeout.connect(_on_timeout)
	_timer.start(DISCARD_TIMER_DURATION)

	while not _resolved:
		await battle.get_tree().process_frame

	if battle.hand.discard_card_clicked.is_connected(_on_card_clicked):
		battle.hand.discard_card_clicked.disconnect(_on_card_clicked)
	battle.hand.set_discard_mode(false)
	battle.turn_banner.hide_banner()
	if is_instance_valid(_timer):
		_timer.stop()
		_timer.queue_free()
	_timer = null

func _on_card_clicked(index: int, _card_data: CardData) -> void:
	if _resolved:
		return
	var pos: int = _selected_indices.find(index)
	if pos != -1:
		_selected_indices.remove_at(pos)
		battle.hand.set_card_discard_selected(index, false)
		return
	_selected_indices.append(index)
	battle.hand.set_card_discard_selected(index, true)
	if _selected_indices.size() >= _required:
		_confirm()

func _on_timeout() -> void:
	if _resolved:
		return
	# Complète aléatoirement la sélection avec les cartes pas encore choisies.
	var remaining_indices: Array[int] = []
	for i in range(battle.hand_cards.size()):
		if not _selected_indices.has(i):
			remaining_indices.append(i)
	remaining_indices.shuffle()
	while _selected_indices.size() < _required and not remaining_indices.is_empty():
		_selected_indices.append(remaining_indices.pop_back())
	_confirm()

func _confirm() -> void:
	if _resolved:
		return
	_resolved = true
	# Tri décroissant : retirer par index sans décaler les indices restants.
	_selected_indices.sort()
	_selected_indices.reverse()
	var discarded_count: int = 0
	for index in _selected_indices:
		if index < 0 or index >= battle.hand_cards.size():
			continue
		var card_data: CardData = battle.hand_cards[index]
		battle.hand_cards.remove_at(index)
		battle.player_graveyard.add_discarded(card_data)
		discarded_count += 1
	battle.hand.set_hand(battle.hand_cards)
	# Contenu privé (comme le mulligan) : seul le nombre de cartes défaussées
	# est communiqué, pour garder le compteur cosmétique de main adverse à jour.
	if battle.net_emitter != null and discarded_count > 0:
		battle.net_emitter.discard(discarded_count)
