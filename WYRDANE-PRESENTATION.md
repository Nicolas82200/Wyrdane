# Wyrdane — Présentation du jeu

Wyrdane est un jeu de cartes à collectionner (TCG) **dark fantasy**, **compétitif en 1 contre 1**, jouable sur PC. Deux joueurs s'affrontent avec leurs decks pour réduire les points de vie du héros adverse à 0, en posant des serviteurs, des sorts, des rituels et des enchantements sur un plateau à deux rangées.

---

## 🎴 Le plateau et les bases du combat

- Chaque joueur dispose de **deux rangées** : **Avant** (⚔️, au contact) et **Arrière** (🛡️, protégée). Certaines cartes sont **Hybrides** (↕️) et peuvent être posées dans l'une ou l'autre au choix du joueur.
- La rangée Arrière ne peut être attaquée que si la rangée Avant adverse est **entièrement vide** — la ligne de front doit tomber avant que l'arrière ne soit exposé (sauf mot-clé spécial qui l'ignore).
- Jusqu'à **10 serviteurs par rangée**, **20 en jeu au total** par joueur.
- Le combat se joue au tour par tour : chaque joueur pioche, pose des cartes, fait attaquer ses serviteurs, puis passe la main.
- Un héros commence avec ses points de vie ; le premier réduit à 0 perd la partie.

### Types de cartes

| Type | Description |
|---|---|
| **Serviteur** | Une unité posée sur le plateau, qui peut attaquer et être attaquée. |
| **Incantation (sort)** | Un effet immédiat, joué puis défaussé. |
| **Rituel** | Un effet persistant à charges limitées, qui se déclenche à certaines conditions jusqu'à épuisement. |
| **Enchantement** | Un effet passif permanent, actif tant qu'il n'est pas détruit. |
| **Ressource** | Une carte spéciale (coût 0) qui augmente le mana disponible d'une race — voir plus bas. |

---

## 💠 Un mana séparé par race

Fini le mana générique unique : **chaque race a sa propre réserve de mana**, alimentée uniquement en jouant une carte-ressource dédiée. Une seule carte-ressource peut être jouée par tour et par camp.

| Race | Ressource |
|---|---|
| Mort-Vivant | Chair |
| Humain | Sceau du Royaume |
| Démon | Âme |
| Abomination | Éclat d'Anomalie |

Le coût d'une carte se divise en deux parts : une partie **verrouillée** (payable uniquement avec le mana de sa propre race, proportionnelle à la rareté de la carte) et une partie **générique** (payable avec n'importe quel surplus de mana, toutes races confondues). Ce système récompense les decks mono-race tout en laissant une vraie place au multi-race pour qui sait équilibrer ses ressources.

En début de tour, plus besoin de choisir entre "mana" ou "pioche" : les réserves se rechargent automatiquement à leur maximum et une carte est piochée.

---

## 🏹 Mots-clés communs

Ces mots-clés existent quelle que soit la race du serviteur :

| Mot-clé | Effet |
|---|---|
| **Rempart** | Doit être attaqué en priorité par les serviteurs ennemis. |
| **Assaut** | Peut attaquer dès le tour où il est posé. |
| **Frénésie** | Peut attaquer deux fois dans le même tour. |
| **Ravage** | Les dégâts en excédent sur sa cible débordent directement sur le héros adverse. |
| **Infiltration** | Ignore la rangée Avant ennemie ; peut viser directement l'Arrière ou le héros. |
| **Moisson** | Les dégâts infligés par ce serviteur soignent le héros allié d'autant. |
| **Venin Mortel** | La moindre blessure infligée par ce serviteur détruit la cible, peu importe ses PV restants. |
| **Égide** | Annule la toute première source de dégâts reçue. |

### Déclencheurs (triggers)

Beaucoup de cartes réagissent à un évènement précis : **Arrivée** (posée en jeu), **Dernier Souffle** (à sa mort), **Mort-rage** (une fois, sous 50 % de ses PV max), **Blessure** (quand elle est touchée), **Attaque**, **Exécution** (quand elle tue un ennemi), **Éveil**/**Déclin** (début/fin de tour), **Renfort** (un allié arrive), **Deuil**/**Carnage** (un allié/un ennemi meurt), **Sortilège** (un sort allié est lancé), **Sacrifice**.

---

## 🧟 Les quatre races jouables

Wyrdane compte **320 cartes** réparties en quatre races, chacune avec son identité mécanique propre. Deux races supplémentaires (Elfe et Nain) sont en réflexion pour l'avenir.

### ☠️ Mort-Vivant — l'attrition et la contagion

Une armée qui use l'adversaire par le nombre et le poison plutôt que par la force brute.

