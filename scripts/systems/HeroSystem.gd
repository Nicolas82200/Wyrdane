extends Node
class_name HeroSystem

var battle

func init(_battle) -> void:
	battle = _battle

func get_owner_hero(minion: Minion) -> Hero:
	if minion == null:
		return battle.player_hero
	return battle.player_hero if minion.owner_is_player else battle.enemy_hero

func get_enemy_hero(minion: Minion) -> Hero:
	if minion == null:
		return battle.enemy_hero
	return battle.enemy_hero if minion.owner_is_player else battle.player_hero

func damage(hero: Hero, amount: int) -> void:
	hero.take_damage(amount)
	update_ui()
	battle.check_game_end()

func update_ui() -> void:
	battle.get_node("PlayerHeroPanel/HealthLabel").text = str(maxi(battle.player_hero.health, 0))
	battle.get_node("EnemyHeroPanel/HealthLabel").text  = str(maxi(battle.enemy_hero.health, 0))
