# Économie de Wyrdane — référence complète

Toutes les sources de gain, tous les coûts, et le temps nécessaire pour compléter la collection. Dernière vérification contre le code : **2026-09-29**.

Chaque valeur de ce document existe à **un seul endroit** dans le code, indiqué en regard. Ce fichier est une vue d'ensemble, jamais une seconde source de vérité : en cas de doute, le code gagne. La plupart des constantes vivent dans `wyrdane-backend` (`backend/src/model/`), la progression étant autoritaire côté serveur.

> **Pourquoi ce document existe.** Les barèmes sont éparpillés sur six modèles backend, et ce projet a déjà connu trois cas de documentation périmée passée inaperçue : les seuils de palier ranked divergents entre client et backend, le nombre de quêtes quotidiennes (2 annoncé contre 3 réels), et les textes de parrainage en dur dans `game.csv`. Une vue d'ensemble rend ces écarts visibles.

---

## 1. Les deux monnaies

| Monnaie | Stockage | Gagnée par | Dépensée pour |
|---|---|---|---|
| **Or** (monnaie molle) | `users.soft_currency`, ledger `currency_ledger` | connexion, quêtes, niveaux, poussière | packs, achat de cartes à l'unité |
| **Packs en stock** | `users.free_packs` | quêtes, niveaux, parrainage, achat avec de l'or | ouverts un par un (`POST /api/packs/open-owned`) |

Le stock de packs ne distingue pas l'origine d'un pack une fois crédité : un pack acheté et un pack gagné sont le même compteur.

**Le solo ne rapporte rien** depuis le 2026-08-26 : ni or, ni XP. Il fait toutefois progresser les quêtes.

---

## 2. Démarrage d'un compte

| Source | Gain | Où |
|---|---|---|
| Création du compte | **250 or** | `currencyModel.STARTER_CURRENCY` |
| Quête cachée de première connexion Steam | **500 or** | `currencyModel.FIRST_LOGIN_REWARD` |
| Decks de départ (1ʳᵉ connexion, `claim-starter`) | 4 decks jouables + **61 cartes distinctes** en collection | `data/starterDecks.ts` |
| Fin de tutoriel | **20 cartes aléatoires** | `tutorialRewardModel` |

Les 4 decks de départ (Mort-Vivant, Humain, Démon, Abomination) comptent 55 à 59 cartes chacun, dont 15 cartes-ressource. Ils ne contiennent **que des serviteurs et quelques éphémères** : aucun Rituel, aucun Enchantement. C'est précisément ce que le lot de fin de tutoriel vient combler.

### Lot de fin de tutoriel

20 cartes tirées dans tout le catalogue hors cartes-ressource, avec une pondération **par rareté exacte** :

| Rareté | Probabilité |
|---|---|
| Commune | 40 % |
| Rare | 30 % |
| Épique | 20 % |
| Légendaire | 10 % |

Nettement plus généreux que la pondération d'un pack (voir §7) : c'est une récompense unique, pas une source récurrente. Le tirage choisit **la rareté** au poids puis la carte uniformément dans cette rareté — contrairement au tirage de pack, qui pondère chaque *carte* et fait donc dépendre les probabilités réelles du nombre de cartes existantes par rareté. Ici les 40/30/20/10 sont donc respectés à la lettre.

Un exemplaire au-delà de la limite de 4 copies est converti en or, comme dans un pack.

---

## 3. Connexion quotidienne

`loginRewardModel.REWARD_BY_DAY` — 1×/jour, réclamée via une popup au menu principal.

| Jour de série | 1 | 2 | 3 | 4 | 5 | 6 et au-delà |
|---|---|---|---|---|---|---|
| **Or** | 20 | 40 | 60 | 80 | 100 | **100** |

La série monte sur 5 jours puis **plafonne** : elle ne reboucle pas. Un jour manqué (dernière réclamation avant-hier ou plus tôt) remet directement au palier 1. Le compteur `streak_day` en base continue de compter la série réelle sans plafond, même quand la récompense plafonne.

Le client n'a **aucune copie** de ce barème : `GET /api/login-reward/status` renvoie les 5 prochains jours calculés côté serveur, la frise de la popup ne fait que les afficher.

