extends GutTest

# Couvre la 5e race de cartes "Artefact" (thème Reliques Anciennes, Race.Type.NONE,
# jouable dans n'importe quel deck) : intégrité des ressources .tres de
# resources/cards/artifact/ et logique non triviale carte par carte, exécutée
# via EffectManager + FakeBattle (tests/unit/doubles/fake_battle.gd), sans
# dépendre des autoloads globaux — convention GUT du projet (voir CLAUDE.md).
# Les mécanismes moteur génériques (AddCardToHand, MimicMinion, echoed_trigger,
# EnemyHeroOrMinion, LowestHPAlly) sont testés indépendamment dans
# tests/unit/test_artifact_engine.gd ; ce fichier vérifie surtout que chaque
# ressource .tres est câblée correctement sur ces mécanismes.

const ARTIFACT_DIR := "res://resources/cards/artifact/"

var effect_manager: EffectManager
var battle: FakeBattle

func before_each() -> void:
	effect_manager = load("res://scripts/EffectManager/EffectManager.gd").new()
	battle = load("res://tests/unit/doubles/fake_battle.gd").new()

func _card(path: String) -> CardData:
	return load(ARTIFACT_DIR + path)

# Serviteur générique (pas une carte Artefact) utilisé comme allié/ennemi de
# complément dans les tests (cible, allié témoin...).
func _minion(attack: int = 2, health: int = 5, is_player: bool = true, row: String = "Front") -> Minion:
	var data := CardData.new()
	data.card_name = "TEST_CARD"
	data.attack = attack
	data.health = health
	var minion := Minion.new(data, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# Instancie en jeu un vrai serviteur Artefact chargé depuis son .tres.
func _minion_from_card(card: CardData, is_player: bool = true, row: String = "Front") -> Minion:
	var minion := Minion.new(card, is_player, row)
	if is_player:
		battle.player_minions.append(minion)
	else:
		battle.enemy_minions.append(minion)
	return minion

# ─── Intégrité des ressources ───────────────────────────────────────────────

func test_all_artifact_resources_load_and_have_consistent_base_fields() -> void:
	var dir := DirAccess.open(ARTIFACT_DIR)
	assert_not_null(dir, "resources/cards/artifact/ introuvable")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var checked := 0
	while file_name != "":
		if file_name.ends_with(".tres"):
			var card: CardData = load(ARTIFACT_DIR + file_name)
			assert_not_null(card, "%s ne charge pas" % file_name)
			assert_eq(card.race, Race.Type.NONE, "%s : race doit être NONE (Artefact, jouable dans n'importe quel deck)" % file_name)
			assert_ne(card.card_name, "", "%s : card_name vide" % file_name)
			assert_true(card.cost >= 0, "%s : coût négatif (%d)" % [file_name, card.cost])
			if card.card_type == "Minion":
				assert_gt(card.health, 0, "%s : serviteur sans HP" % file_name)
			else:
				assert_eq(card.attack, 0, "%s (%s) ne devrait pas avoir d'attaque" % [file_name, card.card_type])
				assert_eq(card.health, 0, "%s (%s) ne devrait pas avoir de HP" % [file_name, card.card_type])
			if card.card_type == "Ritual":
				assert_true(card.ritual_duration != 0, "%s : Rituel sans ritual_duration renseignée" % file_name)
			for effect in card.effects:
				if effect.effect_id == "AddCardToHand":
					assert_not_null(effect.generated_card, "%s : AddCardToHand sans generated_card assignée" % file_name)
					if effect.generated_card != null:
						assert_true(effect.generated_card.is_token, "%s (AddCardToHand) cible %s, qui n'est pas un jeton (is_token=false)" % [file_name, effect.generated_card.card_name])
			checked += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	assert_gt(checked, 0, "aucun fichier .tres trouvé dans resources/cards/artifact/")

# ─── Génération d'objets en main (AddCardToHand) ────────────────────────────

func test_golem_de_basalte_deathrattle_adds_pierre_volcanique_to_hand() -> void:
	var golem := _minion_from_card(_card("golem-de-basalte.tres"))
	var expected_token := _card("pierre-volcanique-token.tres")
	await effect_manager.trigger_effects(battle, golem, "DEATHRATTLE")
	assert_true(expected_token in battle.hand_cards)

func test_urne_scellee_deathrattle_adds_eclat_de_memoire_to_hand() -> void:
	var urne := _minion_from_card(_card("urne-scellee.tres"))
	var expected_token := _card("eclat-de-memoire-token.tres")
	await effect_manager.trigger_effects(battle, urne, "DEATHRATTLE")
	assert_true(expected_token in battle.hand_cards)

func test_chambre_funeraire_deathrattle_adds_fragment_curatif_to_hand() -> void:
	var chambre := _minion_from_card(_card("chambre-funeraire.tres"))
	var expected_token := _card("fragment-curatif-token.tres")
	await effect_manager.trigger_effects(battle, chambre, "DEATHRATTLE")
	assert_true(expected_token in battle.hand_cards)

# Forge Éteinte est un Enchantement (pas un Minion) : passe par TriggerSystem,
# pas directement par EffectManager.trigger_effects (réservé aux triggers
# portés par un Minion). trigger_once_per_turn est géré par TriggerSystem.
func test_forge_eteinte_declin_adds_pierre_volcanique_once_per_turn() -> void:
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	var forge := _card("forge-eteinte.tres")
	var expected_token := _card("pierre-volcanique-token.tres")
	trigger_system.register_enchantment(forge, true, -1)
	await trigger_system.fire("OnDecline", null, true)
	await trigger_system.fire("OnDecline", null, true)
	var count: int = battle.hand_cards.filter(func(c: CardData) -> bool: return c == expected_token).size()
	assert_eq(count, 1, "trigger_once_per_turn : une seule Pierre Volcanique malgré deux Déclins")
	trigger_system.free()

# ─── Écho de trigger (echoed_trigger) ───────────────────────────────────────

func test_le_veilleur_qui_repete_echoes_ally_deathrattle() -> void:
	_minion_from_card(_card("le-veilleur-qui-repete.tres"))
	var urne := _minion_from_card(_card("urne-scellee.tres"))
	var expected_token := _card("eclat-de-memoire-token.tres")
	await effect_manager.trigger_effects(battle, urne, "DEATHRATTLE")
	var count: int = battle.hand_cards.filter(func(c: CardData) -> bool: return c == expected_token).size()
	assert_eq(count, 2, "Le Veilleur Qui Répète : Dernier Souffle allié déclenché une fois de plus")

func test_le_heraut_du_second_pas_echoes_ally_onplay() -> void:
	_minion_from_card(_card("le-heraut-du-second-pas.tres"))
	var porteur := _minion_from_card(_card("porteur-de-rempart-oublie.tres"))
	var ally := _minion(2, 4, true)
	await effect_manager.trigger_effects(battle, porteur, "ONPLAY", ally)
	assert_true(ally.has_keyword(Keyword.Type.TAUNT))
	# 2 déclenchements de GrantKeyword sur la même cible déjà REMPART : le 2e
	# ne fait rien de plus (has_keyword garde-fou), mais on vérifie via un
	# 2e allié témoin qu'il n'y a pas eu de plantage / que l'effet a bien été
	# rejoué (indirectement, via le nombre d'entrées temporaires enregistrées
	# serait 0 ici car granted_keyword est temporaire -> pas de garde-fou
	# fiable) : on vérifie donc directement le compteur d'échos.
	assert_eq(effect_manager._echo_count(battle, porteur, "ONPLAY"), 1)

func test_l_echo_sans_origine_echoes_any_trigger() -> void:
	_minion_from_card(_card("l-echo-sans-origine.tres"))
	var urne := _minion_from_card(_card("urne-scellee.tres"))
	var expected_token := _card("eclat-de-memoire-token.tres")
	await effect_manager.trigger_effects(battle, urne, "DEATHRATTLE")
	var count: int = battle.hand_cards.filter(func(c: CardData) -> bool: return c == expected_token).size()
	assert_eq(count, 2, "écho universel : s'applique aussi au Dernier Souffle")

func test_echo_carriers_cumulate_on_a_real_card() -> void:
	_minion_from_card(_card("le-veilleur-qui-repete.tres"))
	_minion_from_card(_card("l-echo-sans-origine.tres"))
	var urne := _minion_from_card(_card("urne-scellee.tres"))
	var expected_token := _card("eclat-de-memoire-token.tres")
	await effect_manager.trigger_effects(battle, urne, "DEATHRATTLE")
	var count: int = battle.hand_cards.filter(func(c: CardData) -> bool: return c == expected_token).size()
	assert_eq(count, 3, "2 porteurs d'écho = 2 déclenchements supplémentaires (3 au total)")

# ─── Mimétisme (MimicMinion) ─────────────────────────────────────────────────

func test_faux_semblant_mimics_cheap_ally() -> void:
	var faux_semblant := _minion_from_card(_card("faux-semblant.tres"))
	var cheap_ally := _minion(2, 3, true) # coût par défaut CardData.cost = 1
	await effect_manager.trigger_effects(battle, faux_semblant, "ONPLAY", cheap_ally)
	assert_eq(faux_semblant.card_data, cheap_ally.card_data)
	assert_eq(faux_semblant.attack, 2)
	assert_eq(faux_semblant.max_health, 3)

func test_faux_semblant_cannot_mimic_an_ally_above_cost_limit() -> void:
	var faux_semblant := _minion_from_card(_card("faux-semblant.tres"))
	var expensive_ally := _minion(9, 9, true)
	expensive_ally.card_data.cost = 4 # au-dessus de target_max_cost=3
	await effect_manager.trigger_effects(battle, faux_semblant, "ONPLAY", expensive_ally)
	assert_ne(faux_semblant.card_data, expensive_ally.card_data, "coût 4 > target_max_cost=3 : ne doit pas copier")

func test_voleur_de_visage_mimics_enemy_within_cost_limit() -> void:
	var voleur := _minion_from_card(_card("voleur-de-visage.tres"))
	var enemy := _minion(4, 4, false)
	enemy.card_data.cost = 3
	await effect_manager.trigger_effects(battle, voleur, "ONPLAY", enemy)
	assert_eq(voleur.card_data, enemy.card_data)
	assert_true(voleur.owner_is_player, "le mimétisme ne change pas le camp du lanceur")

func test_usurpateur_mimics_enemy_regardless_of_cost() -> void:
	var usurpateur := _minion_from_card(_card("usurpateur.tres"))
	var expensive_enemy := _minion(9, 9, false)
	expensive_enemy.card_data.cost = 10
	await effect_manager.trigger_effects(battle, usurpateur, "ONPLAY", expensive_enemy)
	assert_eq(usurpateur.card_data, expensive_enemy.card_data, "pas de target_max_cost sur Usurpateur : coût illimité")

func test_le_sans_visage_mimics_then_gets_permanent_buff() -> void:
	var sans_visage := _minion_from_card(_card("le-sans-visage.tres"))
	var target := _minion(3, 3, false)
	await effect_manager.trigger_effects(battle, sans_visage, "ONPLAY", target)
	assert_eq(sans_visage.card_data, target.card_data)
	assert_eq(sans_visage.attack, 4, "3 ATK copiée + 1 du buff permanent")
	assert_eq(sans_visage.max_health, 4, "3 HP copiés + 1 du buff permanent")

# ─── Pierre Volcanique (Damage : EnemyHeroOrMinion) ─────────────────────────

func test_pierre_volcanique_token_damages_enemy_hero_without_target() -> void:
	var source := _minion_from_card(_card("golem-de-basalte.tres"))
	var pierre_volcanique := _card("pierre-volcanique-token.tres")
	await effect_manager.execute_effect(battle, source, pierre_volcanique.effects[0], null)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health - 2)

