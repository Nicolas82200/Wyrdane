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

1.  Animation `play_attack_lunge()` (dans `AnimationSystem`)
2.  Trigger `OnAttack` (géré par `EffectManager`)
3.  Application des dégâts simultanés.
4.  Effets spéciaux :
    *   Poison / Deadly
    *   Lifesteal
5.  Trigger `OnDamaged` (géré par `EffectManager`)
6.  Mise à jour UI
7.  `remove_dead_minions()` (dans `DeathSystem`)
8.  `check_game_end()`

### 🛡️ Mécaniques défensives

- **Réduction de dégâts** (`CardData.damage_reduction` + `Minion.aura_damage_reduction`) : chaque source de dégâts subie est réduite d'un montant fixe, sans jamais descendre sous 1 quand un coup touche. La part inhérente vient de la carte (Défenseur Juré, Zombie Bouclier) ; une part peut être ajoutée par une aura via l'effet `AuraDamageReduction` (Pacte de Résistance : Humains alliés −1). Appliquée dans `Minion.take_damage`.
- **Immunité au débordement** (`CardData.blocks_overkill`) : quand un serviteur défenseur meurt, les dégâts excédentaires de RAVAGE ne sont pas reportés sur le héros (Colosse Décomposé). Vérifiée dans `CombatSystem`.
- **Immunité à l'Infection** (`Minion.infection_immune_aura` + `is_infection_immune()`) : accordée par une aura via l'effet `AuraInfectionImmunity` (Aegis de l'Empire : Humains alliés en rangée Avant), en plus de CHAIR MORTE. Le setter de `infected` bloque toute pose ; l'effet `CureInfection` retire les marqueurs déjà présents (Inquisiteur Suprême).

### ⚔️ Autres mécaniques d'effet

- **Exil à la mort** (`CardData.exile_on_death`) : le serviteur ne rejoint pas le cimetière (Possédé Hurlant). Filtré dans `DeathSystem._send_to_graveyards`.
- **Coût de sacrifice ciblé** (effet `SacrificeAlly` + `requires_target`) : le joueur choisit l'allié sacrifié avant de résoudre le reste de l'effet (Don de Chair) ; sans cible (IA), les plus faibles sont sacrifiés automatiquement. `CardSystem.conditions_met` interdit le lancer sans assez d'alliés.
- **Rituels de Sacrifice** (`CardData.sacrifice_count` / `sacrifice_max_hp` + `SacrificeSystem`) : un rituel à trigger `OnSacrifice` posé en jeu s'active en cliquant dessus (surbrillance dorée quand activable), puis en choisissant la ou les victimes alliées ; les victimes meurent (marquées `sacrificed`, pas de REVENANT), l'effet du rituel s'exécute et une charge est consommée (`TriggerSystem.activate_sacrifice_ritual`). Synchronisé en réseau via la commande `ACTIVATE_RITUAL`. Cartes : Pacte Sanglant, Cercle de Sacrifice, Rituel de la Fosse Sans Fond.
- **Réduction de coût en mana** (`CostSystem`) : le coût effectif d'une carte est calculé à la volée (`Battle.get_card_cost`), jamais en modifiant `CardData.cost`. Deux sources : remises temporaires par carte "ce tour" (effet `DrawCardDiscount`, Doigt Décharné) et auras d'enchantement — `AuraSpellCostReduction` (Sanctuaire Nécrotique : sorts alliés −1, min 1) et `AuraFirstOfRaceCostReduction` (Murmure Funeste : premier Mort-Vivant du tour −1, min 1). Le coût réduit s'affiche en vert dans la main.
- **Mana temporaire** (effet `GainMana`) : ajoute du mana disponible sans toucher au maximum ; le surplus est perdu au tour suivant (Vortex des Âmes).
- **Contre-Offensive** (`Battle.counter_offensive` + effet `GrantCounterOffensive`) : ce tour, chaque Humain du camp qui tue un ennemi rejoue immédiatement (+1 attaque dans `CombatSystem`, expire en fin de tour).

### ☠️ Système de mort

Les morts sont traitées en batch (`_processing_deaths = true` dans `DeathSystem`) :

Étapes :

1.  Détection des unités mortes.
2.  Animation `play_death()` (dans `AnimationSystem`).
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

*   `ONPLAY` (Invocation) / `DEATHRATTLE` (Dernier Souffle) / `CHARGE` (Assaut)
*   `OnDamaged` (Blessure) / `OnAttack` / `OnExecution` (Exécution)
*   `OnAwaken` (Éveil) / `OnDecline` (Déclin) — début / fin de tour du propriétaire
*   `OnTurnStart` / `OnTurnEnd`
*   `OnRally` (Ralliement) / `OnGrief` + `OnMourning` (Deuil) / `OnCarnage` (Carnage)
*   `OnSpell` (Sortilège) / `OnSacrifice` (Sacrifice) / `OnDeathRage` (Mort-rage)
*   `OnSummon` (Appel) / `OnAura` (Présence) / `OnResonance` (Résonance)

👉 Les effets sont **data-driven (CardData)**, pas hardcodés dans les minions. Le système `EnchantmentSystem` gère également des modifications permanentes ou temporaires aux minions.

Capacités du moteur d'effets :

*   **Conditions** — un `CardEffect` peut être conditionné (état du plateau, du lanceur...) avant de s'exécuter.
*   **Valeurs dynamiques** — les montants d'un effet peuvent être calculés à l'exécution (ex: en fonction d'un décompte d'unités) plutôt que fixes.
*   **Rituels** — chaque charge n'est consommée que lorsque le trigger du rituel se déclenche réellement (`TriggerSystem._consume_ritual_charge`), pas passivement à chaque tour.
*   **Auras de rangée** (`OnAura`) — buffs appliqués à toute une rangée, recalculés par `AuraSystem`.
*   **Feedback visuel** — popup de la carte à l'origine de l'effet + courbes/flèches dessinées vers les cibles (`CardPopupSystem`, `ArrowOverlay`).

### 🧠 Gestion des lanes

Deux lignes par joueur (`ROW_FRONT`, `ROW_BACK`) :

*   Front protège Back.
*   Back inaccessible si Front occupée (selon logique d’attaque).
*   Les cartes peuvent être limitées par `board_position` (dans `CardData`).

### 🤖 Adversaire : abstraction `OpponentDriver`

Le camp adverse est piloté via l'interface `OpponentDriver` (`scripts/net/OpponentDriver.gd`) : `Battle` et `TurnSystem.end_turn()` appellent `battle.opponent.take_turn()` **sans savoir si l'adversaire est l'IA ou un joueur distant**. Deux implémentations :

*   `AISystem` (mode solo) — décide ses actions localement.
*   `NetworkOpponent` (mode réseau) — rejoue les commandes reçues du joueur distant.

Dans les deux cas, `battle.enemy_turn_active` verrouille les inputs joueur (cartes, attaques, bouton fin de tour) pendant le tour adverse.

#### IA (`AISystem`)

L'IA (`scripts/systems/AISystem.gd`) a son propre deck (20 serviteurs Mort-Vivants aléatoires via `CardLibrary`), sa main et son mana.

Son tour s'exécute automatiquement dans `TurnSystem.end_turn()`, entre la fin du tour joueur et le début du suivant, en 3 phases :

1.  **Ressource** — mana ou pioche (symétrique du choix joueur du `TurnChoicePanel`).
2.  **Pose** — joue les serviteurs les plus chers d'abord, respecte `board_position` (hybrides fragiles à l'arrière).
3.  **Attaque** — priorité : Provocation > létal sur le héros > trade favorable (tuer sans mourir) > héros.

