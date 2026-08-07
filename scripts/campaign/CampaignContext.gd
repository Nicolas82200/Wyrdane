extends RefCounted
class_name CampaignContext

# Passe-plat entre les scènes du mode Campagne (RaceSelect, MapScreen,
# CampaignBattle, écrans de nœud), à travers les changements de scène — même
# pattern que TutorialContext/NetContext. Contrairement à ces deux-là, l'état
# riche est délégué à un objet CampaignRun plutôt qu'empilé en static var
# plates, vu le volume de données (plateau, carte générée, position, PV, or...).
#
# Important : CampaignBattle.gd n'appelle JAMAIS CampaignContext.clear() en
# fin de combat (la run continue après une victoire, sans fin — voir
# CAMPAIGN.md) — seul CampaignEndScreen le fait, à la mort du héros.

static var active: bool = false
static var run: CampaignRun = null

static func clear() -> void:
	active = false
	run = null