func test_pierre_volcanique_token_damages_targeted_enemy_minion() -> void:
	var source := _minion_from_card(_card("golem-de-basalte.tres"))
	var target := _minion(2, 4, false)
	var pierre_volcanique := _card("pierre-volcanique-token.tres")
	await effect_manager.execute_effect(battle, source, pierre_volcanique.effects[0], target)
	assert_eq(target.health, 2)
	assert_eq(battle.enemy_hero.health, battle.enemy_hero.max_health)

# ─── LowestHPAlly (Cercle des Strates Anciennes) ────────────────────────────

func test_cercle_des_strates_anciennes_heals_the_lowest_hp_ally_on_awaken() -> void:
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	var cercle := _card("cercle-des-strates-anciennes.tres")
	trigger_system.register_enchantment(cercle, true, cercle.ritual_duration)
	var mid := _minion(2, 6, true)
	mid.take_damage(2) # 4/6
	var lowest := _minion(2, 8, true)
	lowest.take_damage(7) # 1/8, le plus bas
	await trigger_system.fire("OnAwaken", null, true)
	assert_eq(lowest.health, 3, "le serviteur allié avec le moins de HP doit être soigné de 2")
	assert_eq(mid.health, 4, "les autres alliés ne doivent pas être affectés")
	assert_eq(battle.enchantment_system.turns_updates.size(), 1, "1 charge de rituel consommée")
	assert_eq(battle.enchantment_system.turns_updates[0]["turns"], cercle.ritual_duration - 1)
	trigger_system.free()

