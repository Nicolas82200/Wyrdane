extends RefCounted
class_name AuraSystem

var battle

func init(_battle) -> void:
	battle = _battle

func recompute_all() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		minion.aura_attack_bonus = 0
		minion.aura_health_bonus = 0
	_apply_formation()
	_apply_enchantment_auras()

func _apply_formation() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		if not minion.has_human_keyword(KeywordHuman.Type.FORMATION):
			continue
		var allies: Array[Minion] = battle.get_owner_minions(minion)
		var same_row: Array[Minion] = allies.filter(func(m: Minion): return m.board_row == minion.board_row)
		var idx: int = same_row.find(minion)
		if idx == -1:
			continue
		if idx > 0 or idx < same_row.size() - 1:
			minion.aura_attack_bonus += 1
			minion.aura_health_bonus += 1

func _apply_enchantment_auras() -> void:
	for is_player in [true, false]:
		for entry in battle.trigger_system.get_active_enchantments(is_player):
			var card_data: CardData = entry["card_data"]
			var has_aura: bool = card_data.trigger_types.any(func(t): return t.type == "OnAura")
			if has_aura:
				_apply_single_enchantment_aura(card_data, is_player)

func _apply_single_enchantment_aura(card_data: CardData, is_player: bool) -> void:
	for effect in card_data.effects:
		match effect.effect_id:
			"AuraBuffRow":
				_aura_buff_row(effect, is_player)
			"AuraBuffPerAllyInRow":
				_aura_buff_per_ally_row(effect, is_player)
			_:
				pass  # à étendre carte par carte

func _aura_buff_row(effect: CardEffect, is_player: bool) -> void:
	var targets: Array[Minion] = []
	match effect.target:
		"AllAlliesFront": targets = battle.get_front_minions(is_player)
		"AllAlliesBack":  targets = battle.get_back_minions(is_player)
	for t in targets:
		t.aura_attack_bonus += effect.value
		t.aura_health_bonus += effect.value_2

func _aura_buff_per_ally_row(effect: CardEffect, is_player: bool) -> void:
	var front_count: int = battle.get_front_minions(is_player).size()
	for t in battle.get_back_minions(is_player):
		t.aura_health_bonus += effect.value_2 * front_count
