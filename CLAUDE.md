# CLAUDE.md

Ce fichier fournit le contexte du projet à Claude Code pour travailler efficacement sur FateBound.

## Vue d'ensemble

**FateBound** est un TCG (jeu de cartes à collectionner) dark fantasy compétitif 1v1, développé sous **Godot 4** en **GDScript**. Deux joueurs s'affrontent pour réduire le héros adverse à 0 HP, avec un système de deux rangées positionnelles (Avant/Arrière) par joueur.

Documentation complète des règles : voir `README.md`.
Liste complète des cartes : voir `CARDS.md`.

## Lancer et tester le projet

- Ouvrir dans Godot 4 (moteur "Forward Plus")
- Scène principale (F5) : `scenes/loading/LoadingScreen.tscn` — charge toutes les cartes via `CardLibrary` puis ouvre le menu principal
- Pour tester directement une bataille : lancer `scenes/battle/Battle.tscn` (F6). Attention : `CardLibrary` n'est alors pas pré-chargé, certains systèmes (deck IA notamment) utilisent un fallback
- Pour tester le multijoueur en local : lancer deux instances du jeu sur `scenes/net/NetLobby.tscn` — l'une clique « Héberger », l'autre saisit `127.0.0.1` puis « Rejoindre »
- Vérification syntaxique possible en CLI : `godot --headless --path . --check-only --script res://scripts/.../MonScript.gd --quit`
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
├── battle/          # Scène de bataille + panneau choix Mana/Pioche
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
├── audio/           # AudioManager (autoload)
├── battle/          # Battle.gd — orchestrateur central de la bataille
├── card/            # CardData, Card (UI), CardEffect, styles
├── data/            # Énumérations (EffectType, Keyword, KeywordHuman, KeywordUndead, Race, TargetType, TriggerType...)
├── deck/            # DeckBuilder, DeckData, DeckList, DeckManager (autoload)
├── graveyard/       # Cimetière (logique + vue)
├── hand/            # Gestion et layout de la main
├── hero/            # Héros et panneaux héros
├── loading/         # CardLibrary (autoload) + écran de chargement
├── mainMenu/        # Menu principal
├── minion/          # Minion (logique) et BoardMinion (visuel)
├── net/             # Couche multijoueur (NetworkManager, NetworkOpponent, NetLobby, protocole de commandes...)
├── settings/        # Menus de réglages + SettingsManager (autoload)
└── systems/         # Systèmes de jeu (AISystem, CombatSystem, TurnSystem, DeathSystem...)

