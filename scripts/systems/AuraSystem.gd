extends RefCounted
class_name AuraSystem

var battle

func init(_battle) -> void:
	battle = _battle

func recompute_all() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		minion.aura_attack_bonus = 0
		minion.aura_health_bonus = 0
		minion.aura_damage_reduction = 0
		minion.infection_immune_aura = false
	battle.hero_system.self_damage_reduction[true] = 0
	battle.hero_system.self_damage_reduction[false] = 0
	_apply_formation()
	_apply_horde()
	_apply_infernal_rank()
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

func _apply_horde() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		if not minion.has_undead_keyword(KeywordUndead.Type.HORDE):
			continue
		var allies: Array[Minion] = battle.get_owner_minions(minion)
		var undead_count: int = allies.filter(func(m: Minion): return m.card_data.race == Race.Type.UNDEAD).size()
		if undead_count >= 3:
			minion.aura_attack_bonus += 1

# RANG INFERNAL : +1 ATK par tranche de 10 HP manquants sur le héros du
# propriétaire. Calculé en aura pour suivre les HP du héros à la hausse comme à
# la baisse (soins compris).
func _apply_infernal_rank() -> void:
	for minion in battle.player_minions + battle.enemy_minions:
		if not minion.has_demon_keyword(KeywordDemon.Type.RANG_INFERNAL):
			continue
		var hero: Hero = battle.player_hero if minion.owner_is_player else battle.enemy_hero
		var missing: int = max(0, hero.max_health - hero.health)
		minion.aura_attack_bonus += missing / 10

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
			"AuraDamageReduction":
				_aura_damage_reduction(effect, is_player)
			"AuraInfectionImmunity":
				_aura_infection_immunity(effect, is_player)
			"AuraSelfDamageReduction":
				_aura_self_damage_reduction(effect, is_player)
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
	# race_filter optionnel : ne compte que les alliés Avant de cette race
	# (Symbiose Infernale : +0/+1 par Démon allié en rangée Avant).
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	var front: Array[Minion] = battle.get_front_minions(is_player)
	if race != -1:
		front = front.filter(func(m: Minion): return m.card_data.race == race)
	var front_count: int = front.size()
	for t in battle.get_back_minions(is_player):
		t.aura_health_bonus += effect.value_2 * front_count

# Réduction de dégâts d'aura (Pacte de Résistance). Filtre optionnel par race
# via race_filter ("Human" = seulement les serviteurs Humains alliés).
func _aura_damage_reduction(effect: CardEffect, is_player: bool) -> void:
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	for t in (battle.player_minions if is_player else battle.enemy_minions):
		if race == -1 or t.card_data.race == race:
			t.aura_damage_reduction += effect.value

# Immunité à l'Infection d'aura (Aegis de l'Empire). Filtres optionnels par race
# (race_filter) et par rangée (row_filter). Retire aussi tout marqueur présent :
# un serviteur immunisé ne reste pas infecté.
func _aura_infection_immunity(effect: CardEffect, is_player: bool) -> void:
	var race: int = Race.from_string(effect.race_filter) if not effect.race_filter.is_empty() else -1
	for t in (battle.player_minions if is_player else battle.enemy_minions):
		if race != -1 and t.card_data.race != race:
			continue
		if not effect.row_filter.is_empty() and t.board_row != effect.row_filter:
			continue
		t.infection_immune_aura = true
		t.infected = false

# Réduction des dégâts auto-infligés au héros, par occurrence (Sceau de
# Préservation). Consommée par HeroSystem.self_damage.
func _aura_self_damage_reduction(effect: CardEffect, is_player: bool) -> void:
	battle.hero_system.self_damage_reduction[is_player] += max(0, effect.value)
