# Contrat d'API — Matchmaking classé & boucle de rétention

Destiné à une session de travail sur `wyrdane-backend` (dépôt séparé, inaccessible
depuis la session `card-game` qui a écrit ce document). Le client (`card-game`)
est déjà écrit contre ce contrat — rien à changer côté client une fois ces
routes en place côté backend, sauf ajustement si un détail s'avère impossible
tel quel.

Contexte : le suivi MMR existe déjà (`rating` par joueur, mis à jour via
double-report de chaque match réseau — voir `BackendClient.report_ranked_match`
et `POST /api/ranked/matches/report`, déjà en prod). Ce document couvre ce qui
**manque encore** : l'appariement par compétence (aujourd'hui, « Partie rapide »
prend le premier lobby disponible, sans notion de MMR) et la boucle de
rétention (quêtes quotidiennes, récompense de connexion).

Auth : toutes les routes ci-dessous supposent le cookie de session existant
(`POST /api/auth/steam`), comme le reste de l'API.

---

## 1. File d'attente de matchmaking classé

### Architecture

Le multijoueur reste un relais de commandes P2P (Steam), **pas** un serveur de
jeu autoritaire — le backend n'a donc besoin de connaître que les deux joueurs
à apparier, pas l'état de la partie. Une fois deux tickets appariés :

1. Le backend tire un **hôte** au hasard entre les deux et le communique aux
   deux clients via `role`, en même temps que `opponent_steam_id` — le
   SteamID64 de l'adversaire, lu dans `linked_accounts`.
2. Le client hôte ouvre un socket d'écoute P2P (`SteamTransport.host`,
   `createListenSocketP2P`) et n'accepte que cette identité précise.
3. Le client invité s'y connecte directement (`SteamTransport.join`,
   `connectP2P` sur ce SteamID64), en réessayant quelques secondes le temps que
   l'hôte ait vu son propre appariement.
4. La partie se déroule normalement ; à la fin, `POST /api/ranked/matches/report`
   (déjà existant) crédite le MMR. **Mise à jour (2026-09-24)** : le payload
   porte désormais un champ `mode: "ranked" | "normal"` (omis = `"ranked"`,
   compatibilité avec un client pas encore à jour) — voir `match_reports.mode`/
   `ranked_stats.hidden_mmr` côté backend. Une partie Normal ne fait plus
   jamais gagner/perdre de points de classement public (`mmr`/`wins`/`losses`
   inchangés) ; elle met à jour un MMR **caché** séparé (`hidden_mmr`, jamais
   exposé au client, même au joueur concerné) utilisé uniquement pour apparier
   des parties Normal entre joueurs de niveau similaire, façon MMR caché League
   of Legends — voir `POST /api/matchmaking/queue` ci-dessous, qui porte
   désormais lui aussi `mode` pour apparier séparément Classé (MMR public) et
   Normal (MMR caché), jamais l'un avec l'autre.

> **Réécrit le 2026-09-28.** Les étapes 2 et 3 passaient auparavant par un
> lobby Steam : l'hôte en créait un et publiait son `steam_lobby_id` via
> `POST /queue/:id/report-lobby`, que l'invité découvrait à son poll suivant.
> Ce détour n'apportait qu'un annuaire — `ConnectP2P` n'exige ni amitié ni
> lobby commun (doc Steamworks `ISteamNetworkingSockets`) — au prix d'un
> aller-retour HTTP de plus et de toute une classe d'échecs : fermer un
> transport quitte son lobby, et un lobby quitté par son dernier membre est
> détruit, donc la moindre relance rendait injoignable le lobby que le pair
> était en train de rejoindre (« entrée refusée, code 2 »). Le lobby Steam ne
> sert plus qu'aux invitations d'ami, où il rend possible le « Rejoindre la
> partie » natif de l'overlay Steam.

### `POST /api/matchmaking/queue`

Rejoint la file d'attente. Son MMR est lu depuis `ranked_stats.mmr`/`hidden_mmr`
selon `mode`, pas envoyé par le client — ne jamais faire confiance à un MMR
fourni par le client.

Body **(mis à jour 2026-09-24)** :
```json
{ "mode": "ranked" }
```
`mode: "ranked" | "normal"` (omis = `"ranked"`). Deux tickets ne sont jamais
appariés entre modes différents (`matchmaking_tickets.mode`).

Réponse `200` :
```json
{ "ticket_id": "uuid" }
```

Comportement serveur attendu :
- Un joueur ne peut avoir qu'un ticket actif à la fois (un second appel
  remplace ou rejette le premier — au choix, mais pas les deux tickets actifs
  en même temps).
- Fenêtre d'appariement élargie progressivement pour éviter des temps
  d'attente indéfinis avec peu de joueurs simultanés : ±100 MMR au départ,
  +50 toutes les 15s, jusqu'à un plafond raisonnable (ex. ±500) au-delà
  duquel on apparie sans plus attendre.