**Rendement : 100 or par jour** en régime établi.

---

## 4. Quêtes quotidiennes

`questModel.QUEST_TEMPLATES` — **3 quêtes** par jour (`QUESTS_PER_DAY`), tirées parmi 13 par une rotation déterministe (`userId` + date, jamais de RNG stocké). Récompense en or uniquement.

Toutes les valeurs suivent une **échelle unique de 25/50/75/100**, calée sur la difficulté réelle.

| Quête | Or |
|---|---|
| Jouer 3 parties | 25 |
| Jouer 5 parties | 50 |
| Gagner 2 parties | 50 |
| Jouer 10 cartes d'une race donnée (×4, une par race) | 50 |
| Gagner 3 parties | 75 |
| Gagner 2 parties avec un deck d'une race donnée (×4) | 75 |
| Gagner 1 partie classée | 100 |

Moyenne **61,5 or** par quête. **Rendement : ~185 or par jour** si les 3 sont réclamées.

Les quêtes « Jouer 10 cartes [Race] » comptent toute carte de cette race jouée en partie (serviteur, sort, rituel, enchantement, ressource). Les quêtes « Gagner 2 parties avec un deck [Race] » exigent que le deck de la victoire contienne au moins une carte de cette race.

---

## 5. Quêtes hebdomadaires

`weeklyQuestModel.WEEKLY_QUEST_TEMPLATES` — **1 quête** par semaine, remise à zéro chaque lundi. Récompense en **packs uniquement**, jamais en or.

| Quête | Packs |
|---|---|
| Jouer 30 parties | 1 |
| Jouer 15 parties avec une race donnée (×4) | 1 |
| Gagner 10 parties réseau | 2 |
| Jouer 10 parties multi-races (deck ≥ 2 races) | 2 |

Moyenne **1,29 pack par semaine**.

---

## 6. Quêtes mensuelles

`monthlyQuestModel` — **3 quêtes** par mois : 2 tirées au sort, plus **1 fixe garantie chaque mois**. Récompense **double** (or *et* packs).

| Quête | Or | Packs | |
|---|---|---|---|
| **Se connecter 30 jours** | **1 000** | **4** | fixe, tous les mois |
| Gagner 50 parties réseau | 750 | 3 | rotation |
| Jouer 75 parties multi-races | 750 | 3 | rotation |
| Jouer 100 parties réseau | 500 | 2 | rotation |
| Jouer 60 cartes d'une race donnée (×4) | 500 | 2 | rotation |

La quête fixe est **la plus grosse récompense du mois**, et volontairement : elle ne dépend d'aucune partie jouée, seulement d'une connexion quotidienne (jeu ou site). Elle n'est jamais tirée au sort, elle occupe un troisième emplacement réservé.

Moyenne mensuelle si tout est réclamé : **~2 143 or + ~8,6 packs**, soit **~71 or/jour** amortis.

---

## 7. Niveau de compte (XP)

`levelModel` — l'XP ne vient **que des parties réseau** (classées ou non).

| Événement | XP |
|---|---|
| Victoire réseau | 50 |
| Défaite réseau | 15 |
| Partie solo | 0 |

Multiplicateur de série de victoires, appliqué au gain d'une victoire seulement (jamais à une défaite, et la série retombe à 0 sur toute défaite) :

| Série en cours | Multiplicateur | XP par victoire |
|---|---|---|
| 3 à 4 | ×1,25 | 63 |
| 5 à 6 | ×1,5 | 75 |
| 7 et plus | ×1,75 | 88 |

**XP pour passer du niveau N au suivant : `100 + 5 × N`** (105 au niveau 1, 110 au niveau 2, …). Croissance linéaire, calculée directement depuis le niveau — jamais dérivée du seuil précédent, donc pas de dérive d'arrondi.

### Récompense de chaque niveau

| Type de niveau | Récompense |
|---|---|
| Multiple de **25** | 1 pack + 200 or |
| Multiple de **5** (hors 25) | 1 carte + 100 or |
| Tous les autres | 25, 50, 75 puis 100 or selon la position dans la série de 4 |

