# TODO — Wyrdane

Liste priorisée issue d'une revue transversale du projet (voir aussi la section « Roadmap » de `README.md` pour la vue produit, et « Notes pour les agents » de `CLAUDE.md` pour les conventions).

## P1 — Couverture de tests quasi nulle en dehors des cartes

**Résolu pour la partie raisonnablement testable.** `tests/unit/` couvre désormais `EffectManager`, `CostSystem`, `AuraSystem`, `SacrificeSystem`, `TriggerSystem`, `DeathSystem`, `CombatSystem` (double `SceneTree`, cf. convention ci-dessous), `TurnSystem` (`_apply_infection_damage`/`run_turn_start_triggers`/`run_turn_end_triggers`), `AISystem`, `DeckSystem`/`DeckData`/`DeckManager`, `BoardSystem`/`BoardVisualSystem`, `DropSystem`, `AnimationSystem`, `VfxManager`, `Graveyard`, `TutorialDeck`, la partie pure de `CollectionManager`/`CurrencyManager` (hors appels réseau), la mutation Abomination, le timer de tour, ainsi que `NetCommand`/`NetRegistry` côté protocole réseau (vocabulaire de commandes + attribution/capture d'ids), en plus des tests `Minion`/`CardLibrary`/`CardData` d'origine (867 tests répartis sur 76 scripts, tous verts en headless : `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`).

Restent non couverts, jugés hors de portée d'un test unitaire raisonnable (couplage à la scène réelle/Steam plutôt qu'un manque d'effort) :
- `NetworkManager`/`SteamTransport`/`NetworkOpponent` (`scripts/net/`) — dépendent de GodotSteam (P2P réel), d'un `SceneTree` réseau, et rejouent des commandes sur un `Battle` complet ; testable uniquement via un test d'intégration à deux instances Steam, pas un test unitaire.
- `BackendClient`/`AchievementManager`/`MatchResultReporter`/`PackShop` — couplés à `HTTPRequest`/`SteamService`, mêmes limites.

Convention établie (voir `tests/unit/doubles/fake_battle.gd`) : charger le script cible directement (`load(...).new()`), éviter la dépendance aux autoloads globaux dans le runner GUT `-s`, et étendre `FakeBattle` plutôt que d'en créer un nouveau par système quand c'est raisonnable (RefCounted réels comme `Graveyard`/`NetRegistry` réutilisés tels quels ; `Node`-based comme `SacrificeSystem`/`TriggerSystem` libérés explicitement via `free()` en `after_each()` pour éviter les nœuds orphelins).

## P2 — Fichiers Steam parasites non ignorés par git

**Résolu.** Résidus d'extraction de l'archive GodotSteam (fichiers temporaires préfixés `~`/`.TMP`). `addons/godotsteam/**/~*` et `*.TMP` ajoutés à `.gitignore`, et les fichiers parasites supprimés du working directory local.

## P3 — Steam : passage en production

**Page Steamworks validée par Valve.** `SteamService.APP_ID` pointe sur le vrai AppID Wyrdane (5052390), accessible à tout compte Steam sans ajout manuel comme testeur. Reste :
- Pipeline de build/dépôt Steam préparé (hors dépôt `card-game`, dans `sdk/tools/ContentBuilder/` sur le Bureau) : AppID 5052390 / DepotID 5052391 renseignés dans les scripts `.vdf`, `export_presets.cfg` exporte maintenant vers `/build/windows/Wyrdane.exe` (gitignoré) à copier ensuite dans `sdk/tools/ContentBuilder/content/` avant de lancer `run_build.bat`. Reste à renseigner les identifiants du compte partenaire dans `run_build.bat` (non commité) et à passer `"Preview"` de `1` à `0` dans les `.vdf` une fois un premier essai validé
- ~~Métadonnées de l'exe~~ **déjà renseignées** (vérifié le 2026-09-26) :
  `application/company_name` = `Nertari Studio` et `application/copyright` =
  `© 2026 Nertari Studio` dans `export_presets.cfg`. Cette entrée affirmait
  l'inverse depuis longtemps, à tort.
  **Point à trancher malgré tout** : l'éditeur annoncé au joueur n'est pas le
  même des deux côtés — `MENU_LEGAL_BODY` (mentions légales en jeu, via
  `translations/game.csv`) dit « Éditeur : Amnertaris », là où les métadonnées de
  l'exe disent `Nertari Studio`. Si c'est délibéré (pseudonyme d'auteur d'un
  côté, raison sociale de l'autre), rien à faire ; sinon, aligner les deux avant
  publication.
- **Textes des succès prêts** : `docs/steam-achievements.md` contient les 21
  API Names avec leurs libellés FR/EN et la condition exacte de déclenchement de
  chacun, directement collables dans le dashboard. Restent les icônes et la
  saisie. À noter : le projet annonçait « 20 succès » un peu partout, alors que
  `AchievementManager.gd` en définit **21** (`ACH_FULL_ROSTER` avait été ajouté
  sans mettre les comptages à jour) — corrigé dans `CLAUDE.md`/`README.md`.
- **Résolu (2026-09-24)** : versionning (`VERSION.txt`, `AppVersion.gd`, affichage dynamique dans `MainMenu`) — voir « Versionning » dans `CLAUDE.md`. Penser à lancer `tools/bump_version.ps1` avant chaque build Steam.
- ~~Invitations d'amis~~ **Déjà implémenté** — invitation ciblée d'un ami Wyrdane via le panneau Amis (`MatchmakingOverlay.invite_friend`, table `game_invites` côté `wyrdane-backend`), remplace depuis le 2026-09-25 l'ancien overlay Steam natif (`activateGameOverlayInviteDialog`, retiré). Voir « Multijoueur (1v1 réseau) » dans `CLAUDE.md`.
- Effort : moyen mais surtout administratif (hors code).

## P4 — Incohérence mineure de comptage de cartes

**Re-résolu (revue du 2026-09-14).** Le compte réel des `.tres` dans `resources/cards/` (hors Arena, `arena_only = true`) est 320 : 80 Mort-Vivant dont 4 jetons, 81 Humain dont 5 jetons, **80** Démon dont **4** jetons, 79 Abomination dont 3 jetons. `CLAUDE.md`/`CARDS.md` annonçaient encore 77/1 pour Démon et 317/13 au total (régression depuis la précédente correction de ce point — 3 jetons Démon ajoutés depuis sans mise à jour des comptages). Corrigé dans `CLAUDE.md`/`CARDS.md`. À revérifier lors de la prochaine carte ajoutée/retirée. **Recompté le 2026-09-26** : 332 `.tres` dans `resources/cards/` moins 12 `arena_only` = **320 cartes**, dont 16 jetons — conforme à ce qu'annoncent `CLAUDE.md` et `CARDS.md` (`README.md`, qui affichait encore 317, a été corrigé).

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

**Volet classé résolu et désormais actif.** Branche `0055-signed-match-session-token` (`wyrdane-backend`) : `matchmakingModel.pairTickets` émet désormais un jeton signé (`matchId` serveur + les deux `user_id`, TTL 30 min, `helper/matchSessionToken.ts`) au moment même de l'appariement classé, renvoyé aux deux clients via le poll de file existant. Côté `card-game` : `MatchmakingOverlay` récupère ce `match_id`/`match_session_token`, l'utilise comme `client_match_id` faisant foi (au lieu de celui dérivé localement par `NetHandshake`) et le fait transiter jusqu'à `BackendClient.report_ranked_match`. `rankedController.reportMatch` vérifie le jeton et, quand `ENFORCE_MATCH_SESSION_TOKEN=true`, rejette tout rapport qui en est dépourvu (sinon : simple journalisation en soft mode, le temps qu'un client transmettant le jeton soit déployé — c'était le cas jusqu'au 2026-09-24). **Activé le 2026-09-26** (branche `0087-security-hardening` du backend) : `ENFORCE_MATCH_SESSION_TOKEN: "true"` est désormais fixé dans `docker-compose.yml`, le client qui transmet le jeton étant déployé depuis le 2026-09-24. **Avant de déployer cette branche**, vérifier dans les logs de prod qu'aucune ligne `reportMatch sans jeton de session valide (soft mode)` n'apparaît plus : s'il en reste, des clients non mis à jour sont encore en circulation et leurs rapports classés commenceraient à être rejetés.

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

## P11 — Écran Statistiques / Classement

**Résolu, puis revu.** Backend (`wyrdane-backend`, branche `0065-card-stats-and-leaderboard`) mergé dans `main` et déployé (table `card_play_stats`, colonne `match_reports.cards_played`). Le classement MMR est resté en jeu (écran « Classement », `StatsPanel.gd`), mais les statistiques de cartes (taux de jeu/winrate) ont été retirées de l'écran en jeu et déplacées vers un dashboard admin sur `wyrdane-website` (`/admin/card-stats`, `GET /api/admin/card-stats`, `requireAdmin`) — donnée d'équilibrage interne, pas destinée aux joueurs. Voir « 📊 Statistiques & classement » dans `README.md` et `docs/backend-contracts/card-stats-and-leaderboard.md`.

## P12 — Classement par palier

**Résolu (vérifié le 2026-09-26).** La branche `wyrdane-backend`
`0072-ranked-leaderboard-browse` est mergée dans `main` et déployée
(`GET /api/ranked/leaderboard` répond en prod, tout comme `/leaderboard/me`,
`/around-me` et `/search`). L'historique ci-dessous est conservé pour mémoire.

### Historique

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

## P13 — MMR caché Normal / MMR public Classé + validation Steam réelle

**Code déployé des deux côtés (vérifié le 2026-09-26)** : la branche backend
`0078-ranked-normal-hidden-mmr` est mergée dans `main` et déployée, et
`GET /api/matchmaking/queue/status` répond en prod. **Il reste un point ouvert,
et c'est le plus important du projet** : rien de tout cela n'a jamais été
éprouvé avec deux comptes Steam réels (voir la fin de cette section). Si un
doute subsiste sur le schéma de prod, vérifier la présence de
`ranked_stats.hidden_mmr`, `matchmaking_tickets.mode` et `match_reports.mode`
avant de chercher un bug côté client (voir « Incident sync DB chat/amis »).

**Contexte d'origine.** Avant cette tâche, n'importe quelle partie réseau (Normal, Contre un
ami, Classé) modifiait le MMR public (`ranked_stats.mmr`) — aucune distinction
côté backend. Désormais `report_ranked_match` porte un champ `mode` et seul le
Classé touche à `ranked_stats.mmr`/`wins`/`losses` ; Normal (et tout ce qui
n'est pas explicitement classé) met à jour un MMR **caché** séparé
(`ranked_stats.hidden_mmr`, jamais exposé au client) utilisé uniquement pour
apparier des Normal de niveau similaire — voir « Ranked / paliers /
matchmaking classé » plus haut pour le détail (`_queue_mode`,
`NORMAL_QUEUE_TIMEOUT`, repli silencieux sur l'ancien comportement direct si
le backend est indisponible).

Reste à faire :
- ~~Migration DB~~ / ~~Merge + déploiement~~ : **faits** (voir l'encadré en tête
  de section). Si un symptôme évoque une colonne absente, vérifier le schéma de
  prod avant de suspecter le client.
- **Jamais testé en conditions Steam réelles** (comme tout ce qui touche au
  matchmaking, nécessite deux comptes Steam) : en particulier le repli Normal
  → recherche directe après `NORMAL_QUEUE_TIMEOUT`/échec backend, et le
  réessai de `queue_report_lobby` (voir bug ci-dessous).
- Le bug historique « partie qui ne se lance jamais entre deux amis qui
  viennent de la lancer » a enfin une **cause confirmée** (2026-09-25,
  diagnostiquée sur les logs réels des deux joueurs) : fermer un transport
  quitte le lobby Steam en cours (`NetworkManager._setup_transport` →
  `SteamTransport.close`), donc chaque nouvelle tentative rendait injoignable
  le lobby que l'autre était en train de rejoindre → « entrée refusée
  (code 2) » (*lobby inexistant*) des deux côtés, en boucle, y compris sur une
  invitation explicite. Corrigé : invitation rendue intouchable par le
  matchmaking automatique, relances plafonnées, `HOST_PEER_WAIT_TIMEOUT` 30 →
  60s, délai court de la file plus appliqué à un ticket déjà apparié — voir
  « Robustesse de l'entrée en partie » dans `CLAUDE.md`. La piste précédente
  (échec silencieux de `queue_report_lobby`, corrigée par réessai + message
  explicite dans `MatchmakingOverlay._report_queue_lobby`) reste valable mais
  n'était pas la cause principale.
- **Correctif de fond (2026-09-25, après le précédent)** : la cause profonde
  n'était pas un bug isolé mais **deux systèmes de mise en relation en
  parallèle** sur le mode Normal (file backend + recherche directe dans la liste
  de lobbies Steam en repli), chacun avec ses minuteurs et chacun capable de
  détruire le lobby vivant de l'autre. Le second chemin est supprimé : la file
  backend est le seul point de rendez-vous, `SteamTransport.join()` exige un
  `lobby_id`. Voir « File backend = seul point de rendez-vous » dans
  `CLAUDE.md`. Conséquence assumée : **Normal exige désormais le backend**.
- **À confirmer en conditions réelles** (deux comptes Steam) : que ces deux
  correctifs suffisent réellement à enchaîner plusieurs parties d'affilée entre
  deux amis, sur invitation depuis la liste d'amis comme en « Normal ». Le log d'une partie
  affiche en clair chaque fermeture de transport (`[NetworkManager] Transport
  précédent fermé…`) : sa présence entre la création d'un lobby et l'arrivée du
  pair signale immédiatement une rechute.
- **Suite possible, pas faite** : confier l'arbitrage des reprises au backend
  (aujourd'hui, sur un join refusé, c'est le client qui se remet en file, voir
  `MAX_AUTO_JOIN_RETRIES`) — une route qui invalide l'appariement et remet les
  DEUX tickets en file éviterait que chaque client décide seul. Pas nécessaire
  tant que le chemin unique suffit ; à reconsidérer si des échecs d'appariement
  réapparaissent en conditions réelles.
- **Charge** : la file backend devient le seul point de passage de toute mise en
  relation. Le coût dominant est le poll à `RANKED_POLL_INTERVAL` (2s) ; estimé
  à ~25-100 req/s pour 1000 joueurs simultanés (500 req/s au pire cas si tous
  cherchent en même temps), a priori tenable sur le VPS puisque les parties
  elles-mêmes restent en P2P. À valider par un load test (`k6`/`autocannon`)
  avant la sortie.
  Point chaud identifié en lisant le code (2026-09-25) : `matchmakingModel.
  findOpponent` fait `SELECT * FROM matchmaking_tickets WHERE status='waiting'
  AND mode=? AND user_id!=? ... FOR UPDATE`, donc il **verrouille tous les
  tickets en attente du mode** à chaque poll de chaque joueur. L'appariement
  lui-même est correct (transaction + lignes verrouillées, pas de course), mais
  à 500 joueurs qui pollent toutes les 2s, tous les polls se sérialisent sur les
  mêmes lignes. Remèdes, dans cet ordre : restreindre la plage de MMR dans le
  `WHERE` (au lieu de filtrer en JS après coup) + index sur
  `matchmaking_tickets (mode, status, created_at)` ; vérifier la taille du pool
  de connexions MySQL ; et un backoff du poll côté client (2s les 10 premières
  secondes puis 4-5s) qui diviserait la charge par deux ou trois. Indolore à
  l'échelle actuelle — à traiter seulement si le load test le confirme.
- **Apparier sur le palier affiché plutôt que sur le MMR brut** (façon
  Hearthstone/MTGA : rang/division en classé, MMR caché en non-classé) —
  volontairement **écarté pour l'instant**. L'intérêt est qu'un match paraît
  juste au regard du ladder que le joueur voit, mais ça n'a de sens qu'avec assez
  de monde pour remplir chaque palier ; avec la population actuelle ça ne ferait
  qu'allonger les attentes. À reconsidérer quand il y aura de vrais paliers
  peuplés. Les paliers sont aujourd'hui purement dérivés côté client
  (`RankTier.gd`), le backend ne les connaît pas : ce chantier demanderait donc
  d'abord de les faire remonter côté serveur.
- **Régler `WAIT_BONUS_MMR_PER_SECOND`** (`matchmakingModel.ts`, 5/s plafonné à
  300) avec de vrais joueurs : ce paramètre arbitre « MMR proche » contre
  « attend depuis longtemps », et il est inobservable à 2-3 joueurs en file —
  n'importe quelle valeur donne le même appariement. À revoir une fois la file
  réellement peuplée, en regardant si des joueurs restent bloqués longtemps
  (bonus trop faible) ou si les écarts de MMR paraissent injustes (trop fort).

## P14 — Historique de parties + place au classement

**Résolu (vérifié le 2026-09-26).** `0077-profile-rank-and-match-history` est
mergée dans `main` et déployée : `GET /api/ranked/matches/history` répond en
prod. L'historique ci-dessous est conservé pour mémoire.

### Historique

Même situation que P12/P13 ci-dessus : le client (`MatchHistoryPanel.gd`,
onglet « Historique » du profil) consomme `GET /api/ranked/matches/history`
et `ranked.totalPlayers` sur `GET /api/profile`, tous deux ajoutés côté
`wyrdane-backend` branche `0077-profile-rank-and-match-history` — **pas
encore mergée dans `main`, donc pas déployée**. `match_history` gagne aussi
trois colonnes additives (`mmr_change_player1/2`, `duration_sec`), ajoutées
via `db:sync` comme les autres migrations additives (voir « Appliquer un
changement de schéma en prod » dans le `CLAUDE.md` de `wyrdane-backend`) —
aucune donnée existante affectée, mais sans ce `db:sync` en prod l'onglet
Historique affichera des échecs de chargement (404) une fois le client
déployé. Le champ `mode` ajouté par P13 ci-dessus à `POST /api/ranked/matches/report`
est envoyé par le client dans tous les cas (`report_ranked_match` porte
maintenant `is_ranked`/`durationSec` ensemble) mais ignoré par cette branche
backend tant qu'elle n'a pas elle-même absorbé le changement de P13 — sans
conséquence : le backend actuel n'exploite aucun champ de payload inconnu.

## P15 — Système d'amis Wyrdane + chat

**Résolu (vérifié le 2026-09-26).** Les branches backend
`0079-friends-and-chat` et `0084-game-invites` sont mergées dans `main` et
déployées : `GET /api/friends` et `GET /api/invites/incoming` répondent en
prod. L'historique ci-dessous est conservé pour mémoire.

### Historique

Demande utilisateur du 2026-09-24, implémentée en session suivante (les deux
côtés, voir CLAUDE.md « Amis et chat » côté `card-game` et « Amis, chat et
présence » côté `wyrdane-backend`) : système d'amis propre à Wyrdane (ajout
par pseudo, liste avec statut en ligne/en jeu/hors ligne + étiquette Steam si
l'ami est aussi un ami Steam), panneau Amis qui prend la place des boutons de
navigation du menu principal (clic gauche sur un ami = ouvre le chat, clic
droit = menu contextuel Inviter/Voir le profil/Signaler/Supprimer), chat privé
entre amis avec badge de non-lus, historique **persisté en base**, polling
HTTP (pas de WebSocket, décision utilisateur).

**Pas encore mergé/déployé** (même situation que P12/P14 ci-dessus) :
- Backend : `wyrdane-backend` branche `0079-friends-and-chat` — tables
  `friendships`/`messages` + colonnes `users.last_heartbeat_at`/`in_game`,
  nécessite `db:sync` sur le VPS après déploiement.
- Client : worktree `0614-friends-chat` (`FriendsPanel.gd`, `ChatPanel.gd`,
  `PresenceService.gd`).
- Tant que le backend n'est pas déployé, le panneau Amis/le chat afficheront
  des échecs de chargement silencieux (les BackendClient.* correspondants
  répondent `success=false`/liste vide sur toute erreur HTTP, pas de crash).

**Résolu (2026-09-25)** : « Inviter à jouer » cible désormais directement
l'ami (table `game_invites` côté `wyrdane-backend`), popup de choix de deck
reçue en jeu par le destinataire, sans passer par l'overlay natif Steam. Le
transport reste Steam P2P, seule l'invitation elle-même transite désormais par
le backend. Voir « Multijoueur (1v1 réseau) » → « Invitation d'un ami précis »
dans `CLAUDE.md`.

**Vérification de bout en bout (2026-09-26)** — tout le code est en place des
deux côtés :
- Backend : mergé dans `main` et déployé. La branche `0084-game-invites` n'a
  aucun commit propre (simple ancêtre de `main`), il n'y avait donc rien à
  merger. Vérifié en prod : `GET /api/invites/incoming` répond **401** et non
  404, la route est bien montée.
- Client : les 6 méthodes de `BackendClient` correspondent exactement aux 6
  routes (chemins et payloads vérifiés un par un) ; polling destinataire
  démarré dès `_ready()` de l'autoload et correctement bridé (authentifié, pas
  en bataille, pas de recherche locale en cours, re-vérification de l'état
  après l'aller-retour réseau) ; tous les chemins d'échec affichent un message
  dédié plutôt que de rester muets ; les 37 clés de traduction utilisées par
  `MatchmakingOverlay` existent toutes en FR+EN.
- ⚠ **SEUL POINT RESTANT, non faisable depuis le dépôt** : créer la table
  `game_invites` en base de **prod**. Le déploiement continu ne joue PAS les
  migrations. Commande à lancer sur le VPS :
  `docker compose exec backend node dist/database/sync.js`. Tant que la table
  manque, les routes renvoient **500** (pas 404) et l'expéditeur voit
  « invitation échouée » — troisième occurrence du même piège après le
  matchmaking classé et le chat/amis.

## P16 — Race Artefact : branche complète jamais intégrée

`0426-artifact-race` (dernier commit 2026-09-25) porte une **race Artefact
complète et fonctionnelle mais dormante** : 75 ressources de carte, 290
fichiers touchés, +7711/-1622 lignes, son propre `Race.Type.ARTIFACT`, l'onglet
de filtre du deck builder, le badge de coût générique et ses tests. C'est de
loin la plus grosse valeur non livrée du dépôt.

Décision produit attendue : **finir et merger, ou assumer l'abandon**. Elle a
été laissée en attente, pas rejetée.

**Coût d'intégration mesuré le 2026-09-26** (merge de `dev` réellement joué dans
son worktree, puis annulé — la branche est intacte, rien n'a été commité) :

- **Le merge mécanique est facile** : 67 commits de `dev` de retard, 290 fichiers
  touchés, et pourtant **2 conflits seulement**, tous deux triviaux —
  `scripts/card/CardEffect.gd` (deux `effect_id` ajoutés de part et d'autre dans
  la même liste `@export_enum` : la résolution est leur union) et `CLAUDE.md`
  (deux versions de la ligne de roadmap : garder celle de `dev`, plus à jour, et
  y réinjecter la mention de la 5e race). Tout le reste s'auto-merge, y compris
  `game.csv`, `EffectManager.gd` et `AISystem.gd`.
- **Mais 4 tests de la branche cassent au contact de `dev`** (939 tests, 6 échecs
  dont 2 déjà corrigés par ailleurs — voir le haut de ce fichier) :
  - 1 test simplement **obsolète** : il attend qu'un serviteur ressuscité entre
    en jeu à 1 PV, alors que `dev` a délibérément changé ça (PR #541, « revive
    minions at max health by default instead of 1 HP »). Correction : mettre le
    test à jour, rien d'autre.
  - 3 tests pointent le **mécanisme de ciblage propre à la branche**
    (`EffectManager.resolve_trigger_target` +
    `TriggersSystem._execute_enchantment_effects_with_proxy`, le « ciblage joueur
    généralisé sur un trigger de Rituel/Enchantement » qu'introduit la race
    Artefact) : `test_ritual_with_no_context_target_resolves_it_via_resolve_trigger_target`,
    `test_ritual_with_no_valid_target_pool_does_not_crash_and_does_nothing` et le
    test d'application automatique de `-1/-0`. Le code de la branche a bien
    survécu au merge (vérifié : les deux fonctions sont intactes), donc c'est
    l'interaction avec les évolutions de `TriggersSystem` dans `dev` qui est à
    reprendre. **C'est le seul vrai travail d'intégration**, et il demande de
    connaître l'intention de conception de la branche — à faire par qui la
    reprendra, pas à l'aveugle.
- Comptage réel des cartes sur la branche : 395 hors Arena (dont 19 jetons), les
  75 cartes Artefact comprises.

Autrement dit : le risque n'est pas dans la dérive de `dev` (le merge reste
propre), mais dans ces 3 tests de ciblage. À décider en connaissance de cause.

## P17 — Refactor matchmaking

**Côté client : intégré** (les deux branches du 2026-09-25/26 sont mergées dans
`dev`).
- ~~`worktree-0638-single-rendezvous-matchmaking`~~ — **mergée** (PR #657) : la
  file backend devient le **seul** point de rendez-vous du matchmaking (supprime
  le chemin direct de recherche de lobby Steam, source du bug de lobby détruit
  corrigé la veille).
- ~~`worktree-0639-matchmaking-queue-debug-info`~~ — **mergée** (PR #655) :
  journalise mode/MMR/fenêtre/attente sur le poll de file, et désactive
  `NetDebugLog` par défaut.

**Côté backend : intégré aussi.**
`0086-matchmaking-queue-status-debug-info` (expose `mmr`, `window`, `wait` sur
le statut de file) est **mergée dans `main`** et déployée (PR #105 côté
`wyrdane-backend`), donc les diagnostics ajoutés côté client remontent bien de
vraies valeurs et non des champs vides.

Rien ne bloque donc plus la session de test à deux comptes Steam (P13) — au
contraire, elle exercera précisément ce refactor, jamais éprouvé en conditions
réelles.

## P18 — Ménage du dépôt

**Fait le 2026-09-26**, sauf le dernier point :
- ~~worktrees~~ : **73 worktrees montés → 4** (ne restent que `dev` et les
  branches réellement actives). Aucun n'a été forcé tant que Git signalait du
  travail dedans : les 18 qu'il refusait d'abord ne contenaient que des `.uid`
  générés par Godot, vérifié un par un avant de passer `--force`.
- ~~branches locales~~ : **80 branches déjà mergées dans `dev` supprimées**
  (87 → 7). Seule `worktree-0633-hover-zoom-toggle` a résisté : son contenu est
  bien dans `dev`, mais elle porte un commit absent de sa branche distante, donc
  la suppression douce est refusée — sans conséquence, l'effacer demanderait
  l'option forcée.
- ~~`devlogs/2026-09-21-draft.md`~~ : archivé dans `devlogs/archive/`.
- **Orphelins de tests : deux vraies fuites corrigées, le compteur reste
  élevé et c'est normal.** `FakeHand` héritait de `Node` sans raison (un signal
  n'en demande pas un) et n'était jamais libéré : passé en `RefCounted`, −465
  orphelins. `FakeBattle` porte par ailleurs une douzaine de vrais
  `Control`/`Button`/`Label` pour simuler l'UI, eux aussi jamais libérés : il les
  libère désormais seul via `NOTIFICATION_PREDELETE` (il est `RefCounted`), sans
  devoir ajouter un `after_each()` dans les ~40 fichiers concernés.
  Le total affiché par GUT ne bouge quasiment pas pour autant (6937 → 6426) :
  **GUT compte les orphelins à la fin de chaque test, alors que le script de test
  détient encore son `FakeBattle` dans une variable membre** — la libération
  n'arrive qu'au `before_each()` suivant, après le comptage. Descendre ce
  compteur demanderait de relâcher explicitement le double dans chaque
  `after_each()`, pour un gain purement cosmétique : délibérément non fait. Les
  deux fuites réelles, elles, sont bien fermées.

## P19 — Cartes non traduites en anglais

**Résolu (2026-09-26).** `CLAUDE.md` affirmait que les 320 cartes avaient
toutes leurs clés dans `translations/game.csv` : c'était faux pour 25 textes —
les 12 noms des cartes exclusives à l'Arena (`*-arena.tres`) et 13
descriptions. Une clé absente ne provoque aucune erreur : le texte s'affiche
tel quel, donc **en français dans la version anglaise**, sans que rien ne le
signale. Les 25 lignes FR + EN ont été ajoutées, en suivant les conventions de
traduction déjà en place (REMPART→TAUNT, ASSAUT→CHARGE, COMMANDEMENT→COMMAND,
VENIN MORTEL→DEADLY POISON, ÉGIDE→AEGIS, Mort-rage→Death Rage, Amas
Informe→Formless Mass…).

Trouvé au passage et corrigé : la traduction anglaise de `MENU_LEGAL_BODY`
était **tronquée en jeu** depuis son ajout. Son texte contenait
`provided \"as is\"` — un guillemet échappé par backslash, ce qui n'existe pas
en CSV (un guillemet s'y **double**) : le champ se fermait sur le premier `"`,
la fin de la phrase partait dans une 4e colonne fantôme et n'était jamais
affichée. Remplacé par des guillemets typographiques, comme la version française
qui utilisait déjà « ».

`tests/unit/test_card_translation_coverage.gd` couvre désormais les deux cas
(clé présente pour chaque nom/description de carte, et exactement 3 colonnes par
ligne de CSV), pour que ce genre d'oubli ne puisse plus passer inaperçu.

## P20 — Suites de l'audit de sécurité du 2026-09-26

Failles corrigées ce jour-là (backend `0087-security-hardening`, client `0641-account-data-and-log-redaction`) : `trust proxy` manquant, limite de corps de requête étranglant les rapports de plantage, `ENFORCE_MATCH_SESSION_TOKEN` inactif, route `/api/debug` résiduelle, absence totale de sauvegardes de base, absence de droits RGPD, chemins utilisateur non masqués dans les logs. Détail dans le devlog du 2026-09-28. Ce qui reste :

- **Installer le cron de sauvegarde sur le VPS** — le script existe (`scripts/backup-db.sh`) mais rien ne le lance encore : tant que la ligne crontab n'est pas posée, la base n'est toujours pas sauvegardée. Renseigner aussi `BACKUP_REMOTE` (copie hors du VPS) et **tester une restauration au moins une fois** sur une base jetable.
- **AppID Steam 480 en production** — la vérification de ticket ne prouve ni la possession du jeu ni la provenance du ticket, et aucun bannissement crédible n'est possible. Seul correctif : `STEAM_APP_ID=5052390` + clé Publisher Steamworks. Détail dans l'en-tête de `helper/steamHelper.ts` ; l'API journalise un avertissement au démarrage tant que c'est le cas.
- **Politique de confidentialité** — les routes et l'UI RGPD existent, le document qui décrit quelles données sont collectées et pourquoi n'existe pas encore (attendu par Steam et par le RGPD). À écrire côté `wyrdane-website`.
- **Quota de login à réexaminer quand la base de joueurs grandira** (`authRouter.ts:18`, `rateLimit({ windowMs: 10 * 60 * 1000, max: 20, name: "auth:steam" })`) — **laissé à 20 volontairement** (décision utilisateur 2026-09-26), à revoir plus tard, pas un bug aujourd'hui. Le contexte : ce quota ne compte par IP que parce qu'il n'y a pas encore d'utilisateur authentifié à ce stade (toutes les autres routes comptent par `user:<id>`, donc immunes au partage d'IP). Or une même adresse IP publique peut porter beaucoup de joueurs — réseau mobile (CGNAT : des milliers d'abonnés par IP), résidence étudiante, LAN, cybercafé : au-delà de 20 connexions en 10 minutes depuis cette IP, le 21e joueur ne peut plus se connecter et ne voit qu'un échec de connexion opaque, sans qu'aucune alerte ne remonte côté serveur. Sans danger tant que la population est petite (il faut ~20 joueurs derrière la même connexion dans la même fenêtre) ; le risque croît avec elle. Piste si le cas se présente : passer `max` à 60 — la route ne fait que valider un ticket auprès de l'API Steam, 60 tentatives/10 min n'ouvre aucun abus réel. À noter que ce réglage n'a commencé à s'appliquer correctement qu'avec `trust proxy` (voir plus haut) : avant, toutes les requêtes comptaient sous l'IP du proxy.
- **Triche en partie réseau 1v1** — le modèle reste un relais de commandes sans autorité. `NetworkOpponent` revalide déjà coût en mana, propriété du serviteur et taille de main, mais un client modifié peut encore jouer une carte absente de sa main (le receveur ne connaît pas la main adverse), connaître le contenu du deck adverse (transmis en clair au handshake) et prédire les effets aléatoires (`game_rng` seedée identiquement des deux côtés). Décision prise : **ne pas** viser l'autorité serveur (réécrire le moteur de jeu pour une population encore inexistante), mais rendre la triche détectable — remonter en télémétrie les incohérences que `NetworkOpponent` détecte déjà (`push_warning`) pour pouvoir bannir sur faisceau d'indices, et valider la légalité du deck au démarrage du match (les cartes du handshake sont-elles réellement possédées ?).
- **Attention en touchant à `DeckSystem`** : `battle.deck.shuffle()` utilise la RNG globale de Godot, PAS `battle.game_rng` (seedée par le handshake et donc connue des deux clients). Ce n'est pas un oubli à « corriger » : basculer ce mélange sur `game_rng` rendrait tout l'ordre de pioche prédictible par l'adversaire.

## Non-problèmes vérifiés pendant cette revue

- Aucun marqueur `TODO`/`FIXME`/`HACK`/`XXX` dans `scripts/` ou `scenes/` — rien d'oublié en l'état signalé dans le code.
- i18n côté UI : échantillonnage de `Battle.gd`, `GameOverScreen.gd`, `Card.gd` — tout passe par `SettingsManager.t()` ou `display_*()`, pas de chaîne FR en dur trouvée. Contrôle exhaustif ajouté le 2026-09-26 : toutes les clés passées à `SettingsManager.t()` dans `scripts/`/`scenes/` existent bien dans `game.csv` (la seule « absente » est `RACE_`, une concaténation dynamique).
- i18n côté cartes : **était un vrai trou, corrigé le 2026-09-26** (voir P19).
- `README.md` et `CLAUDE.md` sont globalement alignés (roadmap, limites IA, statut Steam identiques des deux côtés) en dehors du point P4 corrigé ci-dessus.
