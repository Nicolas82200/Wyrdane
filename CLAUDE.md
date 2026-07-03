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
- Pas de suite de tests automatisés pour l'instant — toute nouvelle fonctionnalité doit être vérifiée manuellement en jeu jusqu'à ce qu'un framework de test soit mis en place
- Vérification syntaxique possible en CLI : `godot --headless --path . --check-only --script res://scripts/.../MonScript.gd --quit`

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
└── settings/        # Menus de réglages (audio, contrôles, graphismes)

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
├── settings/        # Menus de réglages
└── systems/         # Systèmes de jeu (AISystem, CombatSystem, TurnSystem, DeathSystem...)
```

Autoloads globaux (voir `project.godot`) :
- `AudioManager` — `scripts/audio/AudioManager.gd`
- `DeckManager` — `scripts/deck/DeckManager.gd`
- `TooltipData` — `scripts/systems/TooltipData.gd`
- `CardLibrary` — `scripts/loading/CardLibrary.gd`

## Concepts du jeu (essentiels pour coder les effets)

### Types de cartes
- **Serviteur** — unité posée sur le plateau (Avant ou Arrière, ou Hybride ↕️)
- **Éphémère** — sort à effet immédiat, jeté et défaussé
- **Rituel** — sort permanent actif X tours, effet se déclenche à chaque tour selon un trigger
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

Races implémentées dans `CARDS.md` et `resources/cards/` : **Mort-Vivant** (`undead/`) et **Humain** (`human/`, avec ses mots-clés propres dans `KeywordHuman.gd` : Commandement, Contre-attaque...). Races prévues : Elfe, Nain, Démon.

### IA adverse
L'adversaire est piloté par `scripts/systems/AISystem.gd` : il a son propre deck (20 serviteurs Mort-Vivants aléatoires via `CardLibrary`), sa main et son mana. Son tour se joue automatiquement après celui du joueur (branché dans `TurnSystem.end_turn()`) en 3 phases : ressource (mana ou pioche), pose de serviteurs, attaques (provocation > létal héros > trade favorable). Pendant son tour, `battle.enemy_turn_active` bloque les inputs du joueur. Limite actuelle : l'IA ne joue que des serviteurs (pas de sorts/rituels/enchantements).

## Décisions de design UI

## Principes UX

- Toujours privilégier la lisibilité des informations importantes.
- Lorsqu'une décision est demandée au joueur, celui-ci doit conserver l'accès aux informations nécessaires pour prendre cette décision.
- Éviter les fenêtres qui masquent complètement le plateau ou la main lorsque ces éléments sont utiles à la décision.

### Choix Mana ou Pioche

- Lorsqu'un choix Mana/Pioche est affiché, le plateau est légèrement assombri.
- La main reste visible afin que le joueur puisse consulter ses cartes avant de choisir.
- Les cartes de la main restent non interactives pendant ce choix.

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

- ✅ Implémenté : IA adverse basique (serviteurs uniquement), deck builder, deux races de cartes (Mort-Vivant, Humain), système d'effets/triggers/enchantements/auras
- ⬜ À faire : écran de fin de partie (actuellement `game_over` bloque juste les inputs), sorts/rituels pour l'IA, mode campagne, collection de cartes, multijoueur, animations shaders, tests automatisés

## Notes pour les agents

- Avant d'implémenter une nouvelle carte : lire son entrée exacte dans `CARDS.md`, identifier son trigger, vérifier s'il existe déjà un `effect_id` similaire dans `scripts/EffectManager/EffectManager.gd` pour réutiliser le pattern, et créer la ressource `.tres` dans `resources/cards/<race>/`
- Ne pas inventer de nouveau mot-clé ou trigger sans qu'il soit d'abord ajouté à `README.md`
- Le projet est en français dans sa documentation et son contenu visible par le joueur (noms de cartes, effets, UI, tooltips) — garder cette langue pour tout ce qui est visible en jeu. Le code (variables, fonctions) peut rester en anglais sauf convention contraire déjà en place. **Seuls les noms de branches et les commits sont toujours en anglais** (voir Workflow Git ci-dessus).

