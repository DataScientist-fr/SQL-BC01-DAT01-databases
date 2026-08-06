# ShopFlow

Base de travail des chapitres 4.1 → 5.3 (jointures, sous-requêtes, vues) et support du projet de
modélisation du chapitre 3.4 du cours SQL BC01-DAT01-01.
**5 catégories, 7 clients, 8 produits, 8 commandes, 15 lignes de commande.**

Connexion, commandes et écarts SQLite → PostgreSQL : voir le [README racine](../../README.md).
Console : `make psql DB=shopflow`.

## Le schéma

```
categories (5) ──┐          customers (7)
   ▲   │         │               │
   └───┘         ▼               ▼
 self-join   products (8)    orders (8)
                  │               │
                  └───────┬───────┘
                          ▼
                  order_items (15)   ← grain le plus fin, source du fan-out
```

| Table | Une ligne = | Particularité |
|---|---|---|
| `categories` | une catégorie | `parent_category_id` réflexive, `NULL` = racine (Informatique, Maison) |
| `customers` | un client | `email` nullable (Bruno Lefef, Emeka Obi) · **Gaël Morin n'a aucune commande** |
| `products` | un produit du catalogue | `is_active` en 0/1 · **Grille-pain vintage jamais commandé** |
| `orders` | une commande | 4 statuts : paid / shipped / cancelled / pending |
| `order_items` | un produit dans une commande | `unit_price` **historisé**, PK technique |

Vues : `vue_commande` et `vue_ca_client` (celles du cours, chapitre 5.3), plus `orders_typed`
(`order_date` en vraie `DATE`) et `v_fanout_demo`.

## Les deux points pédagogiques

### 1. Le fan-out : 8 commandes, 15 lignes

`SELECT * FROM v_fanout_demo;`

| Requête | Résultat |
|---|---|
| `orders` seule | `8` |
| jointe à `order_items`, `COUNT(*)` | `15` — le grain a changé |
| `COUNT(DISTINCT o.order_id)` | `8` — retour au grain commande |

### 2. `unit_price` existe deux fois, et ce n'est pas une erreur

`products.unit_price` est le prix **catalogue**, `order_items.unit_price` le prix **facturé ce
jour-là**. Ils diffèrent volontairement — le Portable Pro 14 est à 1299.00 au catalogue mais facturé
1249.00 dans la commande 5. **Un CA calculé depuis `products` est faux.**

CA total (depuis `order_items`) : **6326.40**. CA par client : Alice Durand 2752.30, Diana Rossi
2597.80, Gaël Morin absent de `vue_ca_client` — la vue fait un `JOIN`, pas un `LEFT JOIN`. C'est le
piège de l'exercice 4.1 EX03.

## Les choix de portage

**`order_items` garde une PK technique `order_item_id`.** Le MLD *enseigné* au chapitre 3.2 demande
`PRIMARY KEY (order_id, product_id)` — c'est la bonne réponse à l'exercice — mais la base réelle de
la plateforme a une clé technique, et l'anti-jointure du chapitre 4.1 teste
`oi.order_item_id IS NULL`. La fidélité aux exercices l'emporte.

**`unit_price` est en `NUMERIC(10,2)`** : les vues du cours écrivent
`ROUND(SUM(quantity * unit_price), 2)` et PostgreSQL n'a pas de `round(double precision, integer)`.

**`is_active` reste un `integer` 0/1**, pas un `boolean` : les solutions écrivent
`WHERE is_active = 1`.

**`order_date` et `signup_date` restent en TEXT** — même arbitrage que `scheduled_at` dans
[CareAccess](../careaccess/). `orders_typed` expose la vraie `DATE`.

Le chapitre 3.3 part d'une table à plat `commandes_plat` (clé `order_id, product_id` ; colonnes
`customer_name, order_date, product_name, category_name, quantity, unit_price`) pour dérouler la
normalisation jusqu'en 3NF — c'est un support papier, elle n'est pas dans la base.
