# CLAUDE.md

Ce fichier fournit le contexte du projet à Claude Code pour travailler efficacement sur Wyrdane.

## Vue d'ensemble

**Wyrdane** est un TCG (jeu de cartes à collectionner) dark fantasy compétitif 1v1, développé sous **Godot 4** en **GDScript**. Deux joueurs s'affrontent pour réduire le héros adverse à 0 HP, avec un système de deux rangées positionnelles (Avant/Arrière) par joueur.

Documentation complète des règles : voir `README.md`.
Liste complète des cartes : voir `CARDS.md`.

## Lancer et tester le projet

- Ouvrir dans Godot 4 (moteur "Forward Plus")
- Scène principale (F5) : `scenes/loading/LoadingScreen.tscn` — charge toutes les cartes via `CardLibrary` puis ouvre le menu principal
- Pour tester directement une bataille : lancer `scenes/battle/Battle.tscn` (F6). Attention : `CardLibrary` n'est alors pas pré-chargé, certains systèmes (deck IA notamment) utilisent un fallback
- Le multijoueur est backend Steam uniquement (plus de mode IP/LAN) : le tester nécessite deux machines/sessions avec deux comptes Steam distincts (deux instances locales sur le même compte échouent avec `NET_STEAM_SAME_ACCOUNT` — voir `SteamService.gd`)
- Vérification syntaxique en CLI : `godot --headless --path . --check-only --script res://scripts/.../MonScript.gd --quit` fonctionne pour un script isolé mais donne de faux positifs sur les autoloads (non chargés) et peut rater de vraies erreurs (ex. inférence `:=` sur un Variant). Pour un check fiable de tout `scripts/`, préférer une scène temporaire headless qui `load()` chaque `.gd` (le projet tourne réellement → autoloads présents) ; penser à restaurer `translations/*.translation` après un `--import`
- Tests automatisés (GUT) : voir section « Tests automatisés » plus bas

## Tests automatisés

Framework : **GUT** (`addons/gut`), activé comme plugin dans `project.godot`. Tests dans `tests/unit/`.

- Lancer toute la suite en CLI (headless) : `godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Après un `git pull`/`git clone` (ou si les tests échouent avec des erreurs "class_names have not been imported" / "Failed to instantiate an autoload"), régénérer le cache d'import une fois : `godot --headless --path . --import`
- Les scripts purs sans dépendance de scène (ex. `Minion`, `CardData`) sont testables directement en instanciant la classe. Éviter de dépendre des autoloads globaux (`CardLibrary`, etc.) dans les tests : le runner GUT (mode `-s`) ne les initialise pas de façon fiable — préférer charger le script cible directement (`load("res://...").new()`) quand c'est possible
- Toute nouvelle carte ou tout nouveau système de jeu mérite un test si sa logique n'est pas triviale (calcul de dégâts, conditions de trigger, intégrité des ressources `.tres`)

## Structure du projet

```
scenes/
├── arena/           # Prototype Arena/Battle Royale solo local (ArenaBattle.tscn)
├── battle/          # Scène de bataille
├── campaign/        # Mode Campagne (sélection de race, construction du plateau, carte de run, combat auto-battler dédié, récompense, boutique, relique, repos, événement, fin de run)
├── card/            # Affichage d'une carte (+ cartes enchantement)
├── deck/            # Deck builder et liste des decks
├── graveyard/       # Vue du cimetière
├── hand/            # Main du joueur
├── loading/         # Écran de chargement (scène principale)
├── mainMenu/        # Menu principal
├── minion/          # Serviteur sur le board
├── net/             # Lobby multijoueur (NetLobby) + scène de test réseau
└── settings/        # Menus de réglages (audio, contrôles, graphismes, affichage)

