extends GutTest

const REAL_CARD_PATH := "res://resources/cards/undead/bloated-giant.tres"

func test_serialize_card_refs_preserves_null_slots() -> void:
	var card: CardData = load(REAL_CARD_PATH)
	var out: Array = ArenaPrivateStateSnapshot.serialize_card_refs([card, null, card])
	assert_eq(out, [REAL_CARD_PATH, "", REAL_CARD_PATH])

func test_deserialize_card_refs_turns_empty_string_back_into_null() -> void:
	var out: Array[CardData] = ArenaPrivateStateSnapshot.deserialize_card_refs([REAL_CARD_PATH, "", REAL_CARD_PATH])
	assert_eq(out.size(), 3)
	assert_not_null(out[0])
	assert_null(out[1], "une case de boutique déjà achetée (chaîne vide) doit redevenir null, pas une carte")
	assert_not_null(out[2])

func test_build_captures_gold_xp_level_freeze_hand_and_shop() -> void:
	var player := ArenaPlayerState.new("Joueur")
	player.gold = 7
	player.xp = 3
	player.level = 2
	player.shop_frozen = true
	var card: CardData = load(REAL_CARD_PATH)
	player.hand.append(Minion.new(card, true, "Front"))
	player.shop_offer = [card, null, null, null, null]
	var command: Dictionary = ArenaPrivateStateSnapshot.build(player)
	assert_eq(ArenaGameCommand.type_of(command), ArenaGameCommand.PRIVATE_STATE_SYNC)
	assert_eq(command["gold"], 7)
	assert_eq(command["xp"], 3)
	assert_eq(command["level"], 2)
	assert_eq(command["shop_frozen"], true)
	assert_eq(command["hand"].size(), 1)
	assert_eq(command["shop_offer"], [REAL_CARD_PATH, "", "", "", ""])

func test_mirror_apply_replaces_local_private_state() -> void:
	var player := ArenaPlayerState.new("Joueur")
	var card: CardData = load(REAL_CARD_PATH)
	var command: Dictionary = ArenaGameCommand.private_state_sync(
		0, 9, 4, 2, true,
		ArenaBoardSnapshot.serialize_row([Minion.new(card, true, "Front")]),
		[], [REAL_CARD_PATH, ""])
	ArenaPrivateStateMirror.apply(player, command)
	assert_eq(player.gold, 9)
	assert_eq(player.xp, 4)
	assert_eq(player.level, 2)
	assert_true(player.shop_frozen)
	assert_eq(player.hand.size(), 1)
	assert_eq(player.hand[0].card_data.resource_path, REAL_CARD_PATH)
	assert_eq(player.shop_offer.size(), 2)
	assert_not_null(player.shop_offer[0])
	assert_null(player.shop_offer[1])

func test_mirror_apply_round_trips_with_the_snapshot_builder() -> void:
	var sender := ArenaPlayerState.new("Expéditeur")
	sender.gold = 12
	sender.xp = 5
	sender.level = 3
	var card: CardData = load(REAL_CARD_PATH)
	sender.hand.append(Minion.new(card, true, "Front"))
	sender.shop_offer = [card, null, card, null, null]
	var command: Dictionary = ArenaPrivateStateSnapshot.build(sender)

	var receiver := ArenaPlayerState.new("Récepteur")
	ArenaPrivateStateMirror.apply(receiver, command)
	assert_eq(receiver.gold, sender.gold)
	assert_eq(receiver.xp, sender.xp)
	assert_eq(receiver.level, sender.level)
	assert_eq(receiver.hand.size(), sender.hand.size())
	assert_eq(receiver.shop_offer.size(), sender.shop_offer.size())
	assert_null(receiver.shop_offer[1])
	assert_null(receiver.shop_offer[3])
