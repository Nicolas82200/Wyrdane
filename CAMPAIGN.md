# 🗡️ Mode Campagne — Design Document

> Document de travail — reflète l'état des décisions prises en session de design. Structure amenée à évoluer, notamment sur les points encore ouverts listés en fin de document.

> **Implémenté.** Toutes les sections de ce document sont implémentées (`scripts/campaign/` + `scenes/campaign/`, voir README.md « Mode Campagne »), y compris les points restés ouverts ci-dessous — sur ceux-là, une hypothèse simple a été prise pour ne pas bloquer le développement plutôt que d'attendre une décision. Les hypothèses prises sont listées dans `TODO.md` (section P7) ; ce document n'est volontairement pas modifié pour refléter ces choix, afin de garder trace de l'intention de design d'origine tant qu'elle n'est pas explicitement validée.

## 🎯 Concept général

Run roguelite solo, **sans fin**, avec une difficulté croissante par paliers. Le joueur part avec un deck préfabriqué (race choisie) et progresse sur une carte à embranchements, combat après combat, jusqu'à sa mort — il n'y a pas de "victoire" au sens classique, la run est conçue pour finir par tuer le joueur à mesure que la difficulté grimpe.

Distinct de la « partie rapide » (deck construit à l'avance) et du multijoueur 1v1.

---

## 🗺️ Structure de la run

- **Choix de race** au lancement : Mort-Vivant, Humain, Démon ou Abomination.
- **Constitution du plateau de départ** : pas de deck ni de pioche — le joueur fait 5 choix successifs parmi 3 cartes Commune de sa race, formant les 5 premières cartes de son plateau (détail complet en section « Constitution du plateau »).
- **Carte de run à embranchements**, paliers successifs, **sans plafond de progression** (contrairement à la v1 initiale à 8 paliers fixes) :
  - **Nombre de chemins par palier : aléatoire (1 à 3 chemins tirés au hasard à chaque palier)**, pas un nombre fixe sur toute la run.
  - Types de nœuds : Combat (Normal), Élite, Boss, Événement, Boutique, Repos.
  - Un Boss apparaît **tous les 10 paliers**, tiré aléatoirement dans un pool de Boss — ce n'est **plus une fin de run**, plutôt un "Élite++" récurrent qui jalonne la progression.
  - **Un nœud Repos est garanti juste avant chaque Boss** (tous les 10 paliers).
  - **La densité des nœuds évolue avec la profondeur** : plus d'Élites et d'Événements à mesure que la run avance ; la fréquence de Repos et de Boutique reste stable (ne diminue pas, pour ne pas punir doublement la difficulté déjà croissante).
- **PV du héros persistants** d'un combat à l'autre ; seul un nœud Repos permet d'en récupérer (soigne 30 % des PV manquants — à revalider avec la nouvelle courbe de difficulté).
- **Défaite** : la run s'arrête immédiatement à la mort du héros. Récompense de consolation en monnaie molle, proportionnelle à la profondeur atteinte.
- Pas de sauvegarde de run "manuelle" — voir section Sauvegarde ci-dessous pour la persistance automatique.

---

## 💾 Sauvegarde de run persistante

**Objectif** : permettre au joueur de fermer le jeu (volontairement ou via crash) sans perdre sa progression de run.

### Déclencheurs de sauvegarde
- **Juste avant d'engager un combat** (nœud choisi, adversaire déjà tiré et figé pour ce nœud).
- **Juste après une victoire** (deck/PV/nœud mis à jour).

### Contenu sauvegardé
- Deck actuel de la run
- PV du héros
- Position sur la carte (nœuds résolus / nœud en cours)
- Reliques et monnaie de run
- L'adversaire figé du nœud en cours (pour qu'il soit identique en cas de relance)
- Les **3 cartes de récompense proposées**, si un combat est gagné mais le choix de carte pas encore fait

### Comportement de reprise
- Le joueur retombe **toujours sur l'écran Carte de run**, jamais directement en combat ni sur l'écran de récompense.
- S'il avait un combat engagé non résolu : le nœud reste "à faire", **même adversaire**, à relancer manuellement.
- S'il avait gagné un combat sans avoir choisi sa récompense : il retrouve le même choix parmi les 3 mêmes cartes proposées.