scripts/
├── EffectManager/   # Moteur d'exécution des effets de cartes
├── arena/           # Mode Arena/Battle Royale (prototype solo local) : ArenaMatch (orchestrateur), SimulatedBattle (combat headless réutilisant CombatSystem/DeathSystem 1v1), ArenaCardPool, ArenaMergeSystem, ArenaPairing, GhostBoard, ArenaBotDriver...
├── audio/           # AudioManager (autoload)
├── battle/          # Battle.gd — orchestrateur central de la bataille
├── campaign/        # Mode Campagne (run roguelite solo sans fin, voir CAMPAIGN.md) — CampaignContext (contexte statique), CampaignRun/CampaignMapNode/CampaignMapGenerator (état + carte par fenêtre glissante), CampaignBoardBuild, CampaignBattle (moteur de combat auto-battler dédié, ne passe jamais par Battle.gd), CampaignOpponentFactory, CampaignRewardPicker, CampaignGold, CampaignEvents, CampaignConsolationReward, CampaignSaveService (sauvegarde locale user://)
├── card/            # CardData, Card (UI), CardEffect, styles
├── collection/      # CollectionManager, CurrencyManager (autoloads) — sync backend
├── data/            # Énumérations (EffectType, Keyword, KeywordHuman, KeywordUndead, Race, TargetType, TriggerType...)
├── deck/            # DeckBuilder, DeckData, DeckList, DeckManager (autoload)
├── graveyard/       # Cimetière (logique + vue)
├── hand/            # Gestion et layout de la main
├── hero/            # Héros et panneaux héros
├── loading/         # CardLibrary (autoload) + écran de chargement
├── mainMenu/        # Menu principal
├── minion/          # Minion (logique) et BoardMinion (visuel)
├── net/             # Couche multijoueur (NetworkManager, NetworkOpponent, NetLobby, protocole de commandes...) + BackendClient (autoload, auth Steam/HTTP)
├── settings/        # Menus de réglages + SettingsManager (autoload)
├── shop/            # PackShop.gd — écran d'ouverture de packs
├── systems/         # Systèmes de jeu (AISystem, CombatSystem, TurnSystem, DeathSystem...)
└── tutorial/        # TutorialManager, TutorialDeck, TutorialOpponent, TutorialContext — tutoriel obligatoire guidé