# ─── Rituels à charges : consommation effective (Rituel de la Chambre Scellée) ──

func test_rituel_de_la_chambre_scellee_consumes_one_charge_per_effective_trigger() -> void:
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	var rituel := _card("rituel-de-la-chambre-scellee.tres")
	var expected_token := _card("pierre-volcanique-token.tres")
	assert_eq(rituel.ritual_duration, 2)
	trigger_system.register_enchantment(rituel, true, rituel.ritual_duration)
	await trigger_system.fire("OnAwaken", null, true)
	assert_true(expected_token in battle.hand_cards)
	assert_eq(battle.enchantment_system.turns_updates.size(), 1)
	assert_eq(battle.enchantment_system.turns_updates[0]["turns"], 1, "2 charges de départ - 1 consommée = 1 restante")
	assert_eq(battle.enchantment_system.destroyed.size(), 0, "il reste une charge : le rituel ne doit pas être détruit")
	await trigger_system.fire("OnAwaken", null, true)
	assert_eq(battle.enchantment_system.destroyed.size(), 1, "dernière charge consommée : le rituel doit être détruit")
	trigger_system.free()

func test_cercle_du_jugement_muet_destroys_low_hp_enemy_on_awaken() -> void:
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	var cercle := _card("cercle-du-jugement-muet.tres")
	trigger_system.register_enchantment(cercle, true, cercle.ritual_duration)
	var weak_enemy := _minion(2, 2, false)
	var strong_enemy := _minion(2, 6, false)
	await trigger_system.fire("OnAwaken", null, true)
	assert_true(weak_enemy.is_dead())
	assert_false(strong_enemy.is_dead())
	trigger_system.free()