### Portée
- **Sauvegarde locale uniquement** (fichier `user://`). La run est éphémère par nature (une session de jeu), pas de la progression durable à synchroniser.
- Seule la récompense de consolation (défaite) ou le résumé de fin de run remonte au backend (`wyrdane-backend`), comme la progression méta classique.

---

## ⚔️ Système de combat — Auto-battler tour par tour

Changement majeur par rapport à la v1 (qui prévoyait un combat classique tour par tour façon partie rapide) : le combat de Campagne devient un **auto-battler**, dans l'esprit du Battle Royale, mais avec une couche de décision manuelle sur les attaques.

### Principes
- **Pas de main ni de mana en combat** : les cartes sont déjà posées sur le plateau avant l'affrontement (pas de phase de pose pendant le combat lui-même).
- **Tour par tour, alternance stricte** joueur ↔ adversaire.
- **1 tour = 1 attaque** par défaut : le joueur choisit **quelle carte** attaque et **quelle cible**, contraint par les règles de ciblage existantes (Rempart prioritaire, Rangée Arrière inaccessible tant que l'Avant adverse a un survivant — logique déjà en place dans `TargetingSystem`).
- Une même carte peut attaquer à des tours différents sans limite de rotation (pas d'obligation de faire tourner ses attaquants).

### Mots-clés spécifiques à ce mode
- **FRÉNÉSIE** : la carte attaque 2 fois pendant son tour ; cibles libres (identiques ou différentes). Ça compte comme le tour du joueur.
- **CHARGE** (redéfini par rapport à son usage classique) : en plus de l'attaque normale obligatoire du tour, le joueur peut *optionnellement* faire attaquer chaque carte CHARGE vivante sur son plateau, avec cible choisie pour chacune. Répétable à chaque tour tant que la carte est vivante. Une carte CHARGE utilisée en attaque bonus ne peut pas *aussi* servir d'attaque normale ce même tour (pas cumulable, sauf si elle a également FRÉNÉSIE).
- **IA** : a accès aux mêmes mécaniques (FRÉNÉSIE, CHARGE) et choisit selon sa propre logique d'évaluation (héritée d'`AISystem` : Provocation > létal > trade favorable > héros).

### Mort en combat
- **Définitive** : toute carte détruite en combat est retirée du deck de run (pas de résurrection temporaire comme au Battle Royale).

### Condition de fin de combat
- Le combat continue tant qu'un camp a **des serviteurs vivants** OU **des enchantements/rituels capables d'en invoquer de nouveaux**.
- Une fois le plateau d'un camp entièrement vide, le héros de ce camp devient **directement attaquable** (ses PV servent de filet de sécurité pendant qu'on attend une éventuelle invocation).
- Un joueur perd le combat quand : plateau vide **ET** plus aucun moyen d'en recréer un **ET** PV du héros à 0.
- Ça donne un vrai enjeu de timing aux enchantements/rituels de invocation, et une raison d'être aux PV de héros pendant le combat (pas seulement entre les combats).

---

## 🃏 Constitution du plateau (pas de deck/pioche en Campagne)

Il n'y a **aucune carte-ressource et aucune pioche** en mode Campagne. Le plateau se construit directement, carte par carte, à la fois pour le joueur et l'adversaire.

### Côté joueur
- **Début de run** : 5 choix successifs, chacun proposant 3 cartes Commune de la race choisie — le joueur en sélectionne une à chaque fois, ce qui constitue les 5 premières cartes de son plateau.
- **Après chaque victoire** : 1 choix parmi 3 cartes vient s'ajouter au plateau (récompense de combat classique).
- Le plateau du joueur grossit **uniquement** via les récompenses de combat, jamais automatiquement.

