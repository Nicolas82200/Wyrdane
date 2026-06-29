# FateBound CARDS.md

Liste complète des cartes de la race Mort-Vivant.

---

## Légende

Stats
- `⬡` = Coût en mana  
- `⚔` = Attaque  
- `♥` = Points de vie

Positionnement (Lane Types)
- `⚔️` = Rangée Avant recommandée  
- `🛡️` = Rangée Arrière recommandée  
- `↕️` = Hybride (flexible, jouable dans n'importe quelle rangée)

---

## Mots-clés

| Mot-clé | Description |
|---|---|
| `REMPART` | Doit être attaqué en priorité par les serviteurs ennemis. |
| `ASSAUT` | Peut attaquer le tour de son invocation. |
| `FRÉNÉSIE` | Peut attaquer deux fois par tour. |
| `RAVAGE` | Les dégâts excédentaires sont infligés directement au héros adverse. |
| `AILES NOIRES` | Ignore la rangée Avant ennemie ; peut cibler directement la rangée Arrière ou le héros. |
| `MOISSON` | Les dégâts infligés par ce serviteur soignent le héros allié d'autant. |
| `VENIN MORTEL` | Toute blessure infligée par ce serviteur détruit la cible, quelle que soit sa vie restante. |
| `ÉGIDE` | Annule la première source de dégâts reçue. |

---

## Triggers (Déclencheurs)

| Trigger | Sur quel type de carte | Description |
|---|:---:|---|
| `Invocation` | Serviteur | Se déclenche quand ce serviteur entre en jeu. |
| `Dernier Souffle` | Serviteur | Se déclenche quand ce serviteur meurt. |
| `Mort-rage` | Serviteur | Se déclenche quand un serviteur ennemi meurt. |
| `Blessure` | Serviteur | Se déclenche quand ce serviteur reçoit des dégâts. |
| `Exécution` | Serviteur | Se déclenche quand ce serviteur tue un ennemi en attaquant. |
| `Ralliement` | Serviteur | Se déclenche quand ce serviteur attaque. |
| `Éveil` | Rituel / Enchantement | Se déclenche à chaque début du tour du joueur. |
| `Deuil` | Rituel / Enchantement | Se déclenche quand un serviteur allié meurt. |
| `Carnage` | Rituel / Enchantement | Se déclenche quand un serviteur ennemi meurt. |
| `Sortilège` | Rituel / Enchantement | Se déclenche quand l'adversaire joue un sort. |
| `Appel` | Enchantement | Se déclenche chaque fois qu'un serviteur allié entre en jeu. |
| `Présence` | Enchantement | Effet passif continu actif tant que l'enchantement est en jeu. |
| `Résonance` | Enchantement | Se déclenche quand un serviteur allié Mort-Vivant attaque. |
| `Sacrifice` | Rituel | Requiert de détruire un ou plusieurs serviteurs alliés pour activer l'effet. |

---

## Serviteurs

### Communes

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 01 | Rampant en Décomposition | ⚔️ | 1 | 1 | 1 | Dernier Souffle : infecte la carte du dessus du deck ennemi (entre en jeu comme Zombie 1/1 sous ton contrôle). | Il ne sait plus pourquoi il avance. Il avance, c'est tout. |
| 02 | Goule Affamée | ⚔️ | 1 | 2 | 1 || La faim ne disparaît pas avec la mort. Elle empire. |
| 03 | Cadavre Errant | ↕️ | 2 | 1 | 3 | REMPART. | Personne ne se souvient de son nom. Lui non plus. |
| 04 | Zombie Mineur | ⚔️ | 2 | 2 | 2 || Il était enfant. C'était avant. |
| 05 | Charognard Putride | ⚔️ | 2 | 3 | 1 | Dernier Souffle : inflige Infection à un serviteur ennemi adjacent. | Même en tombant, il répand ce qui l'a tué. |
| 06 | Infecté Récent | ⚔️ | 2 | 2 | 2 | Mort-rage : +1/+1 par ennemi infecté en jeu. | La morsure date d'hier. Il a encore ses yeux d'avantmais plus rien derrière. |
| 07 | Servant Décharné | 🛡️ | 3 | 2 | 4 | Ralliement : tes serviteurs en rangée Avant ont +0/+1 HP jusqu'à fin de tour. | Il ne commande pas. Il pousse. Et ça suffit. |
| 08 | Mâcheur d'Os | ⚔️ | 3 | 4 | 2 | ASSAUT. Ralliement : inflige 1 dégât splash aux serviteurs adjacents à la cible. | Le craquement des os est le seul son qu'il comprend encore. |
| 09 | Horde Mineure | ⚔️ | 3 | 1 | 1 | Invocation : invoque 2 Rampants 1/1 en rangée Avant. | Un seul ne fait pas peur. Mais il n'est jamais seul. |
| 10 | Mort-Vivant Enchaîné | ⚔️ | 3 | 3 | 3 || Les chaînes ne le retiennent plus. Elles font partie de lui. |
| 11 | Larve Cadavérique | ↕️ | 1 | 1 | 1 | Dernier Souffle : le serviteur allié adjacent gagne +1/+1. | Elle n'est pas née de la vie. Elle est née de ce qui reste. |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 12 | Pestilent | ↕️ | 2 | 1 | 2 | Invocation : inflige Infection à un serviteur ennemi ciblé. | Son souffle est une condamnation à retardement. |
| 13 | Zombie Bouclier | ⚔️ | 2 | 1 | 5 | REMPART. Blessure : réduit de 1 les dégâts reçus (minimum 1). | Les lames s'enfoncent dans la chair morte et s'y perdent. |
| 14 | Hurleur Nécrotique | ↕️ | 3 | 3 | 2 | Invocation : serviteurs Mort-Vivants alliés en rangée Avant +1/+0 jusqu'à fin de tour. | Son cri ne terrorise plus. Il réveille. |
| 15 | Rongeur de Chair | ⚔️ | 4 | 5 | 3 | Exécution : peut attaquer à nouveau une fois par tour. | Il ne s'arrête pas quand la proie tombe. Il s'arrête quand il ne reste plus rien. |
| 16 | Cultiste Zombifié | ↕️ | 2 | 1 | 2 | Dernier Souffle : invoque un Cadavre Errant en rangée Avant. | Il a prié pour la mort éternelle. Il a été exaucéà moitié. |
| 17 | Géant Boursouflé | ⚔️ | 5 | 4 | 6 | Dernier Souffle : inflige 2 dégâts à tous les serviteurs ennemis en rangée Avant. | Sa mort est plus dangereuse que sa vie.Rapport de bataille, campagne de la Vallée Grise |
| 18 | Émissaire de la Peste | ↕️ | 4 | 3 | 4 | Invocation : -2 ATK à un serviteur ennemi ciblé jusqu'à fin du tour adverse. | Il ne vient pas combattre. Il vient annoncer. |
| 19 | Soldat Réanimé | ⚔️ | 3 | 4 | 3 | Invocation : si réanimé depuis le cimetière, entre avec +1/+1. | La mort lui a appris ce que la guerre ne lui avait pas enseigné : la patience. |
| 20 | Banshee Zombie | 🛡️ | 4 | 2 | 5 | Invocation : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse. | Elle hurle sans voix. Ceux qu'elle regarde oublient comment parler. |
| 21 | Possédé Hurlant | ⚔️ | 3 | 5 | 1 | ASSAUT. VENIN MORTEL. Dernier Souffle : retiré du jeu (ne va pas au cimetière). | Même les morts refusent de le reprendre. |
| 22 | Cavalier Zombie | ⚔️ | 4 | 4 | 3 | ASSAUT. Invocation : attaque immédiatement le serviteur ennemi le plus faible en HP. | Le cheval est mort avant lui. Ni l'un ni l'autre ne s'en est rendu compte. |
| 23 | Garde du Charnier | ⚔️ | 2 | 1 | 4 | REMPART. Dernier Souffle : pioche 1 carte. | Il gardait les vivants. Il garde désormais ce qui reste. |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 24 | Le Patient Zéro | ↕️ | 4 | 3 | 3 | Invocation : inflige Infection à tous les serviteurs ennemis en jeu. | On n'a jamais su d'où il venait. On a fini par ne plus chercher. |
| 25 | Ravageur Putréfié | ⚔️ | 5 | 6 | 4 | RAVAGE. Mort-rage : serviteurs Mort-Vivants alliés +2/+2. | Chaque mort nourrit sa rage. Et il y a toujours de nouveaux morts. |
| 26 | Architecte de la Horde | 🛡️ | 3 | 2 | 3 | Ralliement : invoque un Rampant 1/1 en rangée Avant. | Il ne construit pas d'armée. Il la sécrète. |
| 27 | Colosse Décomposé | ⚔️ | 6 | 7 | 7 | REMPART. Blessure : les dégâts excédentaires ne se propagent pas. | Les lames disparaissent dans sa masse. Il continue d'avancer. |
| 28 | Esprit Vorace | ↕️ | 4 | 4 | 4 | MOISSON. Invocation : vole 2 HP au héros ennemi. | Il ne prend pas ta vie. Il la déplacedans les mauvaises mains. |
| 29 | Nuée d'Insectes Cadavériques | ↕️ | 3 | 1 | 2 | Invocation : inflige 1 dégât à tous les serviteurs ennemis en jeu. | Là où elle passe, rien ne guérit vraiment. |
| 30 | Faucheur de la Plaie | ⚔️ | 5 | 5 | 5 | Invocation : détruit un serviteur ennemi ayant 3 HP ou moins. | Il ne choisit pas les plus forts. Il choisit les presque mortspour finir le travail. |
| 31 | Nécromancien Putride | 🛡️ | 4 | 2 | 4 | Invocation : ressuscite le dernier Mort-Vivant allié mort avec 1 HP en rangée Avant. | "Je ne ressuscite personne. Je refuse simplement qu'ils s'arrêtent." |
| 32 | Assassin Décharné | ⚔️ | 3 | 4 | 2 | AILES NOIRES. Ne peut pas être ciblé par sorts ennemis jusqu'à son premier Assaut. | On ne le voit pas venir. On ne le voit que partir. |
| 33 | Berserker Infecté | ⚔️ | 4 | 5 | 4 | FRÉNÉSIE. Mort-rage : +3/+0, revient en jeu avec 1 HP. | La fièvre l'a tué. Ce qui reste est plus rapide. |
| 34 | Tombeau Ambulant | ⚔️ | 5 | 3 | 8 | REMPART. Dernier Souffle : invoque 3 Rampants 1/1 en rangée Avant. | Il n'était pas un monstre. Il était une fosse commune. |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 35 | Le Médecin de la Peste | 🛡️ | 6 | 0 | 4 | Éveil : invoque un Mort-Vivant aléatoire de coût ≤3 en rangée Avant. | Il soignait les vivants autrefois. Il a simplement changé de patientèle. |
| 36 | Roi Liche Zombie | ⚔️ | 7 | 6 | 8 | Invocation : ressuscite les 3 derniers Mort-Vivants alliés morts ce match avec 1 HP en rangée Avant. | Son royaume n'a pas de frontières. Il s'étend à mesure que ses sujets meurent. |
| 37 | Apocalypse Zombie | ⚔️ | 8 | 9 | 9 | Invocation : transforme tous les serviteurs adverses en jeu en Zombies 1/1 sous ton contrôle. | Ce n'était pas une invasion. C'était une conversion. |
| 38 | Léviathan Putréfié | ⚔️ | 7 | 8 | 10 | REMPART. Invocation : serviteurs Mort-Vivants alliés +2/+2. | Les mers l'ont recraché. Elles non plus ne voulaient plus de lui. |
| 39 | La Faucheuse | ⚔️ | 7 | 7 | 6 | Invocation : détruit un serviteur ennemi ciblé et le ressuscite sous ton contrôle sans ses effets. | Elle ne prend pas les âmes. Elle redistribue les corps. |

---

## Éphémères

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| 40 | Souffle Nécrotique | 2 | Commune | 2 dégâts à un serviteur ennemi ciblé. | Ce n'est pas du vent. C'est ce qui reste quand les poumons ne servent plus à rien. |
| 41 | Réveil Soudain | 1 | Commune | Ressuscite le dernier Mort-Vivant allié mort avec 1 HP en rangée Avant. | Il n'y a pas de repos pour ceux qu'on rappelle. |
| 42 | Vague de Putréfaction | 3 | Commune | 1 dégât à tous les serviteurs ennemis en rangée Avant. | La peste ne choisit pas. Elle couvre. |
| 43 | Don de Chair | 2 | Rare | Sacrifice (un serviteur allié) : inflige 3 dégâts au héros ennemi. | Il a donné son corps. Il n'avait plus besoin de consentir. |
| 44 | Étreinte Glaciale | 2 | Commune | Gèle un serviteur ennemi ciblé un tour. (L'Infection continue.) | Le froid stoppe les gestes. Pas le mal qui ronge de l'intérieur. |
| 45 | Morsure Infectieuse | 3 | Rare | Transforme un serviteur ennemi non-Légendaire en Zombie 1/1 sous ton contrôle. | Une seule morsure suffit. Le reste, c'est une question de temps. |
| 46 | Cri des Damnés | 3 | Rare | Mort-Vivants alliés +1/+0 ce tour. Si 5 ou plus en jeu : +2/+0 à la place. | Plus ils sont nombreux à hurler, moins le cri ressemble à quelque chose d'humain. |
| 47 | Poigne du Cimetière | 2 | Rare | Renvoie un serviteur ennemi de 3 HP ou moins dans la main de son propriétaire. | Les morts n'oublient pas ceux qui les ont enterrés. |
| 48 | Exhalation Toxique | 1 | Commune | 1 dégât à tous les serviteurs en jeu. | Même ses alliés évitent de respirer trop près. |
| 49 | Dernier Soupir | 3 | Épique | Carnage : pioche 1 carte par Mort-Vivant allié mort ce tour (max 3). | Leurs voix ne portent plus. Mais leurs secrets, si. |
| 50 | Éclat de Putréfaction | 2 | Rare | Détruit un enchantement ou équipement ennemi. Si enchantement : invoque un Rampant 1/1. | La corruption ne respecte pas la magie. Elle la digère. |
| 51 | Souffle du Charnier | 1 | Commune | Un Mort-Vivant allié ciblé gagne +0/+2. | Ce qui ne peut pas mourir davantage peut encore endurcir. |
| 52 | Doigt Décharné | 1 | Rare | Pioche 1 carte. Si c'est un Mort-Vivant, il coûte 1 de moins ce tour. | Il désigne. Quelque chose, quelque part, répond. |

---

## Rituels

| ID | Nom | ⬡ | Rareté | Durée | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| 53 | Rituel de Résurrection | 5 | Épique | 2 tours | Éveil : ressuscite un Mort-Vivant allié mort aléatoire avec 1 HP en rangée Avant. | Le cercle ne ferme jamais complètement. C'est voulu. |
| 54 | Pacte Sanglant | 4 | Épique | Instantané | Sacrifice (jusqu'à 4 serviteurs à 2 HP ou moins) : invoque un Mort-Vivant X/X (X = sacrifiés × 2). | Quatre cadavres pour en faire un seul. Le calcul semble simple. Il ne l'est pas. |
| 55 | Cercle de Convocation | 5 | Épique | 3 tours | Éveil : invoque un Mort-Vivant aléatoire de coût ≤2 gratuitement. | Le cercle appelle. Les morts n'ont pas appris à décliner. |
| 56 | Communion avec les Morts | 3 | Rare | Instantané | Deuil : pioche 1 carte par Mort-Vivant allié mort ce match (max 4). | Chaque mort laisse quelque chose derrière lui. Il suffit de savoir écouter. |
| 57 | Rituel d'Exhumation | 4 | Rare | Instantané | Ramène en main un serviteur Mort-Vivant ciblé depuis ton cimetière. | On ne l'enterre pas. On l'entrepose. |
| 58 | Cercle de Sacrifice | 6 | Légendaire | Instantané | Sacrifice (exactement 2 serviteurs) : tes serviteurs restants gagnent +ATK/+HP égal aux stats combinées des sacrifiés ce tour. | Deux morts pour que les autres surviventun peu plus longtemps.Théorème du Nécromant de Vael |
| 59 | Rituel du Lien Funeste | 4 | Épique | 3 tours | Deuil : inflige 2 dégâts au héros ennemi. | Chaque allié qui tombe tire un fil. L'ennemi finit par sentir la traction. |
| 60 | Invocation de Masse | 7 | Légendaire | Instantané | Invoque 4 Mort-Vivants aléatoires de coût ≤4. Coûte 6 si tu as 3 serviteurs ou moins en jeu. | Il n'a pas ouvert une porte. Il a retiré le mur. |
| 61 | Rituel de l'Éclipse | 6 | Légendaire | 2 tours | Sortilège ennemi : annulé s'il cible un de tes Mort-Vivants. | Sous l'éclipse, la magie adverse perd ses repères. Les morts, eux, n'en ont plus besoin. |
| 62 | Rituel de la Fosse Sans Fond | 6 | Épique | Instantané | Sacrifice (tous tes serviteurs) : pioche 1 carte par sacrifié. | Il a tout donné. Il savait exactement ce que ça valait. |
| 63 | Épidémie | 4 | Épique | Ce tour | Présence : serviteurs non Mort-Vivants ennemis -2/-2. Ceux réduits à 0 HP ne vont pas dans le cimetière adverse. | Elle ne tue pas. Elle prépare. |
| 64 | Grand Rituel Nécrotique | 8 | Légendaire | Instantané | Ramène en main tous les Mort-Vivants alliés morts ce match (max 5). | "Je n'ai perdu personne. Je les ai simplement prêtés au sol."Le Nécromant d'Ossemoor |

---

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| 65 | Autel des Damnés | 3 | Rare | Deuil : pioche 1 carte. | Chaque mort nourrit l'autel. L'autel, lui, ne se souvient d'aucun nom. |
| 66 | Fosse Commune | 4 | Rare | Appel : si 3 Mort-Vivants alliés ou plus sont en jeu, invoque un Rampant 1/1. | Plus elle se remplit, plus elle déborde. |
| 67 | Aura de Décrépitude | 3 | Rare | Résonance : ce Mort-Vivant attaquant gagne +1/+0 de façon permanente. | La décrépitude n'est pas une faiblesse. C'est une accumulation. |
| 68 | Cimetière Vivant | 5 | Épique | Deuil : ce Mort-Vivant revient en jeu à la fin du tour avec 1 HP. (Une seule fois par serviteur.) | Le sol ici ne garde rien. Il régurgite. |
| 69 | Brouillard Pestilentiel | 3 | Rare | Présence : à chaque début du tour adverse, les serviteurs ennemis infectés perdent 1 HP supplémentaire. | On ne le voit pas. On ne le sent même plus, après un moment. |
| 70 | Symbiose Cadavérique | 5 | Épique | Présence : tes serviteurs en rangée Arrière gagnent +0/+1 par serviteur allié en rangée Avant. | Les morts de devant protègent les morts de derrière. C'est le seul lien qui reste. |
| 71 | Idole de l'Apocalypse | 6 | Légendaire | Résonance : le Mort-Vivant attaquant inflige 1 dégât splash aux serviteurs adjacents à la cible. | On ne l'a pas sculpté. On l'a trouvé ainsi, debout, au milieu des ruines. |
| 72 | Sanctuaire Nécrotique | 4 | Épique | Présence : les sorts alliés coûtent 1 de moins (min 1). | Dans ses murs, la magie de mort coule comme de l'eau froidenaturellement. |
| 73 | Vortex des Âmes | 6 | Légendaire | Carnage : gagne 1 mana temporaire ce tour. | Les âmes qui s'y perdent alimentent quelque chose que personne ne comprend vraiment. |
| 74 | Monument aux Morts | 5 | Épique | Deuil : invoque 2 Mort-Vivants aléatoires de coût ≤3. | On l'a érigé pour honorer les disparus. Il préfère les renvoyer. |
| 75 | Murmure Funeste | 1 | Rare | Présence : le premier Mort-Vivant joué chaque tour coûte 1 de moins (min 1). | On ne l'entend pas. On sent juste que quelque chose a dit oui. |

# FateBound — CARDS_HUMAIN.md

Liste complète des cartes de la race **Humain**.

---

## Légende

**Stats**
- `⬡` = Coût en mana  
- `⚔` = Attaque  
- `♥` = Points de vie

**Positionnement (Lane Types)**
- `⚔️` = Rangée Avant recommandée  
- `🛡️` = Rangée Arrière recommandée  
- `↕️` = Hybride (flexible, jouable dans n'importe quelle rangée)

---

## Mots-clés exclusifs Humain

| Mot-clé | Effet |
|---|---|
| `DISCIPLINE` | Immunisé aux effets de silence, contrôle mental et peur ennemis. |
| `FORMATION` | Tant qu'un serviteur allié est adjacent, ce serviteur gagne +1/+1. |
| `CONTRE-ATTAQUE` | Blessure : si ce serviteur survit, inflige son ATK en retour à l'attaquant. |
| `COMMANDEMENT` | Les serviteurs Humains alliés invoqués après lui gagnent +1/+0 de façon permanente. |
| `FORTIFICATION` | Ne peut pas être déplacé, renvoyé en main ou transformé par des effets ennemis. |

---

## Mots-clés partagés (rappel)

| Mot-clé | Effet |
|---|---|
| `REMPART` | Doit être attaqué en priorité. |
| `ASSAUT` | Peut attaquer le tour de son invocation. |
| `FRÉNÉSIE` | Peut attaquer deux fois par tour. |
| `ÉGIDE` | Ignore la première source de dégâts reçue. |
| `VENIN MORTEL` | Toute blessure infligée détruit la cible. |
| `MOISSON` | Les dégâts infligés soignent le héros allié. |
| `RAVAGE` | Les dégâts excédentaires sont infligés au héros adverse. |

---

## Triggers (Déclencheurs)

| Trigger | Sur quel type de carte | Description |
|---|:---:|---|
| `Invocation` | Serviteur | Se déclenche quand **ce serviteur** entre en jeu. |
| `Dernier Souffle` | Serviteur | Se déclenche quand **ce serviteur** meurt. |
| `Mort-rage` | Serviteur | Se déclenche quand un **serviteur ennemi** meurt. |
| `Blessure` | Serviteur | Se déclenche quand **ce serviteur** reçoit des dégâts. |
| `Exécution` | Serviteur | Se déclenche quand **ce serviteur** tue un ennemi en attaquant. |
| `Ralliement` | Serviteur | Se déclenche quand **ce serviteur** attaque. |
| `Éveil` | Rituel / Enchantement | Se déclenche à chaque début du **tour du joueur**. |
| `Deuil` | Rituel / Enchantement | Se déclenche quand **un serviteur allié** meurt. |
| `Carnage` | Rituel / Enchantement | Se déclenche quand **un serviteur ennemi** meurt. |
| `Sortilège` | Rituel / Enchantement | Se déclenche quand **l'adversaire joue un sort**. |
| `Appel` | Enchantement | Se déclenche chaque fois qu'**un serviteur allié** entre en jeu. |
| `Présence` | Enchantement | Effet **passif continu** actif tant que l'enchantement est en jeu. |
| `Résonance` | Enchantement | Se déclenche quand **un serviteur allié Humain** attaque. |
| `Sacrifice` | Rituel | Requiert de détruire un ou plusieurs serviteurs alliés pour activer l'effet. |

---

## Serviteurs

### Communes

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H01 | Conscrit | ⚔️ | 1 | 1 | 2 | — | *Il n'a pas choisi de venir. Il est venu quand même.* |
| H02 | Milicien du Bourg | ⚔️ | 1 | 2 | 1 | Dernier Souffle : invoque un Éclaireur 1/1. | *Il est tombé en gardant la route ouverte. C'est tout ce qu'il avait demandé.* |
| H03 | Porteur de Bouclier | ⚔️ | 2 | 1 | 4 | REMPART. | *Le bouclier a des marques de griffes. Il ne les compte plus.* |
| H04 | Fantassin Aguerri | ⚔️ | 2 | 2 | 2 | FORMATION : tant qu'un allié est adjacent, gagne +1/+1. | *Seul, il tient. Ensemble, ils avancent.* |
| H05 | Archer de Guet | 🛡️ | 2 | 2 | 1 | Éveil : inflige 1 dégât à un serviteur ennemi en rangée Avant ciblé. | *Il ne rate pas. Il attend juste le bon moment.* |
| H06 | Éclaireur Rapide | ⚔️ | 1 | 1 | 1 | ASSAUT. Invocation : pioche 1 carte si la rangée Avant ennemie a 3 serviteurs ou plus. | *Il revient toujours avec de mauvaises nouvelles. Il revient, c'est ce qui compte.* |
| H07 | Vétéran des Marches | ⚔️ | 3 | 2 | 4 | Blessure : gagne +1/+0 de façon permanente. | *Chaque cicatrice lui a appris quelque chose. Il en a beaucoup appris.* |
| H08 | Frère d'Armes | ⚔️ | 3 | 3 | 2 | Ralliement : le serviteur allié adjacent gagne +0/+1. | *Il ne combat pas pour la victoire. Il combat pour que l'homme à sa gauche rentre chez lui.* |
| H09 | Lancier en Ligne | ⚔️ | 2 | 3 | 1 | FORMATION : inflige 1 dégât supplémentaire si un allié est adjacent. | *La ligne tient ou la ligne tombe. Il n'y a pas d'entre-deux.* |
| H10 | Guérisseur de Camp | 🛡️ | 3 | 0 | 3 | Éveil : restaure 1 HP à un serviteur Humain allié ciblé. | *Il n'a jamais tenu d'épée. Ses mains ont pourtant sauvé plus de vies que n'importe quelle lame.* |
| H11 | Sergent de Troupe | ⚔️ | 3 | 2 | 3 | Invocation : les serviteurs Humains alliés en rangée Avant gagnent +0/+1 jusqu'à fin de tour. | *Sa voix porte plus loin que le bruit du combat. C'est pour ça qu'il est encore en vie.* |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H12 | Chevalier du Mur | ⚔️ | 3 | 2 | 5 | REMPART. CONTRE-ATTAQUE. | *Il a juré de ne pas reculer. Il a tenu sa parole à un prix qu'il ne mentionne jamais.* |
| H13 | Inquisiteur de Fer | ↕️ | 3 | 3 | 2 | Invocation : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse. | *Il ne cherche pas la vérité. Il coupe ce qui parle à la place d'elle.* |
| H14 | Capitaine de Milice | ↕️ | 4 | 3 | 3 | COMMANDEMENT. Invocation : invoque un Milicien 2/1 en rangée Avant. | *Il n'avait pas prévu de commander. Mais quelqu'un devait le faire.* |
| H15 | Briseur de Horde | ⚔️ | 4 | 4 | 3 | Assaut : si la cible est un Mort-Vivant, inflige 2 dégâts supplémentaires. | *Il a perdu son village à la première vague. Il n'a pas perdu la rage.* |
| H16 | Sentinelle des Remparts | ⚔️ | 2 | 1 | 5 | REMPART. FORTIFICATION. | *On a essayé de le faire reculer. On a essayé de le renvoyer. On a abandonné.* |
| H17 | Archer d'Élite | 🛡️ | 3 | 3 | 2 | Assaut : peut cibler n'importe quel serviteur ennemi (Avant ou Arrière). | *La rangée Avant n'est pas un obstacle. C'est un couloir.* |
| H18 | Prêtre de Guerre | 🛡️ | 4 | 1 | 4 | Éveil : restaure 2 HP à un serviteur Humain allié ciblé. Dernier Souffle : invoque un Éclaireur 1/1. | *Il priait pour les vivants. À la fin, il a prié pour quelque chose de plus modeste : du temps.* |
| H19 | Lame-Jurée | ⚔️ | 3 | 4 | 2 | DISCIPLINE. Exécution : gagne +1/+1 de façon permanente. | *Elle a juré sur sa lame. La lame, elle, a juré de le mériter.* |
| H20 | Défenseur Juré | ⚔️ | 2 | 1 | 4 | REMPART. Blessure : les dégâts reçus sont réduits de 1 (minimum 1). | *Il n'esquive pas. Il absorbe. Ce n'est pas pareil.* |
| H21 | Éclaireur Infiltré | ⚔️ | 3 | 3 | 2 | Invocation : révèle tous les serviteurs ennemis en rangée Arrière. Ils ne peuvent pas être ciblés par effets ce tour. | *Il est allé voir. Il est revenu. Pas tout le monde n'en peut dire autant.* |
| H22 | Fantassin de Contre-Choc | ⚔️ | 4 | 3 | 4 | CONTRE-ATTAQUE. Blessure : gagne REMPART jusqu'à fin de tour. | *Chaque coup reçu lui rappelle pourquoi il tient encore debout.* |
| H23 | Soldat de la Foi | ⚔️ | 3 | 2 | 3 | ÉGIDE. Dernier Souffle : invoque un Milicien 2/1 en rangée Avant. | *Il croyait en quelque chose. Ce quelque chose l'a protégé — une fois.* |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H24 | Maréchal de Campagne | 🛡️ | 5 | 2 | 5 | COMMANDEMENT. Éveil : tous les serviteurs Humains alliés gagnent +1/+0 jusqu'à fin de tour. | *Il ne crie pas les ordres. Il les dit une fois, calmement. Ça suffit.* |
| H25 | Champion du Peuple | ⚔️ | 4 | 5 | 4 | Exécution : soigne le héros allié de 2 HP. | *Il se bat pour des gens qu'il ne connaît pas. C'est pour ça qu'il gagne.* |
| H26 | Paladin de l'Aube | ⚔️ | 5 | 4 | 5 | ÉGIDE. MOISSON. Invocation : invoque un Éclaireur 1/1 en rangée Avant. | *Il arrive à l'aube. Les morts reculent à la lumière. Lui aussi en a été surpris, la première fois.* |
| H27 | Brise-Mort | ⚔️ | 4 | 4 | 3 | Invocation : détruit un serviteur ennemi ressuscité ou réanimé depuis le cimetière ciblé. | *"Tu es déjà mort une fois. Je vais m'assurer que tu ne l'oublies pas."* |
| H28 | Mur de Lances | ⚔️ | 4 | 1 | 6 | REMPART. FORMATION. Carnage ennemi : inflige 1 dégât à tous les serviteurs ennemis en rangée Avant. | *Ils ne bougent pas. La ligne tient. Les lances, elles, trouvent toujours quelque chose à traverser.* |
| H29 | Stratège Royal | 🛡️ | 4 | 2 | 4 | Ralliement : place le serviteur allié invoqué dans la rangée de ton choix, même si elle est pleine (échange avec un autre). | *Il ne voit pas un champ de bataille. Il voit un problème à résoudre.* |
| H30 | Exécuteur de l'Ordre | ⚔️ | 5 | 5 | 4 | VENIN MORTEL. DISCIPLINE. Ne peut attaquer que les serviteurs (jamais le héros directement). | *Il n'a pas de haine. Il a des instructions. C'est pire.* |
| H31 | Porte-Étendard | 🛡️ | 3 | 1 | 4 | Ralliement : invoque un Éclaireur 1/1 en rangée Avant pour chaque Humain déjà en jeu (max 3). | *L'étendard ne se rend pas. Tant qu'il tient, les autres tiennent aussi.* |
| H32 | Chevalier de la Contre-Marche | ⚔️ | 5 | 4 | 5 | CONTRE-ATTAQUE. ASSAUT. Blessure : gagne +2/+0 jusqu'à fin de tour. | *Il charge. Il encaisse. Il charge encore. C'est tout ce qu'il sait faire — et c'est suffisant.* |
| H33 | Inquisiteur Suprême | ↕️ | 5 | 3 | 5 | DISCIPLINE. Invocation : annule tous les effets Infection sur tes serviteurs alliés. Immunise tes serviteurs à l'Infection ce tour. | *La corruption s'arrête là où il pose le regard.* |
| H34 | Général de Brigade | 🛡️ | 5 | 3 | 4 | COMMANDEMENT. Éveil : invoque un Chevalier 2/2 en rangée Avant si tu as 4 Humains ou plus en jeu. | *Une armée n'est pas un nombre. C'est une volonté. La sienne.* |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H35 | Le Roi Soldat | ⚔️ | 7 | 6 | 8 | COMMANDEMENT. ÉGIDE. Invocation : tous les serviteurs Humains alliés gagnent +2/+2 de façon permanente. | *Il n'a pas pris la couronne. On la lui a posée sur le champ de bataille, entre deux assauts.* |
| H36 | La Grande Inquisitrice | 🛡️ | 6 | 3 | 6 | DISCIPLINE. Éveil : détruit un enchantement ou rituel ennemi actif au choix. | *Elle ne combat pas la magie ennemie. Elle la refuse.* |
| H37 | Le Rempart Vivant | ⚔️ | 6 | 4 | 10 | REMPART. FORTIFICATION. CONTRE-ATTAQUE. Blessure : invoque un Bouclier Brisé 0/3 REMPART adjacent. | *On lui a demandé combien de temps il pouvait tenir. Il n'a pas répondu. Il tient encore.* |
| H38 | Commandant des Derniers | 🛡️ | 7 | 5 | 6 | COMMANDEMENT. Dernier Souffle : ressuscite tous les serviteurs Humains alliés morts ce tour avec 1 HP en rangée Avant. | *Sa mort n'est pas une fin. C'est un dernier ordre.* |
| H39 | L'Éternel Gardien | ⚔️ | 8 | 7 | 9 | REMPART. ÉGIDE. DISCIPLINE. Invocation : tous les serviteurs ennemis perdent leurs mots-clés jusqu'à la fin du prochain tour adverse. | *Il n'a pas survécu à toutes ces guerres par chance. Il a survécu parce que rien de ce que l'ennemi fait ne le surprend.* |

---

## Éphémères

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| H40 | Cri de Ralliement | 1 | Commune | Humains alliés +0/+1 jusqu'à fin de tour. | *Un seul cri. Toute la ligne se souvient pourquoi elle est là.* |
| H41 | Frappe Coordonnée | 2 | Commune | Deux serviteurs Humains alliés ciblés attaquent immédiatement le même serviteur ennemi ciblé. | *Deux hommes, un seul endroit. L'ennemi n'a pas le temps de choisir lequel regarder.* |
| H42 | Purification | 2 | Commune | Annule tous les effets Infection et marqueurs négatifs sur un serviteur allié ciblé. | *Le mal recule. Pas loin. Mais pour l'instant, ça suffit.* |
| H43 | Repli Tactique | 1 | Commune | Déplace un serviteur allié de la rangée Avant vers la rangée Arrière (ou inversement). Il conserve ses effets. | *Reculer n'est pas fuir. C'est choisir où mourir.* |
| H44 | Volée de Flèches | 3 | Commune | Inflige 1 dégât à tous les serviteurs ennemis en rangée Avant. Si 4 ou plus en rangée Avant : 2 dégâts à la place. | *Plus ils sont nombreux, plus ça fait de cibles.* |
| H45 | Bouclier de Foi | 1 | Rare | Donne ÉGIDE à un serviteur Humain allié ciblé jusqu'à fin du prochain tour adverse. | *La foi ne rend pas invulnérable. Elle donne juste le temps d'encaisser le premier coup.* |
| H46 | Jugement Divin | 3 | Rare | Détruit un serviteur ennemi ayant 2 ATK ou moins. | *Le verdict est rendu avant même que l'accusé comprenne qu'il était jugé.* |
| H47 | Ordre d'Avancer | 2 | Rare | Tous les serviteurs Humains alliés en rangée Arrière gagnent ASSAUT ce tour et peuvent attaquer depuis la Arrière. | *L'ordre est arrivé. Il n'y avait pas de question à poser.* |
| H48 | Contre-Offensive | 3 | Rare | Exécution ce tour : chaque serviteur Humain allié qui tue un ennemi peut attaquer à nouveau immédiatement. | *La victoire s'enchaîne quand on ne lui laisse pas le temps de s'arrêter.* |
| H49 | Appel aux Armes | 4 | Rare | Invoque 2 Miliciens 2/1 en rangée Avant. Si ta rangée Avant est vide : invoque 3 Miliciens à la place. | *Quand la ligne est vide, ceux qui restent n'ont plus à réfléchir. Ils avancent.* |
| H50 | Bénédiction de Guerre | 2 | Épique | Un serviteur Humain allié ciblé gagne +2/+2 et DISCIPLINE jusqu'à fin de tour. | *Ce n'est pas de la magie. C'est la conviction que quelqu'un a mis dans ses mains.* |
| H51 | Massacre Sacré | 4 | Épique | Inflige 3 dégâts à tous les serviteurs Mort-Vivants ennemis en jeu. | *La lumière ne guérit pas les morts. Elle les brûle. C'est mieux.* |
| H52 | Formation Défensive | 3 | Épique | Tous tes serviteurs en rangée Avant gagnent REMPART et +0/+2 jusqu'à fin du tour adverse. | *Ils se serrent. La ligne devient un mur. Le mur ne bouge pas.* |

---

## Rituels

| ID | Nom | ⬡ | Rareté | Durée | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| H53 | Ordre de Tenir | 3 | Commune | 2 tours | Éveil : tes serviteurs en rangée Avant ne peuvent pas être renvoyés en main ni déplacés par des effets ennemis. | *L'ordre est simple. Les hommes, eux, sont compliqués. Mais ils obéissent.* |
| H54 | Hymne de Guerre | 4 | Rare | 3 tours | Ralliement : le serviteur Humain invoqué gagne +1/+1. | *Le chant ne les rend pas invincibles. Il leur rappelle qu'ils ne sont pas seuls.* |
| H55 | Fortification des Lignes | 5 | Rare | Permanent | Éveil : si ta rangée Avant a 5 serviteurs ou plus, ils gagnent tous REMPART jusqu'à fin de tour. | *Cinq hommes côte à côte. Ça devient quelque chose d'autre. Quelque chose qui ne cède pas.* |
| H56 | Serment du Sang | 4 | Rare | 3 tours | Deuil : quand un Humain allié meurt, le serviteur allié adjacent gagne +1/+1. | *Le serment survit à celui qui l'a fait. C'est l'idée.* |
| H57 | Marche Forcée | 3 | Rare | 2 tours | Éveil : invoque un Éclaireur 1/1 en rangée Avant gratuitement. | *Pas de repos. Pas d'arrêt. La ligne avance parce que s'arrêter, c'est mourir.* |
| H58 | Contre-Attaque Générale | 5 | Épique | 2 tours | Blessure : chaque serviteur Humain allié qui subit des dégâts et survit inflige son ATK en retour à l'attaquant. | *Chaque coup reçu est une réponse en attente.* |
| H59 | Code du Chevalier | 5 | Épique | 3 tours | Assaut : chaque serviteur Humain allié qui attaque inflige 1 dégât supplémentaire. | *L'honneur ne protège pas. Mais il donne un tranchant supplémentaire.* |
| H60 | Mur Infranchissable | 6 | Épique | 2 tours | Sortilège ennemi : annulé s'il cible un serviteur Humain allié en rangée Avant. | *La magie s'arrête là où la volonté commence.* |
| H61 | Bannière du Roi | 5 | Épique | Permanent | Éveil : si tu as un Humain Légendaire en jeu, invoque un Chevalier 2/2 en rangée Avant. | *Sous cette bannière, on ne compte plus les morts. On compte ceux qui restent debout.* |
| H62 | Résistance Acharnée | 4 | Épique | 3 tours | Carnage allié : quand un Humain allié meurt, le héros allié gagne 1 HP. | *Chaque mort laisse quelque chose aux vivants. Quelque chose de dur, de têtu — de précieux.* |
| H63 | Purge Sainte | 6 | Légendaire | Instantané | Détruit tous les serviteurs Mort-Vivants ennemis ayant 3 HP ou moins. | *Ce n'est pas une prière. C'est une déclaration.* |
| H64 | Grande Mobilisation | 8 | Légendaire | Instantané | Invoque 4 Humains aléatoires de coût ≤4 en rangée Avant. Coûte 7 si ta rangée Avant est vide. | *Quand tout le reste a échoué, il reste les hommes. Il y en a toujours assez pour une dernière fois.* |

---

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| H65 | Citadelle des Hommes | 4 | Rare | Présence : tes serviteurs en rangée Avant ont +0/+1 HP de façon permanente. | *Ces murs n'ont pas été construits pour durer. Ils ont duré quand même.* |
| H66 | Lignée des Braves | 3 | Rare | Deuil : quand un Humain allié meurt, pioche 1 carte. | *Chaque nom gravé est aussi une leçon. Il suffit de savoir la lire.* |
| H67 | Pacte de Résistance | 3 | Rare | Présence : les serviteurs Humains alliés reçoivent 1 dégât de moins de toute source (minimum 1). | *Ils ont signé ensemble. Aucun d'eux ne s'en souvient exactement. Tous s'en souviennent suffisamment.* |
| H68 | Temple de Guerre | 5 | Épique | Appel : chaque Humain invoqué gagne FORMATION de façon permanente. | *On ne vient pas y prier. On vient y apprendre à tenir sa place dans la ligne.* |
| H69 | Cercle de Commandement | 4 | Épique | Éveil : si tu as un Commandant en jeu (carte avec COMMANDEMENT), tous les Humains alliés gagnent +1/+0 ce tour. | *Un commandant suffit. Le cercle fait le reste.* |
| H70 | Forteresse Imprenable | 5 | Épique | Carnage ennemi : chaque fois qu'un serviteur ennemi meurt, tes serviteurs en rangée Avant gagnent +0/+1 jusqu'à fin de tour. | *Chaque ennemi abattu consolide ce qui reste debout.* |
| H71 | Bouclier de la Foi | 4 | Épique | Sortilège ennemi : la première fois par tour qu'un sort ennemi affecte un de tes serviteurs, réduit ses dégâts de 2 (minimum 0). | *La foi ne comprend pas la magie. Elle n'a pas besoin de la comprendre pour la freiner.* |
| H72 | Ordre des Anciens | 5 | Épique | Éveil : si tu as 5 Humains ou plus en jeu, invoque un Héros Tombé 3/3 en rangée Avant. | *Les anciens ne reviennent pas par magie. Ils reviennent parce qu'on a encore besoin d'eux.* |
| H73 | Mémorial des Héros | 4 | Épique | Dernier Souffle : quand un Humain Légendaire allié meurt, invoque immédiatement un Chevalier 2/2 et un Milicien 2/1 en rangée Avant. | *On grave les noms pour ne pas oublier. On continue pour la même raison.* |
| H74 | Décret Royal | 6 | Légendaire | Éveil : tous tes serviteurs Humains gagnent +1/+1. (S'accumule chaque tour.) | *Le décret n'a pas de date d'expiration. La guerre non plus.* |
| H75 | Aegis de l'Empire | 5 | Légendaire | Présence : tes serviteurs Humains en rangée Avant sont immunisés à l'Infection. Les marqueurs Infection déjà présents sont retirés à la fin de chaque tour. | *L'Empire ne cède pas à la pourriture. Ce n'est pas de l'orgueil. C'est de l'obstination.* |
