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

## P10 — Gel de partie possible en cours de tour IA

**Résolu (2026-09-18).**

Signalé par l'utilisateur (2026-09-17) : après un certain temps de jeu contre l'IA, la partie se fige entièrement (fenêtre "ne répond plus" sous Windows). Le log Godot de la session concernée (`godot2026-09-16T13.54.30.log`) s'arrête net sans aucune erreur ni stack trace — cohérent avec une boucle qui ne se termine jamais plutôt qu'un vrai crash (ce genre de blocage n'écrit rien dans les logs). `AISystem.take_turn()` enchaîne plusieurs phases avec des `while` dont la sortie dépend d'une condition (`_play_cards_phase`, `_attack_phase`) : un candidat plausible non confirmé est la mécanique Humain Contre-Offensive (`CombatSystem._execute_damage`, `attacker.attacks_remaining += 1` à chaque kill, net nul une fois `consume_attack()` appliqué) qui pourrait, dans un enchaînement de kills ininterrompu, ne jamais laisser `attacks_remaining` retomber à 0.

**Mitigé, pas résolu.** `AISystem.take_turn()` a désormais le même filet de sécurité que `TutorialOpponent.MAX_TURN_SAFETY` (déjà en place là-bas, jamais répliqué côté IA normale) : le tour est sondé avec une limite de 30s, au-delà de laquelle la main est rendue de force (`push_warning` loggé) au lieu de bloquer la partie indéfiniment. N'élimine pas la cause racine si elle existe ailleurs qu'une boucle qui cède la main à chaque itération (un vrai verrou synchrone sans `await` ne serait pas intercepté par ce filet). À surveiller : si le warning `AISystem: le tour adverse n'a pas terminé dans le délai prévu` apparaît en jeu, il pointera vers la phase exacte en cause pour une investigation ciblée.

**Diagnostic renforcé (2026-09-17).** Signalement utilisateur d'un nouveau cas (tours IA très longs + warning de sécurité déclenché, sans figer complètement grâce au filet ci-dessus). Le message ne pointait jusqu'ici vers aucune phase précise malgré ce qu'annonçait la note ci-dessus — corrigé : `AISystem._current_phase` (mis à jour à chaque étape de `_run_turn_actions`/`_play_cards_phase`/`_attack_phase`, y compris le nom de la carte posée ou du serviteur qui attaque) est désormais inclus dans le `push_warning`. Au prochain déclenchement, le log dira concrètement sur quelle carte/attaquant l'IA était bloquée. Cause racine toujours à confirmer.

**Élément de réponse (2026-09-18) : pas forcément un blocage, juste de l'accumulation.** Le warning suivant loggé par l'utilisateur pointait sur la phase `'done'` — c'est-à-dire que `_run_turn_actions` avait bel et bien fini de s'exécuter, juste après l'expiration des 30s (course entre `finished = true` et la sonde `elapsed < MAX_TURN_SAFETY_SECONDS`). Autrement dit ce cas précis n'était pas une vraie boucle infinie mais un tour légitimement lent qui frôle la limite : chaque action IA (pose de carte, attaque) attend `Battle.pace_actions()` (`Battle.ACTION_PACE`, partagé avec `NetworkOpponent`/`TriggerSystem`/`TurnSystem`) en plus de ses propres animations/popups — un tour avec beaucoup de cartes/attaques additionne facilement 15-30s rien qu'en pauses de rythme. `ACTION_PACE` réduit de 1.0s à 0.5s pour alléger l'accumulation sur un gros tour (voir commit `perf: halve pacing delay between opponent/AI actions`). N'exclut pas qu'un vrai cas de blocage (boucle infinie) existe par ailleurs — à surveiller si le warning revient avec une phase autre que `'done'`/`'attack_phase'`/`'play_cards_phase'` en fin de liste jouable.

**Deuxième passe (2026-09-18) : la popup d'effet dominait le total, pas seulement `ACTION_PACE`.** Signalement confirmé par l'utilisateur : ~20s entre les actions et la fin de tour même sans carte Pacte impliquée. Chaque serviteur à Arrivée posé par l'IA passe par `CardPopupSystem.show_card_popup` (`READ_HOLD` 0.4s + `DISPLAY_DURATION` 0.9s = 1.3s, volontairement allongé la semaine précédente pour la lisibilité des propres sorts du joueur) en plus de `ACTION_PACE`/l'animation de vol/le délai fixe de `BoardSystem.summon_minion_return` (0.2s) — un tour avec 5-6 serviteurs à effet plus quelques attaques additionne bien ~20s. Plutôt que de revenir sur le réglage de lisibilité récent (qui reste voulu pour les propres cartes du joueur), `CardPopupSystem` réduit désormais de moitié (`ENEMY_TURN_HOLD_SCALE = 0.5`) le temps d'affichage de ses popups (`show_card_popup`/`show_effect_arrows`) tant que `battle.enemy_turn_active` est vrai — le joueur est spectateur pendant le tour adverse, il n'a pas besoin du même temps de lecture que pour ses propres décisions.

**Quatrième passe (2026-09-18) : l'utilisateur précise qu'aucun effet/popup ne s'affiche pendant cette attente — la piste Déclin ci-dessus était donc insuffisante ou fausse sur son cas.** Plutôt que de continuer à deviner, instrumentation temporaire ajoutée (`print` par étape de tour, seuil 300ms) pour localiser la vraie étape en cause au prochain rapport de log.

**Cause racine trouvée et corrigée (2026-09-18), grâce au log fourni par l'utilisateur (`godot.log`).** Les logs de l'instrumentation ci-dessus ont montré que `opponent.take_turn()` prenait systématiquement 29999-30000ms — littéralement à chaque tour, pas seulement dans un cas limite — avec le warning de sécurité qui se déclenchait à chaque fois (`bloqué sur 'done'`), alors que les étapes individuelles du tour se terminaient toutes en ~1s. Bug trouvé : `AISystem.take_turn()`
```gdscript
var finished := false
_run_turn_actions(func(): finished = true)
...
while not finished and elapsed < MAX_TURN_SAFETY_SECONDS: ...
```
capture `finished` **par valeur** dans la lambda (comportement des closures GDScript, PAS par référence) — `finished = true` à l'intérieur du callback ne mutait donc jamais la variable de `take_turn()`, et la boucle d'attente patientait systématiquement les 30 secondes complètes avant de rendre la main de force, quelle que soit la rapidité réelle du tour. **C'est très exactement le même bug déjà rencontré et corrigé une fois sur `PactChoiceSystem.ask`** (voir son commentaire `state["done"]`) — non repéré ici lors de l'ajout du filet de sécurité. Corrigé en remplaçant le `bool` local par un `Dictionary` partagé (`state := {"finished": false}`), type par référence en GDScript. Explique aussi bien le signalement initial de "gel" (2026-09-17) que "l'attente sans rien" (2026-09-18) : chaque tour IA perdait bêtement ~28-29s à ne rien faire après avoir réellement terminé son travail en ~1-2s. L'instrumentation temporaire de la passe précédente a été retirée une fois la cause confirmée.

**Troisième passe (2026-09-18) : l'attente précise décrite par l'utilisateur (après la dernière action visible, avant que le tour ne passe vraiment) venait du Déclin ennemi — hypothèse non confirmée, voir passe suivante.** `battle.enemy_turn_active` repasse à `false` dès la fin de `AISystem.take_turn()` (dans `take_turn()` lui-même) — mais `TurnSystem._begin_player_turn()`, appelé juste après par `end_turn()`, déclenche encore le trigger Déclin (`OnDecline`) des serviteurs ennemis restés en jeu (`_trigger_minions_paced(other_minions, "OnDecline", ...)`) ET les enchantements adverses qui y réagissent. Ces popups se jouaient donc à pleine durée (le flag `enemy_turn_active` scalant `CardPopupSystem` était déjà retombé à `false`), juste après la dernière attaque visible de l'IA — exactement la fenêtre décrite comme « attente avant la fin du tour ». Corrigé : `CardPopupSystem._hold_scale()` se base désormais sur le camp propriétaire de la source (`source_minion`/proxy d'enchantement) quand elle est connue, plutôt que sur `enemy_turn_active` — un Déclin ennemi reste donc à durée réduite même une fois ce flag retombé, tandis qu'un Éveil du joueur (même fenêtre, son propre camp) garde sa pleine lisibilité.

