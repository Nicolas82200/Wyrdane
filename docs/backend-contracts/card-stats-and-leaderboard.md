# Statistiques de cartes & classement — implémenté

Contrairement aux autres fichiers de `docs/backend-contracts/`, celui-ci
documente un chantier **déjà implémenté des deux côtés** (client `card-game`
ET serveur `wyrdane-backend`, branche `0065-card-stats-and-leaderboard`,
pas encore mergée dans `main` au moment de l'écriture) — conservé ici comme
référence plutôt que retiré, cohérent avec les autres contrats du dossier.

Objectif double : (1) donner des données d'équilibrage (taux de jeu et
winrate par carte) et (2) un classement des joueurs par MMR, tous deux
affichés dans un nouvel écran en jeu (« Statistiques », voir
`scripts/mainMenu/StatsPanel.gd`). Portée volontairement réduite aux
**matchs classés confirmés uniquement** — le solo contre l'IA et les parties
non confirmées (un seul rapport reçu) ne sont pas représentatifs pour de
l'équilibrage et gonfleraient le volume sans signal utile.

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

`rankedModel.getTopCards` agrège ensuite :
- **Taux de jeu** = `COUNT(DISTINCT client_match_id) / total_matchs_classés`
  (dénominateur = nombre de lignes dans `match_history` pour la saison).
- **Winrate** = `SUM(won) / COUNT(*)` (au niveau instance carte-jouée, pas
  match — si les deux joueurs jouent la même carte avec des issues
  différentes, les deux comptent).

Seuil minimum : une carte n'apparaît dans les résultats que si
`matches_played >= 20` (`MIN_MATCHES_FOR_CARD_STATS`), pour éviter un
winrate à 100%/0% non significatif en tout début de vie du jeu.

---

## 2. `GET /api/ranked/stats/cards/top`

Retourne les cartes les plus jouées en classé, triées par taux de jeu
décroissant (`rankedController.getTopCardsHandler`) :

```json
{
  "total_ranked_matches": 4820,
  "cards": [
    { "card_name": "Zombie affamé", "play_rate": 0.62, "matches_played": 2988, "winrate": 0.54 },
    { "card_name": "Roi Zombie", "play_rate": 0.41, "matches_played": 1976, "winrate": 0.58 }
  ]
}
```

Mounté sous `/api/ranked` (comme `/me`, `/leaderboard`, `/matches/report`),
donc nécessite le cookie de session comme le reste de cette route — pas une
lecture publique (choix pragmatique : cohérent avec le reste de
`rankedRouter`, pas de middleware séparé à ajouter pour cette seule route ;
à revoir si un affichage public sur `wyrdane-website` est voulu plus tard).

### Côté client
`BackendClient.get_card_stats(on_complete: Callable)`
(`scripts/net/BackendClient.gd`) — `(success: bool, cards: Array)`, chaque
entrée étant le dictionnaire JSON tel quel ci-dessus.

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

`scripts/mainMenu/StatsPanel.gd` (nouveau, même pattern statique que
`QuestsPanel.gd`/`ProfilePanel.gd`) ajoute une nouvelle `InfoView.STATS`
(bouton « Statistiques » dans `BottomCenterRow` de `MainMenu.tscn`), avec
deux sections dans le même conteneur défilant : « Cartes les plus jouées »
(triées par `play_rate`, `winrate` affiché à côté) et « Classement » (rang
calculé + nom + MMR, le joueur local mis en surbrillance dorée s'il
apparaît dans le top 100 affiché, via `SteamService.local_persona_name()`).
Lecture seule, aucune action de réclamation contrairement aux quêtes.

## 5. Reste à faire

- Mergé côté client dans ce worktree ; côté backend, la branche
  `0065-card-stats-and-leaderboard` doit être review/mergée dans `main` puis
  déployée (voir CLAUDE.md `wyrdane-backend` pour le déploiement continu) et
  la synchro de schéma (`npm run db:sync`) appliquée en prod pour créer
  `card_play_stats` et la colonne `match_reports.cards_played` — même
  procédure que les chantiers précédents (quêtes hebdo, matchmaking classé).
- Pas de pagination sur `stats/cards/top` (320 cartes max, acceptable) ni
  granularité par saison passée (toujours `CURRENT_SEASON`) — à revoir si le
  jeu introduit un reset de saison ranked avant que ça devienne un problème.
