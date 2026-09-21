# Statistiques de cartes & classement — implémenté

Contrairement aux autres fichiers de `docs/backend-contracts/`, celui-ci
documente un chantier **déjà implémenté des deux côtés** (client `card-game`
ET serveur `wyrdane-backend`, branche `0065-card-stats-and-leaderboard`,
pas encore mergée dans `main` au moment de l'écriture) — conservé ici comme
référence plutôt que retiré, cohérent avec les autres contrats du dossier.

Objectif double : (1) donner des données d'équilibrage (taux de jeu et
winrate par carte) et (2) un classement des joueurs par MMR. Portée
volontairement réduite aux **matchs classés confirmés uniquement** — le solo
contre l'IA et les parties non confirmées (un seul rapport reçu) ne sont pas
représentatifs pour de l'équilibrage et gonfleraient le volume sans signal
utile.

**Mise à jour 2026-09-21** : les données de taux de jeu/winrate par carte
sont une donnée d'équilibrage interne, pas une information destinée aux
joueurs — retirées de l'écran en jeu (`StatsPanel.gd` ne montre plus que le
classement, voir section 4) et déplacées vers un dashboard admin sur
`wyrdane-website` (`/admin/card-stats`, protégé par `requireAdmin` — voir
`GET /api/admin/card-stats` ci-dessous, section 2). Le classement, lui, reste
en jeu (donnée intéressante pour un joueur, pas sensible pour l'équilibrage).

---

## 1. Extension du report de match classé existant

`POST /api/ranked/matches/report` accepte désormais un champ optionnel
`cardsPlayed` (array de string, noms FR exacts des cartes) en plus du body
existant :

```json
{
  "clientMatchId": "…",
  "opponentId": 123,
  "winnerId": 123,
  "cardsPlayedByRace": { "Mort-Vivant": 4 },
  "deckRaces": ["Mort-Vivant"],
  "cardsPlayed": ["Zombie affamé", "Zombie affamé", "Roi Zombie"],
  "matchSessionToken": "…"
}
```

`cardsPlayed` : une entrée par carte posée par **ce** client pendant le
match (doublons inclus si jouée plusieurs fois). Vide pour une Partie
rapide/Contre un ami comme pour le solo (pas de restriction particulière,
juste un tableau vide envoyé). Borné côté serveur par `sanitizeCardsPlayed`
(`backend/src/helper/matchPayload.ts`, 200 entrées max, 100 caractères max
par nom) avant stockage sur `match_reports.cards_played` (colonne JSON, voir
`schema.sql`).

### Traitement serveur

Une fois les deux rapports d'un match concordants (même court-circuit
`findMatchHistory` que le reste de `reportMatch`, donc jamais rejoué deux
fois pour un même match), `rankedModel.recordCardPlays` insère une ligne par
carte unique dans `card_play_stats` (`INSERT IGNORE`, table dédiée — voir
`schema.sql`) :

```sql
CREATE TABLE card_play_stats (
  id INT AUTO_INCREMENT PRIMARY KEY,
  card_name VARCHAR(150) NOT NULL,
  client_match_id VARCHAR(100) NOT NULL,
  user_id INT NOT NULL,
  won BOOLEAN NOT NULL,
  season INT NOT NULL,
  played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY unique_card_match_user (card_name, client_match_id, user_id),
  ...
);
```

Clé unique `(card_name, client_match_id, user_id)` — pas seulement
`(card_name, match_id)` — pour que, dans le cas rare où les deux joueurs
jouent la même carte dans le même match, chacun contribue sa propre issue
(victoire/défaite) au calcul du winrate plutôt que de s'écraser l'un
l'autre.

`rankedModel.getCardStats` agrège ensuite :
- **Taux de jeu** = `COUNT(DISTINCT client_match_id) / total_matchs_classés`
  (dénominateur = nombre de lignes dans `match_history` pour la saison).
- **Winrate** = `SUM(won) / COUNT(*)` (au niveau instance carte-jouée, pas
  match — si les deux joueurs jouent la même carte avec des issues
  différentes, les deux comptent).

Pas de seuil minimum de parties (contrairement à une première version qui
excluait toute carte sous 20 matchs) : réservé à l'admin (voir section 2),
qui peut juger lui-même de la significativité d'un winrate via
`matches_played`, y compris en tout début de saison.

---

## 2. `GET /api/admin/card-stats` (admin uniquement)

Retourne toutes les cartes jouées en classé, triées par nombre de parties
décroissant (`adminController.getAdminCardStats`) :

```json
{
  "total_ranked_matches": 4820,
  "cards": [
    { "card_name": "Zombie affamé", "play_rate": 0.62, "matches_played": 2988, "winrate": 0.54 },
    { "card_name": "Roi Zombie", "play_rate": 0.41, "matches_played": 1976, "winrate": 0.58 }
  ]
}
```

Mounté sous `/api/admin` (comme `/admin/stats`, `/admin/wishlist`), donc
`authorization` + `requireAdmin` + `requireCsrfHeader` (voir
`router/index.ts`) — inatteignable pour un joueur non-admin. Anciennement une
route joueur publique-authentifiée (`/api/ranked/stats/cards/top`, avec le
seuil de 20 matchs) : déplacée ici le 2026-09-21, la donnée étant destinée à
l'équilibrage plutôt qu'à l'affichage joueur.