### Côté adversaire
- Pas de "deck" — les cartes sont tirées directement pour composer le plateau adverse, dans le pool de la **race définie pour la tranche de 10 paliers en cours** (une race différente à chaque tranche).
- **Placement sur le plateau (Avant/Arrière) entièrement aléatoire** — pas de logique de remplissage (pas de règle "Avant d'abord").
- **Plafond du plateau : 20 cartes maximum (10 Avant + 10 Arrière)**, pour le joueur comme pour l'adversaire.

---

## 📈 Scaling de la difficulté

Deux logiques de scaling **indépendantes et cumulables**, selon le type d'adversaire.

### Normal — scaling par palier
- **Rythme** : tous les 10 paliers.
- **Multiplicateur** : x1,5 cumulatif sur les PV et les stats des cartes, arrondi **au supérieur** à chaque étape (jamais de décimale). Exemple PV : 10 → 15 → 23 → 35 → ...
- **Nombre de cartes** : +1 carte tous les 2 paliers (départ à 3 cartes), jusqu'au plafond de 20 cartes/plateau.

### Élite et Boss — scaling par victoire (pas par palier)
- Élite et Boss **ne suivent pas** le scaling par palier des combats Normaux — leur difficulté dépend uniquement du **nombre de victoires déjà remportées** contre ce type d'adversaire dans la run, pas du palier atteint.
- Chaque type a son **propre compteur de victoires**, totalement indépendant (battre des Élites ne renforce pas les Boss, et inversement).
- **Après chaque victoire** contre ce type : le prochain adversaire de ce type a PV x1,5, stats des cartes x1,5, et quelques cartes en plus sur son plateau (montant exact non encore fixé, voir points ouverts).

### Tableau récapitulatif (valeurs de base, avant tout scaling)

| Type | PV de base | Nb cartes de départ | Scaling |
|---|---|---|---|
| **Normal** | 10 | 3 | x1,5 (PV+stats) tous les 10 paliers ; +1 carte tous les 2 paliers |
| **Élite** | 20 | 5 | x1,5 (PV+stats) + cartes en plus, après chaque Élite vaincu |
| **Boss** | 30 | 7 | x1,5 (PV+stats) + cartes en plus, après chaque Boss vaincu |

### Decks/pools adverses générés par tranche
- **Génération aléatoire au lancement de la run**, régénérée entièrement **tous les 10 paliers** avec de nouvelles cartes tirées aléatoirement dans le pool de la race de la tranche en cours.
- **Rareté croissante avec la profondeur (pool Normal)** : à chaque régénération, la distribution de rareté des cartes tirées se décale vers le haut. **Cumulable** avec le x1,5 sur PV/stats — au palier 70 par exemple, les cartes sont à la fois plus rares (donc plus fortes de base) ET leurs stats sont multipliées par le x1,5 cumulatif.

| Tranche de paliers | Commune | Rare | Épique | Légendaire |
|---|---|---|---|---|
| 1-10 | 70% | 25% | 5% | 0% |
| 11-20 | 55% | 30% | 12% | 3% |
| 21-30 | 40% | 32% | 20% | 8% |
| 31-40 | 28% | 32% | 26% | 14% |
| 41-50 | 18% | 28% | 32% | 22% |
| 51-60 et au-delà | 10% | 22% | 35% | 33% |

*(la table plafonne à la tranche 51-60 ; le x1,5 cumulatif sur les stats, lui, continue de grimper sans plafond au-delà)*

- **Rareté Élite/Boss** : ne suit **pas** le palier — suit le **nombre de victoires** déjà remportées contre ce type (cohérent avec le reste de leur scaling qui est basé sur les victoires, pas sur le palier). La table exacte reste à définir (voir points ouverts).
- Piste à creuser plus tard : un **pool de variations** pour Élite/Boss (parfois plus de cartes plus faibles, parfois moins de cartes mais plus fortes) plutôt qu'une seule configuration figée — non tranché, voir points ouverts.

---

## 💰 Monnaie de run et gains d'or

- **Or de base croissant avec le palier** : x1,25 cumulatif tous les 5 paliers, arrondi **au supérieur** à chaque étape (même logique que le scaling PV/stats). Part de 10 or aux paliers 1-5, sans plafond (cohérent avec une run sans fin).

