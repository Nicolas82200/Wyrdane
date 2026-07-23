extends GutTest

func _make_minion_card(name: String, cost: int, path: String, atk: int = 2, hp: int = 2) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Common"
	data.card_type = "Minion"
	data.resource_path = path
	data.attack = atk
	data.health = hp
	return data

func _make_buff_spell(name: String, cost: int, path: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Rare"
	data.card_type = "Instant"
	data.resource_path = path
	data.arena_only = true
	var effect := CardEffect.new()
	effect.effect_id = "Buff"
	effect.target = "AllAllies"
	effect.duration = "Permanent"
	effect.value = 1
	effect.value_2 = 1
	data.effects = [effect]
	return data

func _make_keyword_spell(name: String, cost: int, path: String, keyword: String) -> CardData:
	var data := CardData.new()
	data.card_name = name
	data.cost = cost
	data.rarity = "Rare"
	data.card_type = "Instant"
	data.resource_path = path
	data.arena_only = true
	var effect := CardEffect.new()
	effect.effect_id = "GrantKeyword"
	effect.target = "AllAllies"
	effect.duration = "Permanent"
	effect.granted_keyword = keyword
	data.effects = [effect]
	return data

func test_arena_card_pool_includes_arena_only_instants_but_not_plain_ones() -> void:
	var arena_spell := _make_buff_spell("ArenaSpell", 2, "res://fake/spell_pool_arena.tres")
	var normal_spell := CardData.new()
	normal_spell.card_name = "NormalSpell"
	normal_spell.cost = 2
	normal_spell.rarity = "Common"
	normal_spell.card_type = "Instant"
	normal_spell.resource_path = "res://fake/spell_pool_normal.tres"
	var pool := ArenaCardPool.new([arena_spell, normal_spell])
	assert_true(pool.remaining_copies.has(arena_spell.resource_path))
	assert_false(pool.remaining_copies.has(normal_spell.resource_path), "un sort 1v1 normal (arena_only=false) ne doit jamais entrer dans le pool Arena")

func test_buying_a_spell_goes_to_spell_hand_not_minion_hand() -> void:
	var spell := _make_buff_spell("Buff Spell", 2, "res://fake/spell_buy.tres")
	var pool := ArenaCardPool.new([spell])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("P")]
	var m := ArenaMatch.new(players, pool)
	var player := players[0]
	player.gold = 2
	player.shop_offer = [spell, null, null, null, null]
	assert_true(m.buy_card(player, 0))
	assert_eq(player.spell_hand.size(), 1)
	assert_eq(player.hand.size(), 0, "un sort acheté ne doit pas créer de Minion")

func test_cast_buff_spell_applies_to_whole_board_and_is_permanent() -> void:
	var minion_card := _make_minion_card("Grunt", 1, "res://fake/spell_cast_grunt.tres")
	var spell := _make_buff_spell("Buff Spell", 2, "res://fake/spell_cast_buff.tres")
	var pool := ArenaCardPool.new([minion_card, spell])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("P")]
	var m := ArenaMatch.new(players, pool)
	var player := players[0]
	var a := Minion.new(minion_card, true, "Front")
	var b := Minion.new(minion_card, true, "Back")
	player.board_front.append(a)
	player.board_back.append(b)
	player.spell_hand.append(spell)
	assert_true(await m.cast_spell(player, spell))
	assert_eq(a.base_attack, 3)
	assert_eq(a.base_max_health, 3)
	assert_eq(b.base_attack, 3)
	assert_eq(b.base_max_health, 3)
	assert_true(player.spell_hand.is_empty(), "le sort est consommé après avoir été lancé")
	# Reset entre rounds n'efface jamais les stats permanentes.
	player.reset_after_combat()
	assert_eq(a.base_attack, 3)

func test_cast_keyword_spell_grants_keyword_to_allies() -> void:
	var minion_card := _make_minion_card("Grunt", 1, "res://fake/spell_cast_kw_grunt.tres")
	var spell := _make_keyword_spell("Keyword Spell", 2, "res://fake/spell_cast_kw.tres", "AEGIS")
	var pool := ArenaCardPool.new([minion_card, spell])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("P")]
	var m := ArenaMatch.new(players, pool)
	var player := players[0]
	var a := Minion.new(minion_card, true, "Front")
	player.board_front.append(a)
	player.spell_hand.append(spell)
	assert_true(await m.cast_spell(player, spell))
	assert_true(a.has_keyword(Keyword.Type.AEGIS))

func test_cannot_cast_a_spell_not_in_hand() -> void:
	var spell := _make_buff_spell("Ghost Spell", 2, "res://fake/spell_not_owned.tres")
	var pool := ArenaCardPool.new([spell])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("P")]
	var m := ArenaMatch.new(players, pool)
	assert_false(await m.cast_spell(players[0], spell))

func test_sell_spell_refunds_full_price_and_releases_to_pool() -> void:
	var spell := _make_buff_spell("Buff Spell", 3, "res://fake/spell_sell.tres")
	var pool := ArenaCardPool.new([spell])
	var players: Array[ArenaPlayerState] = [ArenaPlayerState.new("P")]
	var m := ArenaMatch.new(players, pool)
	var player := players[0]
	player.gold = 0
	pool.take(spell)
	player.spell_hand.append(spell)
	var copies_before: int = pool.copies_remaining(spell)
	assert_true(m.sell_spell(player, spell))
	assert_eq(player.gold, 3)
	assert_eq(pool.copies_remaining(spell), copies_before + 1)
	assert_true(player.spell_hand.is_empty())

func test_hand_full_counts_spells_and_minions_together() -> void:
	var minion_card := _make_minion_card("Filler", 1, "res://fake/spell_hand_full_filler.tres")
	var player := ArenaPlayerState.new("P")
	for i in ArenaConstants.HAND_MAX:
		player.hand.append(Minion.new(minion_card))
	assert_true(player.is_hand_full())
	player.hand.pop_back()
	player.spell_hand.append(_make_buff_spell("S", 1, "res://fake/spell_hand_full_s.tres"))
	assert_true(player.is_hand_full(), "une Incantation en main compte aussi pour le plafond de 10")
