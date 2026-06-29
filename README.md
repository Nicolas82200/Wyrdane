Voici une version révisée de votre `README.md`, intégrant les informations que j'ai pu observer sur la structure de votre projet et les technologies utilisées, tout en conservant l'esprit et la profondeur de votre documentation existante.

```markdown
# FateBound

FateBound est un jeu de cartes développé avec Godot 4 et GDScript, centré sur des mécaniques de combat tactiques et un système de gestion de plateau dynamique.

---

## 🧠 Architecture interne (dev)

Cette section décrit le fonctionnement réel du moteur de jeu côté Godot.

### 🔁 Cycle de rendu du board

Le board n’est **pas redessiné entièrement en boucle**. Le système fonctionne en 3 étapes :

1.  Les données (`player_minions`, `enemy_minions`) sont la source de vérité.
2.  Les visuels (`BoardMinion`) sont stockés dans `minion_to_visual` (géré par `BoardVisualSystem`).
3.  `refresh_board()` met uniquement à jour les visuels existants.

```gdscript
# Exemple conceptuel dans BoardVisualSystem
refresh_board():
    # update_display() sur les minions existants
    # pas de recréation massive sauf spawn/death
```

⚠️ Important :

*   `_refreshing` (dans `BoardVisualSystem`) empêche les appels récursifs.
*   `_refresh_again` (dans `BoardVisualSystem`) permet de re-run proprement si une mise à jour en cascade est nécessaire.

### 🧱 Système de mapping Minion → Visual

Chaque unité logique (`Minion`) a un équivalent visuel (`BoardMinion`) :

```gdscript
var minion_to_visual: Dictionary = {} # Minion -> BoardMinion
```

*   Création → `_rebuild_minion_visuals()` (dans `BoardVisualSystem`)
*   Suppression → `remove_dead_minions()` (dans `DeathSystem`)
*   Recherche → `_find_board_minion_visual()` (dans `BoardVisualSystem`)

👉 Le jeu ne “recrée pas le board” à chaque changement ; il **déplace / met à jour des objets existants**.

### ⚔️ Flow de combat

Ordre exact d’un combat (géré principalement par `CombatSystem`) :

1.  Animation `_animate_attack_lunge()` (dans `AnimationSystem`)
2.  Trigger `OnAttack` (géré par `EffectManager`)
3.  Application des dégâts simultanés.
4.  Effets spéciaux :
    *   Poison / Deadly
    *   Lifesteal
5.  Trigger `OnDamaged` (géré par `EffectManager`)
6.  Mise à jour UI
7.  `remove_dead_minions()` (dans `DeathSystem`)
8.  `check_game_end()`

### ☠️ Système de mort

Les morts sont traitées en batch (`_processing_deaths = true` dans `DeathSystem`) :

Étapes :

1.  Détection des unités mortes.
2.  Animation `_play_death_animation` (dans `AnimationSystem`).
3.  Suppression visuelle.
4.  Ajout au cimetière (géré par `GraveyardSystem`).
5.  Trigger `DEATHRATTLE` (géré par `EffectManager`).
6.  Cleanup des tableaux de minions.
7.  `refresh_board()` (dans `BoardVisualSystem`).

👉 Important : **les morts sont groupées pour éviter les bugs de cascade**.

### 🎯 Système de sélection

Deux modes de sélection (gérés par `SelectionSystem`) :

#### 1. Sélection simple

*   1 attaquant
*   Clic → attaque directe

#### 2. Multi-sélection (CTRL)

```gdscript
selected_attackers[]
selected_board_minions[]
```

*   Attaques en chaîne
*   Résolution gauche → droite
*   `_resolve_multi_attack()` (dans `CombatSystem`)

### 🖱️ Drag & Drop (main → board)

Géré principalement par `DropSystem` et `Hand.gd`.

#### États principaux :

```gdscript
_is_dragging_card (dans Battle.gd et Hand.gd)
waiting_for_target (dans Battle.gd)
pending_card (dans Battle.gd)
pending_row (dans Battle.gd)
```

#### Fonctionnement :

1.  Drag commencé → main compacte.
2.  Affichage preview `BoardMinion ghost`.
3.  Highlight des lanes.
4.  Placeholder dynamique `_drop_placeholder`.
5.  Calcul index insertion :
    ```gdscript
    _get_stable_player_drop_index_at() (dans DropSystem)
    ```

### 🧪 Système d’effets

Centralisé dans `EffectManager.gd` :

```gdscript
EffectManager.execute_effect()
EffectManager.execute_targeted_effect()
```

Triggers disponibles (`TriggerType.gd`) :

*   ONPLAY
*   DEATHRATTLE
*   ONTURNSTART / ONTURNEND
*   OnAttack / OnDamaged

👉 Les effets sont **data-driven (CardData)**, pas hardcodés dans les minions. Le système `EnchantmentSystem` gère également des modifications permanentes ou temporaires aux minions.

### 🧠 Gestion des lanes

Deux lignes par joueur (`ROW_FRONT`, `ROW_BACK`) :

*   Front protège Back.
*   Back inaccessible si Front occupée (selon logique d’attaque).
*   Les cartes peuvent être limitées par `board_position` (dans `CardData`).

### 🚨 Systèmes de protection anti-bug

Plusieurs garde-fous importants sont en place :

#### Anti double refresh

```gdscript
_refreshing / _refresh_again (dans BoardVisualSystem)
```

#### Anti mort multiple

```gdscript
_processing_deaths (dans DeathSystem)
```

#### Anti drag UI conflict

```gdscript
_is_dragging_card (dans Battle.gd et Hand.gd)
```

### 🎞️ Animations système

Animations centralisées dans `AnimationSystem.gd` :

*   `_animate_attack_lunge`
*   `_play_death_animation`
*   `_play_summon_animation`

Toutes utilisent :

```gdscript
create_tween()
```

👉 Important : le gameplay **attend parfois la fin des animations (`await`)**.

### 📦 Classes critiques

*   `Minion.gd` → logique pure du serviteur
*   `BoardMinion.gd` → représentation UI d'un serviteur
*   `CardData.gd` → données de définition d'une carte
*   `Card.gd` → représentation UI d'une carte dans la main/cimetière
*   `Hero.gd` → HP + logique du joueur
*   `Graveyard.gd` → stockage des minions morts et cartes défaussées
*   `EffectManager.gd` → moteur centralisé pour l'exécution des effets
*   `EffectManagerData.gd` → (Potentiellement une donnée ou une ancienne version, à vérifier l'usage actuel avec `EffectManager.gd`)

### ⚠️ Point important (debug futur)

Si le board “ne s’affiche plus” :

Vérifier dans cet ordre :

1.  `refresh_board()` est appelé ?
2.  `minion_to_visual` contient des entrées ?
3.  `_rebuild_minion_visuals()` est exécuté ?
4.  Les containers ne sont pas nuls :
    *   `player_front_container`
    *   `player_back_container`
    *   `enemy_front_container`
    *   `enemy_back_container`
5.  `BoardMinion.tscn` bien instancié.

### 🧩 Résumé mental du système

> Le jeu ne rebuild jamais le board.
> Il maintient une “simulation logique” + une “projection visuelle synchronisée”.

---

## 📂 Structure du Projet

Le projet est organisé autour de dossiers thématiques pour une meilleure maintenabilité.

### Dossiers principaux

*   `assets/`: Contient les ressources visuelles (icônes, etc.).
*   `resources/`: Contient les données de jeu (par exemple, les `CardData` sous `resources/cards/`).
*   `scenes/`: Contient les scènes Godot (.tscn) pour les différentes entités du jeu (battle, card, minion, menu, etc.).
*   `scripts/`: Contient tous les scripts GDScript (.gd), organisés par fonctionnalité.

### Scripts Système (`scripts/systems/`)

Les systèmes sont des scripts autoloadés ou instanciés manuellement qui gèrent des logiques de jeu spécifiques.

*   `BoardSystem.gd`: Gestion des interactions logiques du plateau.
*   `CombatSystem.gd`: Logique de combat entre serviteurs.
*   `CardSystem.gd`: Gestion du jeu et des effets des cartes.
*   `TurnSystem.gd`: Gestion des phases de tour.
*   `SelectionSystem.gd`: Gestion de la sélection des serviteurs pour l'attaque ou les effets.
*   `DropSystem.gd`: Gestion du glisser-déposer des cartes sur le plateau.
*   `BoardVisualSystem.gd`: Synchronisation entre la logique du plateau et son affichage visuel.
*   `DeathSystem.gd`: Gestion du processus de mort des serviteurs.
*   `DeckSystem.gd`: Gestion du deck du joueur.
*   `GraveyardSystem.gd`: Gestion du cimetière.
*   `AnimationSystem.gd`: Centralisation des animations de jeu.
*   `HeroSystem.gd`: Gestion des héros des joueurs.
*   `TargetingSystem.gd`: Gestion du ciblage d'entités pour les effets de cartes.
*   `EnchantmentSystem.gd`: Gestion des enchantements et modifications de statistiques des serviteurs.

### Scripts de Données et Énumérations (`scripts/data/`)

Ces scripts définissent des types et des données utilisées à travers le projet.

*   `ArrowOverlay.gd`
*   `EffectType.gd`
*   `Keyword.gd`
*   `Race.gd`
*   `TargetType.gd`
*   `TriggerType.gd`

### Scripts de Cartes et de Serviteurs (`scripts/card/`, `scripts/minion/`)

Ces dossiers contiennent les définitions logiques et visuelles des cartes et serviteurs.

*   `scripts/card/Card.gd`: Comportement visuel d'une carte.
*   `scripts/card/CardData.gd`: Données brutes d'une carte (coût, effets, type, etc.).
*   `scripts/card/CardEffect.gd`: Définition d'un effet de carte.
*   `scripts/minion/Minion.gd`: Logique interne d'un serviteur.
*   `scripts/minion/BoardMinion.gd`: Représentation visuelle d'un serviteur sur le plateau.

### Autoloads

Le projet utilise des singletons pour des systèmes globaux :

*   `AudioManager` (`res://scripts/autoload/audio/AudioManager.gd`): Gestion de la musique et des effets sonores.
*   `DeckManager` (`res://scripts/autoload/deck/DeckManager.gd`): Gestion du deck global.