# ─── Octroi de mots-clés : cas permanent et temporaire ──────────────────────

func test_autel_des_dons_perdus_grants_permanent_taunt_on_summon() -> void:
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	var autel := _card("autel-des-dons-perdus.tres")
	trigger_system.register_enchantment(autel, true, -1)
	var summoned := _minion(2, 4, true)
	await trigger_system.fire("OnSummon", summoned, true, {"target": summoned})
	assert_true(summoned.has_keyword(Keyword.Type.TAUNT))
	assert_eq(battle.temp_effect_system._entries.size(), 0, "duration = Permanent : aucune entrée temporaire enregistrée")
	trigger_system.free()

func test_benediction_de_pierre_grants_temporary_aegis() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var benediction := _card("benediction-de-pierre.tres")
	await effect_manager.execute_effect(battle, source, benediction.effects[0], target)
	assert_true(target.has_keyword(Keyword.Type.AEGIS))
	assert_eq(battle.temp_effect_system._entries.size(), 1, "duration temporaire : une entrée doit être enregistrée pour l'expiration")

func test_gardien_de_l_assaut_ancien_grants_adjacent_permanent_charge() -> void:
	var neighbor := _minion(2, 4, true)
	var gardien := _minion_from_card(_card("gardien-de-l-assaut-ancien.tres"))
	_minion(2, 4, true) # voisin direct de l'autre côté, non testé
	var far := _minion(2, 4, true) # 2 positions plus loin : hors de portée
	await effect_manager.trigger_effects(battle, gardien, "ONPLAY")
	assert_true(neighbor.has_keyword(Keyword.Type.CHARGE))
	assert_false(far.has_keyword(Keyword.Type.CHARGE))
	assert_eq(battle.temp_effect_system._entries.size(), 0, "duration = Permanent : aucune entrée temporaire")