⚠️ Limite actuelle : l'IA ne joue que des **serviteurs** — pas de sorts, rituels ni enchantements.

### 🌐 Multijoueur 1v1 (réseau)

Le mode multijoueur 1v1 est implémenté dans `scripts/net/`, sur un modèle **relais de commandes** (pas de serveur d'autorité) : chaque client émet ses actions et rejoue localement celles du pair distant.

#### Couche transport

*   `NetTransport` — interface abstraite (host/join/send/close).
*   `ENetTransport` — implémentation P2P hôte/client via `ENetMultiplayerPeer` (IP directe / LAN).
*   `TransportFactory` — crée le backend demandé (prévu pour accueillir d'autres backends, ex: Steam).
*   `NetworkManager` — chef d'orchestre : connexion, sérialisation des commandes (`var_to_bytes`, types de base uniquement — jamais de désérialisation d'objets arbitraires, par sécurité), routage via les signaux `peer_connected` / `peer_disconnected` / `command_received`.

#### Entrée en partie

1.  `scenes/net/NetLobby.tscn` — un joueur clique « Héberger », l'autre saisit l'IP et « Rejoindre ».
2.  `NetHandshake` — échange d'ouverture : decks, graine RNG partagée, premier joueur.
3.  Les deux clients basculent sur `Battle.tscn` en mode réseau ; `NetContext` (statique) transporte le `NetworkManager` et le résultat du handshake à travers le changement de scène.

#### Protocole (`NetCommand.gd`)

Commandes échangées : `PLAY_CARD`, `ATTACK`, `ATTACK_HERO`, `TURN_CHOICE` (mana/pioche), `END_TURN`, `TURN_START`, `HELLO` (handshake). Une carte est désignée par son `resource_path` (identique sur les deux clients), un serviteur par un `net_id` stable attribué par `NetRegistry`.

*   `NetEmitter` — émet les actions du joueur local sous forme de commandes.
*   `NetworkOpponent` — met en file les commandes distantes et les rejoue dans l'ordre jusqu'à `END_TURN`.

#### Déterminisme et synchronisation

*   **RNG de jeu partagée** (graine échangée au handshake) : les effets aléatoires produisent le même résultat sur les deux clients.
*   Triggers de début/fin de tour (Éveil/Déclin) et infection synchronisés entre clients ; les effets d'invocation ciblés sont rejoués côté distant.
*   Main et deck adverses affichés en **compteurs cosmétiques** ; mana adverse affiché en continu.
*   Déconnexion du pair en cours de partie gérée (message + sortie propre) ; quitter la partie déconnecte proprement.

### 🌍 Internationalisation (i18n)

Le jeu est traduit **FR/EN** via le système de traduction natif de Godot :

*   `translations/game.csv` (clé, fr, en) — compilé automatiquement par Godot en `game.fr.translation` / `game.en.translation`.
*   `SettingsManager.t("CLE")` délègue au `TranslationServer` ; les nœuds UI se rafraîchissent via `_retranslate()` sur le signal `language_changed`.
*   **Toute l'UI est traduite** (menus, deck builder, bataille, cimetière, chargement) ainsi que **les 151 cartes** (noms, effets, flavour).
*   Une clé absente du CSV est affichée telle quelle en jeu — utile pour repérer les oublis.
*   Sélecteur de langue dans les réglages d'affichage (avec toggle du highlight des zones).

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

*   `play_attack_lunge`
*   `play_death`
*   `play_summon`

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
*   `OpponentDriver.gd` → interface du camp adverse (IA ou joueur distant)
*   `AISystem.gd` → adversaire IA : deck, main, mana et déroulé de son tour
*   `NetworkManager.gd` → connexion réseau et routage des commandes de jeu

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
*   `TempEffectSystem.gd`: Effets temporaires (buffs/debuffs et mots-clés à durée limitée), retirés automatiquement en fin de tour (`UntilEndOfTurn` / `UntilEndOfEnemyTurn`).
*   `AISystem.gd`: Adversaire — deck, main, mana et déroulé automatique de son tour.
*   `AuraSystem.gd`: Recalcul des bonus d'aura (Présence) des serviteurs.
*   `TriggersSystem.gd`: Déclenchement des triggers des rituels/enchantements en jeu.
*   `CardPopupSystem.gd`: Popups d'effets affichés sur le côté du plateau, avec flèches vers les cibles.
*   `TurnChoicePanel.gd`: Panneau du choix Mana/Pioche en début de tour.
*   `TooltipData.gd`: Tooltips des mots-clés (autoload).

### Scripts Réseau (`scripts/net/`)

Couche multijoueur 1v1 (voir la section « Multijoueur 1v1 » plus haut pour l'architecture) :

*   `NetTransport.gd` / `ENetTransport.gd` / `TransportFactory.gd`: Abstraction et implémentation ENet du transport.
*   `NetworkManager.gd`: Connexion, sérialisation et routage des commandes de jeu.
*   `NetCommand.gd`: Vocabulaire partagé des commandes (`PLAY_CARD`, `ATTACK`, `END_TURN`...).
*   `NetHandshake.gd`: Échange d'ouverture (decks, graine RNG, premier joueur).
*   `NetLobby.gd`: Écran Héberger/Rejoindre (scène `scenes/net/NetLobby.tscn`).
*   `NetContext.gd`: Passe-plat statique entre le lobby et la scène Battle.
*   `NetEmitter.gd`: Émission des actions du joueur local en commandes réseau.
*   `NetRegistry.gd`: Attribution de `net_id` stables aux serviteurs.
*   `OpponentDriver.gd`: Interface commune IA / joueur distant.
*   `NetworkOpponent.gd`: Rejeu local des commandes du joueur distant.

### Scripts de Données et Énumérations (`scripts/data/`)

Ces scripts définissent des types et des données utilisées à travers le projet.

*   `ArrowOverlay.gd`
*   `EffectType.gd`
*   `Keyword.gd` — mots-clés génériques
*   `KeywordHuman.gd` — mots-clés propres aux Humains (Commandement, Contre-attaque...)
*   `KeywordUndead.gd` — mots-clés propres aux Morts-Vivants (Infection, Mort-rage...)
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

*   `AudioManager` (`res://scripts/audio/AudioManager.gd`): Gestion de la musique et des effets sonores.
*   `DeckManager` (`res://scripts/deck/DeckManager.gd`): Gestion des decks du joueur (deck actif, sauvegarde).
*   `TooltipData` (`res://scripts/systems/TooltipData.gd`): Données des tooltips de mots-clés.
*   `CardLibrary` (`res://scripts/loading/CardLibrary.gd`): Chargement de toutes les `CardData` de `resources/cards/`.
*   `SettingsManager` (`res://scripts/settings/SettingsManager.gd`): Réglages persistants (langue, highlights de zones...) et accès aux traductions via `t(key)`.

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

---

## 🎮 Mode Battle Royale (8 joueurs) — Design (v1)
*Document de design — en cours de discussion*

### 🎯 Concept général

Mode autobattler à 8 joueurs mêlant TFT (boutique, pool partagé, économie) et Hearthstone Battlegrounds (combat auto-résolu, niveau de héros). Chaque joueur construit et fait évoluer son plateau (rangées Avant/Arrière existantes) entre des rounds de combat simulé.

### ⚔️ Structure d'un round

1. **Phase Boutique** — achat/reroll/verrouillage de cartes.
2. **Phase Positionnement** — organisation du plateau (Avant/Arrière).
3. **Phase Combat** — appariement aléatoire contre un adversaire, combat résolu automatiquement (`CombatSystem`, sans input joueur).
4. Le perdant du combat perd des PV de héros (montant fonction des survivants du gagnant).
5. Élimination à 0 PV. Classement 8 → 1.

#### Héros
- **PV de départ : 30.**
- **Pouvoir de héros : absent en v1** (tous les joueurs démarrent identiques). Prévu comme extension future — voir section Extensions futures.

#### Dégâts de combat
- Le perdant subit des dégâts **équivalents au coût total en mana des serviteurs survivants** du gagnant.
- **Égalité** (aucun survivant des deux côtés) : **personne ne subit de dégâts**.
- **Timer de combat : 30 secondes maximum.** Si le combat n'est pas terminé (survivants des deux côtés) à l'issue du timer, chaque joueur subit directement des dégâts égaux au **coût en mana total des serviteurs adverses survivants** (comme si le combat s'arrêtait "en l'état").

#### Système de combat auto — ordre et ciblage
- **Tous les serviteurs attaquent**, Avant et Arrière (l'Arrière n'est pas passif).
- **Ordre de résolution** : Rangée Avant d'abord (gauche → droite), puis Rangée Arrière (gauche → droite), en répétant ce cycle tant que les deux camps ont des survivants.
- **Alternance entre joueurs** : une attaque chez vous, puis une chez l'adversaire, puis retour chez vous, etc. (pas toutes les attaques d'un camp d'un coup).
- Si l'attaquant prévu dans l'ordre est déjà mort au moment de son tour, on **passe à l'attaquant suivant**.
- **Ciblage** (réutilise la logique existante du moteur) : Rempart adverse en priorité s'il y en a un ; sinon aléatoire dans la **Rangée Avant** adverse tant qu'elle contient un survivant ; la **Rangée Arrière** n'est ciblable que si la Rangée Avant adverse est entièrement vide (règle déjà existante dans `TargetingSystem`, réutilisée telle quelle).

#### Effectifs inégaux (validé)
- Chaque camp cycle **indépendamment** dans son propre ordre (Avant gauche→droite, puis Arrière gauche→droite).
- **L'alternance entre les deux joueurs reste stricte** à chaque attaque : jamais deux attaques du même camp d'affilée.
- Quand un camp a épuisé tous ses attaquants, il **reprend simplement depuis le début** de son propre cycle (boucle modulo sur sa liste de survivants), sans attendre l'autre camp.
- Exemple (5 vs 2) : A1→B1→A2→B2→A3→B1(reprise)→A4→B2(reprise)→A5→B1(reprise)→...

#### Pose sur le plateau
- Poser une carte achetée (déjà payée en boutique) sur le plateau est **gratuit, sans coût de mana en jeu** — contrairement au mode classique avec cristaux de mana par tour.

#### Règle clé : le plateau est une simulation temporaire
- Le combat est une **projection** : à la fin du round, le plateau revient à son état d'avant-combat.
- Seules **Vente** et **Achat** modifient durablement la composition du plateau.
- Les **morts en combat sont temporaires** (non permanentes) — la carte réapparaît au round suivant.
- **Exception : les buffs permanents restent acquis**, même si la carte concernée meurt pendant la simulation. Règle moteur : *"reset l'état de vie, jamais les stats permanentes."*

#### Fin de partie (validé)
- **Classement brut uniquement** (1er → 8e, basé sur l'ordre d'élimination), affiché en fin de partie.
- **Aucune récompense méta en v1** (pas de monnaie, pas de déblocage, pas de points de rang) — le projet n'a pas encore de système de compte/progression persistante sur lequel accrocher ça (le mode campagne/collection de cartes est un chantier séparé de la roadmap).
- *Extension future* : historique de parties, système de points de classement simple, cosmétiques débloqués par performance — une fois qu'un système de compte/progression existe ailleurs dans le jeu.

#### Ghost Board (appariement à effectif impair)
- Quand un joueur est éliminé, son plateau au moment de l'élimination est **sauvegardé sous forme de "fantôme"** (snapshot indépendant, pas une possession réelle de cartes).
- **Les cartes réelles de ce joueur retournent immédiatement au pool partagé** — le fantôme n'en dépend pas, il s'agit d'une copie utilisée uniquement pour la simulation de combat.
- Le fantôme est utilisé pour combler l'appariement uniquement quand le nombre de joueurs vivants est **impair** (ex: 7, 5, 3 survivants) : un joueur affronte le fantôme au lieu d'un adversaire réel.
- Quand le nombre de joueurs vivants est **pair** (ex: 6, 4, 2), aucun fantôme n'est utilisé — tous les appariements sont entre joueurs réels.
- **Un seul fantôme actif à la fois** : c'est toujours le plateau du **dernier joueur éliminé**. Quand un nouveau joueur est éliminé, le fantôme est remplacé par son plateau à lui.
- **Le fantôme reste un snapshot figé** : pas de scaling, il conserve exactement le plateau du joueur éliminé au moment de son élimination.
- **Le fantôme peut gagner ses combats** comme n'importe quel plateau réel — ce n'est pas un round de repos garanti, juste un plateau qui ne s'améliore plus avec le temps.

#### Anti-répétition d'appariement
Deux joueurs (ou un joueur et le fantôme) ne peuvent pas se recroiser avant un nombre minimum de rounds, dépendant du nombre de participants restants **en comptant le fantôme** :

| Participants restants (fantôme inclus) | Cooldown avant de refaire face au même adversaire |
|---|---|
| 8 ou 7 | 4 rounds |
| 6 ou 5 | 3 rounds |
| 4 ou 3 | 2 rounds |
| 2 | 1 round (un seul adversaire possible) |

Le fantôme est traité comme un participant à part entière pour ce calcul de cooldown, au même titre qu'un joueur réel.

### 🃏 Cycle de vie d'une carte

**Boutique → Main → Plateau (ou vente depuis la main) → si posée : vente depuis le plateau uniquement (pas de retour en main)**

| Action | Effet |
|---|---|
| Achat | Carte en main, coût = coût mana de la carte |
| Vente depuis la main | Remboursement 100% du prix d'achat |
| Vente depuis le plateau | Remboursement 50% du prix d'achat (pénalité d'engagement) |
| Carte vendue (main ou plateau) | Retourne dans le **pool partagé** |
| Carte "morte" en combat simulé | ❌ Ne retourne PAS au pool — réapparaît sur le plateau au round suivant |

- **Main max : 10 cartes.**

**Gestion du dépassement** :
- Si une fusion produit une carte 2★ alors que la main est déjà à 10/10, la carte 2★ est **mise en suspens** — elle n'entre pas en main et n'est ni jouable ni vendable tant qu'une place ne s'est pas libérée (vente ou pose d'une autre carte).
- Dès qu'une place se libère, la carte suspendue rejoint automatiquement la main.
- **À la fin de la phase Positionnement**, si un joueur a toujours plus de 10 cartes (main + carte(s) en suspens), l'excédent est **défaussé aléatoirement** pour revenir strictement à 10.

### 💰 Économie

- Or de départ : **1 au round 1**.
- Or : **+1 par round**, plafond **15**.
- **Pas de système d'intérêt.**
- Reroll boutique : **1 or fixe**.
- Achat de carte : coût = coût mana de la carte (1-8⬡, aligné avec la rareté — voir Pool).
- **Round 1 : montée de niveau du héros impossible** (achat d'XP désactivé). À partir du round 2, achat d'XP libre, sans verrou.
- **Nombre de cartes proposées par tirage boutique : 5.**
- **Durée de la phase Boutique + Positionnement : 45 secondes** (chiffre de départ, à ajuster en playtest selon le ressenti à 8 joueurs).
- **Philosophie de design (confirmée)** : sans intérêt et avec un plafond d'or à 15, garder de l'or inutilisé n'apporte aucun bénéfice — les joueurs sont incités à **dépenser un maximum d'or chaque round** pour chercher la meilleure composition possible, plutôt que d'épargner. C'est un choix assumé (contrairement à TFT où épargner est parfois optimal).

### 🧬 Pool de cartes partagé

Toutes les cartes proviennent d'un pool commun aux 8 joueurs.

#### Règle de verrouillage
- Toute carte en **main ou sur le plateau** d'un joueur est retirée du pool partagé (indisponible pour les autres).
- Elle **retourne au pool** quand elle est vendue (main ou plateau), **ou quand son possesseur est éliminé** (voir Ghost Board ci-dessous — l'élimination libère les cartes réelles, le fantôme n'est qu'une copie/simulation indépendante).
- **Fusion 2★** : les 3 copies fusionnées restent **verrouillées hors du pool tant que la carte 2★ existe**. Vendre la 2★ ne remet qu'**une seule copie** au pool (cohérent avec son remboursement à prix d'1 copie) — les 2 autres copies investies sont définitivement perdues pour le pool commun, comme dans TFT.

#### Tirage en boutique : deux étapes indépendantes
Plutôt qu'une matrice croisée rareté×coût, le tirage se fait en deux étapes :

1. **Coût mana** : déterminé par le niveau du héros (table de probabilités déjà définie plus haut).
2. **Rareté** (au sein du coût tiré) : distribution **variable selon le coût mana**, pour renforcer la sensation que monter en coût = monter en rareté :

| Coût mana | Commune | Rare | Épique | Légendaire |
|---|---|---|---|---|
| 1-2⬡ | 60% | 30% | 8% | 2% |
| 3-4⬡ | 45% | 35% | 15% | 5% |
| 5-6⬡ | 25% | 35% | 30% | 10% |
| 7-8⬡ | 10% | 25% | 40% | 25% |

3. **Carte précise** : tirée parmi les cartes correspondant au couple coût+rareté, **pondérée par le nombre de copies restantes dans le pool** (logique standard type TFT).

**Cas d'une rareté absente à un coût donné** (ex: aucune Légendaire à 1⬡) : les % correspondants sont redistribués proportionnellement aux raretés existantes à ce coût.

**Avantage** : n'exige pas d'aligner manuellement rareté et coût mana sur les ~150 cartes existantes — le système s'adapte automatiquement à ce qui existe réellement à chaque coût, quel que soit le mélange.

#### Copies disponibles dans le pool (par rareté)

| Rareté | Copies dans le pool (8 joueurs) |
|---|---|
| Commune | ~18-20 |
| Rare | ~13-15 |
| Épique | ~8-10 |
| Légendaire | ~3-4 |

*(chiffres à ajuster en playtest)*

#### Upgrade de cartes (fusion 3 copies → carte 2★)
- 3 copies identiques → version améliorée (**stats renforcées uniquement, texte/effet inchangé**).
- **Bonus de stats** : addition des stats des 3 cartes fusionnées (donc une base 2/2 + 2/2 + 2/2 → 6/6 sur la carte 2★, pas un simple +1/+1 fixe ni un doublement).
- **Buffs permanents accumulés** (ex: NÉCROPHAGE) sur une ou plusieurs des 3 copies avant fusion : **conservés et additionnés** sur la carte 2★ résultante — aucune perte de progression en fusionnant.
- **Vente d'une carte 2★** : remboursement calculé comme pour **une seule copie normale** (pas de bonus lié aux 3 cartes investies) — la fusion est donc un choix engageant, pas juste un "stockage de valeur" réversible sans perte.
- Choix fait pour rester simple à générer sur les ~150 cartes existantes sans réécrire de texte par carte.

#### Affichage et déclenchement de la fusion (validé)
- **Affichage** : étoile dorée en overlay sur `BoardMinion`/`Card` (coin haut), simple `TextureRect`/`Label` conditionnel, sans restructurer les scènes existantes.
- **La carte 2★ résultante va toujours en main**, peu importe où se trouvaient les 3 copies fusionnées (main, plateau, ou mélange des deux) — **exception explicite** à la règle générale "jamais de retour en main une fois posée", propre au cas de la fusion.
- Si une ou plusieurs des copies fusionnées étaient posées sur le plateau, leur case est **libérée** au moment de la fusion (le serviteur quitte le plateau, la 2★ devra être reposée manuellement par le joueur comme n'importe quelle carte en main).

### 📈 Progression : niveau de héros

**Durée de partie visée : ~25-30 rounds** (dernier survivant attendu autour de ce round, ~25-35 min de jeu). Cette durée est cohérente avec la courbe XP ci-dessous sans ajustement nécessaire — le niveau 8 devient atteignable naturellement autour du round 25-30 en combinant XP passive et achats volontaires.

Le niveau du héros ne débloque **pas des raretés**, mais des **coûts mana** en boutique (changement validé en cours de discussion) :

- XP passive : **+2 XP par round**, automatique.
- Achat d'XP en boutique : **1 or = 1 XP**, disponible à tout moment (aucun verrou par round).

| Niveau héros | XP requis (cumulé) | XP pour ce niveau | Coûts mana disponibles |
|---|---|---|---|
| 1 | 0 | — | 1⬡ |
| 2 | 4 | 4 | 1-2⬡ |
| 3 | 10 | 6 | 1-3⬡ |
| 4 | 18 | 8 | 1-4⬡ |
| 5 | 28 | 10 | 1-5⬡ |
| 6 | 40 | 12 | 1-6⬡ |
| 7 | 54 | 14 | 1-7⬡ |
| 8 | 70 | 16 | 1-8⬡ (tout débloqué) |

#### Probabilités d'apparition en boutique par coût mana (selon niveau)

| Niveau | 1⬡ | 2⬡ | 3⬡ | 4⬡ | 5⬡ | 6⬡ | 7⬡ | 8⬡ |
|---|---|---|---|---|---|---|---|---|
| 1 | 100% | — | — | — | — | — | — | — |
| 2 | 60% | 40% | — | — | — | — | — | — |
| 3 | 40% | 35% | 25% | — | — | — | — | — |
| 4 | 28% | 30% | 27% | 15% | — | — | — | — |
| 5 | 20% | 22% | 25% | 22% | 11% | — | — | — |
| 6 | 14% | 16% | 20% | 22% | 20% | 8% | — | — |
| 7 | 10% | 12% | 15% | 18% | 20% | 18% | 7% | — |
| 8 | 6% | 8% | 11% | 15% | 18% | 20% | 16% | 6% |

Logique : tous les coûts restent accessibles à tout niveau (jamais 0% une fois débloqués), mais la distribution se décale vers les coûts élevés à mesure que le niveau augmente. *(à calibrer selon le nombre de rounds visé pour une partie complète)*

### 🎴 Contenu jouable (v1)

- **Serviteurs** : tous éligibles.
- **Enchantements / Rituels** : **exclus en v1**. Prévus comme extension future via un système de **"Reliques"** débloquées à un round donné.

#### Incantations (sorts)

**Précision de fonctionnement (validée)** : l'adversaire du round est **révélé pendant la phase Positionnement**, avant le combat auto. Une Incantation ciblant un serviteur/plateau "ennemi" s'applique donc au plateau de l'adversaire déjà connu pour ce round — jouée comme une frappe préventive avant le combat.

**Règles de réinterprétation générales** :
- Toute durée "ce tour" / "jusqu'à fin de tour (adverse)" devient **"jusqu'à la fin de ce combat"**.
- Les effets ciblant un serviteur/plateau "ennemi" s'appliquent au **plateau de l'adversaire révélé pour ce round précis**.
- Les effets du type "tous les serviteurs en jeu" (sans distinction) sont recadrés aux **deux plateaux du combat en cours**, pas à toute la partie à 8 joueurs.

**Critères d'exclusion** : référence à la pioche/deck, renvoi en main/défausse (contredit la règle "jamais de retour en main"), référence aux enchantements/rituels (hors scope v1), Sacrifice (trigger exclu du mode), effets devenus obsolètes car le plateau est toujours restauré entre rounds (ex: ressusciter un mort n'a plus de sens).

**Verdict carte par carte — Mort-Vivant (40-52)**

| ID | Nom | Verdict | Raison |
|---|---|---|---|
| 40 | Souffle Nécrotique | ✅ Éligible | Dégât ciblé, direct |
| 41 | Réveil Soudain | ❌ Exclu | Ressuscite un mort — obsolète, le plateau est toujours restauré au début du round |
| 42 | Vague de Putréfaction | ✅ Éligible | Dégât de zone, ciblage adversaire résolu |
| 43 | Don de Chair | ❌ Exclu | Sacrifice (trigger exclu du mode) |
| 44 | Étreinte Glaciale | ✅ Adapté | "1 tour" → "ce combat" |
| 45 | Morsure Infectieuse | ⚠️ Éligible, à surveiller | Vol permanent d'une carte adverse avant combat — potentiellement fort, à tester en équilibrage |
| 46 | Cri des Damnés | ✅ Éligible | Buff temporaire sur soi |
| 47 | Poigne du Cimetière | ❌ Exclu | Renvoi en main — contredit la règle "jamais de retour en main" |
| 48 | Exhalation Toxique | ✅ Adapté | "Tous en jeu" → limité aux deux plateaux du combat |
| 49 | Dernier Soupir | ❌ Exclu | Pioche de carte |
| 50 | Éclat de Putréfaction | ❌ Exclu | Cible un enchantement (hors scope v1) |
| 51 | Souffle du Charnier | ✅ Éligible | Buff permanent ciblé — cohérent avec les règles de buffs persistants |
| 52 | Doigt Décharné | ❌ Exclu | Pioche de carte |

**Verdict carte par carte — Humain (H40-H52)**

| ID | Nom | Verdict | Raison |
|---|---|---|---|
| H40 | Cri de Ralliement | ✅ Éligible | Buff temporaire sur soi |
| H41 | Frappe Coordonnée | ✅ Adapté | Frappe préventive avant combat, ciblage adversaire résolu |
| H42 | Purification | ✅ Éligible | Cleanse sur soi |
| H43 | Repli Tactique | ✅ Éligible | Repositionnement Avant/Arrière |
| H44 | Volée de Flèches | ✅ Éligible | Dégât de zone adversaire |
| H45 | Bouclier de Foi | ✅ Adapté | Durée recadrée sur "ce combat" |
| H46 | Jugement Divin | ✅ Éligible | Destruction ciblée adversaire |
| H47 | Ordre d'Avancer | ✅ Adapté | "Ce tour" → "ce combat" |
| H48 | Contre-Offensive | ✅ Adapté | Effet actif sur toute la durée du combat |
| H49 | Appel aux Armes | ✅ Éligible | Invocation de tokens |
| H50 | Bénédiction de Guerre | ✅ Adapté | Durée recadrée |
| H51 | Massacre Sacré | ✅ Adapté | "Tous les Mort-Vivants ennemis" → plateau de l'adversaire du combat |
| H52 | Formation Défensive | ✅ Adapté | Durée recadrée sur "ce combat" |

**Bilan** : sur 26 sorts, 19 éligibles (dont 7 à adapter sur la formulation durée/cible), 5 exclus (pioche×3, retour en main×1, Sacrifice×1, enchantement×1), 1 exclu par obsolescence.

**Note** : cette passe d'éligibilité n'a pas encore été refaite pour la race Démon (ajoutée depuis, voir `CARDS.md`) — plusieurs de ses Incantations ciblent explicitement "ton héros" plutôt qu'un serviteur, un cas de figure qui n'existait pas encore lors de cette analyse.

### 🔥 Triggers en combat simulé

| Trigger | Actif pendant le combat simulé ? |
|---|---|
| Arrivée (ONPLAY) | ❌ Non — se déclenche uniquement à la pose réelle depuis la main |
| Sacrifice | ❌ Exclu du mode (pas d'input joueur pendant le combat auto) |
| Dernier Souffle (DEATHRATTLE) | ✅ Oui |
| Mort-rage (OnDeathRage) | ✅ Oui |
| Blessure (OnDamaged) | ✅ Oui |
| Exécution (OnExecution) | ✅ Oui |
| Ralliement (OnRally) | ✅ Oui |
| Éveil / Déclin / Deuil / Mourning / Carnage / Sortilège / Appel / Présence / Résonance | ✅ Oui |

#### Règle NÉCROPHAGE (et effets similaires)
- Les morts sont traitées **dans l'ordre chronologique** pendant la simulation (comme `DeathSystem` actuel en batch).
- Une carte n'est boostée que par les morts survenues **après son entrée en jeu** et **avant sa propre mort** (si elle meurt aussi, sans effet sur ce qui est déjà acquis).
- **Le buff accumulé est conservé au round suivant**, que la carte elle-même ait survécu ou soit "morte" (temporairement) pendant la simulation.

### 🧩 Synergies

**Décision : pas de système de traits/synergies dédié en v1.** Les mots-clés existants (HORDE, NÉCROPHAGE, etc.) remplissent déjà ce rôle organiquement. Un système de traits pourra être ajouté plus tard si le mode manque de direction stratégique en playtest.

### 🔮 Extensions futures (hors scope v1)

- **Pouvoir de héros** : chaque joueur choisit/reçoit un héros avec un pouvoir unique (actif ou passif), à la manière de HS Battlegrounds. Absent en v1 (tous les joueurs démarrent identiques).
- **Enchantements / Rituels** via un système de "Reliques" débloquées à un round donné (déjà noté plus haut).

### 🌐 Réseau & Visibilité

#### Hébergement (non tranché)
Décision reportée. Recommandation actuelle : démarrer en **P2P, un joueur hôte** (`ENetMultiplayerPeer`, API haut-niveau Godot) pour une v1 jouable entre amis via code de partie, sans infra serveur à héberger. Migration vers un serveur dédié envisageable plus tard si besoin de matchmaking public, sans réécrire la logique de jeu (`CombatSystem`/`EffectManager` restent inchangés, seule la couche transport change). Reste aussi à trancher : simulation de combat centralisée (hôte calcule et diffuse le résultat) vs déterministe locale par seed partagée (à la HS BG).

👉 **Base déjà en place** : le multijoueur 1v1 (voir section « Multijoueur 1v1 » plus haut) fournit désormais la couche transport ENet P2P, le handshake avec graine RNG partagée et le protocole de commandes — réutilisables pour le mode BR (reste à étendre le lobby à 8 joueurs).

#### Visibilité entre joueurs (validé)
- **Le plateau (board)** de chaque joueur est **visible par tous les autres joueurs** à tout moment (permet de scouter les adversaires, anticiper les fusions/synergies en cours, décision stratégique classique d'autobattler).
- **La main** de chaque joueur reste **strictement privée** — seul son possesseur la voit. Ça inclut la boutique en cours de consultation, qui fait partie de l'espace privé du joueur jusqu'à ce que les cartes soient posées sur le plateau.
- Implication réseau : le **plateau** de chaque joueur doit être synchronisé à tous les clients en continu (ou au minimum entre chaque round), alors que la **main/boutique** ne doit être envoyée qu'au client concerné — jamais broadcastée à l'ensemble de la partie.

### 📋 Points encore à trancher (mode BR)

1. Réseau/lobby pour 8 joueurs — hébergement, simulation centralisée vs déterministe (voir section Réseau ci-dessus).
2. Passe d'éligibilité des Incantations à refaire pour la race Démon (non couverte lors de l'analyse initiale, voir note ci-dessus).

---

## 🗺️ Roadmap

### Implémenté
*   Moteur de bataille complet (deux rangées, mots-clés, triggers, enchantements, auras, conditions et valeurs dynamiques sur les effets)
*   Deux races jouables : Mort-Vivant et Humain (151 cartes, voir `CARDS.md`)
*   Contenu de cartes de la race Démon défini (~75 cartes, voir `CARDS.md`) — implémentation moteur restant à faire, voir points à trancher dans `CARDS.md`
*   IA adverse basique (`AISystem`) — serviteurs uniquement
*   **Multijoueur 1v1 réseau** — P2P ENet (lobby IP/LAN), relais de commandes, RNG déterministe partagée, gestion des déconnexions (voir section « Multijoueur 1v1 »)
*   **Internationalisation FR/EN** — toute l'UI et les 151 cartes, via le système de traduction natif Godot (`translations/game.csv`)
*   Deck builder et gestion de decks (`DeckManager`) — avec filtre par type de carte
*   Menu principal, réglages (audio, contrôles, graphismes, affichage/langue), écran de chargement ; menu réglages complet accessible en cours de partie (avec bouton quitter)
*   UI de bataille : deck, main et mana adverses visibles, badges type/rareté/lane sur les cartes, raccourcis clavier, popups d'effets avec flèches vers les cibles
*   Design complet du mode Battle Royale 8 joueurs (voir section dédiée ci-dessus) — implémentation restant à faire

### À faire
*   IA : jouer les sorts, rituels et enchantements ; niveaux de difficulté
*   Multijoueur : matchmaking / hébergement au-delà de l'IP directe (code de partie, serveur relais...)
*   Implémentation du mode Battle Royale (design finalisé, voir section dédiée) — nécessite d'étendre le réseau à 8 joueurs
*   Nouvelles races : Elfe, Nain (Démon désormais en contenu, reste à coder côté moteur)
*   Mode campagne et collection de cartes
*   Animations shaders
*   Tests automatisés (GUT / gdUnit4)