La rareté de la carte suit un cycle de 20 niveaux : niveau ≡ 5 → Commune, ≡ 10 → Rare, ≡ 15 → Épique, ≡ 0 → Légendaire. Une carte déjà possédée en 4 exemplaires est convertie en or (barème de poussière), cumulé avec les 100 or du palier plutôt qu'à leur place.

### Cumul

| Niveau atteint | Or | Packs | Cartes | XP cumulée | ~Jours à 5 parties/jour |
|---|---|---|---|---|---|
| 25 | 1 825 | 1 | 4 | 3 900 | 24 |
| 50 | 3 675 | 2 | 8 | 11 025 | 68 |
| 100 | 7 375 | 4 | 16 | 34 650 | 213 |

L'octroi est **immédiat et automatique** au franchissement du niveau. La popup de récompenses de niveau ne fait que lister ce qui a déjà été crédité et permettre de marquer chaque ligne comme vue — aucun second crédit.

---

## 8. Quêtes de progression nouveaux joueurs

`onboardingQuestModel.ONBOARDING_QUEST_TEMPLATES` — 11 quêtes, une seule fois par compte. La piste entière **disparaît au-delà du niveau 25**, sauf les quêtes déjà validées non encore réclamées, qui restent réclamables indéfiniment.

| Quête | Or | Packs |
|---|---|---|
| Atteindre le niveau 5 | 100 | — |
| Atteindre le niveau 10 | 150 | — |
| Atteindre le niveau 15 | 200 | 1 |
| Atteindre le niveau 20 | 250 | 1 |
| Atteindre le niveau 25 | 300 | 2 |
| Acheter 1 pack | 50 | — |
| Acheter 5 packs | 200 | — |
| Acheter 10 packs | 400 | — |
| Gagner 5 parties | 150 | — |
| Gagner 1 partie classée | 100 | — |
| Jouer 1 partie réseau | 50 | — |

**Total : 1 950 or + 4 packs.**

Les paliers `buy_packs` comptent les packs **achetés avec de l'or** uniquement — à ne pas confondre avec la quête unique « Ouvrez 20 packs », qui compte aussi les packs gratuits.

Les paliers de niveau déjà dépassés sont **rétro-accordés** à la première ouverture du menu Quêtes : un joueur déjà niveau 12 reçoit d'emblée les paliers 5 et 10 comme acquis, au lieu de ne plus jamais pouvoir les valider.

---

## 9. Quêtes uniques (jalons de carrière)

`uniqueQuestModel.UNIQUE_QUEST_TEMPLATES` — 23 quêtes, une seule fois par compte, **jamais réinitialisées**. Le catalogue complet est renvoyé à chaque appel, avec la progression de chacune.

| Quête | Or | Packs |
|---|---|---|
| Première partie avec un deck contenant une race donnée (×4) | 150 | — |
| Première victoire avec un deck d'au moins 2 races | 200 | — |
| Une victoire avec chacune des 4 races | 400 | 1 |
| Jouer 50 parties | 400 | — |
| Jouer 100 parties | 600 | — |
| Jouer 150 parties | 700 | — |
| Jouer 200 parties | 850 | 1 |
| Jouer 250 parties | 1 000 | 1 |
| Gagner 10 parties | 100 | 1 |
| Gagner 25 parties | 200 | 2 |
| Gagner 100 parties | 900 | 1 |
| Gagner 10 parties classées | 400 | — |
| Gagner 50 parties classées | 900 | 3 |
| Atteindre le palier **Argent** | 100 | — |
| Atteindre le palier **Or** | 200 | 1 |
| Atteindre le palier **Platine** | 350 | 1 |
| Atteindre le palier **Diamant** | 500 | 1 |
| Atteindre le palier **Maître** | 700 | 2 |
| Atteindre le palier **Légende** | 900 | 5 |
| Ouvrir 20 packs | — | 5 |

**Total : 10 000 or + 25 packs.**

### Seuils de palier ranked

Les paliers sont dérivés du MMR brut. Ces seuils existent en **deux copies** — `RankTier.THRESHOLDS` côté client (affichage du badge) et `uniqueQuestModel.RANK_TIER_MMR_THRESHOLDS` côté backend (validation de la quête) — car le backend n'a aucune notion de palier.