# ─── Sorts utilitaires : au moins un test par effect_id distinct utilisé ────

func test_eclat_de_gres_vivant_permanently_buffs_target() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var eclat := _card("eclat-de-gres-vivant.tres")
	await effect_manager.execute_effect(battle, source, eclat.effects[0], target)
	assert_eq(target.attack, 3)
	assert_eq(target.max_health, 5)

func test_poids_de_la_pierre_ancienne_permanently_debuffs_target() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 4, false)
	var poids := _card("poids-de-la-pierre-ancienne.tres")
	await effect_manager.execute_effect(battle, source, poids.effects[0], target)
	assert_eq(target.attack, 2)
	assert_eq(target.max_health, 3)

func test_fissure_runique_temporarily_reduces_attack_only() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(3, 4, false)
	var fissure := _card("fissure-runique.tres")
	await effect_manager.execute_effect(battle, source, fissure.effects[0], target)
	assert_eq(target.attack, 1)
	assert_eq(target.max_health, 4, "-2/-0 : les HP max ne doivent pas être affectés")
	assert_eq(battle.temp_effect_system._entries.size(), 1, "duration = UntilEndOfTurn : doit s'annuler à l'expiration, pas rester permanent")
	battle.temp_effect_system._revert(battle.temp_effect_system._entries[0])
	assert_eq(target.attack, 3, "après expiration, l'ATK doit revenir à sa valeur d'origine")

func test_effondrement_du_sanctuaire_destroys_targeted_enemy() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var effondrement := _card("effondrement-du-sanctuaire.tres")
	await effect_manager.execute_effect(battle, source, effondrement.effects[0], target)
	assert_true(target.is_dead())

func test_jugement_du_sceau_brise_respects_target_max_hp() -> void:
	var source := _minion(2, 4, true)
	var strong_enemy := _minion(2, 6, false)
	var jugement := _card("jugement-du-sceau-brise.tres")
	await effect_manager.execute_effect(battle, source, jugement.effects[0], strong_enemy)
	assert_false(strong_enemy.is_dead(), "6 HP > 3 (target_max_hp) : ne doit pas être détruit")

func test_etreinte_petrifiante_freezes_target() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var etreinte := _card("etreinte-petrifiante.tres")
	await effect_manager.execute_effect(battle, source, etreinte.effects[0], target)
	assert_eq(target.frozen_turns, 1)

func test_sceau_du_silence_oublie_silences_target() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	target.add_keyword(Keyword.Type.TAUNT)
	var sceau := _card("sceau-du-silence-oublie.tres")
	await effect_manager.execute_effect(battle, source, sceau.effects[0], target)
	assert_true(target.silenced)
	assert_true(target.keywords.is_empty())

func test_maree_de_poussiere_returns_enemy_minion_to_its_owner_hand() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, false)
	var maree := _card("maree-de-poussiere.tres")
	await effect_manager.execute_effect(battle, source, maree.effects[0], target)
	assert_false(target in battle.enemy_minions)
	assert_true(target.card_data in battle.ai_system.hand)

func test_poussiere_du_temps_draws_two_cards() -> void:
	battle.deck = [CardData.new(), CardData.new()]
	var source := _minion(2, 4, true)
	var poussiere := _card("poussiere-du-temps.tres")
	await effect_manager.execute_effect(battle, source, poussiere.effects[0])
	assert_eq(battle.hand_cards.size(), 2)
	assert_true(battle.deck.is_empty())

