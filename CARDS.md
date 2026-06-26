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