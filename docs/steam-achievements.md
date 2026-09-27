# Succès Steam — textes prêts à saisir dans Steamworks

Le code client est prêt (`scripts/net/AchievementManager.gd`) : chaque succès
s'y débloque déjà via `Steam.setAchievement()`. Il ne manque plus que leur
**création côté dashboard partenaire** (app 5052390 → *Achievement
Configuration*), sans laquelle aucun ne peut se débloucher en jeu.

Ce fichier existe pour que cette saisie soit purement mécanique : l'`API Name`
de chaque ligne doit être recopié **à l'identique** (c'est la chaîne que le jeu
envoie), et les colonnes FR/EN sont directement collables dans les champs
*Display Name* / *Description* des locales `french` et `english`.

Rappels :
- Un succès **caché** (*Hidden*) n'affiche pas sa description avant déblocage.
  La colonne « Caché » ci-dessous propose celles dont la description révèle une
  mécanique tardive ; rien de bloquant, c'est un choix éditorial.
- Chaque succès demande une **icône débloquée + une icône verrouillée**
  (64×64 px, PNG/JPG). Non fournies ici.
- Les textes ne passent **pas** par `translations/game.csv` : c'est Steam qui
  affiche ces libellés, pas le jeu.
- Aucun de ces succès n'est testable depuis l'éditeur Godot (même limitation que
  l'overlay, voir l'en-tête de `SteamService.gd`) : il faut une build exportée,
  lancée avec un compte Steam connecté.

## Les 20 succès

| API Name | Nom (FR) | Nom (EN) | Description (FR) | Description (EN) | Caché |
|---|---|---|---|---|---|
| `ACH_GRADUATE` | Premier Pas | First Steps | Terminer le tutoriel. | Complete the tutorial. | non |
| `ACH_PACK_OPENER` | Ouvre-Sceaux | Seal Breaker | Ouvrir votre premier pack de cartes. | Open your first card pack. | non |
| `ACH_FIRST_RANKED_WIN` | Baptême du Rang | Ranked Baptism | Remporter une partie classée. | Win a ranked match. | non |
| `ACH_FLAWLESS_VICTORY` | Sans une Égratignure | Without a Scratch | Remporter une partie sans que votre héros ne perde un seul point de vie. | Win a match without your hero losing a single hit point. | non |
| `ACH_COMEBACK` | Retour des Cendres | Back from the Ashes | Remporter une partie après être descendu à 5 points de vie ou moins. | Win a match after dropping to 5 hit points or less. | non |
| `ACH_GUARDIAN_STREAK` | Gardien Inflexible | Unyielding Guardian | Remporter 2 parties d'affilée sans jamais descendre sous 20 points de vie. | Win 2 matches in a row without ever dropping below 20 hit points. | non |
| `ACH_EXECUTIONER` | Bourreau | Executioner | Tuer 5 serviteurs ennemis en un seul de vos tours. | Kill 5 enemy minions in a single one of your turns. | non |
| `ACH_VETERAN` | Vétéran | Veteran | Remporter 100 parties. | Win 100 matches. | non |
| `ACH_RANK_GOLD` | Éclat d'Or | Golden Sheen | Atteindre le palier Or en partie classée. | Reach the Gold tier in ranked play. | non |
| `ACH_MEGA_DECK` | Bibliothécaire | Librarian | Sauvegarder un deck de plus de 100 cartes jouables (ressources non comprises). | Save a deck with more than 100 playable cards (resources excluded). | non |
| `ACH_MINIMALIST` | Minimaliste | Minimalist | Remporter une partie en ayant joué moins de 5 cartes-ressource. | Win a match having played fewer than 5 resource cards. | non |
| `ACH_FRONT_ONLY` | Toujours en Première Ligne | Always Front Line | Remporter 3 parties sans jamais poser de serviteur en rangée Arrière. | Win 3 matches without ever placing a minion in the Back row. | non |
| `ACH_MONO_RACE` | Pur Sang | Pure Blood | Remporter 3 parties avec un deck d'une seule race. | Win 3 matches with a single-race deck. | non |
| `ACH_NO_LEGENDARY` | Sans Légende | No Legends | Remporter 3 parties avec un deck ne contenant aucune carte Légendaire. | Win 3 matches with a deck containing no Legendary card. | non |
| `ACH_FULL_ROSTER` | Toutes Bannières | Every Banner | Remporter au moins une partie avec chacune des quatre races. | Win at least one match with each of the four races. | non |
| `ACH_COLLECTOR` | Collectionneur | Collector | Posséder toutes les cartes jouables d'une race. | Own every playable card of one race. | non |
| `ACH_PLAGUE` | Porteur de Peste | Plague Bearer | Remporter une partie en infligeant 15 dégâts d'Infection ou plus à des serviteurs ennemis. | Win a match after dealing 15 or more Infection damage to enemy minions. | oui |
| `ACH_SACRIFICE` | Prix du Sang | Blood Price | Sacrifier 3 serviteurs alliés dans une même partie. | Sacrifice 3 allied minions in a single match. | oui |
| `ACH_BLACK_BLOOD` | Sang Noir | Black Blood | Déclencher 10 fois la réaction Sang Noir dans une même partie. | Trigger the Black Blood reaction 10 times in a single match. | oui |
| `ACH_COMMANDEMENT` | Voix du Royaume | Voice of the Realm | Remporter une partie avec un deck 100 % Humain en activant Commandement au moins 5 fois. | Win a match with an all-Human deck, triggering Command at least 5 times. | oui |
| `ACH_MUTATION_MAX` | Chair Instable | Unstable Flesh | Porter un serviteur allié à 5 mutations ou plus. | Bring an allied minion to 5 or more mutations. | oui |