---

## 🛠️ Technologies Utilisées

*   **Moteur de Jeu**: Godot Engine 4.x
*   **Langage de Script**: GDScript
*   **Physique 3D**: Jolt Physics (configuré dans `project.godot`)

---

## ✅ Points Forts du Projet

*   **Architecture modulaire et basée sur les systèmes**: L'organisation en `*System.gd` rend le code très structuré et facile à comprendre.
*   **Séparation claire des préoccupations**: Distinction nette entre la logique (`Minion`) et le visuel (`BoardMinion`), ainsi qu'entre les données (`CardData`) et leur représentation (`Card`).
*   **Gestion optimisée du plateau**: Le fait de ne pas redessiner le plateau en entier à chaque changement, mais de mettre à jour et déplacer les objets existants, est une approche performante.
*   **Systèmes robustes**: Les mécanismes de protection anti-bug (`_refreshing`, `_processing_deaths`, etc.) témoignent d'une bonne anticipation des problèmes courants dans les jeux complexes.
*   **Data-driven effects**: Le système d'effets basé sur `CardData` est très flexible et permet d'ajouter facilement de nouvelles cartes et interactions sans modifier le code central.
*   **Utilisation des `await` pour les animations**: Intégration propre des animations dans le flow de jeu, évitant les désynchronisations.
*   **Documentation interne détaillée**: Le `README.md` actuel est un excellent point de départ pour l'onboarding de nouveaux développeurs ou pour le maintien du projet.