| Palier | MMR requis |
|---|---|
| Bronze | 0 (départ) |
| Argent | 200 |
| Or | 400 |
| Platine | 600 |
| Diamant | 800 |
| Maître | 1 000 |
| Légende | 1 200 |

> ⚠️ **Ces deux copies ont déjà divergé.** Jusqu'au 2026-09-28, le backend exigeait 1 300 de MMR pour valider la quête « palier Or » alors que le client affichait déjà le badge Or à 400 — soit plus du triple. Un test backend fige désormais la correspondance : toute modification de `RankTier.THRESHOLDS` doit être répercutée côté backend, et le test échouera si on l'oublie.

### Recalage des récompenses

Cible et récompenses sont figées dans la ligne du joueur au moment de l'assignation. Comme cette piste n'est jamais réinitialisée (contrairement aux quotidiennes/hebdo/mensuelles, qui reprennent une ligne neuve à chaque période), tout rééquilibrage du catalogue ne toucherait que les comptes créés après. `reconcileWithTemplates` recale donc les lignes **non réclamées** à chaque lecture, sans émettre la moindre requête quand tout est déjà conforme. Une quête déjà réclamée n'est jamais réécrite. Le même correctif existe dans `onboardingQuestModel`, pour la même raison.

Un palier **ajouté après coup** hérite de la progression déjà acquise sur les autres paliers du même objectif (`play`/`win`/`win_ranked`/`open_packs`, tous des compteurs interchangeables), plafonnée à sa propre cible — sinon un joueur à 300 parties repartirait de zéro sur « jouez 250 parties ».

---

## 10. Parrainage

`referralModel` — un joueur ne peut parrainer qu'**un seul** ami (contrainte d'unicité en base, pas en logique applicative : impossible à contourner par une course entre requêtes).

| | |
|---|---|
| Récompense | **4 packs** (aucun or) |
| Créditée à | **au parrain**, jamais au filleul |
| Déclencheur | le filleul termine son tutoriel |

Un code entré *après* que le filleul a déjà fini son tutoriel crédite immédiatement, au lieu d'attendre un déclencheur qui ne viendra jamais.

> ⚠️ Les textes joueur `REFERRAL_STATUS_NONE` et `REFERRAL_FIRST_LAUNCH_DESC` (`translations/game.csv`) annoncent ce montant **en dur** : ils ne sont liés à aucune valeur du backend et redeviendront faux au prochain changement de `REFERRAL_REWARD_*`. Ils annonçaient « 3 packs + 500 or » jusqu'au 2026-09-28.

---

## 11. Dépenses

| Achat | Coût | Détail |
|---|---|---|
| Pack de cartes | **500 or** | 5 cartes ; 50 packs maximum par requête d'achat |
| Carte à l'unité — Commune | **100 or** | deck builder, max 4 exemplaires |
| Carte à l'unité — Rare | **150 or** | |
| Carte à l'unité — Épique | **200 or** | |
| Carte à l'unité — Légendaire | **250 or** | |

L'achat et l'ouverture sont **séparés** : la Boutique ne fait qu'acheter (crédite le stock), la vue Collection ouvre.

### Poussière

Un exemplaire tiré au-delà de la limite de **4 copies** est automatiquement converti en or plutôt qu'ajouté à la collection.

| Rareté | Or rendu | Prix d'achat | Ratio |
|---|---|---|---|
| Commune | 25 | 100 | 25 % |
| Rare | 50 | 150 | 33 % |
| Épique | 75 | 200 | 38 % |
| Légendaire | 100 | 250 | 40 % |

---

## 12. Tirage d'un pack

### Pondération par rareté

`packModel.RARITY_WEIGHTS` donne un poids **par carte**, pas par rareté. La probabilité réelle d'une rareté dépend donc du nombre de cartes qui la composent.

| Rareté | Poids par carte | Cartes au catalogue | Probabilité réelle par tirage |
|---|---|---|---|
| Commune | 58 | 66 | **50,05 %** |
| Rare | 25 | 101 | **33,02 %** |
| Épique | 12 | 90 | **14,12 %** |
| Légendaire | 5 | 43 | **2,81 %** |

