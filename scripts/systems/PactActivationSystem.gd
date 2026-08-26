# PactActivationSystem.gd
extends Node
class_name PactActivationSystem

# Activation volontaire du bonus de Pacte d'une carte "standalone" (voir
# CardData.pact_standalone, ex. Larve Infernale : "Pacte 1 : Ce serviteur
# gagne +1/+1 de façon permanente.", sans aucun autre effet). Contrairement au
# choix demandé automatiquement à un trigger (PactChoiceSystem, ex. Émissaire
# du Pacte), ces cartes n'imposent pas de décider immédiatement à l'Arrivée :
# un bouton reste disponible sur le serviteur en jeu tant que son propriétaire
# ne l'a pas activé, activable à tout moment de son tour. Une seule fois par
# serviteur (Minion.pact_activated). Portée volontairement limitée aux effets
# ciblant Self (voir CardData.pact_standalone) — pas de sélection de cible.

var battle

func init(_battle) -> void:
	battle = _battle

func can_activate(minion: Minion) -> bool:
	if minion == null or not minion.owner_is_player or minion.is_dead():
		return false
	if minion.pact_activated or not minion.card_data.pact_standalone:
		return false
	if battle.game_over or battle.reconnecting or battle.enemy_turn_active or battle.waiting_for_target:
		return false
	if battle.targeting_system.is_targeting() or battle.sacrifice_system.is_active() or battle.fusion_system.is_active():
		return false
	return minion.card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE) > 0

func try_activate(minion: Minion) -> void:
	if not can_activate(minion):
		return
	var effect: CardEffect = _standalone_effect(minion.card_data)
	if effect == null:
		return
	var value: int = minion.card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
	var paid: bool = await battle.pact_choice_system.ask(minion.card_data, value)
	if not paid or minion.is_dead():
		return
	await apply_pact_activation(minion, effect, value)
	if battle.net_emitter != null:
		battle.net_emitter.activate_pact(minion.net_id)

# Cœur de l'effet, rejouable tel quel côté réseau distant (NetworkOpponent) —
# le paiement a déjà été décidé (toujours "oui" : seul le joueur qui clique
# choisit d'activer) donc rien à redemander au rejeu.
func apply_pact_activation(minion: Minion, effect: CardEffect, value: int) -> void:
	if minion == null or minion.is_dead() or minion.pact_activated:
		return
	minion.pact_activated = true
	var minion_visual: Control = battle.board_visual_system.find_visual(minion)
	var hero_panel: Control = battle.get_node("PlayerHeroPanel" if minion.owner_is_player else "EnemyHeroPanel")
	battle.animation_system.play_pact_drain(hero_panel, minion_visual)
	await battle.hero_system.self_damage(minion.owner_is_player, value)
	await battle.effect_manager.execute_effect(battle, minion, effect)
	battle.board_visual_system.refresh_board()

func _standalone_effect(card_data: CardData) -> CardEffect:
	for effect in card_data.effects:
		if effect.pact_bonus:
			return effect
	return null