---

## 💡 Suggestions d'Amélioration Potentielles

*   **Standardisation des `init` des systèmes**: Certains systèmes sont initialisés avec `self` (le script `Battle.gd`) comme argument, d'autres non. Une approche plus uniforme pourrait simplifier l'intégration et la compréhension.
*   **Gestion des erreurs pour les `onready`**: L'utilisation de `get_node_or_null()` pour les nodes `enemy_container`, `player_container`, etc., est bien, mais des assertions ou des logs plus spécifiques pourraient être utiles si ces nodes sont critiques et manquants. L'exemple de `AudioSettingsMenu` est pertinent ici.
*   **Commentaires et typage**: Bien que le code soit déjà bien typé, des commentaires supplémentaires sur les fonctions complexes ou les interactions entre systèmes pourraient améliorer la clarté.
*   **Tests unitaires/intégration**: Pour un projet avec une logique aussi segmentée, l'ajout de tests automatisés pour les systèmes individuels pourrait être très bénéfique pour la stabilité à long terme.
*   **Considérer un "GameManager" global (ou pousser plus loin le concept Battle)**: Le script `Battle.gd` est déjà très central. S'il continue de grandir, le transformer en un `GameManager` plus global (qui instancie et gère le `Battle` lui-même, par exemple) pourrait clarifier les responsabilités entre la scène de bataille et la gestion globale du jeu.
*   **Gestion des ressources (prélodage)**: Bien que `preload` soit utilisé, pour des jeux plus grands, une stratégie de chargement de ressources plus avancée (chargement asynchrone, mise en cache) pourrait être envisagée.
*   **Nommage des variables privées**: L'utilisation de `_` pour les variables privées est bonne. Assurer une cohérence stricte serait un plus (ex: `_is_dragging_card`).
*   **`EffectManagerData` vs `EffectManager`**: Clarifier la relation entre ces deux, si `EffectManagerData` est une donnée ou si `EffectManager` l'a remplacé, serait utile.
```