Poids total : 7 648. Une **carte légendaire précise** ne représente donc que **0,065 %** d'un tirage.

Valeur d'un pack au prix catalogue : **674 or pour 500 or** dépensés. Un pack est donc rentable en valeur brute — mais aléatoire, ce qui change tout en fin de collection (§13).

### Protection anti-doublon

Le poids d'une carte dont le joueur possède **déjà au moins un exemplaire** est multiplié par :

```
1 − 0,9 × complétion
```

où `complétion` est la part du catalogue tirable dont il possède au moins un exemplaire.

| Collection du joueur | Poids d'une carte déjà possédée |
|---|---|
| 10 % | 91 % du poids normal |
| 50 % | 55 % |
| 90 % | 19 % |
| 100 % | 10 %, appliqué à **toutes** les cartes |

**La force suit le taux de complétion**, et c'est le point central : un débutant *a besoin* de doublons (4 exemplaires sont nécessaires pour jouer une carte à fond), alors qu'un joueur à 95 % n'attend plus qu'une quinzaine de cartes qui ne sortaient que dans 0,8 % des tirages. La protection épouse la frustration réelle au lieu de la contrarier.

**La propriété qui rend le mécanisme sûr** : à collection complète, toutes les cartes subissent la *même* réduction, donc les poids **relatifs** redeviennent exactement ceux du tableau ci-dessus. La protection s'efface d'elle-même au lieu de dégénérer, et le remplissage des exemplaires 2/3/4 se poursuit ensuite aux probabilités d'origine.

Deux garde-fous :
- une carte tirée plus tôt dans le **même pack** compte comme possédée pour les tirages suivants de ce pack — sinon un pack pourrait offrir deux fois la même carte neuve alors qu'il en reste d'autres à découvrir ;
- le poids d'une carte possédée ne tombe **jamais à zéro** : un doublon reste toujours possible, et le tirage fonctionne encore quand tout est possédé.

Appliqué aux deux chemins d'ouverture (pack acheté et pack en stock). **Pas** appliqué aux cartes de récompense de niveau ni au lot de fin de tutoriel, qui tirent encore uniformément dans leur rareté.

---

## 13. Combien de temps pour tout débloquer

### Le catalogue

**300 cartes collectionnables** (hors 4 cartes-ressource et 16 jetons, jamais obtenables).

| Rareté | Cartes | Coût pour 1 exemplaire de chaque |
|---|---|---|
| Commune | 66 | 6 600 or |
| Rare | 101 | 15 150 or |
| Épique | 90 | 18 000 or |
| Légendaire | 43 | 10 750 or |
| **Total** | **300** | **50 500 or** |

Pour 4 exemplaires de chaque carte : **202 000 or**.

### Revenus

**Récurrent, en régime établi :**

| Source | Or/jour | Packs/jour |
|---|---|---|
| Connexion quotidienne | 100 | — |
| 3 quêtes quotidiennes | 185 | — |
| Quêtes mensuelles (amorties) | 71 | 0,29 |
| Quête hebdomadaire (amortie) | — | 0,18 |
| **Total** | **~356 or** | **~0,5 pack** |

Plus les récompenses de niveau, dégressives avec le temps.

**Unique, une seule fois par compte :** 250 + 500 (démarrage) + 1 950 (onboarding) + 10 000 (quêtes uniques) = **12 700 or**, et 4 + 25 = **29 packs**, plus 4 packs si le joueur parraine un ami.

### Simulation

Monte-Carlo, 250 tirages, à raison de **5 parties réseau par jour et 50 % de victoires**, tous les barèmes lus dans le code, poussière et protection anti-doublon incluses.

| Stratégie | 1 exemplaire des 300 cartes | 4 exemplaires de chaque |
|---|---|---|
| **Acheter les cartes à l'unité** | **~60 jours** (2,0 mois) | **~330 jours** (10,9 mois) |
| **N'ouvrir que des packs** | ~154 jours (5,1 mois) | ~1 405 jours (46,2 mois) |
| *(packs, sans la protection anti-doublon)* | *~720 jours (23,7 mois)* | *~1 604 jours (52,8 mois)* |