translations/        # Traductions FR/EN (game.csv → .translation compilés par Godot)
```

Autoloads globaux (voir `project.godot`) :
- `AudioManager` — `scripts/audio/AudioManager.gd`
- `DeckManager` — `scripts/deck/DeckManager.gd`
- `TooltipData` — `scripts/systems/TooltipData.gd`
- `CardLibrary` — `scripts/loading/CardLibrary.gd`
- `SettingsManager` — `scripts/settings/SettingsManager.gd` (réglages persistants + i18n)
- `CollectionManager` — `scripts/collection/CollectionManager.gd` (collection de cartes possédées, autoritaire côté backend)
- `CurrencyManager` — `scripts/collection/CurrencyManager.gd` (solde de monnaie molle, autoritaire côté backend)
- `BackendClient` — `scripts/net/BackendClient.gd` (client HTTP vers `wyrdane-backend`, auth Steam)

## Concepts du jeu (essentiels pour coder les effets)

### Types de cartes
- **Serviteur** — unité posée sur le plateau (Avant ou Arrière, ou Hybride ↕️)
- **Éphémère** — sort à effet immédiat, jeté et défaussé
- **Rituel** — sort persistant doté de X charges ; chaque charge est consommée uniquement lorsque son trigger se déclenche réellement (et non passivement à chaque tour). Détruit quand ses charges sont épuisées. Décrément géré par `TriggerSystem._consume_ritual_charge`
- **Enchantement** — effet passif permanent jusqu'à destruction
- **Ressource** — carte de race (coût 0) ; +1 (actuel et max) au pool de mana de sa race, puis retirée de la partie (aucune zone ne la garde — non récupérable). Une seule par tour et par camp. Voir « Système de Ressources par Race » ci-dessous.

### Système de Ressources par Race
Plus de mana générique unique : chaque race a son propre pool (`Battle.race_mana`/`race_max_mana`, `Dictionary` clé `Race.Type`), alimenté uniquement en jouant une carte-ressource (Chair / Sceau du Royaume / Âme / Éclat d'Anomalie). Plus de choix Mana/Pioche en début de tour : `TurnSystem._begin_player_turn` recharge les pools à leur maximum (`Battle.refill_mana_pool`) et pioche automatiquement. Le coût d'une carte de race se scinde en `race_cost` (payable uniquement depuis le pool de sa race, calculé depuis `CardData.rarity` par `CostSystem.get_race_cost`) et `generic_cost` (payable depuis n'importe quel pool en surplus). Détails complets, formules et deckbuilding dans README.md « Système de Ressources par Race ».

Une fois jouée, la carte-ressource n'est posée dans aucune zone du plateau ni conservée dans une structure de données (cimetière ou autre) : elle disparaît simplement de la partie (`Battle.play_resource_card`), donc aucun effet ne peut jamais la récupérer. La pose visuelle en zone dédiée du plateau (`PlayerResourceZone`/`EnemyResourceZone`, `EnchantmentSystem.add_resource`) est **désactivée** (`Battle.RESOURCE_ZONE_ENABLED = false`) mais conservée telle quelle en vue d'une réactivation future.

### Positionnement (lane types)
- ⚔️ Avant / 🛡️ Arrière / ↕️ Hybride (au choix du joueur)
- Rangée Avant doit être vide pour que le héros adverse soit attaquable
- Max 10 serviteurs par rangée, 20 en jeu au total

### Triggers (déclencheurs d'effets)
`Arrivée`, `Dernier Souffle`, `Assaut`, `Blessure`, `Éveil` (début de tour), `Déclin` (fin de tour), `Renfort` (unité alliée arrive), `Deuil` (unité alliée meurt), `Sortilège` (sort allié lancé), `Sacrifice`, `Exécution` (unité ennemie meurt), `Carnage` (n'importe quelle unité meurt).

Implémentation réelle : les triggers sont l'enum `TriggerType.Type` (`scripts/data/TriggerType.gd`) et sont déclenchés par nom via `EffectManager.trigger_effects(battle, minion, "OnAwaken")` ou `TriggerSystem.fire("OnSummon", minion, is_player)`. Les effets eux-mêmes sont **data-driven** : chaque carte (`CardData.effects`) porte des ressources `CardEffect` (effect_id, cible, valeur) exécutées par `EffectManager.execute_effect()` — rien n'est codé en dur dans les serviteurs. **Avant d'ajouter un effet, vérifier si son `effect_id` existe déjà dans le `match` de `EffectManager.gd`.**

### Jetons d'invocation
Un effet `SummonMinion` (cible fixe via `CardEffect.summon_card`) ne doit **jamais** cibler une vraie carte collectionnable du deck — cela invoquerait ses propres triggers/effets et créerait des réactions en chaîne (ex. serviteur A invoque B qui invoque C...). À la place, créer une ressource `.tres` dédiée avec `CardData.is_token = true` : copie des stats/mots-clés passifs de la carte visée mais **sans aucun `trigger_types`/`effects`** (les mots-clés purement passifs comme REMPART/PACTE/HORDE peuvent rester, ils ne déclenchent jamais l'EffectManager). `CardLibrary._scan_recursive` exclut automatiquement les cartes `is_token` du pool (deckbuilder, deck IA, pool `SummonRandom`) ; seule une référence directe via `summon_card` peut y accéder. Convention de nommage : `<carte-source>-token.tres`, documentée dans la section « Jetons » de `CARDS.md` de la race concernée. Exception : `SummonRandom` (« invoque un serviteur de coût ≤X ») pioche légitimement dans le pool de vraies cartes — c'est le comportement voulu, pas un cas à convertir en jeton.

### Mots-clés
`REMPART`, `ASSAUT`, `FRÉNÉSIE`, `RAVAGE`, `INFILTRATION`, `MOISSON`, `VENIN MORTEL`, `ÉGIDE` — définitions complètes dans `README.md`.

### Mécaniques spéciales — Mort-Vivant
- **Infection** — perte de 1 HP au début du tour adverse, persiste jusqu'à mort
- **Mort-rage** — se déclenche une seule fois, quand le serviteur passe sous 50% HP max
- **Cimetière** — pile LIFO des serviteurs alliés morts, visible des deux joueurs
- **Sacrifice** — destruction volontaire d'un allié pour déclencher un effet

Races implémentées dans `CARDS.md` et `resources/cards/` : **Mort-Vivant** (`undead/`, 80 cartes dont 4 jetons), **Humain** (`human/`, 81 cartes dont 5 jetons, avec ses mots-clés propres dans `KeywordHuman.gd` : Commandement, Contre-attaque...), **Démon** (`demon/`, 77 cartes dont 1 jeton, mots-clés dans `KeywordDemon.gd`, Corruption, pipeline de dégâts auto-infligés `HeroSystem.self_damage`, trigger `OnSelfDamage` — voir « Mécaniques Démon » dans `README.md`) et **Abomination** (`abomination/`, 79 cartes dont 3 jetons, mots-clés dans `KeywordAbomination.gd` : MUTATION, FUSION, VIRULENT, CHAIR ADAPTATIVE, ASSIMILATION, INSTABLE — Table de Mutation dans `EffectManager.roll_mutation`, trigger `OnDevoration` (n'importe quelle mort, tout camp) et `OnMutation` — voir « Mécaniques Abomination » dans `README.md`. Plusieurs cartes ont un texte simplifié par rapport à `CARDS.md` faute d'UI de choix de cible/mot-clé — le texte affiché en jeu reflète toujours le comportement réel). Total : 317 cartes (13 jetons compris). Races prévues (non commencées, seuls les enums `Race.Type.ELF`/`Race.Type.DWARF` existent) : Elfe, Nain.

### Adversaire : IA ou joueur distant (`OpponentDriver`)
Le camp adverse est piloté via l'abstraction `scripts/net/OpponentDriver.gd` : `Battle` et `TurnSystem.end_turn()` appellent `battle.opponent.take_turn()` sans savoir qui est en face. Deux implémentations :
- **`AISystem`** (`scripts/systems/AISystem.gd`, mode solo) — deck propre (40 serviteurs Mort-Vivants aléatoires + 12 cartes-ressource Chair via `CardLibrary`), main et pools de mana par race. Tour automatique en 3 phases : début de tour (recharge des pools + pioche automatique), pose de cartes (une ressource par tour puis serviteurs/sorts/rituels/enchantements), attaques (provocation > létal héros > trade favorable). Trois niveaux de difficulté via `SettingsManager.ai_difficulty` (`easy`/`normal`/`hard`).
- **`NetworkOpponent`** (`scripts/net/NetworkOpponent.gd`, mode réseau) — ne décide rien : rejoue localement, dans l'ordre, les commandes reçues du joueur distant jusqu'à `END_TURN`.

Dans les deux cas, `battle.enemy_turn_active` bloque les inputs du joueur pendant le tour adverse.

### Multijoueur (1v1 réseau)
Couche réseau dans `scripts/net/`, en modèle **relais de commandes** : chaque client émet ses actions (`NetEmitter`) et rejoue celles du pair distant — pas de serveur d'autorité.
- **Transport** : interface `NetTransport`, une seule implémentation créée par `TransportFactory` : `SteamTransport` (lobby Steam + P2P Steamworks via l'extension GodotSteam — optionnelle, détectée à l'exécution par `SteamService`, instructions d'installation dans son en-tête). `NetworkManager` orchestre : connexion, sérialisation `var_to_bytes` (types de base uniquement, jamais d'objets arbitraires), routage des commandes, et tentative de reconnexion automatique en cas de coupure P2P transitoire (délai de grâce, voir `NetworkManager.RECONNECT_GRACE_SECONDS`).
- **Entrée en jeu** : `scenes/net/NetLobby.tscn` (Héberger Steam / Partie rapide / Inviter un ami) → handshake `NetHandshake` (échange des decks, graine RNG partagée, premier joueur) → les deux clients basculent sur `Battle.tscn` ; `NetContext` (statique) transporte le `NetworkManager` et le résultat du handshake à travers le changement de scène.
- **Protocole** : vocabulaire dans `NetCommand.gd` (`PLAY_CARD`, `ATTACK`, `ATTACK_HERO`, `END_TURN`, `TURN_START`, `HELLO`). `PLAY_CARD` sert aussi à poser une carte-ressource (`row = "Resource"`). Une carte est désignée par son `resource_path`, un serviteur par un `net_id` stable attribué par `NetRegistry`.
- **Déterminisme** : RNG de jeu partagée (seed du handshake) pour que les effets aléatoires donnent le même résultat des deux côtés ; les triggers de début/fin de tour (Éveil/Déclin, infection) sont synchronisés.
- La déconnexion du pair en cours de partie est gérée (retour propre), et la main/le deck adverses sont affichés en compteurs cosmétiques.

### Backend (`wyrdane-backend`, dépôt séparé)
`BackendClient` (autoload, `scripts/net/BackendClient.gd`) parle en HTTP à un backend Node/Express séparé (dépôt local `E:\wyrdane-backend`, hébergé en prod sur un **VPS OVH** (`137.74.163.226`, `api.wyrdane.com`) via Docker Compose + Nginx — `API_URL` en dur dans le script, voir « Infra & déploiement (VPS) » ci-dessous pour le détail). Authentification par ticket de session Steamworks (`POST /api/auth/steam`), cookie de session porté manuellement sur chaque requête suivante (`request()` générique, callback `(code, parsed_body)`). Toute la progression joueur (collection de cartes possédées, monnaie molle, packs) est **autoritaire côté serveur** : `CollectionManager`/`CurrencyManager` ne mettent jamais en cache hors-ligne, seule la dernière sync fait foi ; tant qu'aucune sync n'a réussi, le deck builder considère le joueur comme ne possédant aucune carte (comportement prudent, pas un bug).
- `MainMenu._start_backend_sync()` lance `BackendClient.login_with_steam()` à l'ouverture du menu, puis déclenche `CollectionManager.sync_from_backend()` et `CurrencyManager.sync_from_backend()` une fois connecté.
- `PackShop.gd` (`scripts/shop/`) est l'écran d'ouverture de packs : dépense la monnaie molle (`CurrencyManager.open_pack`, coût affiché `CurrencyManager.PACK_COST`) contre des cartes aléatoires pondérées par rareté, résolues via `CardLibrary.card_by_backend_id`.
- Le backend local (`E:\wyrdane-backend`, branche **`main`** — `dev` est gelée) est en cours de développement par petites branches (`NNNN-slug` côté backend aussi) ; certaines routes attendues par le client (monnaie, packs, récompenses) peuvent vivre sur une branche pas encore mergée dans `main` — si un appel `BackendClient.request()` échoue en local, vérifier d'abord l'état des branches du backend avant de suspecter un bug côté jeu.
- Dégradation attendue si le backend est injoignable : les managers restent `is_synced = false`, l'UI affiche les valeurs par défaut (solde 0, collection vide) sans bloquer le joueur.

### Panneau d'actualités (menu principal)
Le panneau « Actualités » de `MainMenu` (`scripts/mainMenu/MainMenu.gd`, `_fetch_remote_news`) récupère les devlogs/actus créées sur le site (`wyrdane-website`) via `NEWS_FEED_URL = "https://wyrdane.com/feed.json"` — un manifeste JSON bilingue (fr/en) régénéré à chaque build/déploiement du site (`scripts/generate-feed.mjs`, appelé en `predev`/`prebuild`) à partir de `src/content/news/*.json` et `src/content/devlog/*.json`. Aucune action manuelle : ajouter un fichier JSON côté site puis déployer suffit à le faire apparaître en jeu. Si le fetch échoue (site injoignable), repli sur les ressources locales `res://resources/news/*.tres` (`NewsEntry.gd`, conservées pour ce cas).

### Infra & déploiement (VPS)
Le backend (`wyrdane-backend`) et le site compagnon (`wyrdane-website`, deck builder web) sont hébergés ensemble sur un **VPS OVH** (`137.74.163.226`, Ubuntu, Docker) — plus sur Render. Domaines : `wyrdane.com`/`www.wyrdane.com` (site) et `api.wyrdane.com` (API). Détail complet de la stack (Docker Compose, Nginx, sécurité, CI/CD) documenté dans le `CLAUDE.md` de `wyrdane-backend`. Rien à faire côté `card-game` pour cette infra sinon garder `API_URL` dans `BackendClient.gd` synchronisé si le domaine change.

### Tutoriel guidé obligatoire
`TutorialManager` (`scripts/tutorial/TutorialManager.gd`, ~700 lignes) orchestre un tutoriel scripté séquentiel (popups + attentes d'action réelle via `_popup`/`_popup_wait_action`/`_wait_for`) déclenché par `Battle._start_tutorial` avec un deck dédié (`TutorialDeck.gd`) et un adversaire scripté (`TutorialOpponent.gd`, implémente `OpponentDriver`). Couvre notamment une phase de mulligan guidée (`intro_mulligan`/`guided_mulligan`, appelée par `Battle._run_mulligan()`) et se termine par `notify_victory()` : marque le tutoriel complété (`SettingsManager.set_tutorial_completed()`) puis réclame côté backend les 4 decks préfaits + cartes associées (`POST /api/collection/claim-starter`) avant de retourner au menu principal.

## Décisions de design UI

## Principes UX

- Toujours privilégier la lisibilité des informations importantes.
- Lorsqu'une décision est demandée au joueur, celui-ci doit conserver l'accès aux informations nécessaires pour prendre cette décision.
- Éviter les fenêtres qui masquent complètement le plateau ou la main lorsque ces éléments sont utiles à la décision.

### Zone de ressource (désactivée)

- Chaque camp a sa propre zone de ressource sur le plateau (hors rangées/Rituels/Enchantements), symétrique aux zones Rituel/Enchantement mais du côté opposé.
- Les cartes-ressource posées y restent visibles individuellement ; la zone se resserre pour en accumuler plusieurs sans jamais déborder du cadre (même logique que les zones Rituel/Enchantement).
- Actuellement désactivée (`Battle.RESOURCE_ZONE_ENABLED = false`) : une carte-ressource jouée disparaît simplement de la partie au lieu d'être posée. Conservée pour une réactivation future.
- Les panneaux `Player/EnemyResourcePanel` et `Player/EnemyResourceZone` sont masqués (`visible = false`) dans `Battle.tscn` (nœuds conservés pour la réactivation). Le deck (`Deck/EnemyDeckButton`, affiché en long, tourné à 90°) et le cimetière (`Player/EnemyGraveyardButton`, juste en dessous) occupent désormais cet espace.

## Internationalisation (i18n)

Le jeu est traduit **FR/EN** via le système natif Godot : `translations/game.csv` (clé, fr, en) compilé en `game.fr.translation` / `game.en.translation`.
- Tout texte UI passe par `SettingsManager.t("CLE")` (délègue au `TranslationServer`) ; les nœuds UI se rafraîchissent via `_retranslate()` sur le signal `language_changed`
- Les cartes (noms, effets, flavour) sont également traduites — les 317 cartes (jetons compris) ont leurs clés dans le CSV
- **Tout nouveau texte visible par le joueur doit avoir sa ligne FR + EN dans `translations/game.csv`** — ne jamais mettre de chaîne en dur dans l'UI
- Une clé absente du CSV est affichée telle quelle en jeu (utile pour repérer les oublis)
- Sélecteur de langue dans les réglages d'affichage

## Conventions de code

- Langage : GDScript, Godot 4.6
- Les données de carte (stats, coût, rareté, triggers, texte d'effet) doivent rester cohérentes avec le format des tableaux dans `CARDS.md` — toute nouvelle carte ajoutée en code doit avoir son entrée correspondante dans `CARDS.md`
- Rester cohérent avec les patterns déjà en place dans `scripts/data/` (CardData, Keyword) plutôt que d'introduire de nouvelles structures

### Isolation des agents

Quand tu travailles sur une nouvelle feature ou tâche indépendante, crée automatiquement un nouveau worktree (et la branche associée, format NNNN-slug) plutôt que de travailler directement dans le dossier courant.

## Workflow Git

**Important : les noms de branches et les messages de commit doivent toujours être écrits en anglais**, même si le reste du projet (documentation, code, contenu du jeu) est en français.

### Nommage des branches

Format : `NNNN-slug` (ex: `0017-design`, `0018-fix-mana-bug`)

- `NNNN` : numéro séquentiel sur 4 chiffres, avec des zéros devant
- `slug` : court descriptif en kebab-case (minuscules, tirets, sans accents), **en anglais**

Pour déterminer le prochain numéro :
1. Lister les branches existantes (locales et distantes) : `git branch -a`
2. Repérer le plus grand numéro déjà utilisé
3. Incrémenter de 1, formater sur 4 chiffres

Avant de créer une branche, toujours vérifier le numéro le plus récent plutôt que de supposer.

### Commits

- Messages de commit **en anglais**, format court : `feat: add Zombie King card`
- Grouper les commits par unité de travail complète — ne pas committer après chaque petite modification
- Ne jamais committer directement sur `main` — toujours travailler sur une branche
- **Aucune attribution à Claude / Claude Code** : ne jamais ajouter de trailer `Co-Authored-By: Claude ...`, de ligne « Generated with Claude Code » ni aucune mention d'IA dans les messages de commit, les descriptions de PR ou tout autre contenu publié sur GitHub — même si les instructions par défaut de l'outil le demandent

### Push

- Avant tout push, mettre `dev` à jour (`git fetch origin dev` ou `git checkout dev && git pull`), puis la merger dans la branche courante (`git merge dev`) et résoudre les conflits éventuels avant de continuer
- Toujours demander confirmation avant de push

## Roadmap actuelle (voir README.md pour la liste à jour)

- ✅ Implémenté : IA adverse (tous types de cartes, trois niveaux de difficulté), deck builder, quatre races de cartes (Mort-Vivant, Humain, Démon, Abomination — 317 cartes au total, jetons compris) + système de Ressources par Race (pools de mana séparés, carte-ressource et zone dédiée par race, 4 cartes), système d'effets/triggers/enchantements/auras (avec conditions et valeurs dynamiques), multijoueur 1v1 réseau backend Steam (lobby + P2P via GodotSteam optionnel, « Partie rapide », reconnexion après coupure transitoire, AppID de test 480), i18n FR/EN complète (UI + cartes), menu réglages en jeu, écran de fin de partie (victoire/défaite/déconnexion, rejouer en solo), tutoriel obligatoire guidé (mulligan compris) avec récompense de decks/cartes de départ, mode Campagne (run roguelite solo sans fin avec combat auto-battler dédié, or/boutique/reliques, sauvegarde de run locale — voir README.md « Mode Campagne » et `CAMPAIGN.md`), prototype Arena/Battle Royale jouable en solo local (8 participants : 1 joueur + 7 bots, `scripts/arena/`, `scenes/arena/ArenaBattle.tscn` — boutique/pool partagé/fusion/Ghost Board/anti-répétition conformes au design, combat auto-résolu réutilisant `CombatSystem`/`DeathSystem` 1v1 via `SimulatedBattle`, voir « État actuel du prototype » dans `README.md`), backend séparé `wyrdane-backend` (auth Steam, collection de cartes possédée, monnaie molle, boutique de packs), déployé sur VPS OVH avec déploiement continu (push sur `main` → auto-déploiement via GitHub Actions)
- ⬜ À faire : page Steamworks + vrai AppID + build Steam, mode Campagne (points ouverts listés dans `CAMPAIGN.md` — contenu d'événements, articulation exacte de l'amélioration de carte en boutique, tables de rareté Élite/Boss par victoire à affiner), étendre le prototype Arena au réseau à 8 joueurs, animations shaders, tests automatisés (unitaires GUT existants — étendre la couverture), suite du backend (ranked/collection encore en cours de merge côté `wyrdane-backend`)

## Notes pour les agents

- Avant d'implémenter une nouvelle carte : lire son entrée exacte dans `CARDS.md`, identifier son trigger, vérifier s'il existe déjà un `effect_id` similaire dans `scripts/EffectManager/EffectManager.gd` pour réutiliser le pattern, et créer la ressource `.tres` dans `resources/cards/<race>/`
- Ne pas inventer de nouveau mot-clé ou trigger sans qu'il soit d'abord ajouté à `README.md`
- Le projet est en français dans sa documentation et son contenu visible par le joueur (noms de cartes, effets, UI, tooltips) — garder cette langue pour tout ce qui est visible en jeu. Le code (variables, fonctions) peut rester en anglais sauf convention contraire déjà en place. **Seuls les noms de branches et les commits sont toujours en anglais** (voir Workflow Git ci-dessus).

## Maintenir la documentation à jour

`CLAUDE.md`, `README.md`, `TODO.md` et `CARDS.md` doivent toujours refléter l'état réel du projet. À chaque tâche modifiant le code, avant de considérer le travail terminé (et donc avant tout commit/push) :

- **`CARDS.md`** : toute carte ajoutée, supprimée ou dont les stats/coût/rareté/trigger/texte d'effet changent doit voir son entrée mise à jour dans le tableau de sa race.
- **`README.md`** : toute règle, mot-clé, trigger, mécanique de race ou système de jeu nouveau ou modifié doit être documenté ici (c'est la référence des règles complètes).
- **`TODO.md`** : cocher/retirer les tâches terminées par ce travail, ajouter les nouvelles tâches ou suivis identifiés en cours de route.
- **`CLAUDE.md`** : si la tâche change la structure du projet (nouveau dossier/autoload/système), la roadmap (section « Roadmap actuelle »), ou une convention de travail, mettre à jour la section concernée.

Si une tâche ne touche à aucun de ces aspects (ex. simple refactor interne, correctif visuel sans impact sur les règles), il n'y a rien à mettre à jour — ne pas modifier les `.md` par réflexe. Mais ne jamais laisser la doc devenir obsolète par oubli.

## Devlog hebdomadaire

Un devlog est publié chaque lundi. Pour préparer sa rédaction, chaque session de travail qui modifie du code doit consigner ses changements en brut dans `devlogs/`, avant de considérer le travail terminé. Le dossier `devlogs/` est local uniquement (`.gitignore`) — notes de session brutes, il n'apparaît pas sur GitHub :

- Fichier cible : `devlogs/YYYY-MM-DD-draft.md`, où la date est celle du **prochain lundi** à venir (créer le fichier s'il n'existe pas — voir `devlogs/README.md` pour le format).
- Ajouter une entrée en fin de fichier, sous la date du jour (`## YYYY-MM-DD`), avec une liste à puces brute des changements faits pendant la session — pas de mise en forme, pas de ton marketing, juste les faits (ce qui a été ajouté/corrigé/changé et pourquoi si pertinent).
- Ne pas réécrire ou reformuler les entrées des sessions précédentes dans ce fichier : c'est un journal brut destiné à être relu et transformé en vrai devlog le lundi, avec l'utilisateur.
- Ne rien ajouter pour des tâches sans impact utilisateur/projet perceptible (ex. simple refactor interne sans changement de comportement) — même logique que pour les autres docs ci-dessus.
- Une fois le vrai devlog écrit le lundi, le fichier draft est archivé (`devlogs/archive/`) ou supprimé, et un nouveau draft est créé pour la semaine suivante.

