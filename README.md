# FateBound

**Dark Fantasy TCG compétitif — 1v1**

FateBound est un jeu de cartes à collectionner stratégique dans un univers dark fantasy. Deux joueurs s'affrontent et cherchent à réduire le héros adverse à 0 HP.

---

## Plateau de jeu

Chaque joueur dispose de **deux rangées positionnelles**:

- **Rangée Avant** — serviteurs en première ligne. Protège la rangée Arrière et le héros. Doit être vide pour que le héros adverse soit attaquable directement. Max 10 serviteurs.
- **Rangée Arrière** — serviteurs de soutien, générateurs, buffers. Protégés tant que la rangée Avant est occupée. Max 10 serviteurs.

**Total max**: 20 serviteurs en jeu simultanément.

### Système de Placement

Lors du drag d'une carte de la main:
- La main se **compacte** avec animation pour faire de la place
- La carte **grandit** progressivement à la taille qu'elle aura sur le board
- La **rangée cible** s'illumine (Avant ou Arrière selon le type de carte)
- Un **aperçu ghost** affiche où la carte sera placée dans la rangée
- Les cartes existantes se **décalent visuellement** pour montrer leur future position
- La carte peut être placée **n'importe où** dans sa rangée (flexibilité positionnelle)

---

## Système de mana

Au début de chaque tour, le joueur choisit **l'une des deux options** :

- **+1 Mana Max** — augmente la réserve maximale de mana de façon permanente.
- **Piocher 1 carte** — renforce immédiatement la main.

Il n'y a **aucun plafond de mana**. La gestion de cette progression est une décision stratégique centrale.

---

## Types de cartes

| Type | Description |
|---|---|
| **Serviteur** | Unité placée sur le plateau, Avant ou Arrière. Peut être hybride et joué dans n'importe quelle rangée. |
| **Éphémère** | Sort à effet immédiat, jeté et défaussé. |
| **Rituel** | Sort permanent actif pendant X tours. |
| **Enchantement** | Effet passif permanent jusqu'à destruction. |

---

## Types de Positionnement (Lane Types)

| Type | Description | Placement |
|---|---|---|
| **⚔️ Avant** | Optimisé pour la rangée Avant | Force sur Avant |
| **🛡️ Arrière** | Optimisé pour la rangée Arrière | Force sur Arrière |
| **↕️ Hybride** | Flexible, fonctionne dans les deux | Au choix du joueur |

---

## Races

| Race | Thèmes |
|---|---|
| **Mort-Vivant** | Réanimation · Cimetière · Infection · Invocation · Sacrifice |
| **Humain** | Formation · Commandants · Bonus alliés · Synergies positionnement |
| **Elfe** | Croissance · Buffs progressifs · Valeur long terme |
| **Nain** | Armure · Résistance · Défense · Fortifications |
| **Démon** | Sacrifice · Perte HP · Agressivité · Puissance explosive |

---

## Mots-clés

| Mot-clé | Effet |
|---|---|
| **REMPART** | Doit être attaqué en priorité. Protège les unités derrière. |
| **ASSAUT** | Peut attaquer le tour de son invocation. Parfait pour action immédiate. |
| **FRÉNÉSIE** | Peut attaquer deux fois par tour. Agressif et explosif. |
| **RAVAGE** | Les dégâts excédentaires sont infligés au héros adverse. Contourne la défense. |
| **AILES NOIRES** | Ignore la rangée Avant ennemie (attaque directement la Arrière ou le héros). Bypass de l'avant-garde. |
| **MOISSON** | Les dégâts infligés soignent le héros allié. Sustain passif. |
| **VENIN MORTEL** | Toute blessure infligée détruit la cible. Instant kill peu importe les HP. |
| **ÉGIDE** | Ignore la première source de dégâts reçue. Armure contre un coup. |

---

## Triggers (Déclencheurs d'Effets)

Les effets de cartes se déclenchent sur les événements suivants :

| Trigger | Condition |
|---|---|
| **Invocation** | Cette unité arrive sur le plateau. |
| **Dernier Souffle** | Cette unité meurt. |
| **Assaut** | Cette unité attaque. |
| **Blessure** | Cette unité subit des dégâts. |
| **Éveil** | Début du tour du joueur. |
| **Déclin** | Fin du tour du joueur. |
| **Ralliement** | Une unité alliée arrive sur le plateau. |
| **Deuil** | Une unité alliée meurt. |
| **Sortilège** | Un sort allié est lancé. |
| **Sacrifice** | Une unité alliée est sacrifiée volontairement. |
| **Exécution** | Une unité ennemie meurt. |
| **Carnage** | N'importe quelle unité (alliée ou ennemie) meurt. |

---

## Mécaniques spéciales Mort-Vivant

**Infection** — Un serviteur infecté perd 1 HP au début du tour adverse. Persiste jusqu'à la mort. Amplifiée par certains enchantements (ex. Brouillard Pestilentiel). Peut être appliquée à plusieurs serviteurs.

**Mort-rage** — Se déclenche quand le serviteur tombe sous la moitié de ses HP max pour la première fois. Une seule fois par serviteur. Effet puissant de comeback.

**Cimetière** — Pile de tous les serviteurs alliés morts, visible par les deux joueurs. De nombreuses cartes Mort-Vivant interagissent avec le cimetière (résurrection, pioche, invocation). L'ordre est préservé (LIFO).

**Sacrifice** — Détruire volontairement un serviteur allié pour déclencher un effet. Le serviteur va au cimetière normalement et peut être réanimé.

---

## Fichiers du projet

- `README.md` — Ce fichier. Règles, mécaniques, structure du jeu.
- `CARDS.md` — Liste complète de toutes les cartes avec stats, triggers et effets.

---

## Technologies

- **Godot 4** — Engine de jeu
- **GDScript** — Langage de scripting

---

## Structure du projet

```
scenes/
├── battle/          # Scène principale de bataille
├── card/            # Affichage d'une carte
├── hand/            # Gestion de la main du joueur
├── hero/            # Panneaux du héros
├── minion/          # Affichage serviteur sur board
└── graveyard/       # Affichage du cimetière

scripts/
├── battle/          # Logique de bataille, board, lanes
├── card/            # Logique de carte et drag&drop
├── data/            # Structures de données (CardData, Keyword, etc.)
├── effects/         # Système d'effets de cartes
├── hand/            # Gestion et layout de la main
├── minion/          # Logique serviteur
└── hero/            # Logique héros
```

---

## Lancer le projet

1. Ouvrir le projet dans Godot 4
2. Charger la scène `scenes/battle/Battle.tscn` comme scène principale
3. Exécuter le projet (F5)

---

## Roadmap

- [ ] IA adverse
- [ ] Mode campagne
- [ ] Collection de cartes
- [ ] Construction de deck
- [ ] Effets avancés
- [ ] Multijoueur
- [ ] Animations Shaders

---

## Auteur

Nicolas Séménadisse