**Correctif connexe (2026-09-17), mécanique Pacte.** Repéré pendant cette investigation, sans lien de cause avec le point ci-dessus : `EffectManager._resolve_pact_payment` jouait l'animation de drain (`AnimationSystem.play_pact_drain`) dès qu'un Pacte était accepté, même quand `HeroSystem.self_damage` annulait entièrement les PV perdus (Le Gardien du Pacte Brisé en jeu côté payeur, ou Absolution Écarlate ce tour) — donnant l'impression que le bonus avait été obtenu gratuitement sans que le joueur/l'IA n'ait « payé » quoi que ce soit de visible, alors que le choix avait bien été honoré. L'animation ne se joue désormais que si `self_damage()` retourne des dégâts réellement infligés (`> 0`).

**Télémétrie ajoutée.** `CrashReporter` (voir « Rapport de plantage/gel » dans `CLAUDE.md`) détecte désormais toute session qui ne s'est pas terminée proprement (plantage réel ou gel tué via le gestionnaire des tâches) et propose au joueur d'envoyer le dernier log, transmis sur le salon Discord de développement via `wyrdane-backend` (`POST /api/crash-report`). Ça ne corrige rien par soi-même, mais donne enfin une source de logs réels de joueurs pour identifier la cause exacte d'un futur gel — condition nécessaire avant de pouvoir vraiment fermer ce point.