- **Infection** : un serviteur infecté perd des points de vie à chaque début du tour de son propriétaire, et les marques s'accumulent — plus il y en a, plus les dégâts sont élevés. Seuls certains effets de soin peuvent tout guérir d'un coup.
- **Mort-rage** : une capacité qui se déclenche une seule fois, quand le serviteur passe sous la moitié de ses points de vie maximum.
- **Pestiféré** : ses attaques infligent l'Infection en plus des dégâts habituels.
- **Nécrophage** : gagne en puissance à chaque mort d'un allié.
- **Horde** : plus vous avez de Morts-Vivants en jeu, plus certains serviteurs deviennent forts.
- **Revenant** : revient à la vie une fois, avec 1 point de vie, la première fois qu'il devrait mourir.
- **Chair Morte** : immunisé aux effets néfastes des autres races (Infection, Corruption, Terreur).
- Le **cimetière** conserve tous les serviteurs alliés morts, visible des deux joueurs.

### ⚔️ Humain — l'ordre et le commandement

Une armée disciplinée qui gagne en cohésion et en coordination au fil de la partie.

- **Commandement** : les Humains invoqués après ce serviteur gagnent un bonus permanent d'attaque.
- **Formation** : plus fort tant qu'il combat aux côtés d'un allié.
- **Contre-attaque** : riposte automatiquement à qui lui inflige des dégâts.
- **Fortification** : ne peut pas être déplacé, renvoyé en main ni transformé par un effet ennemi.
- **Discipline** : immunisé aux effets néfastes des autres races (Infection, Corruption, Terreur).

### 🔥 Démon — le risque et le sacrifice

Une race qui paie ses effets les plus puissants... en points de vie de son propre héros.

- **Pacte X** : l'effet de base de la carte se déclenche toujours gratuitement, mais le joueur peut en plus payer X points de vie de son héros pour obtenir un effet bonus, souvent bien plus fort.
- **Corruption** : les attaques infligent, en plus des dégâts, une marque permanente qui réduit l'attaque de la cible.
- **Terreur** : un serviteur touché ne peut pas attaquer au tour suivant de son propriétaire.
- **Rang Infernal** : plus le héros du joueur est blessé, plus ce serviteur devient fort.
- **Sang Noir** : gagne en puissance chaque fois que le héros perd des points de vie à cause de ses propres cartes.
- Un pari risque/récompense assumé : sacrifier ses propres PV pour prendre l'avantage sur le plateau.

### 🧬 Abomination — la mutation et l'absorption

Une race chaotique qui grandit de façon imprévisible en dévorant ce qui l'entoure.

- **Mutation** : chaque fois qu'un serviteur avec ce mot-clé survit à une blessure, il subit un tirage aléatoire permanent (40 % de gagner de l'attaque, 40 % de gagner des PV, 20 % d'en perdre — pouvant aller jusqu'à la mort).
- **Fusion** : sacrifie volontairement un allié adjacent pour absorber ses statistiques restantes et l'un de ses mots-clés, au choix, définitivement.
- **Chair Adaptative** : copie, à son arrivée, un mot-clé présent sur n'importe quel serviteur en jeu, allié ou ennemi.
- **Virulent** : à sa mort, force immédiatement une mutation sur l'allié adjacent.
- **Assimilation** : gagne temporairement en puissance à chaque vague de morts sur le champ de bataille.
- Une race à haute variance, qui récompense la prise de risque et l'improvisation.

---

## 🧠 Jouer contre l'IA

Une intelligence artificielle complète est disponible pour jouer en solo :
- Elle choisit une race au hasard à chaque partie et construit son propre deck autour de celle-ci.
- Elle joue tous les types de cartes (serviteurs, sorts, rituels, enchantements) et priorise ses attaques intelligemment (provocations, coup fatal, échanges favorables).
- **Trois niveaux de difficulté** : Facile, Normal et Difficile.

---

## 🌐 Multijoueur en ligne (1 contre 1)

Le jeu propose un vrai mode multijoueur en ligne, connecté via Steam :

- **Partie rapide** : matchmaking automatique, trouve un adversaire en quelques secondes.
- **Partie classée** : file d'attente équilibrée par niveau (MMR), avec un système de **paliers** (Bronze, Argent, Or, Platine, Diamant, Maître, Légende) affichés sur le profil.
- **Contre un ami** : invitation directe via l'overlay Steam.
- Reconnexion automatique en cas de coupure internet passagère.
- Système anti-abandon : un joueur totalement inactif pendant plusieurs tours d'affilée est déclaré perdant, pour ne jamais laisser un adversaire en attente indéfiniment.
- Un **écran de classement** (leaderboard) affiche les 100 meilleurs joueurs par MMR.

---

## 🃏 Deck builder et collection

- Construisez vos decks librement : **minimum 40 cartes jouables** et **minimum 10 cartes-ressource** (sans maximum), mélangées dans le même paquet.
- Maximum **4 exemplaires** d'une même carte par deck (les cartes-ressource, elles, sont illimitées).
- Le deck builder vous alerte si votre équilibre race/ressource est incohérent, et vous suggère automatiquement un nombre de ressources adapté au coût moyen de votre deck.
- Les cartes se débloquent en jouant : ouverture de **packs**, **récompenses de progression**, **quêtes**, ou **achat direct à l'unité** contre de la monnaie du jeu.
- Le deck builder est aussi disponible sur le **site web du jeu**, en plus du client — pratique pour composer un deck sans lancer le jeu.

