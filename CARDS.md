# Wyrdane CARDS.md

Liste complète des cartes des races **Mort-Vivant**, **Humain** et **Démon**.

> **Notes de révision (à répercuter dans `CLAUDE.md` et `README.md`, et côté code si adopté) :**
> - Le type de carte "Éphémère" est renommé **Incantation** (sort à effet immédiat, jeté après usage), pour les trois races.
> - Les Rituels Mort-Vivant/Humain avec une durée "Instantané" ou "Ce tour" ont été retravaillés en effets vraiment récurrents (voir IDs 54, 56, 57, 58, 60, 62, 63, 64 côté Mort-Vivant ; H55, H61, H63, H64 côté Humain). Les Rituels Démon utilisent directement le système de **charges** décrit dans `CLAUDE.md`.
> - La race **Démon** est une addition récente : voir sa section dédiée en fin de fichier. Le support moteur est en place (voir « Points d'intégration tranchés » en fin de fichier) ; les 75 ressources `.tres` des cartes sont créées dans `resources/cards/demon/`.
> - **Système de Ressources par Race** (voir `README.md`) : chaque race a désormais sa propre carte-ressource (type `Resource`, coût 0, posée dans une zone dédiée du plateau — une seule par tour et par camp) : Éclat d'Âme (Mort-Vivant), Sceau du Royaume (Humain), Fragment de Pacte (Démon). Voir la section « Ressource » de chaque race ci-dessous. Anomalie (Abomination) est documentée en attendant le support moteur de cette race.

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

## Mots-clés exclusifs Mort-Vivant

| Mot-clé | Effet |
|---|---|
| `PESTIFÉRÉ` | Les attaques de ce serviteur infligent **Infection** en plus des dégâts. |
| `NÉCROPHAGE` | Quand un serviteur allié meurt, ce serviteur gagne +1/+1 de façon permanente. |
| `HORDE` | Tant que tu contrôles 3 Morts-Vivants ou plus, ce serviteur gagne +1/+0. |
| `REVENANT` | La première fois que ce serviteur devrait mourir, il se relève avec 1 HP à la place (une seule fois par partie). Ne se déclenche pas en cas de Sacrifice. |
| `CHAIR MORTE` | Immunisé à l'Infection, au poison et aux effets de peur. |

---

## Mots-clés partagés (rappel)

| Mot-clé | Description |
|---|---|
| `REMPART` | Doit être attaqué en priorité par les serviteurs ennemis. |
| `ASSAUT` | Peut attaquer le tour de son invocation. |
| `FRÉNÉSIE` | Peut attaquer deux fois par tour. |
| `RAVAGE` | Les dégâts excédentaires sont infligés directement au héros adverse. |
| `INFILTRATION` | Ignore la rangée Avant ennemie ; peut cibler directement la rangée Arrière ou le héros. |
| `MOISSON` | Les dégâts infligés par ce serviteur soignent le héros allié d'autant. |
| `VENIN MORTEL` | Toute blessure infligée par ce serviteur détruit la cible, quelle que soit sa vie restante. |
| `ÉGIDE` | Annule la première source de dégâts reçue. |

---

## Triggers (Déclencheurs)

| Trigger | Sur quel type de carte | Description |
|---|:---:|---|
| `Arrivée` | Serviteur | Se déclenche quand ce serviteur entre en jeu. |
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
| 01 | Rampant en Décomposition | ⚔️ | 1 | 1 | 1 | Dernier Souffle : invoque un Zombie 1/1 sous ton contrôle. | Il ne sait plus pourquoi il avance. Il avance, c'est tout. |
| 02 | Goule Affamée | ⚔️ | 1 | 2 | 1 | NÉCROPHAGE. | La faim ne disparaît pas avec la mort. Elle empire. |
| 03 | Cadavre Errant | ↕️ | 2 | 1 | 3 | REMPART. CHAIR MORTE. | Personne ne se souvient de son nom. Lui non plus. |
| 04 | Zombie Mineur | ⚔️ | 2 | 2 | 2 | HORDE. | Il était enfant. C'était avant. |
| 05 | Charognard Putride | ⚔️ | 2 | 3 | 1 | Dernier Souffle : inflige Infection à un serviteur ennemi ciblé. | Même en tombant, il répand ce qui l'a tué. |
| 06 | Infecté Récent | ⚔️ | 2 | 2 | 2 | Mort-rage : +1/+1 par ennemi infecté en jeu. | La morsure date d'hier. Il a encore ses yeux d'avantmais plus rien derrière. |
| 07 | Servant Décharné | 🛡️ | 3 | 2 | 4 | Ralliement : tes serviteurs en rangée Avant ont +0/+1 HP jusqu'à fin de tour. | Il ne commande pas. Il pousse. Et ça suffit. |
| 08 | Mâcheur d'Os | ⚔️ | 3 | 4 | 2 | ASSAUT. Ralliement : inflige 1 dégât splash aux serviteurs adjacents à la cible. | Le craquement des os est le seul son qu'il comprend encore. |
| 09 | Horde Mineure | ⚔️ | 3 | 1 | 1 | Arrivée : invoque 2 Rampants 1/1 en rangée Avant. | Un seul ne fait pas peur. Mais il n'est jamais seul. |
| 10 | Mort-Vivant Enchaîné | ⚔️ | 3 | 3 | 3 | HORDE. | Les chaînes ne le retiennent plus. Elles font partie de lui. |
| 11 | Larve Cadavérique | ↕️ | 1 | 1 | 1 | NÉCROPHAGE. | Elle n'est pas née de la vie. Elle est née de ce qui reste. |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 12 | Pestilent | ↕️ | 2 | 1 | 2 | PESTIFÉRÉ. | Son souffle est une condamnation à retardement. |
| 13 | Zombie Bouclier | ⚔️ | 2 | 1 | 5 | REMPART. Blessure : réduit de 1 les dégâts reçus (minimum 1). | Les lames s'enfoncent dans la chair morte et s'y perdent. |
| 14 | Hurleur Nécrotique | ↕️ | 3 | 3 | 2 | Arrivée : serviteurs Mort-Vivants alliés en rangée Avant +1/+0 jusqu'à fin de tour. | Son cri ne terrorise plus. Il réveille. |
| 15 | Rongeur de Chair | ⚔️ | 4 | 5 | 3 | Exécution : peut attaquer à nouveau une fois par tour. | Il ne s'arrête pas quand la proie tombe. Il s'arrête quand il ne reste plus rien. |
| 16 | Cultiste Zombifié | ↕️ | 2 | 1 | 2 | Dernier Souffle : invoque un Cadavre Errant en rangée Avant. | Il a prié pour la mort éternelle. Il a été exaucéà moitié. |
| 17 | Géant Boursouflé | ⚔️ | 5 | 4 | 6 | Dernier Souffle : inflige 2 dégâts à tous les serviteurs ennemis en rangée Avant. | Sa mort est plus dangereuse que sa vie.Rapport de bataille, campagne de la Vallée Grise |
| 18 | Émissaire de la Peste | ↕️ | 4 | 3 | 4 | PESTIFÉRÉ. | Il ne vient pas combattre. Il vient annoncer. |
| 19 | Soldat Réanimé | ⚔️ | 3 | 4 | 3 | REVENANT. | La mort lui a appris ce que la guerre ne lui avait pas enseigné : la patience. |
| 20 | Banshee Zombie | 🛡️ | 4 | 2 | 5 | Arrivée : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse. | Elle hurle sans voix. Ceux qu'elle regarde oublient comment parler. |
| 21 | Possédé Hurlant | ⚔️ | 3 | 5 | 1 | ASSAUT. VENIN MORTEL. Dernier Souffle : retiré du jeu (ne va pas au cimetière). | Même les morts refusent de le reprendre. |
| 22 | Cavalier Zombie | ⚔️ | 4 | 4 | 3 | ASSAUT. Arrivée : attaque immédiatement le serviteur ennemi le plus faible en HP. | Le cheval est mort avant lui. Ni l'un ni l'autre ne s'en est rendu compte. |
| 23 | Garde du Charnier | ⚔️ | 2 | 1 | 4 | REMPART. Dernier Souffle : pioche 1 carte. | Il gardait les vivants. Il garde désormais ce qui reste. |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 24 | Le Patient Zéro | ↕️ | 4 | 3 | 3 | Arrivée : inflige Infection à tous les serviteurs ennemis en jeu. | On n'a jamais su d'où il venait. On a fini par ne plus chercher. |
| 25 | Ravageur Putréfié | ⚔️ | 5 | 6 | 4 | RAVAGE. Mort-rage : serviteurs Mort-Vivants alliés +2/+2. | Chaque mort nourrit sa rage. Et il y a toujours de nouveaux morts. |
| 26 | Architecte de la Horde | 🛡️ | 3 | 2 | 3 | Ralliement : invoque un Rampant 1/1 en rangée Avant. | Il ne construit pas d'armée. Il la sécrète. |
| 27 | Colosse Décomposé | ⚔️ | 6 | 7 | 7 | REMPART. CHAIR MORTE. Blessure : les dégâts excédentaires ne se propagent pas. | Les lames disparaissent dans sa masse. Il continue d'avancer. |
| 28 | Esprit Vorace | ↕️ | 4 | 4 | 4 | MOISSON. Arrivée : vole 2 HP au héros ennemi. | Il ne prend pas ta vie. Il la déplacedans les mauvaises mains. |
| 29 | Nuée d'Insectes Cadavériques | ↕️ | 3 | 1 | 2 | Arrivée : inflige 1 dégât à tous les serviteurs ennemis en jeu. | Là où elle passe, rien ne guérit vraiment. |
| 30 | Faucheur de la Plaie | ⚔️ | 5 | 5 | 5 | Arrivée : détruit tous les serviteurs ennemis ayant 3 HP ou moins. | Il ne choisit pas les plus forts. Il choisit les presque mortspour finir le travail. |
| 31 | Nécromancien Putride | 🛡️ | 4 | 2 | 4 | Arrivée : ressuscite le dernier Mort-Vivant allié mort avec 1 HP en rangée Avant. | "Je ne ressuscite personne. Je refuse simplement qu'ils s'arrêtent." |
| 32 | Assassin Décharné | ⚔️ | 3 | 4 | 2 | INFILTRATION. Ne peut pas être ciblé par les sorts ennemis jusqu'à sa première attaque. | On ne le voit pas venir. On ne le voit que partir. |
| 33 | Berserker Infecté | ⚔️ | 4 | 5 | 4 | FRÉNÉSIE. REVENANT. Mort-rage : +3/+0. | La fièvre l'a tué. Ce qui reste est plus rapide. |
| 34 | Tombeau Ambulant | ⚔️ | 5 | 3 | 8 | REMPART. Dernier Souffle : invoque 3 Rampants 1/1 en rangée Avant. | Il n'était pas un monstre. Il était une fosse commune. |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 35 | Le Médecin de la Peste | 🛡️ | 6 | 0 | 4 | Éveil : invoque un Mort-Vivant aléatoire de coût ≤3 en rangée Avant. | Il soignait les vivants autrefois. Il a simplement changé de patientèle. |
| 36 | Roi Liche Zombie | ⚔️ | 7 | 6 | 8 | Arrivée : ressuscite les 3 derniers Mort-Vivants alliés morts ce match avec 1 HP en rangée Avant. | Son royaume n'a pas de frontières. Il s'étend à mesure que ses sujets meurent. |
| 37 | Apocalypse Zombie | ⚔️ | 8 | 9 | 9 | Arrivée : transforme tous les serviteurs adverses en jeu en Zombies 1/1 sous ton contrôle. | Ce n'était pas une invasion. C'était une conversion. |
| 38 | Léviathan Putréfié | ⚔️ | 7 | 8 | 10 | REMPART. Arrivée : serviteurs Mort-Vivants alliés +2/+2. | Les mers l'ont recraché. Elles non plus ne voulaient plus de lui. |
| 39 | La Faucheuse | ⚔️ | 7 | 7 | 6 | Arrivée : détruit un serviteur ennemi ciblé et le ressuscite sous ton contrôle sans ses effets. | Elle ne prend pas les âmes. Elle redistribue les corps. |

---

## Incantations

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| 40 | Souffle Nécrotique | 2 | Commune | 2 dégâts à un serviteur ennemi ciblé. | Ce n'est pas du vent. C'est ce qui reste quand les poumons ne servent plus à rien. |
| 41 | Réveil Soudain | 1 | Commune | Ressuscite le dernier serviteur allié mort avec 1 HP en rangée Avant. | Il n'y a pas de repos pour ceux qu'on rappelle. |
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

| ID | Nom | ⬡ | Rareté | Charges | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| 53 | Rituel de Résurrection | 5 | Épique | 2 charges | Éveil : ressuscite un Mort-Vivant allié mort aléatoire avec 1 HP en rangée Avant. | Le cercle ne ferme jamais complètement. C'est voulu. |
| 54 | Pacte Sanglant | 4 | Épique | 3 charges | Sacrifice (un serviteur allié à 2 HP ou moins) : invoque un Mort-Vivant 2/2. | Chaque tour, le cercle redemande son dû — et chaque fois, il redonne quelque chose en retour. |
| 55 | Cercle de Convocation | 5 | Épique | 3 charges | Éveil : invoque un Mort-Vivant aléatoire de coût ≤2 gratuitement. | Le cercle appelle. Les morts n'ont pas appris à décliner. |
| 56 | Communion avec les Morts | 3 | Rare | 4 charges | Deuil : pioche 1 carte par Mort-Vivant allié mort ce match (max 4). | Chaque mort laisse quelque chose derrière lui. Il suffit de savoir écouter. |
| 57 | Rituel d'Exhumation | 4 | Rare | 3 charges | Éveil : si ton cimetière contient un Mort-Vivant, ramène-le en main. | On ne l'enterre pas. On l'entrepose, tour après tour. |
| 58 | Cercle de Sacrifice | 6 | Légendaire | 2 charges | Sacrifice (un serviteur allié) : tes serviteurs restants gagnent +1/+1 jusqu'à la fin du tour. | Le cercle ne se lasse pas de demander. Il attend juste la prochaine offrande. |
| 59 | Rituel du Lien Funeste | 4 | Épique | 3 charges | Deuil : inflige 2 dégâts au héros ennemi. | Chaque allié qui tombe tire un fil. L'ennemi finit par sentir la traction. |
| 60 | Arrivée de Masse | 7 | Légendaire | 3 charges | Éveil : invoque un Mort-Vivant aléatoire de coût ≤4. | Il n'a pas ouvert une porte. Il l'a laissée entrouverte, encore et encore. |
| 61 | Rituel de l'Éclipse | 6 | Légendaire | 2 charges | Sortilège ennemi : annulé s'il cible un de tes Mort-Vivants. | Sous l'éclipse, la magie adverse perd ses repères. Les morts, eux, n'en ont plus besoin. |
| 62 | Rituel de la Fosse Sans Fond | 6 | Épique | 2 charges | Sacrifice (un serviteur allié) : pioche 1 carte. | Il a tout donné. Il savait exactement ce que ça valait — un peu à la fois. |
| 63 | Épidémie | 4 | Épique | 2 charges | Présence : serviteurs non Mort-Vivants ennemis -2/-2. Ceux réduits à 0 HP ne vont pas dans le cimetière adverse. | Elle ne tue pas. Elle prépare, jour après jour. |
| 64 | Grand Rituel Nécrotique | 8 | Légendaire | 3 charges | Deuil : ramène en main le Mort-Vivant allié le plus récemment mort. | "Je n'ai perdu personne. Je les rappelle, un par un, chaque fois qu'il le faut."Le Nécromant d'Ossemoor |

---

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| 65 | Autel des Damnés | 3 | Rare | Deuil : pioche 1 carte. | Chaque mort nourrit l'autel. L'autel, lui, ne se souvient d'aucun nom. |
| 66 | Fosse Commune | 4 | Rare | Appel : si 3 Mort-Vivants alliés ou plus sont en jeu, invoque un Rampant 1/1. (Une seule fois par tour.) | Plus elle se remplit, plus elle déborde. |
| 67 | Aura de Décrépitude | 3 | Rare | Résonance : ce Mort-Vivant attaquant gagne +1/+0 de façon permanente. | La décrépitude n'est pas une faiblesse. C'est une accumulation. |
| 68 | Cimetière Vivant | 5 | Épique | Deuil : ce Mort-Vivant revient en jeu à la fin du tour avec 1 HP. (Une seule fois par serviteur.) | Le sol ici ne garde rien. Il régurgite. |
| 69 | Brouillard Pestilentiel | 3 | Rare | Présence : à chaque début du tour adverse, les serviteurs ennemis infectés perdent 1 HP supplémentaire. | On ne le voit pas. On ne le sent même plus, après un moment. |
| 70 | Symbiose Cadavérique | 5 | Épique | Présence : tes serviteurs en rangée Arrière gagnent +0/+1 par serviteur allié en rangée Avant. | Les morts de devant protègent les morts de derrière. C'est le seul lien qui reste. |
| 71 | Idole de l'Apocalypse | 6 | Légendaire | Résonance : le Mort-Vivant attaquant inflige 1 dégât splash aux serviteurs adjacents à la cible. | On ne l'a pas sculpté. On l'a trouvé ainsi, debout, au milieu des ruines. |
| 72 | Sanctuaire Nécrotique | 4 | Épique | Présence : les sorts alliés coûtent 1 de moins (min 1). | Dans ses murs, la magie de mort coule comme de l'eau froidenaturellement. |
| 73 | Vortex des Âmes | 6 | Légendaire | Carnage : gagne 1 mana temporaire ce tour. | Les âmes qui s'y perdent alimentent quelque chose que personne ne comprend vraiment. |
| 74 | Monument aux Morts | 5 | Épique | Deuil : invoque 2 Mort-Vivants aléatoires de coût ≤3. | On l'a érigé pour honorer les disparus. Il préfère les renvoyer. |
| 75 | Murmure Funeste | 1 | Rare | Présence : le premier Mort-Vivant joué chaque tour coûte 1 de moins (min 1). | On ne l'entend pas. On sent juste que quelque chose a dit oui. |

### Jetons

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| 76 | Zombie | ⚔️ | 1 | 1 | 1 | — (jeton vanille, obtenu par transformation : Morsure Infectieuse, Apocalypse Zombie). | Ni vivant, ni mort. Juste debout. |

---

## Ressource

Carte-ressource de la race, posée dans sa propre zone (hors rangées/Rituels/Enchantements) — voir « Système de Ressources par Race » dans `README.md`.

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| 77 | Éclat d'Âme | 0 | Commune | Ajoute 1 Âme à ta réserve de Mort-Vivant. Une seule carte-ressource par tour et par camp. | Ce qui reste d'une vie, cristallisé par la nécromancie. |

# Wyrdane — CARDS_HUMAIN.md

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
| `Arrivée` | Serviteur | Se déclenche quand **ce serviteur** entre en jeu. |
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
| H02 | Milicien du Bourg | ⚔️ | 1 | 2 | 1 | Dernier Souffle : invoque un Éclaireur Rapide 1/1. | *Il est tombé en gardant la route ouverte. C'est tout ce qu'il avait demandé.* |
| H03 | Porteur de Bouclier | ⚔️ | 2 | 1 | 4 | REMPART. | *Le bouclier a des marques de griffes. Il ne les compte plus.* |
| H04 | Fantassin Aguerri | ⚔️ | 2 | 2 | 2 | FORMATION : tant qu'un allié est adjacent, gagne +1/+1. | *Seul, il tient. Ensemble, ils avancent.* |
| H05 | Archer de Guet | 🛡️ | 2 | 2 | 1 | Éveil : inflige 1 dégât à un serviteur ennemi aléatoire en rangée Avant. | *Il ne rate pas. Il attend juste le bon moment.* |
| H06 | Éclaireur Rapide | ⚔️ | 1 | 1 | 1 | ASSAUT. Arrivée : pioche 1 carte si la rangée Avant ennemie a 3 serviteurs ou plus. | *Il revient toujours avec de mauvaises nouvelles. Il revient, c'est ce qui compte.* |
| H07 | Vétéran des Marches | ⚔️ | 3 | 2 | 4 | Blessure : gagne +1/+0 de façon permanente. | *Chaque cicatrice lui a appris quelque chose. Il en a beaucoup appris.* |
| H08 | Frère d'Armes | ⚔️ | 3 | 3 | 2 | Ralliement : le serviteur allié adjacent gagne +0/+1. | *Il ne combat pas pour la victoire. Il combat pour que l'homme à sa gauche rentre chez lui.* |
| H09 | Lancier en Ligne | ⚔️ | 2 | 3 | 1 | FORMATION : tant qu'un allié est adjacent, gagne +1/+1. | *La ligne tient ou la ligne tombe. Il n'y a pas d'entre-deux.* |
| H10 | Guérisseur de Camp | 🛡️ | 3 | 0 | 3 | Éveil : restaure 1 HP à un serviteur Humain allié aléatoire. | *Il n'a jamais tenu d'épée. Ses mains ont pourtant sauvé plus de vies que n'importe quelle lame.* |
| H11 | Sergent de Troupe | ⚔️ | 3 | 2 | 3 | Arrivée : les serviteurs Humains alliés en rangée Avant gagnent +0/+1 jusqu'à fin de tour. | *Sa voix porte plus loin que le bruit du combat. C'est pour ça qu'il est encore en vie.* |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H12 | Chevalier du Mur | ⚔️ | 3 | 2 | 5 | REMPART. CONTRE-ATTAQUE. | *Il a juré de ne pas reculer. Il a tenu sa parole à un prix qu'il ne mentionne jamais.* |
| H13 | Inquisiteur de Fer | ↕️ | 3 | 3 | 2 | Arrivée : silence un serviteur ennemi ciblé jusqu'à fin du prochain tour adverse. | *Il ne cherche pas la vérité. Il coupe ce qui parle à la place d'elle.* |
| H14 | Capitaine de Milice | ↕️ | 4 | 3 | 3 | COMMANDEMENT. Arrivée : invoque un Milicien du Bourg 2/1 en rangée Avant. | *Il n'avait pas prévu de commander. Mais quelqu'un devait le faire.* |
| H15 | Briseur de Horde | ⚔️ | 4 | 4 | 3 | **Ralliement** : si la cible est un Mort-Vivant, inflige 2 dégâts supplémentaires. | *Il a perdu son village à la première vague. Il n'a pas perdu la rage.* |
| H16 | Sentinelle des Remparts | ⚔️ | 2 | 1 | 5 | REMPART. FORTIFICATION. | *On a essayé de le faire reculer. On a essayé de le renvoyer. On a abandonné.* |
| H17 | Archer d'Élite | 🛡️ | 3 | 3 | 2 | INFILTRATION : peut cibler n'importe quel serviteur ennemi (Avant ou Arrière). | *La rangée Avant n'est pas un obstacle. C'est un couloir.* |
| H18 | Prêtre de Guerre | 🛡️ | 4 | 1 | 4 | Éveil : restaure 2 HP à un serviteur Humain allié aléatoire. Dernier Souffle : invoque un Éclaireur Rapide 1/1. | *Il priait pour les vivants. À la fin, il a prié pour quelque chose de plus modeste : du temps.* |
| H19 | Lame-Jurée | ⚔️ | 3 | 4 | 2 | DISCIPLINE. Exécution : gagne +1/+1 de façon permanente. | *Elle a juré sur sa lame. La lame, elle, a juré de le mériter.* |
| H20 | Défenseur Juré | ⚔️ | 2 | 1 | 4 | REMPART. Blessure : les dégâts reçus sont réduits de 1 (minimum 1). | *Il n'esquive pas. Il absorbe. Ce n'est pas pareil.* |
| H21 | Éclaireur Infiltré | ⚔️ | 3 | 3 | 2 | Arrivée : **la rangée Arrière ennemie peut être ciblée directement par tes effets et attaques ce tour.** | *Il est allé voir. Il est revenu. Pas tout le monde n'en peut dire autant.* |
| H22 | Fantassin de Contre-Choc | ⚔️ | 4 | 3 | 4 | CONTRE-ATTAQUE. Blessure : gagne REMPART jusqu'à fin de tour. | *Chaque coup reçu lui rappelle pourquoi il tient encore debout.* |
| H23 | Soldat de la Foi | ⚔️ | 3 | 2 | 3 | ÉGIDE. Dernier Souffle : invoque un Milicien du Bourg 2/1 en rangée Avant. | *Il croyait en quelque chose. Ce quelque chose l'a protégé — une fois.* |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H24 | Maréchal de Campagne | 🛡️ | 5 | 2 | 5 | COMMANDEMENT. Éveil : tous les serviteurs Humains alliés gagnent +1/+0 jusqu'à fin de tour. | *Il ne crie pas les ordres. Il les dit une fois, calmement. Ça suffit.* |
| H25 | Champion du Peuple | ⚔️ | 4 | 5 | 4 | Exécution : soigne le héros allié de 2 HP. | *Il se bat pour des gens qu'il ne connaît pas. C'est pour ça qu'il gagne.* |
| H26 | Paladin de l'Aube | ⚔️ | 5 | 4 | 5 | ÉGIDE. MOISSON. Arrivée : invoque un Éclaireur Rapide 1/1 en rangée Avant. | *Il arrive à l'aube. Les morts reculent à la lumière. Lui aussi en a été surpris, la première fois.* |
| H27 | Brise-Mort | ⚔️ | 4 | 4 | 3 | Arrivée : détruit un serviteur ennemi ressuscité ou réanimé depuis le cimetière ciblé. | *"Tu es déjà mort une fois. Je vais m'assurer que tu ne l'oublies pas."* |
| H28 | Mur de Lances | ⚔️ | 4 | 1 | 6 | REMPART. FORMATION. Carnage : inflige 1 dégât à tous les serviteurs ennemis en rangée Avant. | *Ils ne bougent pas. La ligne tient. Les lances, elles, trouvent toujours quelque chose à traverser.* |
| H29 | Stratège Royal | 🛡️ | 4 | 2 | 4 | Ralliement : place le serviteur allié invoqué dans la rangée de ton choix, même si elle est pleine (échange avec un autre). | *Il ne voit pas un champ de bataille. Il voit un problème à résoudre.* |
| H30 | Exécuteur de l'Ordre | ⚔️ | 5 | 5 | 4 | VENIN MORTEL. DISCIPLINE. Ne peut attaquer que les serviteurs (jamais le héros directement). | *Il n'a pas de haine. Il a des instructions. C'est pire.* |
| H31 | Porte-Étendard | 🛡️ | 3 | 1 | 4 | Ralliement : invoque un Éclaireur Rapide 1/1 en rangée Avant pour chaque Humain déjà en jeu (max 3). | *L'étendard ne se rend pas. Tant qu'il tient, les autres tiennent aussi.* |
| H32 | Chevalier de la Contre-Marche | ⚔️ | 5 | 4 | 5 | CONTRE-ATTAQUE. ASSAUT. Blessure : gagne +2/+0 jusqu'à fin de tour. | *Il charge. Il encaisse. Il charge encore. C'est tout ce qu'il sait faire — et c'est suffisant.* |
| H33 | Inquisiteur Suprême | ↕️ | 5 | 3 | 5 | DISCIPLINE. Arrivée : annule tous les effets Infection sur tes serviteurs alliés. Immunise tes serviteurs à l'Infection ce tour. | *La corruption s'arrête là où il pose le regard.* |
| H34 | Général de Brigade | 🛡️ | 5 | 3 | 4 | COMMANDEMENT. Éveil : invoque un Fantassin Aguerri 2/2 en rangée Avant si tu as 4 Humains ou plus en jeu. | *Une armée n'est pas un nombre. C'est une volonté. La sienne.* |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| H35 | Le Roi Soldat | ⚔️ | 7 | 6 | 8 | COMMANDEMENT. ÉGIDE. Arrivée : tous les serviteurs Humains alliés gagnent +2/+2 de façon permanente. | *Il n'a pas pris la couronne. On la lui a posée sur le champ de bataille, entre deux assauts.* |
| H36 | La Grande Inquisitrice | 🛡️ | 6 | 3 | 6 | DISCIPLINE. Éveil : détruit un enchantement ou rituel ennemi actif aléatoire. | *Elle ne combat pas la magie ennemie. Elle la refuse.* |
| H37 | Le Rempart Vivant | ⚔️ | 6 | 4 | 10 | REMPART. FORTIFICATION. CONTRE-ATTAQUE. Blessure : invoque un Porteur de Bouclier 1/4 REMPART. | *On lui a demandé combien de temps il pouvait tenir. Il n'a pas répondu. Il tient encore.* |
| H38 | Commandant des Derniers | 🛡️ | 7 | 5 | 6 | COMMANDEMENT. Dernier Souffle : ressuscite tous les serviteurs Humains alliés morts ce tour avec 1 HP en rangée Avant. | *Sa mort n'est pas une fin. C'est un dernier ordre.* |
| H39 | L'Éternel Gardien | ⚔️ | 8 | 7 | 9 | REMPART. ÉGIDE. DISCIPLINE. Arrivée : tous les serviteurs ennemis perdent leurs mots-clés jusqu'à la fin du prochain tour adverse. | *Il n'a pas survécu à toutes ces guerres par chance. Il a survécu parce que rien de ce que l'ennemi fait ne le surprend.* |

---

## Incantations

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| H40 | Cri de Ralliement | 1 | Commune | Humains alliés +0/+1 jusqu'à fin de tour. | *Un seul cri. Toute la ligne se souvient pourquoi elle est là.* |
| H41 | Frappe Coordonnée | 2 | Commune | Deux serviteurs Humains alliés ciblés attaquent immédiatement le même serviteur ennemi ciblé. | *Deux hommes, un seul endroit. L'ennemi n'a pas le temps de choisir lequel regarder.* |
| H42 | Purification | 2 | Commune | Annule tous les effets Infection et marqueurs négatifs sur un serviteur allié ciblé. | *Le mal recule. Pas loin. Mais pour l'instant, ça suffit.* |
| H43 | Repli Tactique | 1 | Commune | Déplace un serviteur allié de la rangée Avant vers la rangée Arrière (ou inversement). Il conserve ses effets. | *Reculer n'est pas fuir. C'est choisir où mourir.* |
| H44 | Volée de Flèches | 3 | Commune | Inflige 1 dégât à tous les serviteurs ennemis en rangée Avant. Si 4 ou plus en rangée Avant : 2 dégâts à la place. | *Plus ils sont nombreux, plus ça fait de cibles.* |
| H45 | Bouclier de Foi | 1 | Rare | Donne ÉGIDE à un serviteur Humain allié ciblé jusqu'à fin du prochain tour adverse. | *La foi ne rend pas invulnérable. Elle donne juste le temps d'encaisser le premier coup.* |
| H46 | Jugement Divin | 3 | Rare | Détruit un serviteur ennemi ayant 2 ATK ou moins. | *Le verdict est rendu avant même que l'accusé comprenne qu'il était jugé.* |
| H47 | Ordre d'Avancer | 2 | Rare | Tous les serviteurs Humains alliés en rangée Arrière gagnent ASSAUT ce tour et peuvent attaquer depuis la rangée Arrière ce tour. | *L'ordre est arrivé. Il n'y avait pas de question à poser.* |
| H48 | Contre-Offensive | 3 | Rare | Exécution ce tour : chaque serviteur Humain allié qui tue un ennemi peut attaquer à nouveau immédiatement. | *La victoire s'enchaîne quand on ne lui laisse pas le temps de s'arrêter.* |
| H49 | Appel aux Armes | 4 | Rare | Invoque 2 Miliciens du Bourg 2/1 en rangée Avant. Si ta rangée Avant est vide : invoque 3 Miliciens du Bourg à la place. | *Quand la ligne est vide, ceux qui restent n'ont plus à réfléchir. Ils avancent.* |
| H50 | Bénédiction de Guerre | 2 | Épique | Un serviteur Humain allié ciblé gagne +2/+2 et DISCIPLINE jusqu'à fin de tour. | *Ce n'est pas de la magie. C'est la conviction que quelqu'un a mis dans ses mains.* |
| H51 | Massacre Sacré | 4 | Épique | Inflige 3 dégâts à tous les serviteurs Mort-Vivants ennemis en jeu. | *La lumière ne guérit pas les morts. Elle les brûle. C'est mieux.* |
| H52 | Formation Défensive | 3 | Épique | Tous tes serviteurs en rangée Avant gagnent REMPART et +0/+2 jusqu'à fin du tour adverse. | *Ils se serrent. La ligne devient un mur. Le mur ne bouge pas.* |

---

## Rituels

| ID | Nom | ⬡ | Rareté | Charges | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| H53 | Ordre de Tenir | 3 | Commune | 2 charges | Éveil : tes serviteurs en rangée Avant ne peuvent pas être renvoyés en main ni déplacés par des effets ennemis. | *L'ordre est simple. Les hommes, eux, sont compliqués. Mais ils obéissent.* |
| H54 | Hymne de Guerre | 4 | Rare | 3 charges | Ralliement : le serviteur Humain invoqué gagne +1/+1. | *Le chant ne les rend pas invincibles. Il leur rappelle qu'ils ne sont pas seuls.* |
| H55 | Fortification des Lignes | 5 | Rare | 3 charges | Éveil : si ta rangée Avant a 5 serviteurs ou plus, ils gagnent tous REMPART jusqu'à fin de tour. | *Cinq hommes côte à côte. Ça devient quelque chose d'autre. Quelque chose qui ne cède pas.* |
| H56 | Serment du Sang | 4 | Rare | 3 charges | Deuil : quand un Humain allié meurt, **le serviteur allié qui lui était adjacent** gagne +1/+1. | *Le serment survit à celui qui l'a fait. C'est l'idée.* |
| H57 | Marche Forcée | 3 | Rare | 2 charges | Éveil : invoque un Éclaireur Rapide 1/1 en rangée Avant gratuitement. | *Pas de repos. Pas d'arrêt. La ligne avance parce que s'arrêter, c'est mourir.* |
| H58 | Contre-Attaque Générale | 5 | Épique | 2 charges | Blessure : chaque serviteur Humain allié qui subit des dégâts et survit inflige son ATK en retour à l'attaquant. | *Chaque coup reçu est une réponse en attente.* |
| H59 | Code du Chevalier | 5 | Épique | 3 charges | **Ralliement** : chaque serviteur Humain allié qui attaque inflige 1 dégât supplémentaire. | *L'honneur ne protège pas. Mais il donne un tranchant supplémentaire.* |
| H60 | Mur Infranchissable | 6 | Épique | 2 charges | Sortilège ennemi : annulé s'il cible un serviteur Humain allié en rangée Avant. | *La magie s'arrête là où la volonté commence.* |
| H61 | Bannière du Roi | 5 | Épique | 2 charges | Éveil : si tu as un Humain Légendaire en jeu, invoque un Fantassin Aguerri 2/2 en rangée Avant. | *Sous cette bannière, on ne compte plus les morts. On compte ceux qui restent debout.* |
| H62 | Résistance Acharnée | 4 | Épique | 3 charges | **Deuil** : quand un Humain allié meurt, le héros allié gagne 1 HP. | *Chaque mort laisse quelque chose aux vivants. Quelque chose de dur, de têtu — de précieux.* |
| H63 | Purge Sainte | 6 | Légendaire | 2 charges | Éveil : détruit un serviteur Mort-Vivant ennemi ayant 3 HP ou moins. | *Ce n'est pas une prière. C'est une déclaration — répétée, chaque matin.* |
| H64 | Grande Mobilisation | 8 | Légendaire | 3 charges | Éveil : invoque un Humain aléatoire de coût ≤4 en rangée Avant. | *Quand tout le reste a échoué, il reste les hommes. Il en arrive d'autres, à chaque aube.* |

---

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| H65 | Citadelle des Hommes | 4 | Rare | Présence : tes serviteurs en rangée Avant ont +0/+1 HP de façon permanente. | *Ces murs n'ont pas été construits pour durer. Ils ont duré quand même.* |
| H66 | Lignée des Braves | 3 | Rare | Deuil : quand un Humain allié meurt, pioche 1 carte. (Une seule fois par tour.) | *Chaque nom gravé est aussi une leçon. Il suffit de savoir la lire.* |
| H67 | Pacte de Résistance | 3 | Rare | Présence : les serviteurs Humains alliés reçoivent 1 dégât de moins de toute source (minimum 1). | *Ils ont signé ensemble. Aucun d'eux ne s'en souvient exactement. Tous s'en souviennent suffisamment.* |
| H68 | Temple de Guerre | 5 | Épique | Appel : chaque serviteur allié invoqué gagne +1/+1 de façon permanente. | *On ne vient pas y prier. On vient y apprendre à tenir sa place dans la ligne.* |
| H69 | Cercle de Commandement | 4 | Épique | Éveil : si tu as un Commandant en jeu (carte avec COMMANDEMENT), tous les Humains alliés gagnent +1/+0 ce tour. | *Un commandant suffit. Le cercle fait le reste.* |
| H70 | Forteresse Imprenable | 5 | Épique | Carnage : chaque fois qu'un serviteur ennemi meurt, tes serviteurs en rangée Avant gagnent +0/+1 jusqu'à fin de tour. | *Chaque ennemi abattu consolide ce qui reste debout.* |
| H71 | Bouclier de la Foi | 4 | Épique | Sortilège ennemi : la première fois par tour qu'un sort ennemi affecte un de tes serviteurs, réduit ses dégâts de 2 (minimum 0). | *La foi ne comprend pas la magie. Elle n'a pas besoin de la comprendre pour la freiner.* |
| H72 | Ordre des Anciens | 5 | Épique | Éveil : si tu as 5 Humains ou plus en jeu, invoque un Capitaine de Milice 3/3 en rangée Avant. | *Les anciens ne reviennent pas par magie. Ils reviennent parce qu'on a encore besoin d'eux.* |
| H73 | Mémorial des Héros | 4 | Épique | **Deuil** : si le serviteur allié mort est un Humain Légendaire, invoque immédiatement un Fantassin Aguerri 2/2 et un Milicien du Bourg 2/1 en rangée Avant. | *On grave les noms pour ne pas oublier. On continue pour la même raison.* |
| H74 | Décret Royal | 6 | Légendaire | Éveil : tous tes serviteurs Humains gagnent +1/+1. (S'accumule chaque tour.) | *Le décret n'a pas de date d'expiration. La guerre non plus.* |
| H75 | Aegis de l'Empire | 8 | Légendaire | Présence : tous tes serviteurs alliés sont immunisés à tous les effets néfastes ennemis (Infection, poison, peur, silence, contrôle mental, et toute réduction de stats ou débuff). Les effets néfastes déjà présents sont retirés à la fin de chaque tour. | *L'Empire ne cède à rien de ce que l'ennemi lui inflige. Ce n'est pas de l'orgueil. C'est de l'obstination.* |

---

## Ressource

Carte-ressource de la race, posée dans sa propre zone (hors rangées/Rituels/Enchantements) — voir « Système de Ressources par Race » dans `README.md`.

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| H76 | Sceau du Royaume | 0 | Commune | Ajoute 1 Sceau à ta réserve Humaine. Une seule carte-ressource par tour et par camp. | *Frappé au nom du roi, il lie chaque soldat à son serment.* |

---

# Wyrdane — CARDS_DEMON.md

Liste complète des cartes de la race **Démon**.

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

## 🎯 Identité de faction

Les Démons paient leurs pouvoirs avec la vie de leur propre héros. Là où le Mort-Vivant exploite la mort de ses serviteurs et l'Humain la discipline collective, le Démon convertit les HP de son héros en puissance brute, en corruption durable de l'adversaire, et en effets explosifs. Jouer Démon, c'est accepter de s'affaiblir pour frapper plus fort — un pari risqué qui récompense l'agressivité et punit la passivité.

---

## Mots-clés exclusifs Démon

| Mot-clé | Effet |
|---|---|
| `PACTE` | Quand ce serviteur entre en jeu, ton héros perd un nombre de HP égal à son coût en mana. Il gagne ASSAUT. |
| `CORRUPTION` | Les attaques de ce serviteur infligent Corruption en plus des dégâts (la cible perd 1 ATK de façon permanente, cumulable). |
| `TERREUR` | Quand ce serviteur attaque, la cible ne peut pas attaquer lors du prochain tour adverse. |
| `RANG INFERNAL` | Ce serviteur gagne +1/+0 pour chaque tranche de 10 HP manquants sur ton héros. |
| `CHAIR DE SOUFRE` | Immunisé à Corruption, à la peur et aux effets de contrôle mental. |
| `SANG NOIR` | Chaque fois que ton héros perd des HP à cause d'une de tes propres cartes, ce serviteur gagne +1/+0 de façon permanente. |

---

## Mots-clés partagés (rappel)

| Mot-clé | Effet |
|---|---|
| `REMPART` | Doit être attaqué en priorité par les serviteurs ennemis. |
| `ASSAUT` | Peut attaquer le tour de son invocation. |
| `FRÉNÉSIE` | Peut attaquer deux fois par tour. |
| `RAVAGE` | Les dégâts excédentaires sont infligés directement au héros adverse. |
| `INFILTRATION` | Ignore la rangée Avant ennemie ; peut cibler directement la rangée Arrière ou le héros. |
| `MOISSON` | Les dégâts infligés par ce serviteur soignent le héros allié d'autant. |
| `VENIN MORTEL` | Toute blessure infligée par ce serviteur détruit la cible, quelle que soit sa vie restante. |
| `ÉGIDE` | Annule la première source de dégâts reçue. |

---

## Triggers (Déclencheurs)

| Trigger | Sur quel type de carte | Description |
|---|:---:|---|
| `Arrivée` | Serviteur | Se déclenche quand ce serviteur entre en jeu. |
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
| `Résonance` | Enchantement | Se déclenche quand un serviteur allié Démon attaque. |
| `Sacrifice` | Rituel / Incantation | Requiert de détruire un ou plusieurs serviteurs alliés pour activer l'effet. |

---

## Serviteurs

### Communes

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| D01 | Larve Infernale | ⚔️ | 1 | 2 | 1 | PACTE. | *Elle ne demande rien. Elle prend juste sa part avant même d'arriver.* |
| D02 | Suppôt des Abysses | ⚔️ | 1 | 1 | 2 | CORRUPTION. | *Une simple morsure, et déjà quelque chose s'effrite en toi.* |
| D03 | Gargouille de Cendres | 🛡️ | 2 | 1 | 3 | REMPART. CHAIR DE SOUFRE. | *Elle a regardé brûler des cathédrales entières sans ciller.* |
| D04 | Croc de Braise | ⚔️ | 2 | 3 | 1 | PACTE. | *Chaque morsure lui coûte, à toi aussi.* |
| D05 | Chuchoteur Malin | ↕️ | 2 | 2 | 2 | Arrivée : ton héros perd 1 HP ; pioche 1 carte. | *Il murmure une vérité. Elle a toujours un prix.* |
| D06 | Sangsue Infernale | ⚔️ | 2 | 2 | 2 | Arrivée : ton héros regagne 2 HP. | *Elle ne mord jamais l'ennemi en premier. Elle commence toujours par toi, doucement.* |
| D07 | Séducteur Écarlate | 🛡️ | 3 | 2 | 3 | Ralliement : la cible perd 1 ATK de façon permanente (Corruption). | *Il ne promet rien. Il se contente de prendre, doucement.* |
| D08 | Harpie Carmine | ⚔️ | 3 | 4 | 2 | TERREUR. | *Son cri ne blesse pas. Il paralyse.* |
| D09 | Bourreau Mineur | ⚔️ | 3 | 3 | 3 | Exécution : ton héros perd 1 HP ; ce serviteur gagne +1/+1 de façon permanente. | *Chaque exécution le nourrit — et te vide un peu.* |
| D10 | Sentinelle du Gouffre | 🛡️ | 3 | 1 | 4 | REMPART. Blessure : ton héros perd 1 HP ; ce serviteur regagne 1 HP. | *Elle boit la douleur des autres. La tienne fera l'affaire.* |
| D11 | Invocateur Novice | ↕️ | 1 | 1 | 1 | PACTE. | *Son premier pacte. Il ne sait pas encore combien ça va coûter, au fil du temps.* |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| D12 | Chasseur des Abysses | ⚔️ | 2 | 3 | 2 | CORRUPTION. | *Il ne tue pas toujours. Parfois, il préfère laisser pourrir.* |
| D13 | Buveur de Souffrance | ⚔️ | 3 | 2 | 3 | SANG NOIR. | *Il ne ressent pas ta douleur. Il l'absorbe, littéralement.* |
| D14 | Émissaire du Pacte | ↕️ | 3 | 2 | 3 | PACTE. Arrivée : pioche 1 carte. | *Il apporte toujours plus qu'il ne semble offrir — dans les deux sens.* |
| D15 | Bourreau des Flammes | ⚔️ | 4 | 5 | 3 | RAVAGE. | *Ce qu'il ne peut pas tuer, il l'incendie derrière lui.* |
| D16 | Larve Ascendante | ↕️ | 2 | 1 | 2 | RANG INFERNAL. | *Elle grandit dans les cicatrices, pas dans la lumière.* |
| D17 | Titan de Cendres | ⚔️ | 5 | 4 | 6 | REMPART. Dernier Souffle : ton héros perd 2 HP ; inflige 3 dégâts au héros adverse. | *Sa chute n'éteint rien. Elle propage juste l'incendie ailleurs.* |
| D18 | Suppôt du Répit | 🛡️ | 3 | 2 | 3 | Blessure : ton héros regagne 1 HP. | *Chaque coup qu'il encaisse repart, transformé, vers celui qu'il protège.* |
| D19 | Chevalier Déchu | ⚔️ | 3 | 4 | 3 | PACTE. | *Son armure était sacrée, autrefois. Elle a changé de camp avec lui.* |
| D20 | Banshee des Abysses | 🛡️ | 4 | 2 | 5 | Arrivée : inflige Corruption à un serviteur ennemi ciblé. | *Son chant ne tue personne. Il fait juste pourrir ce qui l'entend.* |
| D21 | Possédé Écarlate | ⚔️ | 3 | 5 | 1 | ASSAUT. TERREUR. | *Il ne réfléchit plus. Quelque chose réfléchit à sa place, et ça va vite.* |
| D22 | Cavalier des Flammes | ⚔️ | 4 | 4 | 3 | ASSAUT. Arrivée : ton héros perd 2 HP ; ce serviteur gagne +2/+0 de façon permanente. | *Sa monture est morte au premier galop. Il n'a pas ralenti pour autant.* |
| D23 | Garde Infernal | ⚔️ | 2 | 1 | 4 | REMPART. Dernier Souffle : ton héros perd 1 HP ; invoque une Larve Infernale 2/1. | *Il ne meurt jamais vraiment seul. Quelque chose se lève toujours après lui.* |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| D24 | Le Corrupteur | ↕️ | 4 | 3 | 3 | Arrivée : inflige Corruption à tous les serviteurs ennemis en jeu. | *Il n'a pas besoin de convaincre. Il lui suffit de rester assez longtemps.* |
| D25 | Ravageur des Flammes | ⚔️ | 5 | 6 | 4 | RAVAGE. RANG INFERNAL. | *Plus ton héros saigne, plus il brûle fort.* |
| D26 | Architecte du Pacte | 🛡️ | 3 | 2 | 3 | PACTE. Ralliement : invoque une Larve Infernale 2/1 en rangée Avant. | *Chaque contrat qu'il signe en engendre un autre, sans fin.* |
| D27 | Grand Inquisiteur du Sang | ⚔️ | 5 | 3 | 5 | SANG NOIR. RANG INFERNAL. | *Plus tu payes, plus il devient difficile à ignorer.* |
| D28 | Suceur d'Âmes | ↕️ | 4 | 4 | 4 | MOISSON. Arrivée : ton héros perd 2 HP ; vole 4 HP au héros ennemi. | *Il prélève des deux côtés. C'est ce qui rend le marché intéressant, pour lui.* |
| D29 | Nuée de Tourments | ↕️ | 3 | 1 | 2 | TERREUR. Arrivée : inflige 1 dégât à tous les serviteurs ennemis en jeu. | *Elle ne mord pas fort. Elle mord partout, et longtemps.* |
| D30 | Faucheur des Abysses | ⚔️ | 5 | 5 | 5 | Arrivée : détruit un serviteur ennemi ayant 3 HP ou moins ; ton héros perd 2 HP. | *Il choisit les plus faibles. Toi, tu paies pour son jugement.* |
| D31 | Grand Prophète Écarlate | 🛡️ | 4 | 2 | 4 | CORRUPTION. Arrivée : inflige Corruption à un serviteur ennemi ciblé. | *Ses visions ne mentent jamais. Elles s'assurent juste de se réaliser.* |
| D32 | Assassin des Ombres Rouges | ⚔️ | 3 | 4 | 2 | INFILTRATION. PACTE. | *Il ne frappe jamais ce qu'on protège. Il frappe ce qu'on croyait à l'abri.* |
| D33 | Berserker du Pacte | ⚔️ | 4 | 5 | 4 | FRÉNÉSIE. PACTE. | *Chaque contrat qu'il signe le rend plus rapide, et toi plus vulnérable.* |
| D34 | Trône de Cendres | ⚔️ | 5 | 3 | 8 | REMPART. RANG INFERNAL. | *Il siège sur ce que ton héros a déjà perdu.* |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| D35 | Le Marchand d'Âmes | 🛡️ | 6 | 0 | 4 | Éveil : ton héros perd 1 HP ; pioche 1 carte. | *Il ne se bat pas. Il n'en a pas besoin — le contrat travaille pour lui, tour après tour.* |
| D36 | Roi Démon Écarlate | ⚔️ | 7 | 6 | 8 | CORRUPTION. Arrivée : ton héros perd 3 HP ; inflige Corruption à tous les serviteurs ennemis. | *Son royaume ne s'étend pas par la conquête. Il s'étend par ce qu'il te fait accepter.* |
| D37 | Apocalypse Infernale | ⚔️ | 8 | 9 | 9 | RANG INFERNAL. Arrivée : ton héros perd 5 HP ; tous tes serviteurs Démons gagnent +2/+2 de façon permanente. | *Ce n'était pas une invasion. C'était le prix qu'il fallait payer.* |
| D38 | Le Gardien du Pacte Brisé | 🛡️ | 6 | 5 | 7 | Tant que ce serviteur est en jeu, les dégâts que tes propres cartes infligent à ton héros sont annulés. | *Il a lu chaque clause du contrat. Il a décidé qu'aucune ne s'appliquerait plus.* |
| D39 | Le Grand Pacte | ⚔️ | 7 | 7 | 6 | PACTE. Arrivée : ton héros perd 3 HP supplémentaires ; détruit un serviteur ennemi ciblé. | *Il ne demande jamais la permission. Il constate simplement ce que tu es prêt à perdre.* |

---

## Incantations

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| D40 | Flamme Infernale | 2 | Commune | 2 dégâts à un serviteur ennemi ciblé ; ton héros perd 1 HP. | *Le feu ne fait pas de distinction. Il te lèche un peu au passage.* |
| D41 | Pacte Hâtif | 1 | Commune | Ton héros perd 2 HP ; pioche 2 cartes. | *Signer vite coûte cher. Signer tard coûte pareil.* |
| D42 | Vague de Corruption | 3 | Commune | Inflige Corruption à tous les serviteurs ennemis en rangée Avant. | *Rien ne pourrit d'un coup. Tout pourrit, éventuellement.* |
| D43 | Rite de Sang | 2 | Rare | Sacrifice (un serviteur allié) : ton héros regagne 3 HP ; inflige 3 dégâts au héros ennemi. | *Un sang pour un autre. L'échange est rarement équitable — sauf pour toi, cette fois.* |
| D44 | Étreinte du Gouffre | 2 | Commune | Gèle un serviteur ennemi ciblé un tour ; ton héros perd 1 HP. | *Le froid des Abysses n'épargne personne, pas même celui qui l'invoque.* |
| D45 | Marque du Pacte | 3 | Rare | Un serviteur Démon allié ciblé gagne PACTE et RANG INFERNAL jusqu'à fin de tour. | *La marque ne s'efface pas. Elle attend juste son heure.* |
| D46 | Hurlement Écarlate | 3 | Rare | Démons alliés +1/+0 ce tour. Ton héros perd 2 HP. Si 5 ou plus en jeu : +2/+0 à la place. | *Plus ils sont nombreux à hurler, plus le prix grimpe — pour toi.* |
| D47 | Emprise Écarlate | 2 | Rare | Prend le contrôle d'un serviteur ennemi ayant 2 ATK ou moins jusqu'à la fin de ce tour, puis le détruit. | *Elle n'emprunte jamais rien. Elle rend, mais brisé.* |
| D48 | Communion Écarlate | 2 | Commune | Ton héros regagne 3 HP ; pioche 1 carte. | *Le pacte n'est pas qu'une dette. Parfois, il rembourse.* |
| D49 | Ultime Sacrifice | 3 | Épique | Sacrifice (jusqu'à 3 serviteurs alliés) : pioche 1 carte par sacrifié ; ton héros perd 1 HP par sacrifié. | *Ils ne meurent pas pour rien. Ils meurent pour que tu continues — de justesse.* |
| D50 | Absolution Écarlate | 3 | Rare | Les dégâts que tes cartes infligeraient à ton héros ce tour sont annulés. | *Pour une fois, le contrat se tait.* |
| D51 | Souffle Corrupteur | 1 | Commune | Un serviteur ennemi ciblé perd 1 ATK de façon permanente (Corruption). | *Un murmure suffit. Le reste se fait tout seul, avec le temps.* |
| D52 | Doigt Écarlate | 1 | Rare | Pioche 1 carte. Ton héros perd 1 HP. Si c'est un Démon, il coûte 1 de moins ce tour. | *Il désigne. Ce qu'il montre a toujours un prix, y compris pour toi.* |

---

## Rituels

Rappel moteur (`CLAUDE.md`) : un Rituel est un sort persistant doté de **X charges** ; chaque charge n'est consommée que lorsque son trigger se déclenche réellement, pas passivement à chaque tour. Il est détruit quand ses charges sont épuisées.

| ID | Nom | ⬡ | Rareté | Charges | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| D53 | Rituel du Pacte Éternel | 5 | Épique | 3 charges | Éveil : ton héros perd 1 HP ; invoque une Larve Infernale 2/1 en rangée Avant. | *Le pacte ne se referme jamais. C'est écrit dans les clauses les plus petites.* |
| D54 | Marché de Sang | 4 | Épique | 3 charges | Deuil : ton héros perd 1 HP ; invoque une Larve Infernale 2/1 dotée de PACTE. | *Chaque offrande en appelle une autre, encore, et encore.* |
| D55 | Cercle de Corruption | 5 | Épique | 3 charges | Éveil : inflige Corruption à un serviteur ennemi aléatoire. | *Le cercle ne choisit pas. Il se contente de continuer.* |
| D56 | Communion Infernale | 3 | Rare | 4 charges | Deuil : pioche 1 carte ; ton héros perd 1 HP. | *Chaque mort te parle. Écouter a un coût, à chaque fois.* |
| D57 | Cercle de Guérison Infernale | 4 | Rare | 3 charges | Éveil : ton héros regagne 2 HP. | *Même les Abysses savent qu'un pacte mort ne rapporte plus rien.* |
| D58 | Cercle du Grand Pacte | 6 | Légendaire | 2 charges | Sacrifice (un serviteur allié) : tes serviteurs restants gagnent +1/+1 jusqu'à la fin du tour ; ton héros perd 1 HP. | *Le cercle ne se lasse pas de demander. Il attend juste la prochaine offrande.* |
| D59 | Rituel de la Terreur | 4 | Épique | 3 charges | Deuil : le héros ennemi ne peut pas soigner jusqu'à la fin de son prochain tour. | *La peur ne referme aucune plaie. C'est précisément le but, encore et encore.* |
| D60 | Invasion Écarlate | 7 | Légendaire | 3 charges | Éveil : invoque un Démon aléatoire de coût ≤4 ; ton héros perd 1 HP. | *Ils ne demandent pas la permission d'entrer. Ils reviennent, simplement, tour après tour.* |
| D61 | Rituel de l'Éclipse Rouge | 6 | Légendaire | 3 charges | Sortilège ennemi : annulé s'il cible un de tes Démons ; ton héros perd 1 HP à chaque annulation. | *Sous cette éclipse, même se protéger a un prix, à répétition.* |
| D62 | Rituel du Gouffre Sans Fond | 6 | Épique | 2 charges | Sacrifice (un serviteur allié) : pioche 1 carte ; ton héros regagne 1 HP. | *Le seul rituel démoniaque qui rend plus qu'il ne prend — tant qu'il reste des charges.* |
| D63 | Fléau Écarlate | 4 | Épique | 2 charges | Éveil : serviteurs non Démons ennemis -1/-1 ; ton héros perd 1 HP. | *Le fléau ne fait pas de tri. Il revient juste, patiemment.* |
| D64 | Grand Rituel du Pacte | 8 | Légendaire | 3 charges | Deuil : ramène en main le Démon allié le plus récemment mort ; ton héros perd 1 HP. | *"Je ne les ai pas ressuscités. Je les rappelle, un par un, à chaque fois qu'il le faut."* |

---

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| D65 | Autel des Sacrifices | 3 | Rare | Deuil : ton héros perd 1 HP ; pioche 1 carte. | *L'autel ne demande jamais deux fois. Il attend, c'est tout.* |
| D66 | Fosse Écarlate | 4 | Rare | Appel : si 3 Démons alliés ou plus sont en jeu, invoque une Larve Infernale 2/1. | *Plus elle se remplit, plus elle déborde de quelque chose d'affamé.* |
| D67 | Aura de Corruption | 3 | Rare | Résonance : ce Démon attaquant inflige Corruption supplémentaire à sa cible. | *La corruption ne recule jamais. Elle s'accumule, discrètement.* |
| D68 | Cœur du Gouffre | 5 | Épique | Présence : au début de ton tour, ton héros perd 1 HP ; tous tes serviteurs Démons gagnent +1/+0 jusqu'à la fin du tour. | *Il bat au rythme de ce que tu es prêt à sacrifier chaque matin.* |
| D69 | Sceau du Répit | 3 | Rare | Présence : quand un serviteur Démon allié meurt, ton héros regagne 1 HP. | *Chaque perte laisse une trace. Celle-ci, au moins, te profite.* |
| D70 | Symbiose Infernale | 5 | Épique | Présence : tes serviteurs en rangée Arrière gagnent +0/+1 par serviteur Démon allié en rangée Avant. | *Ceux de devant brûlent. Ceux de derrière se nourrissent de la chaleur.* |
| D71 | Idole du Grand Pacte | 6 | Légendaire | Résonance : le Démon attaquant inflige 1 dégât splash aux serviteurs adjacents à la cible ; ton héros perd 1 HP. | *On ne l'a pas sculptée. Elle a simplement accepté de rester.* |
| D72 | Sanctuaire Écarlate | 4 | Épique | Présence : les sorts alliés coûtent 1 de moins (min 1). Ton héros perd 1 HP la première fois que ce rabais s'applique chaque tour. | *Dans ses murs, la magie coule librement. Rien n'est jamais vraiment gratuit.* |
| D73 | Vortex des Damnés | 6 | Légendaire | Carnage : gagne 1 mana temporaire ce tour ; ton héros perd 1 HP. | *Les âmes qui s'y perdent paient toujours un peu plus que prévu.* |
| D74 | Autel de la Souffrance | 4 | Épique | Présence : chaque fois que ton héros perd des HP à cause d'une de tes cartes, tes serviteurs Démons en jeu gagnent +0/+1 jusqu'à la fin du tour. | *L'autel ne juge pas ce que tu sacrifies. Il se contente d'en redistribuer la force.* |
| D75 | Sceau de Préservation | 3 | Rare | Présence : réduit de 1 (minimum 0) les dégâts que tes propres cartes infligent à ton héros, à chaque occurrence. | *Une clause discrète, glissée dans les petits caractères — en ta faveur, pour une fois.* |

---

## Ressource

Carte-ressource de la race, posée dans sa propre zone (hors rangées/Rituels/Enchantements) — voir « Système de Ressources par Race » dans `README.md`.

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| D76 | Fragment de Pacte | 0 | Commune | Ajoute 1 Pacte à ta réserve Démoniaque. Une seule carte-ressource par tour et par camp. | *Une clause parmi tant d'autres. Elle aussi se paiera.* |

---

## ✅ Points d'intégration tranchés (Démon)

Le support moteur est en place (voir « Mécaniques Démon » dans `README.md`) ; les 75 ressources `.tres` des cartes sont créées dans `resources/cards/demon/`.

1. **`CORRUPTION`** : marqueur cumulable `Minion.corruption_stacks` + `apply_corruption()` (-1 ATK permanent par marqueur), mots-clés dans `KeywordDemon.gd` sur le modèle de `KeywordHuman.gd`. Posée par le mot-clé à l'attaque (`CombatSystem`) ou par l'effet `Corrupt`.
2. **Dégâts auto-infligés** : pipeline `HeroSystem.self_damage` — l'effet `Damage` ciblant `OwnerHero` y passe désormais, tout comme le coût du PACTE. `RANG INFERNAL` est une aura recalculée sur les HP manquants du héros.
3. **Garde-fou adopté** : les dégâts auto-infligés ne réduisent jamais son propre héros sous 1 HP (clampé dans `HeroSystem.self_damage`).
4. **`Le Gardien du Pacte Brisé` (D38)** : flag `CardData.blocks_self_damage` — tant qu'un serviteur qui le porte est en jeu, les dégâts auto-infligés du camp sont annulés (vérifié en tête du pipeline `self_damage`).

---

# Race Abomination

## 🎯 Identité de faction

Là où le Mort-Vivant exploite la mort de ses serviteurs et le Démon paie sa puissance avec les HP de son héros, l'Abomination recompose la chair elle-même. Ses serviteurs ne sont jamais stables : ils mutent, fusionnent, absorbent ce qui meurt autour d'eux — le leur comme celui de l'adversaire. C'est une race de croissance organique et imprévisible : chaque partie fait grandir tes serviteurs différemment, au prix d'un vrai risque (les mutations peuvent affaiblir autant que renforcer).

Antagonisme naturel avec le Mort-Vivant : le Mort-Vivant veut garder les cadavres pour les ressusciter, l'Abomination veut les dévorer pour muter. Aucune des deux ne recycle les corps de la même façon.

Les noms de cette race ne suivent volontairement aucune convention martiale (pas de chevaliers, assassins, rois ou architectes) : une Abomination n'a pas de rang, pas de fonction, pas d'histoire propre. Elle est décrite par ce qu'elle fait à un corps, jamais par ce qu'elle est.

## Mots-clés exclusifs Abomination

| Mot-clé | Effet |
|---|---|
| `MUTATION` | Ce serviteur mute (voir Table de Mutation ci-dessous) chaque fois qu'il survit à une blessure. Les effets sont permanents et cumulables. |
| `FUSION` | Sacrifice un serviteur allié adjacent : ce serviteur absorbe ses stats restantes ET un de ses mots-clés au choix, de façon permanente. |
| `VIRULENT` | Dernier Souffle : le serviteur allié adjacent déclenche immédiatement une mutation. |
| `CHAIR ADAPTATIVE` | Arrivée : copie un mot-clé au choix présent sur un serviteur adjacent (allié ou ennemi), de façon permanente. |
| `ASSIMILATION` | Dévoration : ce serviteur peut absorber les restes pour gagner +1/+1 de façon permanente (une fois par mort). |
| `INSTABLE` | Ce serviteur ne peut pas être ciblé par des effets de soin, alliés ou ennemis — sa chair est trop erratique pour être stabilisée. |

## Table de Mutation

| Résultat | Probabilité | Effet |
|---|---|---|
| Croissance | 40% | +2/+0 permanent |
| Renforcement | 40% | +0/+2 permanent |
| Dégénérescence | 20% | -1/-1 permanent (si les HP tombent à 0, le serviteur meurt) |

## Mots-clés partagés (rappel)

| Mot-clé | Effet |
|---|---|
| `REMPART` | Doit être attaqué en priorité par les serviteurs ennemis. |
| `ASSAUT` | Peut attaquer le tour de son invocation. |
| `FRÉNÉSIE` | Peut attaquer deux fois par tour. |
| `RAVAGE` | Les dégâts excédentaires sont infligés directement au héros adverse. |
| `AILES NOIRES` | Ignore la rangée Avant ennemie ; peut cibler directement la rangée Arrière ou le héros. |
| `MOISSON` | Les dégâts infligés par ce serviteur soignent le héros allié d'autant. |
| `VENIN MORTEL` | Toute blessure infligée par ce serviteur détruit la cible, quelle que soit sa vie restante. |
| `ÉGIDE` | Annule la première source de dégâts reçue. |

## Triggers (Déclencheurs)

| Trigger | Sur quel type de carte | Description |
|---|---|---|
| Arrivée | Serviteur | Se déclenche quand ce serviteur entre en jeu. |
| Dernier Souffle | Serviteur | Se déclenche quand ce serviteur meurt. |
| Mort-rage | Serviteur | Se déclenche quand un serviteur ennemi meurt. |
| Blessure | Serviteur | Se déclenche quand ce serviteur reçoit des dégâts. |
| Exécution | Serviteur | Se déclenche quand ce serviteur tue un ennemi en attaquant. |
| Ralliement | Serviteur | Se déclenche quand ce serviteur attaque. |
| Dévoration | Serviteur | Se déclenche quand n'importe quel serviteur (allié ou ennemi) meurt en jeu, où qu'il soit. |
| Éveil | Rituel / Enchantement | Se déclenche à chaque début du tour du joueur. |
| Deuil | Rituel / Enchantement | Se déclenche quand un serviteur allié meurt. |
| Carnage | Rituel / Enchantement | Se déclenche quand un serviteur ennemi meurt. |
| Sortilège | Rituel / Enchantement | Se déclenche quand l'adversaire joue un sort. |
| Appel | Enchantement | Se déclenche chaque fois qu'un serviteur allié entre en jeu. |
| Présence | Enchantement | Effet passif continu actif tant que l'enchantement est en jeu. |
| Résonance | Enchantement | Se déclenche quand un serviteur allié Abomination gagne une mutation. |
| Sacrifice | Rituel / Incantation | Requiert de détruire un ou plusieurs serviteurs alliés pour activer l'effet. |

## Serviteurs

### Communes

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| A01 | Amas Informe | ⚔️ | 1 | 1 | 2 | MUTATION. | *Il n'a pas de nom parce qu'il n'a pas encore de forme.* |
| A02 | Cœur Sans Corps | ↕️ | 1 | 2 | 1 | ASSIMILATION. | *Il bat pour quelque chose qui n'existe plus.* |
| A03 | Peau-Trop-Grande | 🛡️ | 2 | 1 | 3 | REMPART. INSTABLE. | *Elle flotte autour de ce qu'elle contient, comme si elle attendait encore d'être remplie.* |
| A04 | Nœud de Chair | ⚔️ | 2 | 2 | 2 | MUTATION. | *Chaque coup reçu le noue un peu plus serré.* |
| A05 | Ce-Qui-Se-Partage | ⚔️ | 2 | 3 | 1 | Dernier Souffle : le serviteur allié adjacent gagne +1/+1 permanent. | *Il ne meurt pas vraiment. Il se répartit ailleurs.* |
| A06 | Regard Détaché | 🛡️ | 2 | 1 | 2 | Arrivée : regarde la carte du dessus de ton deck, tu peux la remettre au fond. | *Il ne cligne jamais. Il n'a plus rien à protéger.* |
| A07 | Le Poids-Qui-Marche | ⚔️ | 3 | 2 | 4 | MUTATION. ASSIMILATION. | *On ne sait pas ce qu'il porte. Lui non plus.* |
| A08 | Emprunt de Peau | ↕️ | 3 | 2 | 3 | CHAIR ADAPTATIVE. | *Elle n'a rien à elle. Elle prend ce qui traîne à côté.* |
| A09 | Un-Devenu-Plusieurs | ⚔️ | 3 | 1 | 1 | Arrivée : invoque 2 Amas Informes 1/2 en rangée Avant. | *Il n'a jamais compris qu'il était censé rester seul.* |
| A10 | Visage-Encore-Flou | ⚔️ | 3 | 3 | 3 | FUSION. | *Il essaie plusieurs expressions. Aucune ne lui va tout à fait.* |
| A11 | Semence Amère | ↕️ | 1 | 1 | 1 | VIRULENT. | *Elle n'attend pas d'être plantée. Elle éclate là où elle tombe.* |

### Rares

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| A12 | Masse-Qui-Ne-Cesse | ⚔️ | 4 | 4 | 5 | MUTATION. REMPART. | *Elle a arrêté de compter les formes qu'elle a portées.* |
| A13 | Bouche-Mère | ⚔️ | 3 | 3 | 3 | ASSIMILATION. | *Elle ne distingue pas allié et ennemi. Seulement mort et pas-encore-mort.* |
| A14 | Second Regard | 🛡️ | 3 | 2 | 3 | CHAIR ADAPTATIVE. Arrivée : pioche 1 carte. | *Il voit ce que les autres pourraient devenir, avant qu'ils ne le sachent eux-mêmes.* |
| A15 | Main-Qui-Choisit | ⚔️ | 4 | 5 | 3 | Exécution : déclenche immédiatement une mutation. | *Chaque mise à mort la change un peu plus.* |
| A16 | Locataire Sans Bail | ↕️ | 2 | 1 | 2 | FUSION. | *Il ne demande jamais la permission de s'installer dans un autre corps.* |
| A17 | Ce-Qui-A-Trop-Poussé | ⚔️ | 5 | 4 | 6 | REMPART. MUTATION. | *On l'a vu changer trois fois dans la même bataille.* |
| A18 | Voix-Sous-la-Peau | 🛡️ | 3 | 2 | 3 | Arrivée : le serviteur allié adjacent gagne CHAIR ADAPTATIVE de façon permanente. | *Elle ne donne pas d'ordres. Elle se contente de murmurer, et la chair voisine écoute.* |
| A19 | Armure Fondue | ⚔️ | 3 | 4 | 3 | MUTATION. INSTABLE. | *Le métal a fusionné avec ce qu'il était censé protéger. Impossible de dire où l'un finit et l'autre commence.* |
| A20 | Doigt-Dans-les-Nerfs | 🛡️ | 4 | 2 | 5 | Arrivée : réduit l'ATK d'un serviteur ennemi ciblé de 1 jusqu'à la fin du prochain tour adverse. | *Un seul contact suffit à dérégler ce qui reste de coordination.* |
| A21 | Vase Brisé, Encore Plein | ⚔️ | 3 | 5 | 1 | ASSAUT. VENIN MORTEL. Dernier Souffle : se reforme en Amas Informe 2/2 sous ton contrôle (ne va pas au cimetière). | *Il ne meurt jamais tout à fait. Il se réarrange.* |
| A22 | Monture-et-Cavalier-Ne-Font-Qu'Un | ⚔️ | 4 | 4 | 3 | ASSAUT. Arrivée : attaque immédiatement le serviteur ennemi le plus faible en HP, puis mute. | *On ne sait plus lequel des deux dirige encore l'autre.* |
| A23 | Le Reste-Qui-Veille | ⚔️ | 2 | 1 | 4 | REMPART. ASSIMILATION. | *Il grandit à chaque garde tombée, la sienne comme celle d'en face.* |

### Épiques

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| A24 | Le Premier Écart | ↕️ | 4 | 3 | 3 | Arrivée : tous tes serviteurs Abomination alliés mutent immédiatement. | *Tout a commencé par une simple erreur de forme. Rien ne s'est arrêté depuis.* |
| A25 | La Faim Cuirassée | ⚔️ | 5 | 6 | 4 | RAVAGE. ASSIMILATION. | *Chaque mort autour d'elle l'épaissit un peu plus.* |
| A26 | Semeur de Nœuds | 🛡️ | 3 | 2 | 3 | FUSION. Ralliement : invoque un Amas Informe 1/2 en rangée Avant. | *Il ne construit rien. Il fait pousser.* |
| A27 | Ce-Qui-N'a-Plus-de-Bords | ⚔️ | 6 | 7 | 7 | REMPART. INSTABLE. MUTATION. | *On ne sait plus où il s'arrête, ni s'il s'arrête vraiment.* |
| A28 | Faim Sans Fond | ↕️ | 4 | 4 | 4 | MOISSON. ASSIMILATION. | *Elle ne prend pas la vie. Elle l'intègre.* |
| A29 | Poussière Qui Change | ↕️ | 3 | 1 | 2 | VIRULENT. Arrivée : inflige 1 dégât à tous les serviteurs ennemis en jeu. | *Là où elle se dépose, quelque chose commence toujours à changer.* |
| A30 | Le Trieur de Chairs | ⚔️ | 5 | 5 | 5 | Arrivée : détruit un serviteur ennemi ayant 3 HP ou moins, puis mute. | *Il ne choisit pas ses proies. Il choisit ce qu'il veut devenir ensuite.* |
| A31 | Le Sculpteur Sans Mains | 🛡️ | 4 | 2 | 4 | Arrivée : un serviteur allié ciblé gagne un mot-clé Abomination de ton choix, de façon permanente. | *"La forme n'est qu'une suggestion. Je préfère négocier."* |
| A32 | Ombre à Plusieurs Corps | ⚔️ | 3 | 4 | 2 | AILES NOIRES. FUSION. | *Elle n'a jamais eu qu'un seul visage à la fois. Elle en emprunte un nouveau à chaque cible.* |
| A33 | Fureur Sans Forme Fixe | ⚔️ | 4 | 5 | 4 | FRÉNÉSIE. MUTATION. | *Plus il frappe, moins il ressemble à ce qu'il était en arrivant.* |
| A34 | Ce-Qui-A-Cessé-de-S'arrêter | ⚔️ | 5 | 3 | 8 | REMPART. ASSIMILATION. Dernier Souffle : invoque 3 Amas Informes 1/2 en rangée Avant. | *Elle n'était pas un monstre. Elle était une croissance qu'on a laissée trop longtemps.* |

### Légendaires

| ID | Nom | Lane | ⬡ | ⚔ | ♥ | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|:---:|---|---|
| A35 | L'Éternel Recommencement | 🛡️ | 6 | 0 | 4 | Éveil : invoque une Abomination aléatoire de coût ≤3 en rangée Avant ; elle mute immédiatement. | *Il ne se soigne plus. Il se réinvente, sans fin.* |
| A36 | Ce-Qui-Se-Souvient-Par-le-Corps | ⚔️ | 7 | 6 | 8 | Arrivée : fusionne avec les 2 derniers serviteurs alliés morts ce match — absorbe leurs stats restantes cumulées et un mot-clé de chacun. | *Il n'a pas de mémoire. Il a une chair qui se souvient à sa place.* |
| A37 | La Grande Contamination | ⚔️ | 8 | 9 | 9 | Arrivée : transforme tous les serviteurs adverses en jeu en Amas Informe 1/1 sous ton contrôle. | *Ce n'était pas une invasion. C'était une contamination.* |
| A38 | Ce-Qui-Ne-Finit-Jamais-de-Grandir | ⚔️ | 7 | 8 | 10 | REMPART. Chaque mutation qu'il déclenche s'applique deux fois. | *Il a arrêté de compter ses formes il y a longtemps.* |
| A39 | L'Innommable | ⚔️ | 7 | 7 | 6 | Arrivée : choisis un serviteur ennemi ciblé — il devient une copie exacte (stats et mots-clés) sous ton contrôle jusqu'à la fin de la partie. | *Il n'a pas de visage. Il porte le tien, à présent.* |

## Incantations

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| A40 | Morsure de l'Air | 2 | Commune | 2 dégâts à un serviteur ennemi ciblé ; s'il survit, il perd 1 ATK de façon permanente. | *Ce qui ne tue pas ronge quand même.* |
| A41 | Premier Tressaut | 1 | Commune | Un serviteur allié ciblé déclenche immédiatement une mutation. | *Il n'a pas eu le temps de choisir. Peu importe.* |
| A42 | Pluie Qui Change | 3 | Commune | 1 dégât à tous les serviteurs ennemis en rangée Avant ; les survivants ont -1 ATK jusqu'à la fin du tour. | *L'air lui-même devient hostile en son sillage.* |
| A43 | Partage Forcé | 2 | Rare | Sacrifice (un serviteur allié) : le serviteur allié adjacent absorbe ses stats restantes de façon permanente. | *Rien ne se perd. Tout se recompose.* |
| A44 | Sommeil Qui Ronge | 2 | Commune | Gèle un serviteur ennemi ciblé un tour ; à la fin du gel, il subit une mutation forcée : Dégénérescence. | *Le froid ne le tue pas. Il le laisse simplement pourrir sur place.* |
| A45 | Appétit Ciblé | 3 | Rare | Détruit un serviteur ennemi ayant 2 HP ou moins ; un serviteur Abomination allié ciblé gagne +1/+1 permanent. | *Rien ne se jette. Tout se digère.* |
| A46 | Chant Qui Déforme | 3 | Rare | Abominations alliées +1/+0 ce tour. Si 5 ou plus en jeu : elles mutent aussi immédiatement. | *Un seul chant, mille chairs qui répondent en changeant de forme.* |
| A47 | Étau de Chair Neuve | 2 | Rare | Renvoie un serviteur ennemi de 3 HP ou moins dans la main de son propriétaire, réduit à une copie 1/1 sans mots-clés et coûtant 1. | *Il revient. Mais ce n'est plus vraiment lui.* |
| A48 | Respir Qui Change Tout | 1 | Commune | 1 dégât à tous les serviteurs en jeu ; les Abominations alliées touchées mutent à la place de perdre des HP. | *Même tes alliés changent, un peu, à chaque respiration.* |
| A49 | Sursaut Final | 3 | Épique | Carnage : le prochain serviteur Abomination allié qui meurt ce tour ressuscite comme Amas Informe 1/1 (une seule fois). | *Une dernière contraction. Ça suffit parfois à repartir.* |
| A50 | Fracture Vivante | 2 | Rare | Détruit un enchantement ou équipement ennemi. Si enchantement : un serviteur Abomination allié ciblé mute immédiatement. | *La corruption ne respecte pas la magie. Elle la digère aussi.* |
| A51 | Emprunt Instantané | 1 | Commune | Un serviteur Abomination allié ciblé copie un mot-clé présent sur n'importe quel autre serviteur en jeu (allié ou ennemi). | *Il n'a rien inventé. Il a juste regardé, et pris.* |
| A52 | Signe Qui Répond | 1 | Rare | Pioche 1 carte. Si c'est une Abomination, elle coûte 1 de moins ce tour et mute dès son entrée en jeu. | *Il désigne. Quelque chose répond, déjà changé.* |

## Rituels

Rappel moteur (`CLAUDE.md`) : un Rituel est un sort persistant doté de **X charges** ; chaque charge n'est consommée que lorsque son trigger se déclenche réellement, pas passivement à chaque tour. Il est détruit quand ses charges sont épuisées.

| ID | Nom | ⬡ | Rareté | Charges | Effet | Flavour |
|:---:|---|:---:|:---:|:---:|---|---|
| A53 | Rituel de la Forme Jamais Fixée | 5 | Épique | 3 charges | Éveil : un serviteur Abomination allié aléatoire mute immédiatement. | *Le cercle ne s'arrête jamais de proposer de nouvelles formes.* |
| A54 | Accord de la Chair Neuve | 4 | Épique | 3 charges | Sacrifice (un serviteur allié à 2 HP ou moins) : invoque un Amas Informe 2/2 doté de MUTATION. | *Chaque offrande revient sous une forme différente.* |
| A55 | Cercle de l'Assemblage | 5 | Épique | 2 charges | Sacrifice (deux serviteurs alliés adjacents) : fusionne-les en un seul serviteur cumulant leurs stats restantes et tous leurs mots-clés. | *Deux corps entrent. Un seul en ressort — plus grand.* |
| A56 | Écho des Chutes | 3 | Rare | 4 charges | Dévoration : pioche 1 carte (une seule fois par tour). | *Chaque mort, où qu'elle soit, nourrit le cercle.* |
| A57 | Rituel de la Chair Qui Recoud | 4 | Rare | 3 charges | Éveil : le serviteur Abomination allié avec le moins de HP restaure 2 HP. | *La chair se répare mal. Elle se répare quand même.* |
| A58 | Cercle de Dégénérescence | 6 | Légendaire | 2 charges | Sacrifice (un serviteur allié) : tous les serviteurs ennemis en rangée Avant subissent une mutation forcée : Dégénérescence. | *Ce que le cercle ne peut pas améliorer, il le corrompt.* |
| A59 | Rituel du Fil Sous la Peau | 4 | Épique | 3 charges | Deuil : le serviteur allié adjacent au serviteur mort mute immédiatement. | *Un fil invisible relie chaque chair à sa voisine. Il tire fort, à chaque rupture.* |
| A60 | Éclosion Sans Fin | 7 | Légendaire | 3 charges | Éveil : invoque une Abomination aléatoire de coût ≤4 ; elle mute deux fois. | *Elle n'a pas éclos une fois. Elle éclot encore.* |
| A61 | Rituel de l'Œil Sans Sommeil | 6 | Légendaire | 2 charges | Sortilège ennemi : annulé s'il cible un de tes Abominations. | *Il ne dort jamais. Il voit venir la magie adverse avant qu'elle n'arrive.* |
| A62 | Rituel du Ventre Qui Prend Tout | 6 | Épique | 2 charges | Sacrifice (un serviteur allié) : pioche 1 carte ; ton héros regagne des HP égaux aux HP restants du sacrifié. | *Rien ne se perd vraiment. Tout se redistribue, même à toi.* |
| A63 | Lente Altération | 4 | Épique | 2 charges | Présence : au début de chaque tour adverse, serviteurs non Abomination ennemis -1/-1. | *Elle ne prépare pas une invasion. Elle prépare une transformation.* |
| A64 | Grand Retour Sous une Autre Forme | 8 | Légendaire | 3 charges | Deuil : ramène en main le serviteur Abomination allié le plus récemment mort ; il coûte 1 de moins et mute dès qu'il est rejoué. | *"Je ne les rappelle pas. Je les laisse simplement finir de devenir autre chose."* |

## Enchantements

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| A65 | Autel Qui Ne Reconnaît Rien | 3 | Rare | Deuil : un serviteur Abomination allié aléatoire mute. | *Chaque mort nourrit l'autel. L'autel, lui, ne rend jamais la même forme deux fois.* |
| A66 | Nid Débordant | 4 | Rare | Appel : si 3 Abominations alliées ou plus sont en jeu, invoque un Amas Informe 1/2 (une seule fois par tour). | *Plus il se remplit, plus il en sort.* |
| A67 | Halo Qui Encourage le Changement | 3 | Rare | Résonance : le serviteur qui vient de muter gagne +1/+0 supplémentaire de façon permanente. | *Chaque changement en appelle un autre, plus franc.* |
| A68 | La Terre Qui Refuse de Garder | 5 | Épique | Deuil : le serviteur allié mort revient en jeu à la fin du tour avec 1 HP, transformé en Abomination (perd sa race d'origine, gagne MUTATION). Une seule fois par serviteur. | *Le sol ici ne garde rien. Il rend, mais jamais tel quel.* |
| A69 | Vapeur Qui S'Accroche | 3 | Rare | Présence : à chaque début du tour adverse, les serviteurs ennemis affaiblis (débuff actif) perdent 1 HP supplémentaire. | *On ne la voit pas. On sent juste que quelque chose continue de ronger.* |
| A70 | Lien Sans Membrane | 5 | Épique | Présence : tes serviteurs en rangée Arrière gagnent +0/+1 par serviteur Abomination allié en rangée Avant. | *Ceux de devant absorbent. Ceux de derrière en profitent.* |
| A71 | Effigie Née d'Elle-Même | 6 | Légendaire | Résonance : le serviteur Abomination attaquant inflige 1 dégât splash aux serviteurs adjacents à la cible, qui subissent alors une mutation forcée : Dégénérescence. | *On ne l'a pas sculptée. Elle a poussé, un jour, et personne ne l'a arrêtée.* |
| A72 | Repaire Qui Digère la Magie | 4 | Épique | Présence : les sorts alliés coûtent 1 de moins (min 1). | *Dans ses murs, tout se transforme un peu plus vite, même les sorts.* |
| A73 | Puits Qui Avale Tout | 6 | Légendaire | Dévoration : gagne 1 mana temporaire ce tour (une seule fois par tour). | *Tout ce qui meurt ici finit par nourrir autre chose.* |
| A74 | Ce Qu'on a Laissé Pousser | 5 | Épique | Deuil : invoque 2 Abominations aléatoires de coût ≤3 ; elles mutent immédiatement. | *On l'a érigé pour se souvenir des disparus. Il préfère les remplacer.* |
| A75 | Chuchotement Qui Change la Forme | 1 | Rare | Présence : la première Abomination jouée chaque tour coûte 1 de moins (min 1) et mute dès son entrée en jeu. | *On ne l'entend pas. On sent juste que quelque chose a déjà commencé à changer.* |

## Ressource (design uniquement — pas encore de support moteur, voir points ci-dessous)

| ID | Nom | ⬡ | Rareté | Effet | Flavour |
|:---:|---|:---:|:---:|---|---|
| A76 | Éclat d'Anomalie | 0 | Commune | Ajoute 1 Anomalie à ta réserve Abomination. Une seule carte-ressource par tour et par camp. | *Ça ne devrait pas exister. Ça existe quand même.* |

## ⚠️ Points d'intégration à trancher (Abomination)

Contrairement au Démon, le support moteur n'est pas encore en place. À ajouter dans `CLAUDE.md` et `README.md` avant de créer les 75 ressources `.tres` dans `resources/cards/abomination/` :

1. **`MUTATION`** : nécessite un système de jet pondéré (40/40/20) déclenché sur survie à une Blessure. Prévoir `Minion.mutation_stacks` (liste des mutations gagnées, pour l'affichage) et une fonction `roll_mutation()` centralisée — à appeler aussi par VIRULENT, les cartes qui déclenchent une mutation immédiate, et les rituels/enchantements qui en dépendent, pour éviter de dupliquer la logique de jet.
2. **`FUSION`** : nécessite de définir précisément ce que « absorber les stats restantes » signifie (ATK/HP actuels du sacrifié, pas ses valeurs de base) et comment choisir le mot-clé à copier (choix manuel du joueur, UI à prévoir).
3. **Dévoration** (nouveau trigger) : contrairement à Deuil/Carnage qui sont scindés par camp, Dévoration s'applique à toute mort en jeu, y compris entre deux serviteurs ennemis. Vérifier que le pipeline d'événements de mort notifie bien tous les triggers Dévoration actifs, quel que soit le camp du serviteur mort.
4. **`CHAIR ADAPTATIVE`** : copie de mot-clé « au choix » → nécessite une UI de sélection similaire à celle de FUSION, du Sculpteur Sans Mains (A31) et d'Emprunt Instantané (A51).
5. **Garde-fou à adopter** (sur le modèle de `HeroSystem.self_damage` pour le Démon) : la Dégénérescence ne doit jamais réduire un serviteur sous 1 HP de façon à le tuer avant que Dernier Souffle ne se résolve correctement — clarifier l'ordre mutation → check de mort dans le pipeline de combat.

Cette section est à retirer une fois ces points tranchés et le support moteur effectivement implémenté (cf. traitement final de la section Démon).