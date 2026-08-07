# PactChoiceSystem.gd
# Demande au joueur LOCAL s'il accepte de payer le coût en PV du mot-clé PACTE
# d'une carte qu'il vient de jouer (voir CardSystem.handle_card_played). Le
# texte de l'effet est déjà visible sur la carte elle-même (description) ; la
# popup ne fait que confirmer le coût. Non utilisé pour l'IA (AISystem décide
# seule via une heuristique) ni pour le pair distant (NetworkOpponent rejoue
# le choix déjà fait, transporté par NetCommand.PLAY_CARD).
extends RefCounted
class_name PactChoiceSystem

var battle

func init(_battle) -> void:
	battle = _battle

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