func test_veine_de_mana_fossile_gains_mana() -> void:
	var source := _minion(2, 4, true)
	var veine := _card("veine-de-mana-fossile.tres")
	await effect_manager.execute_effect(battle, source, veine.effects[0])
	assert_eq(int(battle.race_mana.get(Race.Type.NONE, 0)), 2)

func test_onde_de_la_source_tarie_heals_owner_hero() -> void:
	battle.player_hero.health = battle.player_hero.max_health - 6
	var source := _minion(2, 4, true)
	var onde := _card("onde-de-la-source-tarie.tres")
	await effect_manager.execute_effect(battle, source, onde.effects[0])
	assert_eq(battle.player_hero.health, battle.player_hero.max_health - 2)

func test_siphon_de_basalte_damages_target_and_heals_owner_hero() -> void:
	battle.player_hero.health = battle.player_hero.max_health - 5
	var source := _minion(2, 4, true)
	var target := _minion(2, 5, false)
	var siphon := _card("siphon-de-basalte.tres")
	for effect in siphon.effects:
		await effect_manager.execute_effect(battle, source, effect, target)
	assert_eq(target.health, 2)
	assert_eq(battle.player_hero.health, battle.player_hero.max_health - 2)

func test_souffle_du_cairn_buffs_all_allies_temporarily() -> void:
	var source := _minion(2, 4, true)
	var ally := _minion(2, 4, true)
	var enemy := _minion(2, 4, false)
	var souffle := _card("souffle-du-cairn.tres")
	await effect_manager.execute_effect(battle, source, souffle.effects[0])
	assert_eq(source.attack, 3)
	assert_eq(ally.attack, 3)
	assert_eq(enemy.attack, 2, "le camp ennemi ne doit pas être affecté")

func test_porte_chance_fossilise_grants_temporary_lifesteal() -> void:
	var porte_chance := _minion_from_card(_card("porte-chance-fossilise.tres"))
	var ally := _minion(2, 4, true)
	await effect_manager.trigger_effects(battle, porte_chance, "ONPLAY", ally)
	assert_true(ally.has_keyword(Keyword.Type.LIFESTEAL))

func test_colonne_des_pactes_rompus_grants_temporary_ravage_on_summon() -> void:
	var colonne := _card("colonne-des-pactes-rompus.tres")
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	trigger_system.register_enchantment(colonne, true, -1)
	var summoned := _minion(2, 4, true)
	await trigger_system.fire("OnSummon", summoned, true, {"target": summoned})
	assert_true(summoned.has_keyword(Keyword.Type.RAVAGE))
	trigger_system.free()

func test_relique_de_la_frenesie_grants_temporary_fury() -> void:
	var relique := _minion_from_card(_card("relique-de-la-frenesie.tres"))
	var ally := _minion(2, 4, true)
	await effect_manager.trigger_effects(battle, relique, "ONPLAY", ally)
	assert_true(ally.has_keyword(Keyword.Type.FURY))

func test_rite_du_venin_oublie_grants_temporary_deadly_poison() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var rite := _card("rite-du-venin-oublie.tres")
	await effect_manager.execute_effect(battle, source, rite.effects[0], target)
	assert_true(target.has_keyword(Keyword.Type.DEADLY_POISON))

func test_sceau_de_l_infiltration_grants_temporary_black_wings() -> void:
	var source := _minion(2, 4, true)
	var target := _minion(2, 4, true)
	var sceau := _card("sceau-de-l-infiltration.tres")
	await effect_manager.execute_effect(battle, source, sceau.effects[0], target)
	assert_true(target.has_keyword(Keyword.Type.BLACK_WINGS))

func test_vestige_de_l_ancien_monde_grants_temporary_aegis_on_summon() -> void:
	var vestige := _card("vestige-de-l-ancien-monde.tres")
	var trigger_system = load("res://scripts/systems/TriggersSystem.gd").new()
	trigger_system.init(battle)
	trigger_system.register_enchantment(vestige, true, -1)
	var summoned := _minion(2, 4, true)
	await trigger_system.fire("OnSummon", summoned, true, {"target": summoned})
	assert_true(summoned.has_keyword(Keyword.Type.AEGIS))
	trigger_system.free()