| Paliers | Or de base (combat Normal) |
|---|---|
| 1-5 | 10 |
| 6-10 | 13 |
| 11-15 | 17 |
| 16-20 | 22 |
| 21-25 | 28 |
| 26-30 | 35 |
| 31-35 | 44 |
| 36-40 | 55 |

*(continue de grimper au même rythme au-delà)*

- **Multiplicateurs** appliqués sur l'or de base du palier en cours :
  - Normal : x1
  - Élite : x1,5
  - Boss : x3
- **Pas de plafond d'accumulation** : l'or peut s'accumuler sans limite en run (contrairement au Battle Royale et son plafond à 15).
- **Fin de run (mort du héros)** : l'or non dépensé est **perdu**, aucune conversion en monnaie molle méta ni bonus sur la récompense de consolation.
- Monnaie de run distincte de la monnaie molle méta.
- Sert à acheter en Boutique (voir section suivante).

---

## 🏪 Boutique (nœud)

Remplace la version v1 ("variante de récompense de combat avec meilleure distribution de rareté, pas de monnaie séparée"). Avec la monnaie de run, la Boutique devient un vrai lieu d'achat, avec 4 options :

### Achat de carte
- **5 cartes proposées** à chaque visite (Serviteur, Enchantement, Rituel).
- **Prix fixe par rareté** : Commune 25 or / Rare 75 or / Épique 125 or / Légendaire 175 or.

### Amélioration de carte
- **50 or de base.**
- Le joueur choisit une carte de son deck de run, puis se voit proposer des options à ajouter **définitivement** sur la carte : soit un **mot-clé** (parmi 2-3 proposés), soit un **buff de stats** (ex: +3/+0, +1/+1) — l'articulation exacte entre les deux types d'option (choix mixte à chaque visite, deux offres séparées, prix différenciés...) reste à trancher, voir points ouverts.
- Pas de fusion 3 copies comme au Battle Royale (deck à 1 exemplaire) — cette mécanique remplace ce rôle.

### Soin
- Soigne un **pourcentage des PV manquants** (même principe que le nœud Repos, 30%).
- **20 or de base** (paliers 1-5), puis **scale avec le palier** sur le même rythme que la croissance de l'or gagné (x1,25 cumulatif tous les 5 paliers) — cohérent pour que le soin reste abordable relativement à l'or disponible à mesure que la run avance.

### Retrait de carte (désengorgement)
- Retire n'importe quelle carte du deck de run, en échange d'or.
- **10 or pour le premier retrait**, puis **+10 or à chaque retrait suivant** (compteur propre à la run, ne redescend jamais sur la durée de la run).

---

## 🔮 Reliques

Les Reliques ne sont pas un système de bonus passif à part — ce sont littéralement des **cartes Enchantement/Rituel** qui rejoignent le plateau du joueur, avec les mécaniques déjà existantes du moteur (`EnchantmentSystem`, zones dédiées, triggers, `TriggerSystem`).

### Obtention
- **Toujours aléatoire/imposée** — pas de choix parmi plusieurs propositions, contrairement aux récompenses de carte de combat classiques (1 parmi 3).
- **Séparée du pool de récompense de combat** : les Enchantements/Rituels ne font **pas** partie du choix 1-parmi-3 après un combat (ce choix reste réservé aux Serviteurs).
- Deux sources :
  - **Nœud dédié** "Relique" sur la carte de run.
  - **Boutique** : une relique aléatoire disponible par visite, à un prix plus élevé que les cartes classiques.

