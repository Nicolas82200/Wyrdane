extends RefCounted
class_name CampaignConsolationReward

# Récompense de consolation en monnaie molle après une défaite de run,
# proportionnelle à la profondeur atteinte (CAMPAIGN.md « Structure de la
# run » : « proportionnelle à la profondeur atteinte »). Isolé dans son
# propre fichier pour rester testable et ajustable sans toucher à
# CampaignBattle.gd/CampaignEndScreen.gd.

const REWARD_PER_DEPTH := 5

static func compute(run: CampaignRun) -> int:
	return run.depth * REWARD_PER_DEPTH
