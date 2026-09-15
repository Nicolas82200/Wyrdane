extends ArenaSeatController
class_name ArenaBotSeatController

# Enveloppe ArenaBotDriver (IA minimale existante, sans état propre à part son
# rng — voir ArenaBotDriver.gd) derrière l'interface ArenaSeatController.
# Voir ArenaSeatController pour le rôle de cette abstraction.

var driver: ArenaBotDriver

func _init(p: ArenaPlayerState, _driver: ArenaBotDriver) -> void:
	super._init(p)
	driver = _driver

func take_shop_turn(match_: ArenaMatch) -> void:
	driver.play_shop_phase(player, match_)
	driver.play_positioning_phase(player)
	# Après la pose, pas avant : les Incantations "tout le plateau" doivent
	# viser la composition finale du bot, pas un plateau encore incomplet.
	await driver.cast_spells_phase(player, match_)