### Limite
- Pas de limite globale sur le nombre de Reliques (contrairement à ce qu'on pensait initialement) — mais **une limite séparée** s'applique spécifiquement aux zones Enchantement/Rituel du plateau (montant exact à chiffrer, voir points ouverts).

---

## 🎭 Événements

Nœud "choix textuel" de la carte de run, structure flexible façon roguelite classique.

### Structure
- **Nombre de choix variable** : parfois 2, parfois 3, parfois **un seul résultat automatique** sans choix à faire (l'événement se résout tout seul).
- **Nature du résultat variable selon l'événement** :
  - Certains événements sont **risqués** : le résultat (positif ou négatif) est tiré au hasard, le joueur ne sait pas à l'avance ce qu'il va obtenir.
  - D'autres proposent des **choix garantis sans risque** : chaque option a un effet connu et fixe, le joueur choisit en toute connaissance de cause.
  - Un même passage par les Événements peut mélanger les deux types selon l'événement rencontré.

### Ressources affectées
- Un événement peut toucher **n'importe quelle ressource de la run** selon son contenu : PV (gain ou perte), or, cartes (gain, retrait, amélioration), ou reliques.

### Contenu
- Le contenu concret (textes, effets précis par événement) reste **entièrement à écrire** — la structure ci-dessus définit le cadre mécanique, pas le catalogue d'événements lui-même (chantier de contenu séparé, voir points ouverts).

---

## 📋 Ce qu'il reste à voir / à définir

Cette section liste tout ce qui a été identifié en discussion mais pas encore tranché. À reprendre dans un prochain passage.

### Combat — points restés en suspens
- Le nombre exact de cartes gagnées par un Élite/Boss après chaque victoire ("quelques cartes en plus" — fixe type +1, ou variable ?).
- Que se passe-t-il une fois le plafond de 20 cartes/plateau atteint par le scaling — le scaling continue-t-il uniquement sur PV/stats (plus sur le nombre de cartes), ou autre chose ?
- Le pool de variation Élite/Boss (parfois plus de cartes plus faibles, parfois moins de cartes plus fortes) — évoqué mais pas conçu.
- Table de rareté Élite/Boss par nombre de victoires (équivalent de la table par tranche de paliers, mais indexée sur le compteur de victoires) — pas encore chiffrée.

### Boutique — à chiffrer
- **Amélioration de carte** : articulation exacte entre l'option "mot-clé" et l'option "buff de stats" — est-ce un choix mixte proposé en une fois (2-3 options mêlant mots-clés et buffs), deux offres séparées avec des prix potentiellement différents, ou toujours les deux appliqués ensemble pour 50 or ? Et si buff de stats : montant fixe (+1/+1) ou plusieurs options au choix (+3/+0, +1/+1, +0/+3) ?
- **Amélioration de carte (mots-clés)** : logique de sélection des 2-3 mots-clés proposés (aléatoire ? contrainte par la race de la carte ? tous les mots-clés du jeu sont-ils éligibles ou seulement certains, adaptés à ce contexte hors-combat classique ?).

### Or — points non fermés
Aucun — tous les points sont résolus (voir section « Monnaie de run et gains d'or »).

### Reliques — à chiffrer
- Limite exacte des zones Enchantement/Rituel du plateau (nombre max de cartes dans ces zones).
- Prix d'une relique en Boutique (montant de base, scaling ou non avec le palier comme le soin).
- Fréquence d'apparition du nœud dédié "Relique" sur la carte de run (voir aussi section Structure de la carte à embranchements).
- Pool de reliques disponibles : toutes les cartes Enchantement/Rituel existantes sont-elles éligibles, ou un sous-ensemble dédié au mode Campagne ?

### Événements — contenu à écrire
- Structure mécanique validée (voir section Événements ci-dessus) — reste à écrire le **catalogue concret** : liste d'événements, textes, effets précis de chaque choix.
- Fréquence d'apparition du nœud Événement sur la carte de run (voir Structure de la carte à embranchements).

### Structure de la carte à embranchements
- Proportions exactes de tirage entre les types de nœuds (Combat/Élite/Événement/Boutique/Repos) à chaque palier — la logique globale est fixée (1 à 3 chemins aléatoires, densité Élite/Événement croissante, Repos/Boutique stables, Repos garanti avant Boss), mais les pourcentages précis restent à caler en playtest.

### Autres
- Sauvegarde locale confirmée — pas de point ouvert ici, sauf si le besoin de cross-device ou de leaderboard apparaît plus tard.
- Identité mécanique complète des Abominations (mots-clés exclusifs) — non commencée, mentionnée comme chantier séparé dans le doc général du projet.