Avancement en n'ouvrant que des packs : 44 % au jour 7, 74 % au jour 30, 91 % au jour 60, 97 % au jour 90.

### Trois enseignements

**Le rythme de jeu compte à peine.** À 2 parties/jour la collection à 1 exemplaire tombe en ~90 jours, à 5 en ~60, à 10 en ~55 (et respectivement 391 / 330 / 300 jours pour le playset). Les revenus sont dominés par la connexion quotidienne et les quêtes, pas par le nombre de matchs : un joueur qui se connecte sans beaucoup jouer avance presque aussi vite.

**Acheter à l'unité reste ~2,5× plus rapide que le pack** pour compléter la collection. C'est l'écart voulu entre une acquisition ciblée et un tirage au sort. Avant la protection anti-doublon, l'écart était d'un facteur **10** — un joueur qui mettait tout son or en packs se pénalisait lourdement sans aucun moyen de le savoir.

**Le playset (4 exemplaires) est l'objectif long**, environ 11 mois par achat direct. C'est lui, et non la collection à 1 exemplaire, qui définit la durée de vie réelle de la progression.

---

## 14. Où modifier quoi

| Ce que tu veux changer | Fichier | Constante |
|---|---|---|
| Connexion quotidienne | `wyrdane-backend` `model/loginRewardModel.ts` | `REWARD_BY_DAY` |
| Quêtes quotidiennes | `model/questModel.ts` | `QUEST_TEMPLATES`, `QUESTS_PER_DAY` |
| Quêtes hebdomadaires | `model/weeklyQuestModel.ts` | `WEEKLY_QUEST_TEMPLATES` |
| Quêtes mensuelles | `model/monthlyQuestModel.ts` | `MONTHLY_QUEST_TEMPLATES`, `LOGIN_STREAK_TEMPLATE` |
| Quêtes nouveaux joueurs | `model/onboardingQuestModel.ts` | `ONBOARDING_QUEST_TEMPLATES`, `ONBOARDING_LEVEL_CAP` |
| Quêtes uniques | `model/uniqueQuestModel.ts` | `UNIQUE_QUEST_TEMPLATES`, `RANK_TIER_REWARDS`, `PLAY_MILESTONES` |
| Seuils de palier ranked | `model/uniqueQuestModel.ts` **et** `card-game` `scripts/data/RankTier.gd` | `RANK_TIER_MMR_THRESHOLDS` / `THRESHOLDS` — **les deux** |
| XP et récompenses de niveau | `model/levelModel.ts` | `XP_WIN_NETWORK`, `XP_CURVE_*`, `GOLD_TIER_BY_LEVEL_MOD_5` |
| Parrainage | `model/referralModel.ts` **et** `translations/game.csv` | `REFERRAL_REWARD_GOLD/PACKS` — **les deux** |
| Prix et tirage des packs | `model/packModel.ts` | `PACK_COST`, `RARITY_WEIGHTS`, `MAX_DUPLICATE_WEIGHT_REDUCTION` |
| Prix des cartes, poussière | `model/collectionModel.ts` | `CARD_PRICE_BY_RARITY`, `DUST_VALUE_BY_RARITY`, `MAX_COPIES_PER_CARD` |
| Solde de départ | `model/currencyModel.ts` | `STARTER_CURRENCY`, `FIRST_LOGIN_REWARD` |
| Lot de fin de tutoriel | `model/tutorialRewardModel.ts` | `TUTORIAL_REWARD_CARDS`, `TUTORIAL_RARITY_WEIGHTS` |
| Decks de départ | `data/starterDecks.ts` | `STARTER_DECKS` |

**Après toute modification d'un catalogue de quêtes uniques ou nouveaux joueurs**, aucun script de migration n'est nécessaire : `reconcileWithTemplates` recale les comptes existants tout seul, à leur prochaine lecture.

**Après tout ajout de colonne** (une nouvelle piste de quêtes, par exemple), un `db:sync` est obligatoire en production — le déploiement continu ne le fait pas. C'est la cause des quatre dernières pannes de mise en production.