translations/        # Traductions FR/EN (game.csv → .translation compilés par Godot)
```

Autoloads globaux (voir `project.godot`) :
- `AudioManager` — `scripts/audio/AudioManager.gd`
- `DeckManager` — `scripts/deck/DeckManager.gd`
- `TooltipData` — `scripts/systems/TooltipData.gd`
- `CardLibrary` — `scripts/loading/CardLibrary.gd`
- `SettingsManager` — `scripts/settings/SettingsManager.gd` (réglages persistants + i18n)

## Concepts du jeu (essentiels pour coder les effets)

### Types de cartes
- **Serviteur** — unité posée sur le plateau (Avant ou Arrière, ou Hybride ↕️)
- **Éphémère** — sort à effet immédiat, jeté et défaussé
- **Rituel** — sort persistant doté de X charges ; chaque charge est consommée uniquement lorsque son trigger se déclenche réellement (et non passivement à chaque tour). Détruit quand ses charges sont épuisées. Décrément géré par `TriggerSystem._consume_ritual_charge`
- **Enchantement** — effet passif permanent jusqu'à destruction

### Positionnement (lane types)
- ⚔️ Avant / 🛡️ Arrière / ↕️ Hybride (au choix du joueur)
- Rangée Avant doit être vide pour que le héros adverse soit attaquable
- Max 10 serviteurs par rangée, 20 en jeu au total

### Triggers (déclencheurs d'effets)
`Invocation`, `Dernier Souffle`, `Assaut`, `Blessure`, `Éveil` (début de tour), `Déclin` (fin de tour), `Ralliement` (unité alliée arrive), `Deuil` (unité alliée meurt), `Sortilège` (sort allié lancé), `Sacrifice`, `Exécution` (unité ennemie meurt), `Carnage` (n'importe quelle unité meurt).

Implémentation réelle : les triggers sont l'enum `TriggerType.Type` (`scripts/data/TriggerType.gd`) et sont déclenchés par nom via `EffectManager.trigger_effects(battle, minion, "OnAwaken")` ou `TriggerSystem.fire("OnSummon", minion, is_player)`. Les effets eux-mêmes sont **data-driven** : chaque carte (`CardData.effects`) porte des ressources `CardEffect` (effect_id, cible, valeur) exécutées par `EffectManager.execute_effect()` — rien n'est codé en dur dans les serviteurs. **Avant d'ajouter un effet, vérifier si son `effect_id` existe déjà dans le `match` de `EffectManager.gd`.**

### Mots-clés
`REMPART`, `ASSAUT`, `FRÉNÉSIE`, `RAVAGE`, `AILES NOIRES`, `MOISSON`, `VENIN MORTEL`, `ÉGIDE` — définitions complètes dans `README.md`.

### Mécaniques spéciales — Mort-Vivant
- **Infection** — perte de 1 HP au début du tour adverse, persiste jusqu'à mort
- **Mort-rage** — se déclenche une seule fois, quand le serviteur passe sous 50% HP max
- **Cimetière** — pile LIFO des serviteurs alliés morts, visible des deux joueurs
- **Sacrifice** — destruction volontaire d'un allié pour déclencher un effet

Races implémentées dans `CARDS.md` et `resources/cards/` : **Mort-Vivant** (`undead/`, 75 cartes), **Humain** (`human/`, 74 cartes, avec ses mots-clés propres dans `KeywordHuman.gd` : Commandement, Contre-attaque...) et **Démon** (`demon/`, 75 cartes, mots-clés dans `KeywordDemon.gd`, Corruption, pipeline de dégâts auto-infligés `HeroSystem.self_damage`, trigger `OnSelfDamage` — voir « Mécaniques Démon » dans `README.md`). Races prévues (non commencées, seuls les enums `Race.Type.ELF`/`Race.Type.DWARF` existent) : Elfe, Nain.

### Adversaire : IA ou joueur distant (`OpponentDriver`)
Le camp adverse est piloté via l'abstraction `scripts/net/OpponentDriver.gd` : `Battle` et `TurnSystem.end_turn()` appellent `battle.opponent.take_turn()` sans savoir qui est en face. Deux implémentations :
- **`AISystem`** (`scripts/systems/AISystem.gd`, mode solo) — deck propre (20 serviteurs Mort-Vivants aléatoires via `CardLibrary`), main et mana. Tour automatique en 3 phases : ressource (mana ou pioche), pose de serviteurs, attaques (provocation > létal héros > trade favorable). Limite actuelle : l'IA ne joue que des serviteurs (pas de sorts/rituels/enchantements).
- **`NetworkOpponent`** (`scripts/net/NetworkOpponent.gd`, mode réseau) — ne décide rien : rejoue localement, dans l'ordre, les commandes reçues du joueur distant jusqu'à `END_TURN`.

Dans les deux cas, `battle.enemy_turn_active` bloque les inputs du joueur pendant le tour adverse.

### Multijoueur (1v1 réseau)
Couche réseau dans `scripts/net/`, en modèle **relais de commandes** : chaque client émet ses actions (`NetEmitter`) et rejoue celles du pair distant — pas de serveur d'autorité.
- **Transport** : interface `NetTransport`, deux implémentations créées par `TransportFactory` : `ENetTransport` (P2P hôte/client, IP directe ou LAN) et `SteamTransport` (lobby Steam + P2P Steamworks via l'extension GodotSteam — optionnelle, détectée à l'exécution par `SteamService`, instructions d'installation dans son en-tête). `NetworkManager` orchestre : connexion, sérialisation `var_to_bytes` (types de base uniquement, jamais d'objets arbitraires), routage des commandes.
- **Entrée en jeu** : `scenes/net/NetLobby.tscn` (Héberger / Rejoindre par IP) → handshake `NetHandshake` (échange des decks, graine RNG partagée, premier joueur) → les deux clients basculent sur `Battle.tscn` ; `NetContext` (statique) transporte le `NetworkManager` et le résultat du handshake à travers le changement de scène.
- **Protocole** : vocabulaire dans `NetCommand.gd` (`PLAY_CARD`, `ATTACK`, `ATTACK_HERO`, `TURN_CHOICE`, `END_TURN`, `TURN_START`, `HELLO`). Une carte est désignée par son `resource_path`, un serviteur par un `net_id` stable attribué par `NetRegistry`.
- **Déterminisme** : RNG de jeu partagée (seed du handshake) pour que les effets aléatoires donnent le même résultat des deux côtés ; les triggers de début/fin de tour (Éveil/Déclin, infection) sont synchronisés.
- La déconnexion du pair en cours de partie est gérée (retour propre), et la main/le deck adverses sont affichés en compteurs cosmétiques.

## Décisions de design UI

## Principes UX

- Toujours privilégier la lisibilité des informations importantes.
- Lorsqu'une décision est demandée au joueur, celui-ci doit conserver l'accès aux informations nécessaires pour prendre cette décision.
- Éviter les fenêtres qui masquent complètement le plateau ou la main lorsque ces éléments sont utiles à la décision.

### Choix Mana ou Pioche

- Lorsqu'un choix Mana/Pioche est affiché, le plateau est légèrement assombri.
- La main reste visible afin que le joueur puisse consulter ses cartes avant de choisir.
- Les cartes de la main restent non interactives pendant ce choix.

## Internationalisation (i18n)

Le jeu est traduit **FR/EN** via le système natif Godot : `translations/game.csv` (clé, fr, en) compilé en `game.fr.translation` / `game.en.translation`.
- Tout texte UI passe par `SettingsManager.t("CLE")` (délègue au `TranslationServer`) ; les nœuds UI se rafraîchissent via `_retranslate()` sur le signal `language_changed`
- Les cartes (noms, effets, flavour) sont également traduites — les 151 cartes ont leurs clés dans le CSV
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

### Push

- Toujours demander confirmation avant de push

## Roadmap actuelle (voir README.md pour la liste à jour)

- ✅ Implémenté : IA adverse basique (serviteurs uniquement), deck builder, trois races de cartes (Mort-Vivant, Humain, Démon — 226 cartes au total), système d'effets/triggers/enchantements/auras (avec conditions et valeurs dynamiques), multijoueur 1v1 réseau (P2P ENet, lobby IP/LAN), backend Steam (lobby + P2P via GodotSteam optionnel, « Partie rapide », AppID de test 480), i18n FR/EN complète (UI + cartes), menu réglages en jeu, écran de fin de partie (victoire/défaite/déconnexion, rejouer en solo)
- ⬜ À faire : sorts/rituels pour l'IA, page Steamworks + vrai AppID + build Steam, mode campagne, collection de cartes, mode Battle Royale (design finalisé dans `README.md`), animations shaders, tests automatisés

## Notes pour les agents

- Avant d'implémenter une nouvelle carte : lire son entrée exacte dans `CARDS.md`, identifier son trigger, vérifier s'il existe déjà un `effect_id` similaire dans `scripts/EffectManager/EffectManager.gd` pour réutiliser le pattern, et créer la ressource `.tres` dans `resources/cards/<race>/`
- Ne pas inventer de nouveau mot-clé ou trigger sans qu'il soit d'abord ajouté à `README.md`
- Le projet est en français dans sa documentation et son contenu visible par le joueur (noms de cartes, effets, UI, tooltips) — garder cette langue pour tout ce qui est visible en jeu. Le code (variables, fonctions) peut rester en anglais sauf convention contraire déjà en place. **Seuls les noms de branches et les commits sont toujours en anglais** (voir Workflow Git ci-dessus).

