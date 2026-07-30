# TODO — Wyrdane

Liste priorisée issue d'une revue transversale du projet (voir aussi la section « Roadmap » de `README.md` pour la vue produit, et « Notes pour les agents » de `CLAUDE.md` pour les conventions).

## P1 — Couverture de tests quasi nulle en dehors des cartes

**Mis à jour dans cette branche.** `tests/unit/` couvre désormais `EffectManager`, `CostSystem`, `AuraSystem`, `SacrificeSystem`, `TriggerSystem` (`TriggersSystem.gd`), `DeathSystem`, la mutation Abomination et le timer de tour, en plus des tests `Minion`/`CardLibrary` d'origine (121 tests, tous verts en headless : `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`).

Restent non couverts :
- `CombatSystem` (`scripts/systems/CombatSystem.gd`) — `resolve_combat`/`_execute_damage` appellent directement `AudioManager.play(...)` (autoload non fiable en runner `-s`, voir convention ci-dessous) et `battle.get_tree().create_timer(...)` (nécessite un arbre de scène réel). Untestable en l'état sans un double `SceneTree` déjà utilisé pour `DeathSystem`/`TriggersSystem`, *et* un contournement de l'appel `AudioManager` — soit en l'extrayant derrière une interface injectable, soit en acceptant de tester uniquement la logique privée (`_execute_damage`) en species-casing l'appel audio. À trancher avant de s'y attaquer.
- `TurnSystem` (`scripts/systems/TurnSystem.gd`) — orchestration de tour complète (`end_turn`/`_begin_player_turn`) trop couplée à la scène (`battle.opponent`, `turn_timer`, `tutorial_manager`, `hand`, `deck_button`, `AudioManager.play` dans `draw_card`) pour un test unitaire direct ; seule la sous-logique pure (`_apply_infection_damage`, `run_turn_start_triggers` hors phases UI) serait raisonnablement testable avec un double étendu.
- Le protocole réseau (`scripts/net/`) — sérialisation des commandes, rejeu côté `NetworkOpponent`

Convention établie (voir `tests/unit/doubles/fake_battle.gd`) : charger le script cible directement (`load(...).new()`), éviter la dépendance aux autoloads globaux dans le runner GUT `-s`, et étendre `FakeBattle` plutôt que d'en créer un nouveau par système quand c'est raisonnable (RefCounted réels comme `Graveyard`/`NetRegistry` réutilisés tels quels ; `Node`-based comme `SacrificeSystem`/`TriggerSystem` libérés explicitement via `free()` en `after_each()` pour éviter les nœuds orphelins).

## P2 — Fichiers Steam parasites non ignorés par git

`git status` fait apparaître :
```
addons/godotsteam/win64/~libgodotsteam.windows.template_debug.x86_64.dll
addons/godotsteam/win64/~libgodotsteam.windows.template_debug.x86_64.dll~RFacf7d8.TMP
```
Ce sont des résidus d'extraction de l'archive GodotSteam (fichiers temporaires préfixés `~`). **Fait dans cette branche** : ajout de `addons/godotsteam/**/~*` et `*.TMP` à `.gitignore`. Reste à faire : supprimer ces deux fichiers du working directory local (pas fait ici pour ne pas toucher à l'installation Steam de quelqu'un d'autre sans confirmation).

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

`resources/cards/human/hold-the-line.tres` a un `trigger_types` (Éveil) mais un tableau `effects` vide : le rituel ne fait rien à l'heure actuelle malgré sa description ("tes serviteurs en rangée Avant ne peuvent pas être renvoyés en main ni déplacés par des effets ennemis"). Contrairement aux autres bugs corrigés dans cette branche, celui-ci demande un nouveau statut de protection (vérifié dans `ReturnToHand`/`MoveRow`/`StealMinion`, uniquement quand la source de l'effet appartient au camp adverse à celui du protégé) plutôt qu'un simple champ de filtrage — non fait ici par prudence (risque de mécanique bâclée sans tests dédiés). À reprendre dans une branche dédiée.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