- **Choix parmi les candidats éligibles (ajout 2026-09-25)** : la fenêtre dit
  seulement qui est *acceptable*, pas qui est *le meilleur*. Parmi les tickets
  dans la fenêtre, retenir celui qui minimise
  `|Δmmr| − BONUS × attente_du_candidat` (implémenté côté `wyrdane-backend` avec
  BONUS = 5 points de MMR par seconde, plafonné à 300) : le MMR le plus proche
  gagne normalement, mais un ticket qui patiente depuis longtemps finit toujours
  par passer devant, sans qu'on ait à élargir la fenêtre. Sans cette règle, le
  serveur retenait le premier candidat dans l'ordre d'arrivée — donc le plus
  ancien, jamais le plus proche en MMR. La fenêtre reste une contrainte dure : un
  adversaire hors fenêtre n'est jamais rattrapé par son ancienneté.
- Un ticket sans appariement après un délai serveur (ex. 5 min) passe en
  `expired` : le client abandonne de son côté après 3 min (`RANKED_QUEUE_TIMEOUT`
  dans `MatchmakingOverlay.gd`), donc la valeur exacte côté serveur importe peu tant
  qu'elle n'est pas plus courte que ça.

### `GET /api/matchmaking/queue/:ticket_id`

Interroge l'état d'un ticket (poll côté client, toutes les 2s — voir
`MatchmakingOverlay._poll_ranked_queue`).

Réponse `200`, avant appariement :
```json
{ "status": "waiting" }
```

Réponse `200`, une fois apparié (identique pour les deux camps, au `role` près) :
```json
{
  "status": "matched",
  "role": "host",
  "opponent_id": 42,
  "opponent_steam_id": "76561198012345678",
  "match_id": "…",
  "match_session_token": "…"
}
```

`opponent_steam_id` est **l'adresse de rendez-vous** : l'hôte n'accepte que
cette identité sur son socket d'écoute, l'invité s'y connecte. Comme tout
identifiant Steam 64 bits, il voyage en **chaîne de chiffres — jamais en nombre
JSON** : 57 bits significatifs ne tiennent pas dans un double (53 bits de
mantisse), et un id arrondi ne désigne pas « rien », il désigne quelqu'un
d'autre. Il est lu depuis `linked_accounts.external_id` (déjà un `VARCHAR`,
donc jamais arrondi par le driver) et relu côté client par
`SteamTransport._parse_steam_id`. Le champ est **absent** si le compte adverse
n'a pas de SteamID lié : le client rend alors l'appariement
(`POST /queue/:id/abandon`) plutôt que de tenter une connexion impossible.

`steam_lobby_id` peut encore apparaître dans cette réponse : le champ est
conservé pour les clients d'une version antérieure au 2026-09-28, qui
attendaient que l'hôte publie un lobby Steam. Le client actuel l'ignore et
n'appelle plus jamais `report-lobby`.

Réponse `200`, ticket introuvable/expiré/annulé :
```json
{ "status": "expired" }
```
ou `{ "status": "cancelled" }` — le client traite les deux de façon identique
(abandon silencieux, réactive les boutons).

### `POST /api/matchmaking/queue/:ticket_id/report-lobby`

> **Obsolète depuis le 2026-09-28** — plus aucun client ne l'appelle : la file
> ne passe plus par un lobby Steam (voir § Architecture). La route reste en
> place le temps que les builds antérieures disparaissent de la circulation.

Hôte uniquement, appelé juste après la création réussie du lobby Steam.

Body :
```json
{ "steamLobbyId": "109775241000123456" }
```

Réponse `200` (ou `204`), aucun contenu attendu par le client.

Validation attendue : vérifier que l'appelant est bien le `role: "host"` de ce
ticket (comparer au cookie de session), rejeter sinon. `steamLobbyId` doit être
une chaîne de chiffres (`/^[1-9][0-9]{0,19}$/`) : refuser un nombre par un `400`
plutôt que d'enregistrer un id déjà corrompu par l'arrondi (voir ci-dessus).

### `POST /api/matchmaking/queue/:ticket_id/abandon`

Appelé par l'un OU l'autre des deux joueurs quand un appariement n'a pas pu se
concrétiser : adversaire jamais joignable en P2P côté invité (essais épuisés,
`SteamTransport.DIRECT_CONNECT_MAX_ATTEMPTS`), ou hôte qui n'a jamais vu arriver
son pair (`HOST_PEER_WAIT_TIMEOUT`).

Pas de body. Réponse `204`, y compris quand il n'y avait rien à abandonner
(ticket déjà relancé, inconnu, ou pas apparié) : le client n'a pas d'action
différente à mener dans ce cas, il se remet en file.

Effet attendu : remettre **les deux** tickets du match en `waiting`, en purgeant
`steam_lobby_id`, `opponent_id`, `role`, `match_id` et `match_session_token`, et
en réinitialisant `created_at`. Les deux tickets sont désignés par leur
`match_id` commun, ce qui rend l'appel idempotent et sans effet de bord sur un
adversaire qui aurait déjà relancé une recherche de son côté (son `match_id`
aurait changé).

