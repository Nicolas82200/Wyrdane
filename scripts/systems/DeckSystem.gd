extends Node
class_name DeckSystem

var battle

func init(_battle) -> void:
	battle = _battle
	# Bouton deck adverse laissé purement cosmétique (main/deck adverses ne
	# sont que des compteurs, jamais consultables en détail).
	battle.deck_button.pressed.connect(_toggle_deck_view)

func _toggle_deck_view() -> void:
	if battle.graveyard_view.visible:
		battle.graveyard_view.close()
	else:
		battle.graveyard_view.open_deck(battle.deck)

func load_deck() -> void:
	var active := DeckManager.get_active_deck()
	if active:
		var cards := active.get_cards()
		battle.deck.clear()
		for card in cards:
			battle.deck.append(card)
	else:
		var card := load("res://resources/cards/undead/gaunt-servant.tres") as CardData
		battle.deck.clear()
		for i in range(20):
			battle.deck.append(card)
	_compute_deck_races()

# Figé une seule fois ici (composition du deck entier, pas seulement les
# cartes piochées) — voir Battle.deck_races.
func _compute_deck_races() -> void:
	battle.deck_races.clear()
	# Succès Steam "Petit budget" (voir AchievementManager) : calculé ici, avant
	# toute pioche, car battle.deck est ensuite consommé au fil de la partie.
	battle.deck_has_legendary = false
	for card in battle.deck:
		if card.rarity == "Legendary":
			battle.deck_has_legendary = true
		if card.race == Race.Type.NONE:
			continue
		var race_name := Race.get_race_name(card.race)
		if race_name not in battle.deck_races:
			battle.deck_races.append(race_name)

const STARTING_HAND := 7

# Mélange le deck local et pioche la main de départ (dans battle.hand_cards),
# sans encore l'afficher : le mulligan peut la modifier avant que Battle
# appelle hand.set_hand().
func deal_opening_hand() -> void:
	AudioManager.play(AudioManager.SHUFFLE)
	battle.deck.shuffle()
	for i in range(STARTING_HAND):
		battle.hand_cards.append(battle.deck.pop_back())
	update_deck_ui()

# Remplace UNE carte de la main (désignée par son index, pas sa CardData : deux
# exemplaires d'une même carte partagent la même ressource) pendant le
# mulligan : elle retourne dans le deck (mélangé), une nouvelle est piochée à
# sa place, au même index. Retourne la nouvelle carte, ou null si le deck est
# vide (rien à piocher, la carte reste en main) ou l'index invalide.
# En tutoriel, le deck de pioche (TutorialDeck.player_deck_padding) ne contient
# aucune carte-ressource : piocher au hasard dedans transformerait un échange
# de ressource en Zombie/Cadavre Errant surnuméraire et ferait manquer une des
# 3 ressources attendues par le script (voir TutorialManager.run()), le
# bloquant indéfiniment. On remplace donc toujours une ressource par une
# nouvelle ressource, sans piocher dans le deck.
func mulligan_replace_one(index: int) -> CardData:
	if index < 0 or index >= battle.hand_cards.size():
		return null
	var old_card: CardData = battle.hand_cards[index]
	if battle.tutorial_active and TutorialDeck.is_swappable_during_tutorial(old_card):
		battle.deck.append(old_card)
		battle.deck.shuffle()
		var new_resource: CardData = TutorialDeck.resource_card()
		battle.hand_cards[index] = new_resource
		update_deck_ui()
		return new_resource
	if battle.deck.is_empty():
		return null
	battle.deck.append(old_card)
	battle.deck.shuffle()
	var new_card: CardData = battle.deck.pop_back()
	battle.hand_cards[index] = new_card
	update_deck_ui()
	return new_card

func draw_card() -> void:
	if battle.deck.is_empty():
		return
	battle.hand_cards.append(battle.deck.pop_back())
	var deck_pos: Vector2 = battle.deck_button.global_position + battle.deck_button.size / 2.0
	AudioManager.play(AudioManager.DRAW)
	battle.hand.set_hand(battle.hand_cards, true, deck_pos)
	update_deck_ui()

func update_deck_ui() -> void:
	_update_pile_ui(battle.deck_button, battle.deck_count_label, battle.deck.size())

func update_enemy_deck_ui() -> void:
	_update_pile_ui(battle.enemy_deck_button, battle.enemy_deck_count_label, battle.opponent.get_deck_count())

func _update_pile_ui(button: Button, label: Label, count: int) -> void:
	button.visible = count > 0
	label.text = str(count)
	for child in button.get_children():
		if child != label:
			child.queue_free()
	if count == 0:
		return
	var visible_count: int = clamp(
	int(float(count) / 10.0 * battle.MAX_STACK_VISUAL) + 1,
	1, battle.MAX_STACK_VISUAL
	)
	for i in range(visible_count, 0, -1):
		var card_back := TextureRect.new()
		card_back.texture = battle.CARD_BACK
		card_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		card_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_back.anchors_preset = 15
		card_back.anchor_right = 1.0
		card_back.anchor_bottom = 1.0
		# (i-1) : la carte du dessus reste alignée sur le bouton, rien ne dépasse dessous
		card_back.offset_top    = -(i - 1) * 1.5
		card_back.offset_left   = -(i - 1) * 1.5
		card_back.offset_right  = -(i - 1) * 1.5
		card_back.offset_bottom = -(i - 1) * 1.5
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(card_back)
	button.move_child(label, button.get_child_count() - 1)
