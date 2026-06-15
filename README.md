# Fantasy Card Game (Godot 4)

Un jeu de cartes stratégique inspiré de Hearthstone, World of Warcraft TCG et Warcraft, développé avec Godot 4.

L'objectif du projet est de construire un moteur de jeu de cartes flexible, orienté données et facilement extensible afin de supporter des centaines de cartes, des synergies complexes, des campagnes PvE et une IA avancée.

---

## Fonctionnalités actuelles

### Cartes

Les cartes sont définies via des ressources `CardData`.

Chaque carte possède :

* Nom
* Description
* Illustration
* Coût en mana
* Race
* Type
* Statistiques
* Mots-clés
* Trigger
* Liste d'effets

### Types de cartes

* Minion
* Spell
* Weapon (prévu)

### Races

* Human
* Elf
* Dwarf
* Undead
* Demon

### Mots-clés

* Taunt
* Charge
* Protection
* Lifesteal
* Fury

---

## Système d'effets

Le projet utilise une architecture centralisée basée sur un `EffectManager`.

Tous les effets du jeu transitent par :

```gdscript
EffectManager.execute_effect(
    battle,
    source_minion,
    effect,
    selected_target
)
```

### Effets disponibles

* Damage
* Heal
* Buff
* Destroy
* DrawCard
* SummonMinion
* StealHealth

### Système de ciblage

Les effets sont séparés de leurs cibles :

Exemples :

```text
Damage + EnemyHero
Damage + AllEnemies
Heal + AllAllies
Buff + RandomAlly
```

Cibles actuellement supportées :

```text
Self
EnemyHero
OwnerHero

EnemyMinion
AllyMinion
AnyMinion

AllEnemies
AllAllies
AllMinions

RandomEnemy
RandomAlly
```

### Filtres

Les effets peuvent être filtrés par race :

```text
Damage all Demons
Heal all Undead
Buff all Elves
```

---

## Triggers

Les cartes peuvent réagir à différents événements :

```text
Battlecry
Deathrattle
OnAllyDeath
OnTurnStart
OnTurnEnd
OnAttack
OnDamaged
Aura
```

---

## Architecture

### CardData

Définition des cartes.

```text
CardData
 ├─ Nom
 ├─ Description
 ├─ Stats
 ├─ Keywords
 ├─ Trigger
 └─ Effects[]
```

### CardEffect

Définition d'un effet indépendant de la carte.

```text
CardEffect
 ├─ Effect Type
 ├─ Target Type
 ├─ Value
 ├─ Filters
 └─ Summon / Transform Data
```

### EffectManager

Responsable de l'exécution de tous les effets du jeu.

```text
Card Played
    ↓
EffectManager
    ↓
Target Resolution
    ↓
Effect Application
```

### Battle

Contient l'état complet de la partie :

```text
Heroes
Boards
Hands
Decks
Mana
Turn State
```

### Minion

Représentation runtime d'un serviteur sur le plateau.

```text
Attack
Health
Max Health
Keywords
Owner
Card Data
```

---

## Interface

### Plateau

Interface fantasy sombre inspirée de :

* Hearthstone
* Warcraft
* Diablo
* WoW TCG

### Fonctionnalités actuelles

* Plateau de jeu
* Main en éventail
* Invocation de serviteurs
* Battlecry
* Deathrattle
* Gestion du mana
* Ciblage de base

### Fonctionnalités prévues

* Animations d'attaque
* Animations de pioche
* Effets visuels
* Drag & Drop
* Zoom des cartes
* Hover avancé
* Sons
* Particules

---

## Roadmap

### Court terme

* Conversion des strings en enums
* Système complet de mots-clés
* Effets ciblés avancés
* Amélioration de l'UI

### Moyen terme

* Système d'événements global
* Auras dynamiques
* Cartes légendaires
* Synergies de race

### Long terme

* IA
* Campagne PvE
* Génération de rencontres
* Collection de cartes
* Progression du joueur
* Éditeur de cartes

---

## Technologies

* Godot 4
* GDScript

---

## Philosophie du projet

Le projet privilégie :

* Architecture orientée données
* Extensibilité
* Réutilisation du code
* Séparation des responsabilités
* Facilité d'ajout de nouvelles cartes

L'objectif est d'éviter le code spécifique aux cartes et de permettre la création de nouvelles mécaniques principalement via les ressources de données.

---

## État du projet

En développement actif.