## P11 — Écran Statistiques : backend écrit mais pas encore déployé

**Résolu, puis revu.** Backend (`wyrdane-backend`, branche `0065-card-stats-and-leaderboard`) mergé dans `main` et déployé (table `card_play_stats`, colonne `match_reports.cards_played`). Le classement MMR est resté en jeu (écran « Classement », `StatsPanel.gd`), mais les statistiques de cartes (taux de jeu/winrate) ont été retirées de l'écran en jeu et déplacées vers un dashboard admin sur `wyrdane-website` (`/admin/card-stats`, `GET /api/admin/card-stats`, `requireAdmin`) — donnée d'équilibrage interne, pas destinée aux joueurs. Voir « 📊 Statistiques & classement » dans `README.md` et `docs/backend-contracts/card-stats-and-leaderboard.md`.

## P12 — Classement par palier : backend écrit, pas encore mergé/déployé

Refonte du panneau « Classement » côté client (`StatsPanel.gd`) : 4 onglets
de palier (Bronze/Argent/Or/Légende) au lieu d'un top-100 plat, ouverture
centrée sur la position du joueur local, recherche de joueur, avatars Steam,
bannières or/argent/bronze pour le top 3 de chaque palier. Nécessite le
backend de la branche `wyrdane-backend` `0072-ranked-leaderboard-browse`
(**pas encore mergée dans `main`, donc pas déployée**) : enveloppe
`{ total, players }` + `rank`/`steam_id` sur `GET /api/ranked/leaderboard`,
et les nouvelles routes `/leaderboard/me`, `/leaderboard/around-me`,
`/leaderboard/search`. Tant que cette branche n'est pas mergée et déployée
sur le VPS, l'écran en jeu affichera des échecs de chargement (404/ancien
format de réponse) en prod. Voir `docs/backend-contracts/card-stats-and-leaderboard.md`
section 5.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée.
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
