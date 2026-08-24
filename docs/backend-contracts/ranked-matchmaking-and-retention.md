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

1. Le backend désigne un **hôte** de façon déterministe (ex. le plus petit
   `user_id` des deux) et le communique aux deux clients via `role`.
2. Le client hôte crée un lobby Steam (code déjà existant, `SteamTransport.host`)
   et rapporte son `steam_lobby_id` via `POST /queue/:id/report-lobby`.
3. Le client invité reçoit ce `steam_lobby_id` au prochain `GET /queue/:id` et
   rejoint directement ce lobby (`SteamTransport.join({"lobby_id": ...})`),
   sans passer par la recherche de lobby publique.
4. La partie se déroule normalement ; à la fin, `POST /api/ranked/matches/report`
   (déjà existant) crédite le MMR comme n'importe quel match réseau — **aucun
   changement requis sur ce point**, une victoire en classé n'est distinguée
   d'une victoire en partie rapide par aucun champ actuellement. Si vous voulez
   les distinguer dans les stats plus tard (ex. exclure la partie rapide du
   MMR), c'est un changement séparé, pas couvert ici.

### `POST /api/matchmaking/queue`

Rejoint la file d'attente. Body vide (le joueur est identifié par le cookie de
session ; son MMR est lu depuis `rating`, pas envoyé par le client — ne jamais
faire confiance à un MMR fourni par le client).

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
- Un ticket sans appariement après un délai serveur (ex. 5 min) passe en
  `expired` : le client abandonne de son côté après 3 min (`RANKED_QUEUE_TIMEOUT`
  dans `NetLobby.gd`), donc la valeur exacte côté serveur importe peu tant
  qu'elle n'est pas plus courte que ça.

### `GET /api/matchmaking/queue/:ticket_id`

Interroge l'état d'un ticket (poll côté client, toutes les 2s — voir
`NetLobby._poll_ranked_queue`).

Réponse `200`, avant appariement :
```json
{ "status": "waiting" }
```

Réponse `200`, une fois apparié (encore sans lobby, ou pour l'hôte) :
```json
{ "status": "matched", "role": "host", "opponent_id": 42 }
```

Réponse `200`, invité une fois l'hôte ayant rapporté son lobby :
```json
{ "status": "matched", "role": "guest", "opponent_id": 17, "steam_lobby_id": 109775241000123456 }
```

`steam_lobby_id` est un entier 64 bits (SteamID de lobby) — le stocker/renvoyer
en `int`/`bigint` selon votre ORM, pas en `string`, pour rester cohérent avec ce
que `BackendClient.queue_status` attend côté client (`int(data.get("steam_lobby_id", 0))`).
Absent ou `0` tant que l'hôte n'a pas encore appelé `report-lobby` — le client
invité continue de repoller dans ce cas (`_on_ranked_matched`, branche invité).

Réponse `200`, ticket introuvable/expiré/annulé :
```json
{ "status": "expired" }
```
ou `{ "status": "cancelled" }` — le client traite les deux de façon identique
(abandon silencieux, réactive les boutons).

### `POST /api/matchmaking/queue/:ticket_id/report-lobby`

Hôte uniquement, appelé juste après la création réussie du lobby Steam.

Body :
```json
{ "steamLobbyId": 109775241000123456 }
```

Réponse `200` (ou `204`), aucun contenu attendu par le client.

Validation attendue : vérifier que l'appelant est bien le `role: "host"` de ce
ticket (comparer au cookie de session), rejeter sinon.

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
