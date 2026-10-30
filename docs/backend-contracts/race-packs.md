# Contrat backend — packs par race

Le client (`card-game`) propose désormais **5 packs achetables** : un pack
multirace (comportement historique) et un pack par race implémentée. Côté jeu,
tout passe par `CurrencyManager` (`scripts/collection/CurrencyManager.gd`),
l'affichage par `PackCarousel`/`ShopBuyPacksPanel` (Boutique) et
`ShopCollectionPanel` (ouverture).

Ce document décrit ce que `wyrdane-backend` doit implémenter pour que la
fonctionnalité soit réellement opérationnelle. **Tant que le backend ignore le
champ `race`, le client reste fonctionnel mais dégradé** : tout le stock est
compté en multirace (voir « Rétrocompatibilité » plus bas), donc acheter un
pack Démon crédite et ouvre un pack multirace.

## Clés de race

Exactement les valeurs de `CurrencyManager.PACK_RACES`, dans cet ordre :

```
"Undead", "Human", "multirace", "Demon", "Abomination"
```

Ce sont les `Race.get_race_name()` du client, plus le littéral `"multirace"`.
Toute autre valeur doit être **rejetée** (400), jamais interprétée comme
multirace par défaut : un client modifié ne doit pas pouvoir inventer une
catégorie de stock.

## Routes

### `POST /api/packs/buy`

Corps : `{ "quantity": int, "race": string }` (`race` absent = `"multirace"`,
pour les builds antérieures encore en circulation).

Prix inchangé (`PACK_COST` par pack, quelle que soit la race) — un pack de race
n'est pas plus cher, il est juste plus ciblé.

### `POST /api/packs/open-owned`

Corps : `{ "race": string }` (absent = `"multirace"`). Consomme un pack **du
stock de cette race** et tire ses cartes :

- `"multirace"` : tirage inchangé (toutes races).
- sinon : tirage restreint aux cartes de cette race, pondération par rareté
  inchangée (`RARITY_WEIGHTS`).

Refuser (409) si le stock de cette race est vide — ne jamais retomber sur un
autre stock.

### Réponses

Les trois routes qui renvoient déjà `free_packs`
(`GET /api/currency/balance`, `POST /api/packs/buy`,
`POST /api/packs/open-owned`) doivent renvoyer **en plus** :

```json
"free_packs_by_race": {
  "multirace": 3, "Undead": 0, "Human": 2, "Demon": 0, "Abomination": 1
}
```

`free_packs` reste la **somme** de ces valeurs : c'est elle que lisent la
pastille du menu principal et le reste du client. Les clés absentes sont lues
comme 0 côté client.

## Stockage

`users.free_packs` ne suffit plus (un entier unique). Le plus simple est une
table `user_pack_stock (user_id, race, quantity)` avec une ligne par race
possédée, `free_packs` devenant la somme — toutes les sources de packs
existantes (quêtes hebdo/mensuelles, niveaux, parrainage, récompense de
tutoriel) créditent du **multirace**, elles n'ont donc pas à être touchées au
cas par cas.

⚠ Changement de schéma : nécessite un `db:sync` en prod après déploiement
(voir « Appliquer un changement de schéma en prod » dans le `CLAUDE.md` de
`wyrdane-backend`), sans quoi les routes répondent 500 — scénario déjà
rencontré trois fois (matchmaking classé, chat/amis, invitations de partie).

## Rétrocompatibilité

Côté client, `CurrencyManager._set_free_packs_by_race` traite l'absence de
`free_packs_by_race` en versant tout `free_packs` dans `"multirace"`. Un client
à jour contre un backend pas encore déployé affiche donc le stock correctement,
avec un unique pack multirace dans la Collection, et les boutons d'achat de
packs de race créditent du multirace.
