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

`SteamService.APP_ID` pointe maintenant sur le vrai AppID Wyrdane (5052390) — la page Steamworks est créée mais **en attente de validation par Valve**. Reste :
- Attendre la validation Valve de la page Steam
- D'ici là, seuls les comptes ajoutés comme testeurs Steamworks (« Users with access ») peuvent s'authentifier avec cet AppID ; les autres doivent repasser temporairement sur l'AppID de test 480 (Spacewar) en local
- Pipeline de build/dépôt Steam préparé (hors dépôt `card-game`, dans `sdk/tools/ContentBuilder/` sur le Bureau) : AppID 5052390 / DepotID 5052391 renseignés dans les scripts `.vdf`, `export_presets.cfg` exporte maintenant vers `/build/windows/Wyrdane.exe` (gitignoré) à copier ensuite dans `sdk/tools/ContentBuilder/content/` avant de lancer `run_build.bat`. Reste à renseigner les identifiants du compte partenaire dans `run_build.bat` (non commité) et à passer `"Preview"` de `1` à `0` dans les `.vdf` une fois un premier essai validé
- Métadonnées de l'exe (`application/company_name`, `application/copyright` dans `export_presets.cfg`) encore vides — nom légal du studio à trancher avant une vraie publication
- Invitations d'amis
- Effort : moyen mais surtout administratif (hors code).

## P4 — Incohérence mineure de comptage de cartes

**Résolu dans cette branche.** Le compte réel des `.tres` dans `resources/cards/` est désormais 317 (80 Mort-Vivant dont 4 jetons, 81 Humain dont 5 jetons, 77 Démon dont 1 jeton, 79 Abomination dont 3 jetons) — `README.md` et `CLAUDE.md` annonçaient encore 226/227/303. Deux cartes-jetons Abomination (« Amas Informe Mutant », « Amas Informe Reformé ») existaient dans `resources/cards/abomination/` sans ligne correspondante dans `CARDS.md` ; ajoutées (A78/A79). Comptages mis à jour dans `README.md`, `CLAUDE.md` et `CARDS.md`. À revérifier lors de la prochaine carte ajoutée/retirée.

## P5 — Elfe / Nain : scaffolding minimal

Seuls les enums `Race.Type.ELF` et `Race.Type.DWARF` existent (`scripts/data/Race.gd`). Aucun fichier `KeywordElf.gd`/`KeywordDwarf.gd`, aucun dossier `resources/cards/elf|dwarf/`, aucune entrée dans `CARDS.md`. Chantier de design complet à faire avant tout code (mots-clés propres à définir dans `README.md` d'abord, comme convenu pour toute nouvelle race/mot-clé).

## P6 — Ordre de Tenir (Humain, H53) : effet non implémenté

**Résolu.** Corrigé dans le commit `8e75cc8` (« fix: make non-functional cards work ») avec Fortification (déplacement/transformation), l'appariement de trigger de War Priest et l'`effect_id` de dégâts explicite. Le rituel applique désormais bien la protection contre le renvoi en main / déplacement par effet ennemi pour les serviteurs alliés en rangée Avant.

## P7 — Options d'accessibilité étendues

**Résolu.** Ajout de 4 options d'accessibilité dans le menu Réglages (`SettingsManager.gd`, `GraphismSettingsMenu`) : contraste élevé (overlay shader dédié), réduction des animations (shake désactivé, tweens de déplacement raccourcis à 35 %), symbole de rareté sur le bandeau de type des cartes, icône d'alerte sous 30 % HP héros. Rebind clavier déjà générique (`ControlSettingsMenu.gd`) mais limité aux 3 seules actions ayant un raccourci clavier dans le projet — rien d'autre à étendre pour l'instant ; si de nouvelles actions clavier sont ajoutées au jeu, penser à les inscrire dans `SettingsManager.REBINDABLE_ACTIONS`.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
