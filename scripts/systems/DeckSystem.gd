extends Node
class_name DeckSystem

var battle

func init(_battle) -> void:
	battle = _battle

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

func start_game() -> void:
	battle.deck.shuffle()
	for i in range(5):
		battle.hand_cards.append(battle.deck.pop_back())
	battle.hand.set_hand(battle.hand_cards, false)
	update_deck_ui()

func draw_card() -> void:
	if battle.deck.is_empty():
		return
	battle.hand_cards.append(battle.deck.pop_back())
	var deck_pos: Vector2 = battle.deck_button.global_position + battle.deck_button.size / 2.0
	AudioManager.play(AudioManager.DRAW)
	battle.hand.set_hand(battle.hand_cards, true, deck_pos)
	update_deck_ui()

func update_deck_ui() -> void:
	battle.deck_button.visible = not battle.deck.is_empty()
	battle.deck_count_label.text = str(battle.deck.size())
	for child in battle.deck_button.get_children():
		if child.name != "CountLabel":
			child.queue_free()
	if battle.deck.is_empty():
		return
	var visible_count: int = clamp(
	int(float(battle.deck.size()) / 10.0 * battle.MAX_STACK_VISUAL) + 1,
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
		card_back.offset_top    = -i * 1.5
		card_back.offset_left   = -i * 1.5
		card_back.offset_right  = -i * 1.5
		card_back.offset_bottom = -i * 1.5
		card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		battle.deck_button.add_child(card_back)
	battle.deck_button.move_child(battle.deck_count_label, battle.deck_button.get_child_count() - 1)
