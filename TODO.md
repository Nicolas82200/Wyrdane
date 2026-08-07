# TODO — Wyrdane

Liste priorisée issue d'une revue transversale du projet (voir aussi la section « Roadmap » de `README.md` pour la vue produit, et « Notes pour les agents » de `CLAUDE.md` pour les conventions).

## P1 — Couverture de tests quasi nulle en dehors des cartes

**Résolu pour la partie raisonnablement testable.** `tests/unit/` couvre désormais `EffectManager`, `CostSystem`, `AuraSystem`, `SacrificeSystem`, `TriggerSystem`, `DeathSystem`, `CombatSystem` (double `SceneTree`, cf. convention ci-dessous), `TurnSystem` (`_apply_infection_damage`/`run_turn_start_triggers`/`run_turn_end_triggers`), `AISystem`, `DeckSystem`/`DeckData`/`DeckManager`, `BoardSystem`/`BoardVisualSystem`, `DropSystem`, `AnimationSystem`, `VfxManager`, la mutation Abomination, le timer de tour, ainsi que `NetCommand`/`NetRegistry` côté protocole réseau (vocabulaire de commandes + attribution/capture d'ids), en plus des tests `Minion`/`CardLibrary`/`CardData` d'origine (521 tests, tous verts en headless : `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`).

Restent non couverts, jugés hors de portée d'un test unitaire raisonnable (couplage à la scène réelle/Steam plutôt qu'un manque d'effort) :
- `NetworkManager`/`SteamTransport`/`NetworkOpponent` (`scripts/net/`) — dépendent de GodotSteam (P2P réel), d'un `SceneTree` réseau, et rejouent des commandes sur un `Battle` complet ; testable uniquement via un test d'intégration à deux instances Steam, pas un test unitaire.

Convention établie (voir `tests/unit/doubles/fake_battle.gd`) : charger le script cible directement (`load(...).new()`), éviter la dépendance aux autoloads globaux dans le runner GUT `-s`, et étendre `FakeBattle` plutôt que d'en créer un nouveau par système quand c'est raisonnable (RefCounted réels comme `Graveyard`/`NetRegistry` réutilisés tels quels ; `Node`-based comme `SacrificeSystem`/`TriggerSystem` libérés explicitement via `free()` en `after_each()` pour éviter les nœuds orphelins).

## P2 — Fichiers Steam parasites non ignorés par git

**Résolu.** Résidus d'extraction de l'archive GodotSteam (fichiers temporaires préfixés `~`/`.TMP`). `addons/godotsteam/**/~*` et `*.TMP` ajoutés à `.gitignore`, et les fichiers parasites supprimés du working directory local.

## P3 — Steam : passage en production

Le backend fonctionne avec l'AppID de test 480 (Spacewar), documenté et volontairement temporaire (`scripts/net/SteamService.gd`). Reste :
- Créer la page Steamworks et obtenir le vrai AppID
- Remplacer `SteamService.APP_ID`
- Invitations d'amis, pipeline de build/dépôt Steam
- Effort : moyen mais surtout administratif (hors code).

## P4 — Incohérence mineure de comptage de cartes

**Résolu dans cette branche.** Le compte réel des `.tres` dans `resources/cards/` est désormais 317 (80 Mort-Vivant dont 4 jetons, 81 Humain dont 5 jetons, 77 Démon dont 1 jeton, 79 Abomination dont 3 jetons) — `README.md` et `CLAUDE.md` annonçaient encore 226/227/303. Deux cartes-jetons Abomination (« Amas Informe Mutant », « Amas Informe Reformé ») existaient dans `resources/cards/abomination/` sans ligne correspondante dans `CARDS.md` ; ajoutées (A78/A79). Comptages mis à jour dans `README.md`, `CLAUDE.md` et `CARDS.md`. À revérifier lors de la prochaine carte ajoutée/retirée.

## P5 — Elfe / Nain : scaffolding minimal

Seuls les enums `Race.Type.ELF` et `Race.Type.DWARF` existent (`scripts/data/Race.gd`). Aucun fichier `KeywordElf.gd`/`KeywordDwarf.gd`, aucun dossier `resources/cards/elf|dwarf/`, aucune entrée dans `CARDS.md`. Chantier de design complet à faire avant tout code (mots-clés propres à définir dans `README.md` d'abord, comme convenu pour toute nouvelle race/mot-clé).

## P6 — Ordre de Tenir (Humain, H53) : effet non implémenté

**Résolu.** Corrigé dans le commit `8e75cc8` (« fix: make non-functional cards work ») avec Fortification (déplacement/transformation), l'appariement de trigger de War Priest et l'`effect_id` de dégâts explicite. Le rituel applique désormais bien la protection contre le renvoi en main / déplacement par effet ennemi pour les serviteurs alliés en rangée Avant.

## P7 — Mode Campagne v2 (CAMPAIGN.md) livré, points ouverts restants

Run roguelite solo sans fin (choix de race, construction du plateau par 5 choix, carte à embranchements par fenêtre glissante, combat auto-battler dédié, or/boutique/reliques, sauvegarde de run locale, défaite avec consolation) implémentée dans `scripts/campaign/` + `scenes/campaign/`, voir README.md « Mode Campagne » et `CAMPAIGN.md` (design). Remplace entièrement la v1 (deck/pioche/mana classique, boss de fin) livrée puis abandonnée dans la même session suite à l'ajout de `CAMPAIGN.md`.

Hypothèses prises sur des points explicitement laissés ouverts par `CAMPAIGN.md`, à revalider :
- FRÉNÉSIE = mot-clé `FURY` existant (2 attaques) ; CHARGE redéfini pour la Campagne (attaque bonus répétable) implémenté localement dans `CampaignBattle.gd`, sans toucher `Minion.gd`/`Keyword.gd` partagés.
- Placement Avant/Arrière du plateau du joueur : suit `CardData.board_position` (Hybride → Avant), pas de choix manuel — le document ne précise cette règle que pour l'adversaire.
- Pas de ciblage interactif pour un effet d'Enchantement/Rituel déclenché sans cible déjà résolue par le trigger (comportement déjà celui du moteur partagé, pas spécifique à la Campagne).
- "1 tour = 1 attaque obligatoire" non strictement forcé (le joueur peut terminer son tour sans attaquer) — évite un soft-lock si aucun attaquant valide.
- Amélioration de carte en Boutique : un seul type d'amélioration (buff de stats fixe +1/+1), pas de choix mot-clé — CAMPAIGN.md liste l'articulation exacte comme un point ouvert.
- Table de rareté Élite/Boss par nombre de victoires : réutilise la même table par tranche de 10 que le scaling Normal, indexée sur le compteur de victoires au lieu du palier — CAMPAIGN.md indique que la table exacte reste à définir.
- Nombre de cartes gagnées par victoire Élite/Boss : +1 carte/victoire (repli simple).
- Fréquence du nœud Relique : poids modeste arbitraire dans `CampaignMapGenerator` — non spécifiée dans le document.
- Un plateau vide rend le héros directement attaquable sans vérifier la présence d'un enchantement/rituel capable d'invoquer (mentionné dans CAMPAIGN.md, complexité non justifiée pour la fréquence attendue des Reliques d'invocation).
- Récompense de fin de run (consolation défaite) réutilise `CurrencyManager.report_solo_match_result()` tel quel — pas de route backend dédiée à la campagne.

**Résolu après premier retour utilisateur.** Plusieurs cartes de la partie rapide s'appuient sur la main/le deck/le mana en combat (pioche, retour en main, gain de mana) — concepts inexistants dans l'auto-battler de Campagne (`EffectManager._draw_cards`/`_return_to_hand`/`_return_from_grave`/`_gain_mana`/`_draw_card_discount` plantaient sur `battle.hand`/`deck_system`/`race_mana_pool` absents). `EffectManager.gd` neutralise désormais ces effets en no-op quand ces propriétés n'existent pas sur `battle` (détection par duck-typing `battle.get(...)`/`battle.has_method(...)`, sans impact sur la partie rapide/le multijoueur qui les ont toujours). En complément, `CampaignCardFilter.gd` (nouveau) exclut ces cartes "sans intérêt" des pools de choix du joueur (construction du plateau, récompense, boutique, relique) et du plateau adverse — elles ne sont donc plus proposées du tout, pas seulement neutralisées.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
