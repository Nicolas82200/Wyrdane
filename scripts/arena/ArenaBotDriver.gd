extends RefCounted
class_name ArenaBotDriver

# IA minimale pour le prototype Arena (voir plan Arena) : achète des cartes
# abordables au hasard, pose au hasard Avant/Arrière. N'a pas vocation à jouer
# intelligemment — seul le moteur de règles (boutique/pool/combat/économie)
# est sous test via ce prototype, pas la qualité de décision des bots.

var rng: RandomNumberGenerator

func _init(_rng: RandomNumberGenerator = null) -> void:
	rng = _rng if _rng != null else RandomNumberGenerator.new()

# Achète tant que possible, reroll occasionnel si rien d'abordable, puis
# achète 1 XP selon la règle fixe du plan (or restant >= 2 et round >= 2 —
# sinon les bots resteraient bloqués niveau 1 toute la partie).
func play_shop_phase(player: ArenaPlayerState, match_: ArenaMatch) -> void:
	var reroll_attempts := 0
	while true:
		var affordable: Array[int] = _affordable_indices(player)
		if affordable.is_empty():
			if reroll_attempts >= 3 or player.gold < ArenaConstants.REROLL_COST or rng.randf() > 0.5:
				break
			reroll_attempts += 1
			match_.reroll(player)
			continue
		if player.is_hand_full():
			break
		var index: int = affordable[rng.randi() % affordable.size()]
		match_.buy_card(player, index)

	if player.gold >= 2 and match_.round_number >= 2:
		match_.buy_xp(player)

func _affordable_indices(player: ArenaPlayerState) -> Array[int]:
	var result: Array[int] = []
	for i in player.shop_offer.size():
		var card: CardData = player.shop_offer[i]
		if card != null and card.cost <= player.gold:
			result.append(i)
	return result

# Lance toutes les Incantations achetées : elles ne sont que des buffs/octrois
# de mot-clé sans contrepartie en Arena v1 (voir README « Cartes exclusives
# Arena »), donc les lancer systématiquement est un choix raisonnable même
# pour un bot très simple.
func cast_spells_phase(player: ArenaPlayerState, match_: ArenaMatch) -> void:
	for card_data in player.spell_hand.duplicate():
		await match_.cast_spell(player, card_data)

# Pose gratuite au hasard Avant/Arrière, dans la limite de 10 par rangée
# (README « Pose sur le plateau »).
func play_positioning_phase(player: ArenaPlayerState) -> void:
	for minion in player.hand.duplicate():
		var rows: Array[bool] = []
		if player.can_place_on_row(true):
			rows.append(true)
		if player.can_place_on_row(false):
			rows.append(false)
		if rows.is_empty():
			break  # plateau plein des deux côtés (20 serviteurs)
		var is_front: bool = rows[rng.randi() % rows.size()]
		player.place_on_board(minion, is_front)