### Côté client
Consommé uniquement par `wyrdane-website` (`src/pages/AdminCardStats.tsx`,
route `/admin/card-stats`, même garde `AdminRequire` que `/admin`) — plus
aucun appel côté jeu.

---

## 3. Classement — route déjà existante, pas de changement serveur

`GET /api/ranked/leaderboard?limit=&offset=` existait déjà avant ce chantier
(`rankedController.getLeaderboardHandler`/`rankedModel.getLeaderboard`) mais
n'était pas encore consommée côté jeu. Retourne un **tableau brut** (pas
d'enveloppe `{ players: [...] }`) :

```json
[
  { "user_id": 42, "mmr": 2140, "wins": 88, "losses": 40, "season": 1, "username": "Nécro_42" }
]
```

Pas de champ `rank` explicite — calculé côté client depuis la position dans
le tableau (`StatsPanel._populate_leaderboard`, `?limit=100` demandé).

### Côté client
`BackendClient.get_leaderboard(on_complete: Callable)` — `(success: bool,
players: Array)`, forme du tableau ci-dessus.

---

## 4. Écran en jeu

`scripts/mainMenu/StatsPanel.gd` (même pattern statique que
`QuestsPanel.gd`/`ProfilePanel.gd`) ajoute une `InfoView.STATS` (bouton «
Classement » dans `BottomCenterRow` de `MainMenu.tscn`) avec une seule
section : « Classement » (rang calculé + nom + MMR, le joueur local mis en
surbrillance dorée s'il apparaît dans le top 100 affiché, via
`SteamService.local_persona_name()`). Lecture seule, aucune action de
réclamation contrairement aux quêtes. Ne montre plus de statistiques de
cartes (voir section 1, mise à jour du 2026-09-21).

## 5. Navigation par palier, recherche et avatars (branche `0072-ranked-leaderboard-browse`)

Chantier suivant, sur `wyrdane-backend` (branche `0072-ranked-leaderboard-browse`,
**pas encore mergée dans `main`**) — étend `GET /api/ranked/leaderboard`
plutôt que de le remplacer :

- Réponse changée : enveloppe `{ total, players }` au lieu d'un tableau brut
  (`total` = nombre de joueurs classés correspondant au filtre). Chaque ligne
  de `players` porte désormais `rank` (calculé en SQL via `RANK() OVER (ORDER
  BY mmr DESC)`, donc toujours correct même filtré/paginé — plus besoin de le
  déduire de la position dans le tableau) et `steam_id` (`LEFT JOIN
  linked_accounts`, peut être `null`).
- Nouveaux paramètres optionnels `minMmr`/`maxMmr` : filtrent par palier —
  les paliers eux-mêmes restent une notion purement client (`RankTier.gd`,
  bornes 1000/1300/1600), le backend ne connaît que des bornes de MMR.
- `GET /api/ranked/leaderboard/me` : position du joueur authentifié (`rank`,
  `mmr`...), 404 si jamais classé.
- `GET /api/ranked/leaderboard/around-me?limit=&minMmr=&maxMmr=` : page déjà
  centrée sur le joueur authentifié au sein d'un palier — le serveur calcule
  l'offset (compte des lignes du palier avec un MMR strictement supérieur au
  sien) plutôt que de le faire déduire côté client. 404 si jamais classé.
- `GET /api/ranked/leaderboard/search?q=` : recherche par pseudo
  (sous-chaîne, insensible à la casse, 20 résultats max), pour que la barre
  de recherche du client retrouve le rang exact d'un joueur.

### Côté client
`scripts/mainMenu/StatsPanel.gd` (panneau « Classement ») : 4 onglets de
palier (Bronze/Argent/Or/Légende), ouverture sur
le palier du joueur local centré sur sa position, recherche par pseudo,
défilement infini vers le bas (pas de rechargement vers le haut au-delà de la
page initiale — limitation assumée). `BackendClient.get_leaderboard`/
`get_my_leaderboard_position`/`get_leaderboard_around_me`/`search_leaderboard`
(`scripts/net/BackendClient.gd`). Avatars via `SteamService.request_avatar_async`
(`scripts/net/SteamService.gd`) : best-effort, Steam ne garantit l'avatar en
cache que pour des joueurs déjà croisés (amis, parties communes...) — beaucoup
de lignes resteront sans avatar, c'est attendu.

## 6. Reste à faire

- Mergé côté client dans ce worktree ; côté backend, la branche
  `0065-card-stats-and-leaderboard` doit être review/mergée dans `main` puis
  déployée (voir CLAUDE.md `wyrdane-backend` pour le déploiement continu) et
  la synchro de schéma (`npm run db:sync`) appliquée en prod pour créer
  `card_play_stats` et la colonne `match_reports.cards_played` — même
  procédure que les chantiers précédents (quêtes hebdo, matchmaking classé).
- Pas de pagination sur `/admin/card-stats` (320 cartes max, acceptable) ni
  granularité par saison passée (toujours `CURRENT_SEASON`) — à revoir si le
  jeu introduit un reset de saison ranked avant que ça devienne un problème.
