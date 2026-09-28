extends GutTest

# Composition du texte de récompense d'une quête (voir QuestsPanel._reward_text).
# Les quatre types de quêtes partagent ce format depuis le 2026-09-28 : une
# quête qui ne donne que de l'or affichait auparavant « 400 or, 0 pack(s) ».
# Comparé aux clés de traduction plutôt qu'à des chaînes en dur : le test reste
# valable quelle que soit la langue active. Script chargé directement plutôt que
# via sa classe globale (voir « Tests automatisés » dans CLAUDE.md).

var QuestsPanelScript = load("res://scripts/mainMenu/QuestsPanel.gd")


func test_gold_only_never_mentions_packs() -> void:
	var text: String = QuestsPanelScript._reward_text(400, 0)
	assert_eq(text, SettingsManager.t("QUESTS_REWARD_GOLD") % 400)


func test_packs_only_never_mentions_gold() -> void:
	var text: String = QuestsPanelScript._reward_text(0, 5)
	assert_eq(text, SettingsManager.t("QUESTS_REWARD_PACKS") % 5)


func test_both_rewards_are_listed_together() -> void:
	var text: String = QuestsPanelScript._reward_text(1000, 5)
	var expected := "%s, %s" % [
		SettingsManager.t("QUESTS_REWARD_GOLD") % 1000,
		SettingsManager.t("QUESTS_REWARD_PACKS") % 5,
	]
	assert_eq(text, expected)


func test_no_reward_falls_back_to_a_dedicated_label() -> void:
	# Aucune quête du catalogue n'est à 0/0, mais le format ne doit jamais
	# produire une parenthèse vide si le backend en renvoyait une.
	assert_eq(QuestsPanelScript._reward_text(0, 0), SettingsManager.t("QUESTS_REWARD_NONE"))