### Monnaie et packs

- Une monnaie molle (l'or) s'accumule en jouant, en remplissant des quêtes et en progressant en niveau de compte.
- Les **packs de cartes** s'achètent contre de l'or et contiennent des cartes aléatoires pondérées par rareté (Commune, Rare, Épique, Légendaire).
- Une carte tirée au-delà de la limite de 4 exemplaires est automatiquement convertie en or ("poussière").

---

## 📈 Progression de compte

- Chaque partie en ligne (classée ou rapide) rapporte de l'**XP de compte**, qui fait monter votre **niveau de joueur**.
- Chaque niveau franchi offre une récompense : or, carte aléatoire, ou pack gratuit selon des paliers réguliers.
- Une **série de victoires** en classé augmente le gain d'XP obtenu sur chaque victoire suivante.
- Une popup dédiée permet de consulter toutes les récompenses de niveau, atteintes ou à venir.

---

## 🎯 Quêtes et fidélité

- **Quêtes quotidiennes** : plusieurs objectifs tirés au hasard chaque jour (jouer des parties, gagner, jouer des cartes d'une race précise...), récompensées en or.
- **Quêtes hebdomadaires et mensuelles** : objectifs plus ambitieux, récompensés en or et en packs de cartes gratuits.
- **Quêtes uniques** : une quinzaine de jalons de carrière à débloquer une seule fois, avec de belles récompenses.
- **Récompense de connexion quotidienne** : un bonus d'or croissant sur 7 jours consécutifs de connexion.
- **Parrainage** : invitez un ami avec votre code personnel — récompense en or et en packs quand il termine le tutoriel.

---

## 🎓 Tutoriel guidé

Un tutoriel complet, scénarisé et interactif, accompagne les nouveaux joueurs pas à pas (y compris la phase de mulligan de départ) avec un adversaire scripté. Il se termine par l'obtention de **quatre decks de départ prêts à jouer** et de leurs cartes associées.

---

## 🏟️ Mode Arena (Battle Royale) — prototype

Un mode annexe façon autobattler, inspiré de Teamfight Tactics et Hearthstone Battlegrounds :

- **8 participants** (vous et des adversaires, contrôlés par bots en solo, ou par de vrais joueurs en réseau).
- Chaque round se déroule en 3 temps : **boutique** (achat de cartes avec de l'or, reroll, gel de l'offre), **positionnement** (organisation du plateau Avant/Arrière), puis **combat automatique** contre un adversaire tiré au sort.
- Le perdant du combat perd des points de vie de héros ; le dernier survivant l'emporte.
- **Fusion** : 3 exemplaires identiques d'une carte se combinent en une version améliorée aux statistiques renforcées.
- Un pool de cartes est **partagé entre tous les joueurs** — chaque carte achetée est indisponible pour les autres tant qu'elle n'est pas revendue.
- Actuellement jouable en solo local (1 joueur + 7 bots) ; le mode réseau à 8 joueurs réels est en cours de finalisation.

---

## ⚙️ Réglages et confort de jeu

- Menu de réglages complet, accessible aussi bien depuis le menu principal qu'en cours de partie : audio, graphismes, contrôles, affichage et langue.
- Un **panneau d'actualités** dans le menu principal affiche les dernières nouveautés et devlogs directement depuis le site du jeu.
- Les mots-clés de chaque carte s'affichent avec une infobulle explicative (survol pour un aperçu, clic droit pour le détail complet des effets/déclencheurs).

---

## ♿ Accessibilité

- **Échelle de l'interface** ajustable (85 % à 130 %).
- **Assistance daltonisme** (protanopie, deutéranopie, tritanopie) via un filtre qui décale les teintes confondues.
- **Contraste élevé**, cumulable avec l'assistance daltonisme.
- **Réduction des animations** pour limiter les mouvements et le shake d'écran.
- **Rebind clavier** des raccourcis principaux.
- Chaque mot-clé du jeu est déjà représenté par une **icône propre**, pas seulement par une couleur.

---

## 🌍 Langues

Le jeu est intégralement traduit en **français** et en **anglais** — interface, menus et texte des 320 cartes.

---

## 🏆 Succès Steam

**20 succès** sont prévus pour récompenser des exploits variés : victoire parfaite sans perdre de PV, deck massif, comeback héroïque, série de victoires en restant à PV élevés, exécution de plusieurs ennemis en un tour, victoire avec un deck mono-race, collection complète d'une race, victoire en classé, atteinte du palier Or, 100 victoires cumulées, fin du tutoriel, premier pack ouvert, et bien d'autres.

---

*Ce document présente les fonctionnalités de Wyrdane du point de vue du joueur. Pour la documentation technique et les règles complètes, voir `README.md` et `CARDS.md`.*