> 21 lignes pour 20 succès annoncés ailleurs dans la doc : le compte de 20 datait
> d'avant l'ajout de `ACH_FULL_ROSTER`. La liste ci-dessus est la bonne, elle est
> dérivée directement des constantes de `AchievementManager.gd`.

## Conditions exactes de déclenchement

À vérifier si un succès ne se débloque pas comme attendu — les seuils viennent
des constantes en tête de `AchievementManager.gd`, les descriptions ci-dessus y
sont alignées.

| API Name | Déclencheur (code) | Seuil |
|---|---|---|
| `ACH_GRADUATE` | `TutorialManager.notify_victory` | — |
| `ACH_PACK_OPENER` | `PackShop._on_packs_opened` | 1 pack |
| `ACH_FIRST_RANKED_WIN` | `on_victory`, `battle.is_ranked_match` | — |
| `ACH_FLAWLESS_VICTORY` | `on_victory`, `hero.health >= hero.max_health` | — |
| `ACH_COMEBACK` | `on_victory`, `player_was_low_hp_this_match` | ≤ 5 PV |
| `ACH_GUARDIAN_STREAK` | `_update_guardian_streak` (victoire ET défaite) | 2 victoires, plancher 20 PV |
| `ACH_EXECUTIONER` | `on_enemy_kills_this_turn` | 5 kills / tour |
| `ACH_VETERAN` | `on_victory`, `SettingsManager.match_wins` | 100 victoires |
| `ACH_RANK_GOLD` | `check_rank_tier` | `RankTier.Type.GOLD` ou + |
| `ACH_MEGA_DECK` | `on_deck_saved` | > 100 cartes jouables |
| `ACH_MINIMALIST` | `on_victory`, `player_resource_cards_played` | < 5 ressources |
| `ACH_FRONT_ONLY` | `on_victory`, cumulatif | 3 victoires |
| `ACH_MONO_RACE` | `on_victory`, `deck_races.size() == 1`, cumulatif | 3 victoires |
| `ACH_NO_LEGENDARY` | `on_victory`, `deck_has_legendary` faux, cumulatif | 3 victoires |
| `ACH_FULL_ROSTER` | `_check_full_roster` | les 4 races |
| `ACH_COLLECTOR` | `check_collector` (à chaque sync de collection) | 1 race complète |
| `ACH_PLAGUE` | `on_victory`, `player_infection_damage_dealt` | 15 dégâts |
| `ACH_SACRIFICE` | `on_sacrifice` | 3 sacrifices / partie |
| `ACH_BLACK_BLOOD` | `on_black_blood_trigger` | 10 déclenchements / partie |
| `ACH_COMMANDEMENT` | `on_victory`, deck Humain seul | 5 activations |
| `ACH_MUTATION_MAX` | `on_minion_mutated` | 5 mutations |
