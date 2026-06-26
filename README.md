
# 🧠 Architecture interne (dev)

Cette section décrit le fonctionnement réel du moteur de jeu côté Godot.

---

## 🔁 Cycle de rendu du board

Le board n’est **pas redessiné entièrement en boucle**.

Le système fonctionne en 3 étapes :

1. Les données (`player_minions`, `enemy_minions`) sont la source de vérité
2. Les visuals (`BoardMinion`) sont stockés dans `minion_to_visual`
3. `refresh_board()` met uniquement à jour les visuels existants

```gdscript
refresh_board():
- update_display() sur les minions existants
- pas de recréation massive sauf spawn/death
```

⚠️ Important :

* `_refreshing` empêche les appels récursifs
* `_refresh_again` permet de re-run proprement si update en cascade

---

## 🧱 Système de mapping Minion → Visual

Chaque unité logique a un équivalent visuel :

```gdscript
var minion_to_visual: Dictionary = {} # Minion -> BoardMinion
```

* Création → `_rebuild_minion_visuals()`
* Suppression → `remove_dead_minions()`
* Recherche → `_find_board_minion_visual()`

👉 Le jeu ne “recrée pas le board”, il **déplace / met à jour des objets existants**.

---

## ⚔️ Flow de combat

Ordre exact d’un combat :

1. Animation `_animate_attack_lunge()`
2. Trigger `OnAttack`
3. Application dégâts simultanés
4. Effets spéciaux :

   * Poison / Deadly
   * Lifesteal
5. Trigger `OnDamaged`
6. Mise à jour UI
7. `remove_dead_minions()`
8. check game end

---

## ☠️ Système de mort

Les morts sont traitées en batch :

```gdscript
_processing_deaths = true
```

Étapes :

1. Détection des unités mortes
2. Animation `_play_death_animation`
3. Suppression visuelle
4. Ajout cimetière
5. Trigger `DEATHRATTLE`
6. Cleanup arrays
7. refresh_board()

👉 Important : **les morts sont groupées pour éviter les bugs de cascade**

---

## 🎯 Système de sélection

Deux modes :

### 1. Sélection simple

* 1 attaquant
* clic → attaque directe

### 2. Multi-sélection (CTRL)

```gdscript
selected_attackers[]
selected_board_minions[]
```

* Attaques en chaîne
* Résolution gauche → droite
* `_resolve_multi_attack()`

---

## 🖱️ Drag & Drop (main → board)

### États principaux :

```gdscript
_is_dragging_card
waiting_for_target
pending_card
pending_row
```

### Fonctionnement :

1. Drag commencé → main compacte
2. Affichage preview `BoardMinion ghost`
3. Highlight des lanes
4. Placeholder dynamique `_drop_placeholder`
5. Calcul index insertion :

```gdscript
_get_stable_player_drop_index_at()
```

---

## 🧪 Système d’effets

Centralisé dans :

```gdscript
EffectManagerData.execute_effect()
EffectManagerData.execute_targeted_effect()
```

Triggers disponibles :

* ONPLAY
* DEATHRATTLE
* ONTURNSTART / ONTURNEND
* OnAttack / OnDamaged

👉 Les effets sont **data-driven (CardData)**, pas hardcodés dans les minions.

---

## 🧠 Gestion des lanes

Deux lignes par joueur :

* Front (`ROW_FRONT`)
* Back (`ROW_BACK`)

Règles :

* Front protège Back
* Back inaccessible si Front occupée (selon logique d’attaque)
* cartes peuvent être limitées par `board_position`

---

## 🚨 Systèmes de protection anti-bug

Tu as plusieurs garde-fous importants :

### Anti double refresh

```gdscript
_refreshing / _refresh_again
```

### Anti mort multiple

```gdscript
_processing_deaths
```

### Anti drag UI conflict

```gdscript
_is_dragging_card
```

---

## 🎞️ Animations système

Animations centralisées :

* `_animate_attack_lunge`
* `_play_death_animation`
* `_play_summon_animation`

Toutes utilisent :

```gdscript
create_tween()
```

👉 Important : gameplay **attend parfois la fin des animations (`await`)**

---

## 📦 Classes critiques

* `Minion` → logique pure
* `BoardMinion` → UI
* `CardData` → données carte
* `Hero` → HP + logique joueur
* `Graveyard` → stockage morts
* `EffectManagerData` → moteur d’effets

---

## ⚠️ Point important (debug futur)

Si le board “ne s’affiche plus” :

Vérifier dans cet ordre :

1. `refresh_board()` est appelé ?
2. `minion_to_visual` contient des entrées ?
3. `_rebuild_minion_visuals()` est exécuté ?
4. containers non null :

   * `player_front_container`
   * `player_back_container`
5. `BoardMinion.tscn` bien instancié

---

## 🧩 Résumé mental du système

> Le jeu ne rebuild jamais le board.
> Il maintient une “simulation logique” + une “projection visuelle synchronisée”.

---