**Le serveur ne doit pas en dépendre.** Cette route et le `joinQueue` qui suit
sont deux requêtes HTTP indépendantes : rien ne garantit leur ordre d'arrivée, et
si le `joinQueue` passe le premier, le ticket n'est plus `matched` et l'abandon
ne trouve plus rien à libérer. `joinQueue` doit donc, de lui-même, remettre en
file l'adversaire du ticket qu'il remplace quand celui-ci était apparié
(`releaseStaleMatch`). `/abandon` reste utile pour le cas où le joueur ne
relance PAS de recherche derrière (il quitte l'écran, ferme le jeu).

**Pourquoi cette route existe.** Sans elle, le joueur dont l'entrée échouait se
remettait en file tout seul, alors que son adversaire restait `matched` pendant
tout son délai d'attente (60 s côté client) — et un ticket `matched` n'est jamais
ré-apparié (l'appariement ne considère que les `waiting`). Les deux joueurs
étaient donc structurellement incapables de se retrouver, et le client
abandonnait bien avant (`MAX_AUTO_JOIN_RETRIES`). C'était l'une des deux causes
du symptôme « partie entre amis qui ne se lance jamais » ; l'autre était un
`steam_lobby_id` hérité du match précédent et jamais purgé à l'appariement (voir
§ Architecture).

### `DELETE /api/matchmaking/queue/:ticket_id`

Annule un ticket (bouton « Annuler la recherche », ou navigation hors de
l'écran lobby). Réponse `200`/`204`, idempotent (annuler un ticket déjà
consommé/expiré ne doit pas renvoyer d'erreur bloquante).

---

## 2. Quêtes quotidiennes

Pas encore de scaffolding client (à faire une fois ces routes disponibles :
nouvelle vue `InfoView.QUESTS` dans `MainMenu.gd`, même pattern que `PROFILE`).

Contrainte de conception : le client n'envoie **aucune télémétrie fine** par
action de jeu (pas de « carte X jouée » en temps réel) — seulement un résumé
en fin de match. Les objectifs de quête doivent donc être dérivables d'un
résumé de ce type, pas d'un flux d'événements détaillé.

### `POST /api/matches/summary`

Nouvel appel, envoyé par le client à la fin de **chaque** match (solo IA ou
réseau, classé ou non — un seul point d'entrée, à appeler juste à côté de
`report_ranked_match` dans `Battle._show_game_over`). Fait progresser les
quêtes actives côté serveur ; ne remplace pas `report_ranked_match` (MMR),
qui reste un appel séparé.

Body proposé :
```json
{
  "result": "victory",
  "race": "Undead",
  "cardsPlayed": 14,
  "damageDealt": 27,
  "mode": "ranked"
}
```
`mode` : `"ranked" | "quick_match" | "solo"`. À affiner selon les objectifs de
quête réellement conçus (ex. "gagne 2 parties en classé" a besoin de `mode`,
"joue 15 cartes Mort-Vivant" a besoin de `race`+`cardsPlayed`).

### `GET /api/quests/daily`

Réponse `200` :
```json
{
  "quests": [
    { "id": "q1", "description_key": "QUEST_WIN_2", "progress": 1, "target": 2, "reward_currency": 50, "claimed": false }
  ],
  "resets_at": "2026-08-18T00:00:00Z"
}
```
`description_key` : clé de traduction côté client (`translations/game.csv`),
pas de texte brut envoyé par le serveur — cohérent avec le reste de l'i18n du
projet (voir CLAUDE.md « Internationalisation »). Prévoir un jeu de clés fixe
côté client correspondant aux templates de quête possibles côté serveur.

### `POST /api/quests/:id/claim`

Réclame la récompense d'une quête complétée (`progress >= target`). Réponse
`200` avec le nouveau solde de monnaie molle (même format que
`CurrencyManager.sync_from_backend`), erreur `400` si pas encore complétée ou
déjà réclamée.

---

## 3. Récompense de connexion quotidienne

### `GET /api/login-reward/status`

Réponse `200` :
```json
{ "claimed_today": false, "streak_day": 3 }
```
`streak_day` : jour courant de la série (1 à 7, reset à 1 si un jour est
manqué — logique de calcul de la série entièrement côté serveur, le client
n'affiche qu'un calendrier statique de 7 paliers de récompense croissante).

### `POST /api/login-reward/claim`

Réponse `200` :
```json
{ "streak_day": 3, "reward_currency": 30 }
```
Erreur `400` si déjà réclamée aujourd'hui (`claimed_today` déjà vrai).

---

## Hors scope de ce document

- Saisons ranked (reset de MMR, récompenses de fin de saison) — pas de contrat
  précis pour l'instant, à concevoir séparément une fois la file d'attente en
  place et utilisée.
- Piste de progression saisonnière (« battle pass » gratuit) — dépend des
  saisons ci-dessus.
- Tout ce qui impliquerait de la monnaie dure/argent réel — hors scope,
  Wyrdane est F2P cosmétique uniquement (packs/monnaie molle exclusivement
  gagnés en jeu, jamais achetables).
