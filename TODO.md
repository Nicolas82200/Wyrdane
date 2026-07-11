# TODO — FateBound

Liste priorisée issue d'une revue transversale du projet (voir aussi la section « Roadmap » de `README.md` pour la vue produit, et « Notes pour les agents » de `CLAUDE.md` pour les conventions).

## P1 — IA : ne joue que des serviteurs

`scripts/systems/AISystem.gd::_pick_best_playable_card()` filtre explicitement `card.card_type != "Minion"` : l'IA ignore totalement les Éphémères, Rituels et Enchantements de sa main, même s'ils seraient le meilleur coup (removal, buff, etc.).

- Étendre `_play_cards_phase()` pour évaluer aussi les sorts jouables (ciblage simple d'abord : dégâts/buff/soin sur cible évidente)
- Ajouter la pose de Rituels/Enchantements (pas de ciblage à la pose)
- Activation des rituels à trigger `OnSacrifice` par l'IA (`TriggerSystem.activate_sacrifice_ritual`) — actuellement seul le joueur humain peut les activer
- Effort : large. À découper en plusieurs branches (une par type de carte) plutôt qu'une seule feature géante.

## P2 — Couverture de tests quasi nulle en dehors des cartes

Seuls `tests/unit/test_minion.gd` et `tests/unit/test_card_library.gd` existent. Aucun test sur :

- `EffectManager` (1005 lignes, cœur du moteur data-driven — le plus gros risque de régression silencieuse)
- `CombatSystem`, `TurnSystem`, `TriggerSystem`, `DeathSystem`
- `AuraSystem`, `SacrificeSystem`, `CostSystem`
- Le protocole réseau (`scripts/net/`) — sérialisation des commandes, rejeu côté `NetworkOpponent`

Prioriser `EffectManager` et `CombatSystem` en premier (logique la plus dense et la plus souvent modifiée à chaque nouvelle carte). Suivre la convention déjà en place : charger le script cible directement (`load(...).new()`), éviter la dépendance aux autoloads dans le runner GUT `-s`.

## P3 — Fichiers Steam parasites non ignorés par git

`git status` fait apparaître :
```
addons/godotsteam/win64/~libgodotsteam.windows.template_debug.x86_64.dll
addons/godotsteam/win64/~libgodotsteam.windows.template_debug.x86_64.dll~RFacf7d8.TMP
```
Ce sont des résidus d'extraction de l'archive GodotSteam (fichiers temporaires préfixés `~`). **Fait dans cette branche** : ajout de `addons/godotsteam/**/~*` et `*.TMP` à `.gitignore`. Reste à faire : supprimer ces deux fichiers du working directory local (pas fait ici pour ne pas toucher à l'installation Steam de quelqu'un d'autre sans confirmation).

## P4 — Steam : passage en production

Le backend fonctionne avec l'AppID de test 480 (Spacewar), documenté et volontairement temporaire (`scripts/net/SteamService.gd`). Reste :
- Créer la page Steamworks et obtenir le vrai AppID
- Remplacer `SteamService.APP_ID`
- Invitations d'amis, pipeline de build/dépôt Steam
- Effort : moyen mais surtout administratif (hors code).

## P5 — Incohérence mineure de comptage de cartes

`README.md` et `CLAUDE.md` annoncent 226 cartes au total ; le compte réel des `.tres` dans `resources/cards/` est 224 (75 Mort-Vivant + 74 Humain + 75 Démon). Écart mineur, à vérifier lors de la prochaine carte ajoutée/retirée (peut-être un chiffre resté après une carte supprimée en cours de design). **Fait dans cette branche** : correction de la ligne obsolète dans `CLAUDE.md` qui indiquait encore que les `.tres` Démon « restent à créer » (ils existent déjà, 75 fichiers).

## P6 — Elfe / Nain : scaffolding minimal

Seuls les enums `Race.Type.ELF` et `Race.Type.DWARF` existent (`scripts/data/Race.gd`). Aucun fichier `KeywordElf.gd`/`KeywordDwarf.gd`, aucun dossier `resources/cards/elf|dwarf/`, aucune entrée dans `CARDS.md`. Chantier de design complet à faire avant tout code (mots-clés propres à définir dans `README.md` d'abord, comme convenu pour toute nouvelle race/mot-clé).

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P5 corrigé ci-dessus.
