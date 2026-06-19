# FateBound

**Dark Fantasy TCG compétitif — 1v1**

FateBound est un jeu de cartes à collectionner stratégique dans un univers dark fantasy. Deux joueurs s'affrontent et cherchent à réduire le héros adverse à 0 HP.

---

## Plateau de jeu

Chaque joueur dispose de deux rangées :

- **Rangée Avant** — serviteurs en première ligne. Protège la rangée Arrière et le héros. Doit être vide pour que le héros adverse soit attaquable directement.
- **Rangée Arrière** — serviteurs de soutien, générateurs, buffers. Protégés tant que la rangée Avant est occupée.

Chaque rangée peut accueillir **10 serviteurs maximum**. Un joueur ne peut avoir plus de **20 serviteurs** en jeu simultanément.

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
| **Serviteur** | Unité placée sur le plateau, Avant ou Arrière. |
| **Éphémère** | Sort à effet immédiat, jeté et défaussé. |
| **Rituel** | Sort permanent actif pendant X tours. |
| **Enchantement** | Effet passif permanent jusqu'à destruction. |

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
| **REMPART** | Doit être attaqué en priorité. |
| **ASSAUT** | Peut attaquer le tour de son invocation. |
| **FRÉNÉSIE** | Peut attaquer deux fois par tour. |
| **RAVAGE** | Les dégâts excédentaires sont infligés au héros adverse. |
| **AILES NOIRES** | Ignore la rangée Avant ennemie (attaque directement la Arrière ou le héros). |
| **MOISSON** | Les dégâts infligés soignent le héros allié. |
| **VENIN MORTEL** | Toute blessure infligée détruit la cible. |
| **ÉGIDE** | Ignore la première source de dégâts reçue. |

---

## Triggers

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
| **Sacrifice** | Une unité alliée est sacrifiée. |
| **Exécution** | Une unité ennemie meurt. |
| **Carnage** | N'importe quelle unité meurt. |

---

## Mécaniques spéciales Mort-Vivant

**Infection** — Un serviteur infecté perd 1 HP au début du tour adverse. Persiste jusqu'à la mort. Amplifiée par certains enchantements (ex. Brouillard Pestilentiel).

**Mort-rage** — Se déclenche quand le serviteur tombe sous la moitié de ses HP max pour la première fois. Une seule fois par serviteur.

**Cimetière** — Pile de tous les serviteurs alliés morts, visible par les deux joueurs. De nombreuses cartes Mort-Vivant interagissent avec le cimetière (résurrection, pioche, invocation). L'ordre est préservé.

**Sacrifice** — Détruire volontairement un serviteur allié pour déclencher un effet. Le serviteur va au cimetière normalement et peut être réanimé.

---

## Fichiers du projet

- `README.md` — Ce fichier. Règles, mécaniques, structure du jeu.
- `CARDS.md` — Liste complète de toutes les cartes avec stats, triggers et effets.

## Technologies

Godot 4
GDScript

## Structure du projet

scenes/
├── battle/
├── card/
├── hand/
├── hero/
├── minion/

scripts/
├── battle/
├── card/
├── data/
├── effects/

## Lancer le projet

Ouvrir le projet dans Godot 4.
Charger la scène principale.
Exécuter le projet.

## Roadmap

[ ]IA adverse
[ ]Mode campagne
[ ]Collection de cartes
[ ]Construction de deck
[ ]Effets avancés
[ ]Multijoueur

## Auteur

Nicolas Séménadisse