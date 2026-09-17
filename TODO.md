# TODO — Wyrdane

Liste priorisée issue d'une revue transversale du projet (voir aussi la section « Roadmap » de `README.md` pour la vue produit, et « Notes pour les agents » de `CLAUDE.md` pour les conventions).

## P1 — Couverture de tests quasi nulle en dehors des cartes

**Résolu pour la partie raisonnablement testable.** `tests/unit/` couvre désormais `EffectManager`, `CostSystem`, `AuraSystem`, `SacrificeSystem`, `TriggerSystem`, `DeathSystem`, `CombatSystem` (double `SceneTree`, cf. convention ci-dessous), `TurnSystem` (`_apply_infection_damage`/`run_turn_start_triggers`/`run_turn_end_triggers`), `AISystem`, `DeckSystem`/`DeckData`/`DeckManager`, `BoardSystem`/`BoardVisualSystem`, `DropSystem`, `AnimationSystem`, `VfxManager`, `Graveyard`, `TutorialDeck`, la partie pure de `CollectionManager`/`CurrencyManager` (hors appels réseau), la mutation Abomination, le timer de tour, ainsi que `NetCommand`/`NetRegistry` côté protocole réseau (vocabulaire de commandes + attribution/capture d'ids), en plus des tests `Minion`/`CardLibrary`/`CardData` d'origine (732 tests, tous verts en headless : `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`).

Restent non couverts, jugés hors de portée d'un test unitaire raisonnable (couplage à la scène réelle/Steam plutôt qu'un manque d'effort) :
- `NetworkManager`/`SteamTransport`/`NetworkOpponent` (`scripts/net/`) — dépendent de GodotSteam (P2P réel), d'un `SceneTree` réseau, et rejouent des commandes sur un `Battle` complet ; testable uniquement via un test d'intégration à deux instances Steam, pas un test unitaire.
- `BackendClient`/`AchievementManager`/`MatchResultReporter`/`PackShop` — couplés à `HTTPRequest`/`SteamService`, mêmes limites.

Convention établie (voir `tests/unit/doubles/fake_battle.gd`) : charger le script cible directement (`load(...).new()`), éviter la dépendance aux autoloads globaux dans le runner GUT `-s`, et étendre `FakeBattle` plutôt que d'en créer un nouveau par système quand c'est raisonnable (RefCounted réels comme `Graveyard`/`NetRegistry` réutilisés tels quels ; `Node`-based comme `SacrificeSystem`/`TriggerSystem` libérés explicitement via `free()` en `after_each()` pour éviter les nœuds orphelins).

## P2 — Fichiers Steam parasites non ignorés par git

**Résolu.** Résidus d'extraction de l'archive GodotSteam (fichiers temporaires préfixés `~`/`.TMP`). `addons/godotsteam/**/~*` et `*.TMP` ajoutés à `.gitignore`, et les fichiers parasites supprimés du working directory local.

## P3 — Steam : passage en production

**Page Steamworks validée par Valve.** `SteamService.APP_ID` pointe sur le vrai AppID Wyrdane (5052390), accessible à tout compte Steam sans ajout manuel comme testeur. Reste :
- Pipeline de build/dépôt Steam préparé (hors dépôt `card-game`, dans `sdk/tools/ContentBuilder/` sur le Bureau) : AppID 5052390 / DepotID 5052391 renseignés dans les scripts `.vdf`, `export_presets.cfg` exporte maintenant vers `/build/windows/Wyrdane.exe` (gitignoré) à copier ensuite dans `sdk/tools/ContentBuilder/content/` avant de lancer `run_build.bat`. Reste à renseigner les identifiants du compte partenaire dans `run_build.bat` (non commité) et à passer `"Preview"` de `1` à `0` dans les `.vdf` une fois un premier essai validé
- Métadonnées de l'exe (`application/company_name`, `application/copyright` dans `export_presets.cfg`) encore vides — nom légal du studio à trancher avant une vraie publication
- ~~Invitations d'amis~~ **Déjà implémenté** — vérifié dans le code : `SteamTransport.invite_friends()` (overlay `activateGameOverlayInviteDialog`) câblé bout en bout via `MatchmakingOverlay.start_invite()` (héberge un lobby si besoin, puis ouvre l'overlay dès qu'il est prêt). Cette liste et la roadmap listaient ce point par erreur comme restant à faire.
- Effort : moyen mais surtout administratif (hors code).

## P4 — Incohérence mineure de comptage de cartes

**Re-résolu (revue du 2026-09-14).** Le compte réel des `.tres` dans `resources/cards/` (hors Arena, `arena_only = true`) est 320 : 80 Mort-Vivant dont 4 jetons, 81 Humain dont 5 jetons, **80** Démon dont **4** jetons, 79 Abomination dont 3 jetons. `CLAUDE.md`/`CARDS.md` annonçaient encore 77/1 pour Démon et 317/13 au total (régression depuis la précédente correction de ce point — 3 jetons Démon ajoutés depuis sans mise à jour des comptages). Corrigé dans `CLAUDE.md`/`CARDS.md`. À revérifier lors de la prochaine carte ajoutée/retirée.

## P5 — Elfe / Nain : scaffolding minimal

Seuls les enums `Race.Type.ELF` et `Race.Type.DWARF` existent (`scripts/data/Race.gd`). Aucun fichier `KeywordElf.gd`/`KeywordDwarf.gd`, aucun dossier `resources/cards/elf|dwarf/`, aucune entrée dans `CARDS.md`. Chantier de design complet à faire avant tout code (mots-clés propres à définir dans `README.md` d'abord, comme convenu pour toute nouvelle race/mot-clé).

**Premier jet posé.** Un brouillon de mots-clés/thème (« 🧝 Elfe & 🪓 Nain — proposition de design », dans `README.md`, juste après la section Abomination) propose une identité mécanique pour chaque race (Elfe : embuscade/ruse/repositionnement ; Nain : fortification/forge/réduction de dégâts cumulable), explicitement marqué non validé — aucun code, aucun `Keyword*.gd`, aucune carte tant que la proposition n'est pas retenue/ajustée par une décision produit.

## P6 — Ordre de Tenir (Humain, H53) : effet non implémenté

**Résolu.** Corrigé dans le commit `8e75cc8` (« fix: make non-functional cards work ») avec Fortification (déplacement/transformation), l'appariement de trigger de War Priest et l'`effect_id` de dégâts explicite. Le rituel applique désormais bien la protection contre le renvoi en main / déplacement par effet ennemi pour les serviteurs alliés en rangée Avant.

## P7 — Options d'accessibilité étendues

**Résolu.** Ajout de 4 options d'accessibilité dans le menu Réglages (`SettingsManager.gd`, `GraphismSettingsMenu`) : contraste élevé (overlay shader dédié), réduction des animations (shake désactivé, tweens de déplacement raccourcis à 35 %), symbole de rareté sur le bandeau de type des cartes, icône d'alerte sous 30 % HP héros. Rebind clavier déjà générique (`ControlSettingsMenu.gd`) mais limité aux 3 seules actions ayant un raccourci clavier dans le projet — rien d'autre à étendre pour l'instant ; si de nouvelles actions clavier sont ajoutées au jeu, penser à les inscrire dans `SettingsManager.REBINDABLE_ACTIONS`.

## P8 — Quêtes hebdomadaires & parrainage

**Résolu.** Contrat (`docs/backend-contracts/weekly-quests-and-referral.md`), routes backend (`wyrdane-backend`, branche `0044-weekly-quests-and-referral` : `/api/quests/weekly`, `/api/packs/open-owned`, `/api/referral/*`) et squelette client (`QuestsPanel._populate_weekly`, `ReferralPanel.gd`, `CurrencyManager.free_packs`/`open_owned_pack`) tous en place. Bouton « Ouvrir un pack gratuit » câblé dans `PackShop.tscn`/`PackShop.gd` (visible seulement si `free_packs > 0`). Popup « entrer un code de parrainage » affiché une seule fois (`SettingsManager.referral_prompt_seen`) juste après la fin du tutoriel (`ReferralPanel.maybe_show_first_launch_prompt`, appelé depuis `MainMenu._launch_backend_syncs`), en plus du champ resté dans la vue Profil pour un usage tardif. Déployé en prod le 2026-09-12 (table de schéma synchronisée sur le VPS) — ces écrans fonctionnent désormais réellement en jeu.

## P9 — Backend : aucune preuve serveur qu'un match a réellement eu lieu

Audit de sécurité (2026-09-06) : `POST /api/rewards/solo-match` et `POST /api/ranked/matches/report` (`wyrdane-backend`) acceptent un résultat de match auto-déclaré par le client (`result`, `cardsPlayedByRace`, `deckRaces`) sans aucun lien vérifiable à une vraie session Steam P2P. Un script (ou deux comptes colludés côté ranked, via un double-report concordant) peut fabriquer des rapports fictifs pour farmer quêtes/MMR/or. Mitigation déjà en place (branche `0051-security-hardening` du backend) : rate-limiting par utilisateur sur ces deux routes + bornage des valeurs déclarées (races inconnues et compteurs absurdes rejetés) — réduit l'ampleur d'un abus mais ne le rend pas impossible.

**Volet classé résolu côté code, pas encore actif en prod.** Branche `0055-signed-match-session-token` (`wyrdane-backend`) : `matchmakingModel.pairTickets` émet désormais un jeton signé (`matchId` serveur + les deux `user_id`, TTL 30 min, `helper/matchSessionToken.ts`) au moment même de l'appariement classé, renvoyé aux deux clients via le poll de file existant. Côté `card-game` : `MatchmakingOverlay` récupère ce `match_id`/`match_session_token`, l'utilise comme `client_match_id` faisant foi (au lieu de celui dérivé localement par `NetHandshake`) et le fait transiter jusqu'à `BackendClient.report_ranked_match`. `rankedController.reportMatch` vérifie le jeton quand il est présent, mais **ne rejette pas encore** un rapport qui en est dépourvu (`ENFORCE_MATCH_SESSION_TOKEN=false` par défaut, soft mode — seulement journalisé) : la version actuellement déployée en prod n'envoie pas encore ce jeton, un rejet immédiat casserait le classé en production. À faire pour activer réellement la protection : déployer les deux branches (backend + ce commit client), confirmer que les rapports en prod portent bien le jeton, puis ne passer `ENFORCE_MATCH_SESSION_TOKEN=true` qu'à ce moment-là.

Volet solo (`POST /api/rewards/solo-match`) non couvert par ce mécanisme et volontairement laissé de côté : pas d'appariement backend à faire foi contre l'IA (pas d'adversaire réseau), seul le bornage des valeurs déclarées s'applique.

## P10 — Gel de partie possible en cours de tour IA (cause racine non identifiée)

Signalé par l'utilisateur (2026-09-17) : après un certain temps de jeu contre l'IA, la partie se fige entièrement (fenêtre "ne répond plus" sous Windows). Le log Godot de la session concernée (`godot2026-09-16T13.54.30.log`) s'arrête net sans aucune erreur ni stack trace — cohérent avec une boucle qui ne se termine jamais plutôt qu'un vrai crash (ce genre de blocage n'écrit rien dans les logs). `AISystem.take_turn()` enchaîne plusieurs phases avec des `while` dont la sortie dépend d'une condition (`_play_cards_phase`, `_attack_phase`) : un candidat plausible non confirmé est la mécanique Humain Contre-Offensive (`CombatSystem._execute_damage`, `attacker.attacks_remaining += 1` à chaque kill, net nul une fois `consume_attack()` appliqué) qui pourrait, dans un enchaînement de kills ininterrompu, ne jamais laisser `attacks_remaining` retomber à 0.

**Mitigé, pas résolu.** `AISystem.take_turn()` a désormais le même filet de sécurité que `TutorialOpponent.MAX_TURN_SAFETY` (déjà en place là-bas, jamais répliqué côté IA normale) : le tour est sondé avec une limite de 30s, au-delà de laquelle la main est rendue de force (`push_warning` loggé) au lieu de bloquer la partie indéfiniment. N'élimine pas la cause racine si elle existe ailleurs qu'une boucle qui cède la main à chaque itération (un vrai verrou synchrone sans `await` ne serait pas intercepté par ce filet). À surveiller : si le warning `AISystem: le tour adverse n'a pas terminé dans le délai prévu` apparaît en jeu, il pointera vers la phase exacte en cause pour une investigation ciblée.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
