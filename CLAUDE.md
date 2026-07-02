# CLAUDE.md

Ce fichier fournit le contexte du projet à Claude Code pour travailler efficacement sur FateBound.

## Vue d'ensemble

**FateBound** est un TCG (jeu de cartes à collectionner) dark fantasy compétitif 1v1, développé sous **Godot 4** en **GDScript**. Deux joueurs s'affrontent pour réduire le héros adverse à 0 HP, avec un système de deux rangées positionnelles (Avant/Arrière) par joueur.

Documentation complète des règles : voir `README.md`.
Liste complète des cartes : voir `CARDS.md`.

## Lancer et tester le projet

- Ouvrir dans Godot 4 (moteur "Forward Plus")
- Scène principale : `scenes/battle/Battle.tscn`
- Lancer avec F5 dans l'éditeur Godot
- Pas de suite de tests automatisés pour l'instant — toute nouvelle fonctionnalité doit être vérifiée manuellement en jeu jusqu'à ce qu'un framework de test soit mis en place

## Structure du projet

```
scenes/
├── battle/          # Scène principale de bataille
├── card/             # Affichage d'une carte
├── hand/               # Gestion de la main du joueur
├── hero/                 # Panneaux du héros
├── minion/              # Affichage serviteur sur board
└── graveyard/          # Affichage du cimetière

scripts/
├── battle/          # Logique de bataille, board, lanes
├── card/             # Logique de carte et drag&drop
├── data/               # Structures de données (CardData, Keyword, etc.)
├── effects/           # Système d'effets de cartes
├── hand/                # Gestion et layout de la main
├── minion/             # Logique serviteur
└── hero/                # Logique héros
```

Autoloads globaux (voir `project.godot`) : `AudioManager`, `DeckManager`, `TooltipData`, `CardLibrary`.

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

Convention attendue pour les noms de fonctions GDScript associées aux triggers (à confirmer/adapter si une convention existe déjà dans `scripts/effects/`) : `_on_invocation()`, `_on_last_breath()`, etc. **Toujours vérifier le pattern existant dans `scripts/effects/` avant d'en inventer un nouveau.**

### Mots-clés
`REMPART`, `ASSAUT`, `FRÉNÉSIE`, `RAVAGE`, `AILES NOIRES`, `MOISSON`, `VENIN MORTEL`, `ÉGIDE` — définitions complètes dans `README.md`.

### Mécaniques spéciales — Mort-Vivant (race actuellement implémentée dans CARDS.md)
- **Infection** — perte de 1 HP au début du tour adverse, persiste jusqu'à mort
- **Mort-rage** — se déclenche une seule fois, quand le serviteur passe sous 50% HP max
- **Cimetière** — pile LIFO des serviteurs alliés morts, visible des deux joueurs
- **Sacrifice** — destruction volontaire d'un allié pour déclencher un effet

Races prévues mais pas encore détaillées en cartes : Humain, Elfe, Nain, Démon (thèmes listés dans `README.md`).

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

IA adverse, mode campagne, collection de cartes, construction de deck, effets avancés, multijoueur, animations shaders — aucun de ces éléments n'est encore implémenté.

## Notes pour les agents

- Avant d'implémenter une nouvelle carte : lire son entrée exacte dans `CARDS.md`, identifier son trigger, vérifier s'il existe déjà une carte avec un effet similaire dans `scripts/effects/` pour réutiliser le pattern
- Ne pas inventer de nouveau mot-clé ou trigger sans qu'il soit d'abord ajouté à `README.md`
- Le projet est en français dans sa documentation et son contenu visible par le joueur (noms de cartes, effets, UI, tooltips) — garder cette langue pour tout ce qui est visible en jeu. Le code (variables, fonctions) peut rester en anglais sauf convention contraire déjà en place. **Seuls les noms de branches et les commits sont toujours en anglais** (voir Workflow Git ci-dessus).

