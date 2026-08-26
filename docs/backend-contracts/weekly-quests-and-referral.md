# Contrat d'API — Quêtes hebdomadaires & parrainage

Destiné à une session de travail sur `wyrdane-backend` (dépôt séparé,
inaccessible depuis la session `card-game` qui a écrit ce document). Le
client (`card-game`) contient déjà un squelette écrit contre ce contrat
(voir « Côté client » à la fin de chaque section) — échoue proprement tant
que les routes ci-dessous n'existent pas côté serveur (mêmes garde-fous que
`docs/backend-contracts/ranked-matchmaking-and-retention.md` pour le
matchmaking classé en son temps).

Contexte : les quêtes quotidiennes existent déjà en prod (`QUEST_TEMPLATES`,
`POST /api/matches/summary`, `GET /api/quests/daily`, `POST /api/quests/:id/claim`
— voir CLAUDE.md « Boucle de rétention »). Ce document couvre deux ajouts :

1. Des **quêtes hebdomadaires**, mêmes mécanismes que les quotidiennes mais
   objectifs plus longs et récompense en **pack à ouvrir** plutôt qu'en or.
2. Un **système de parrainage** à usage unique par joueur (un joueur ne peut
   parrainer qu'un seul ami, pour limiter la création de faux comptes) :
   3 packs + 500 or au parrain quand le filleul termine le tutoriel.

Auth : toutes les routes ci-dessous supposent le cookie de session existant
(`POST /api/auth/steam`), comme le reste de l'API.

---

## 1. Quêtes hebdomadaires

### Réutilisation de la télémétrie existante

Aucune nouvelle donnée envoyée par le client : `POST /api/matches/summary`
(déjà appelé à la fin de chaque match, voir le contrat ranked/rétention pour
son body) alimente à la fois les compteurs quotidiens et hebdomadaires côté
serveur — juste une fenêtre de reset différente (voir plus bas) et des
templates différents. Exemples de templates hebdo visés par cette demande :

- « Gagne 10 parties contre des joueurs » → nécessite `mode: "ranked" |
  "quick_match"` dans le résumé de match (déjà présent) pour exclure le solo
  IA — objectif long, cohérent avec une reset hebdomadaire.
- « Joue 15 parties avec un deck Démon » → `race` + un compteur de matchs
  joués (pas seulement de cartes jouées) avec ce deck. Si le résumé actuel ne
  distingue pas encore « race du deck utilisé » de « race des cartes jouées
  dans le match », ajouter un champ `deckRace` au body de `/api/matches/summary`
  (le client connaît déjà la race du deck actif, voir `deck_races` déjà
  envoyé à `report_ranked_match`).
- Autres templates hebdo possibles avec les données déjà dispo : « Gagne 5
  parties classées », « Joue 30 parties toutes races confondues ».

### `GET /api/quests/weekly`

Même forme que `GET /api/quests/daily`, avec un champ de récompense en packs
plutôt qu'en or :
```json
{
  "quests": [
    { "id": "w1", "description_key": "QUEST_WEEKLY_WIN_NETWORK_10", "progress": 3, "target": 10, "reward_pack": 1, "claimed": false }
  ],
  "resets_at": "2026-09-01T00:00:00Z"
}
```
`reward_pack` : nombre de packs crédités (pas d'or, contrairement aux quêtes
quotidiennes — garder les deux systèmes de récompense distincts et
composables : un template hebdo pourrait un jour donner les deux, donc les
champs `reward_currency`/`reward_pack` peuvent coexister dans un même objet
quête si besoin plus tard, mais pas nécessaire pour ce lot).

`description_key` : même logique que les quêtes quotidiennes, prévoir un jeu
de clés dédié (`QUEST_WEEKLY_*`) pour ne pas mélanger les pools de templates
quotidien/hebdo côté client (le client a déjà réservé `QUEST_WEEKLY_WIN_NETWORK_10`
et `QUEST_WEEKLY_PLAY_RACE_15` comme exemples dans ses traductions).

### `POST /api/quests/weekly/:id/claim`

Réclame la récompense d'une quête hebdo complétée. Contrairement à
`/api/quests/:id/claim` (qui renvoie un solde d'or), crédite le **solde de
packs à ouvrir** (`free_packs`, voir section 3) plutôt que l'or :
```json
{ "free_packs": 2, "reward_pack": 1 }
```
`free_packs` : nouveau solde total après crédit. Erreur `400` si pas encore
complétée ou déjà réclamée (même sémantique que la route quotidienne).

### Côté client

`BackendClient.get_weekly_quests`/`claim_weekly_quest` déjà écrits (mêmes
callbacks `(success, data)` que les méthodes quotidiennes existantes).
`QuestsPanel.gd` affiche une section « Hebdomadaire » sous les quêtes
quotidiennes dans la même vue (`InfoView.QUESTS`), avec un bouton Réclamer qui
appelle `claim_weekly_quest` puis `CurrencyManager.sync_from_backend()` (pour
rafraîchir `free_packs`) — pas d'ouverture de pack automatique, le joueur
ouvre son pack depuis la boutique (`PackShop`, bouton dédié packs gratuits,
voir section 3).

---

## 2. Solde de packs gratuits (`free_packs`)

Nouveau compteur par joueur, alimenté par les quêtes hebdo (section 1) et le
parrainage (section 3) — deux sources de packs gratuits, un seul solde.

### Extension de `GET /api/currency/balance`

Ajouter `free_packs` à la réponse existante :
```json
{ "balance": 1250, "free_packs": 2 }
```
Le client lit déjà `balance` (`CurrencyManager.sync_from_backend`) ; ajouter
la lecture de `free_packs` est un ajout non cassant.

### `POST /api/packs/open-owned`

Ouvre un pack en consommant le solde `free_packs` (pas l'or, contrairement à
`POST /api/packs/open` existant). Réponse `200` :
```json
{ "cards": [ { "id": 42, "rarity": "Rare", ... } ], "free_packs": 1 }
```
Erreur `400` si `free_packs <= 0`. Les probabilités de tirage par rareté sont
les **mêmes** que `POST /api/packs/open` (pas de pack « gratuit » au rabais) —
seule la source de débit change.

Ne pas confondre avec `POST /api/packs/open-free`, la route de dev existante
(`DEV_FREE_PACKS`, sans débit du tout, réservée aux tests internes) : celle-ci
reste inchangée et hors scope.

### Côté client

`CurrencyManager.free_packs: int` (nouveau champ, mis à jour par
`sync_from_backend` et par `open_owned_pack`, avec un signal
`free_packs_changed` — même pattern que `balance`/`balance_changed`).
`CurrencyManager.open_owned_pack(on_complete)` déjà écrit, wrapper direct sur
`POST /api/packs/open-owned`. `PackShop.gd` doit gagner un bouton « Ouvrir un
pack gratuit (x`free_packs`) », visible seulement si `free_packs > 0` — **pas
encore câblé côté client dans ce lot** (nécessite une édition de la scène
`PackShop.tscn`, laissée à une session dédiée UI ; le solde est déjà visible
en attendant via le badge Quêtes et la vue Profil/Parrainage).

---

## 3. Parrainage (un ami maximum par joueur)

### Modèle de données proposé

Table `referrals` :
- `referrer_id` (FK user, **UNIQUE**) — un joueur ne peut être `referrer_id`
  que d'une seule ligne : applique la règle « un seul ami parrainable »
  directement en contrainte DB plutôt qu'en logique applicative.
- `referred_id` (FK user, **UNIQUE**, nullable jusqu'à redemption) — un
  compte ne peut être parrainé qu'une seule fois, par n'importe qui (contrainte
  symétrique, empêche un joueur de se faire "reparrainer" pour désynchroniser
  l'anti-abus).
- `code` (string, unique, généré à la création de la ligne — voir ci-dessous).
- `redeemed_at` (timestamp nullable) — posé quand le filleul entre le code.
- `completed_at` (timestamp nullable) — posé quand le filleul termine le
  tutoriel (voir `POST /api/collection/claim-starter` existant).
- `reward_granted_at` (timestamp nullable) — posé une fois l'or/les packs
  crédités au parrain, pour idempotence (ne jamais créditer deux fois).

Un code est généré **lazily** au premier `GET /api/referral/code` d'un joueur
(pas à la création du compte) : `referrer_id` posé, `referred_id`/`code`
uniquement remplis à ce moment (`code` = ex. 8 caractères alphanumériques,
non ambigus visuellement — éviter `0/O/1/I`).

### `GET /api/referral/code`

Réponse `200` :
```json
{ "code": "K7M2XQPA" }
```
Crée la ligne `referrals` pour ce joueur si elle n'existe pas encore
(`referrer_id` = joueur courant), renvoie le `code` existant sinon (idempotent).

### `GET /api/referral/status`

Réponse `200` :
```json
{
  "code": "K7M2XQPA",
  "referred_username": null,
  "status": "none",
  "reward_granted": false
}
```
`status` : `"none"` (personne parrainé pour l'instant) | `"pending"` (filleul
a entré le code, tutoriel pas encore terminé) | `"completed"` (récompense
créditée). `referred_username` : pseudo Steam du filleul une fois `status !=
"none"` (pour affichage « X a rejoint grâce à toi », sans exposer d'ID brut).

### `POST /api/referral/redeem`

Appelé par le **filleul** (le nouveau joueur), body :
```json
{ "code": "K7M2XQPA" }
```
Réponse `200` : `{ "success": true }`. Erreurs `400` avec un `error` typé pour
affichage traduit côté client :
- `REFERRAL_INVALID_CODE` — code inconnu.
- `REFERRAL_SELF` — le joueur essaie d'utiliser son propre code.
- `REFERRAL_ALREADY_REFERRED` — ce compte a déjà un `referred_id` posé
  ailleurs (par ce code ou un autre) : un compte n'est jamais parrainé deux fois.
- `REFERRAL_CODE_USED` — ce code a déjà un `referred_id` (le parrain a déjà
  utilisé son unique parrainage).

Effet serveur : pose `referred_id`/`redeemed_at` sur la ligne du parrain. Si
le filleul a **déjà** `tutorial_completed_at` posé au moment du redeem (cas
rare : code entré après coup, tutoriel déjà fini) — poser aussi `completed_at`
immédiatement et déclencher le crédit (voir plus bas), plutôt que d'attendre
un `claim-starter` qui ne sera jamais rappelé.

### Déclenchement de la récompense (aucune nouvelle route)

Réutilise `POST /api/collection/claim-starter` (déjà appelé une fois par
`TutorialManager.notify_victory()` à la fin du tutoriel du filleul) : à cet
appel, si le joueur courant a une ligne `referrals` où il est `referred_id`
avec `completed_at IS NULL`, poser `completed_at = now()`, puis créditer
`referrer_id` de **3 `free_packs`** et **500 or**, et poser
`reward_granted_at`. Le crédit va au **parrain**, pas au filleul (le filleul
reçoit déjà les 4 decks de départ via `claim-starter`, pas de bonus
supplémentaire prévu dans cette demande).

Idempotence : si `claim-starter` est rappelé (retry réseau) et
`reward_granted_at` déjà posé, ne rien recréditer.

### Lien de parrainage (site web)

Le lien partagé par le joueur pointe vers le site compagnon
(`wyrdane.com`), pas directement vers un store — Steam ne propage aucun
paramètre d'URL jusqu'au client du jeu à l'installation, donc le filleul doit
**entrer le code manuellement en jeu** après installation (voir « Côté
client » ci-dessous), le lien sert surtout à préremplir/afficher le code sur
une page d'accueil du site (`wyrdane.com/invite/K7M2XQPA` par ex., à créer
côté `wyrdane-website`, hors scope de ce document — mais UTM/query param à
prévoir si vous voulez un jour mesurer le taux de clic avant installation,
indépendamment du redeem en jeu qui reste la seule source de vérité pour la
récompense).

### Côté client

`BackendClient.get_referral_code`/`get_referral_status`/`redeem_referral_code`
déjà écrits. Nouveau `ReferralPanel.gd` (même pattern statique que
`QuestsPanel.gd`/`ProfilePanel.gd`), ajouté dynamiquement à la vue Profil
(`InfoView.PROFILE`, pas de nouvel écran/bouton de nav pour rester dans le
scope « pas d'édition de scène risquée ») :
- Code du joueur + bouton « Copier le lien » (`https://wyrdane.com/invite/<code>`
  dans le presse-papier via `DisplayServer.clipboard_set`).
- Statut du parrainage en cours (aucun / en attente / complété) si `status != "none"`.
- Un champ de saisie « Entrer un code de parrainage » **visible uniquement si
  `status == "none"` côté filleul potentiel** (impossible de distinguer
  proprement « ce joueur n'a jamais rien parrainé » de « ce joueur peut encore
  être parrainé » avec les seules données de `/referral/status` qui décrit son
  rôle de *parrain* — le champ reste affiché à tout joueur sans référence
  claire d'avoir déjà été parrainé lui-même ; un joueur qui a terminé son
  tutoriel depuis longtemps peut toujours le remplir, il échouera juste côté
  serveur avec `REFERRAL_ALREADY_REFERRED` si son compte a déjà un
  `referred_id`, ce qui est le comportement correct même si redondant à
  afficher). Amélioration possible plus tard : montrer ce champ uniquement
  pendant le tutoriel/premier lancement plutôt que dans le menu principal, pas
  fait dans ce lot pour éviter de toucher `TutorialManager`.

---

## Hors scope de ce document

- Bouton « Ouvrir un pack gratuit » dans `PackShop.tscn` — nécessite une
  édition de scène, le solde `free_packs` est prêt côté client/serveur mais
  pas encore exposé dans la boutique.
- Page `wyrdane.com/invite/:code` côté site — juste un lien généré côté
  client pour l'instant, la page de destination est un travail séparé sur
  `wyrdane-website`.
- Placement du champ « entrer un code » dans le flow de premier lancement/
  tutoriel plutôt que dans le menu — voir note ci-dessus.
- Templates de quêtes hebdo au-delà des deux exemples donnés — à finaliser
  ensemble une fois ce contrat en place, `QUEST_WEEKLY_*` n'est qu'une
  proposition de convention de nommage, pas une liste figée.
