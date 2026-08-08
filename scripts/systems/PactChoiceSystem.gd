# PactChoiceSystem.gd
# Demande au joueur LOCAL s'il accepte de payer le coût en PV du mot-clé PACTE
# pour activer le bonus d'un effet (CardEffect.pact_bonus), à chaque
# déclenchement effectif du trigger concerné — Arrivée comprise, aucun
# traitement à part : `resolve_trigger()` est appelé identiquement par
# EffectManager.trigger_effects (serviteurs) et TriggerSystem
# (_fire_on_enchantments / activate_sacrifice_ritual / try_cancel_spell pour
# Rituels/Enchantements). Aucun canal réseau dédié n'existe pour ce choix
# répété : en partie réseau, les deux camps décident via la même heuristique
# déterministe que l'IA (`heuristic_decision`), pour rester synchronisés sans
# nouveau protocole. `ask()` n'affiche la popup que pour le joueur LOCAL hors
# partie réseau.
extends RefCounted
class_name PactChoiceSystem

const SAFE_HEALTH_MARGIN := 6

var battle

func init(_battle) -> void:
	battle = _battle

func resolve_trigger(card_data: CardData, is_player: bool) -> bool:
	var value: int = card_data.get_demon_keyword_value(KeywordDemon.Type.PACTE)
	if value <= 0:
		return true
	if battle.network_manager != null:
		return heuristic_decision(is_player, value)
	if is_player:
		return await ask(card_data, value)
	return heuristic_decision(is_player, value)

# Décision déterministe (IA, ou joueur en partie réseau pour un choix de
# Rituel/Enchantement sans canal réseau dédié) : paie si la marge de PV restante
# après paiement reste confortable.
func heuristic_decision(is_player: bool, value: int) -> bool:
	var hero: Hero = battle.player_hero if is_player else battle.enemy_hero
	return hero.health - value >= SAFE_HEALTH_MARGIN

func ask(card_data: CardData, value: int) -> bool:
	var dialog := ConfirmationDialog.new()
	dialog.title = card_data.display_name()
	dialog.dialog_text = SettingsManager.t("PACT_CONFIRM_TEXT") % value
	dialog.ok_button_text = SettingsManager.t("PACT_CONFIRM_YES")
	dialog.cancel_button_text = SettingsManager.t("PACT_CONFIRM_NO")
	battle.add_child(dialog)
	dialog.popup_centered()

	var paid: bool = false
	var done: bool = false
	dialog.confirmed.connect(func() -> void:
		paid = true
		done = true
	)
	dialog.canceled.connect(func() -> void:
		paid = false
		done = true
	)
	while not done:
		await battle.get_tree().process_frame
	dialog.queue_free()
	return paid
