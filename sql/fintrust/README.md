# FinTrust

Base de travail des exercices 2.1 EX03 et 2.3 EX03, et des démos de modélisation des chapitres
3.1 → 3.3 du cours SQL BC01-DAT01-01.
**3 comptes, 4 commerçants, 10 transactions** (juin 2025).

Connexion, commandes et écarts SQLite → PostgreSQL : voir le [README racine](../../README.md).
Console : `make psql DB=fintrust`.

## Le schéma

```
accounts (3)            merchants (4)
    │                        │
    └────────┬───────────────┘
             ▼
      transactions (10)   ← amount SIGNÉ : négatif = débit
```

| Table | Une ligne = | NULL notable |
|---|---|---|
| `accounts` | un compte bancaire | — |
| `merchants` | un commerçant | — |
| `transactions` | une transaction | `merchant_id` (virements internes : tx 1, 5, 8, 9) |

Deux vues : `transactions_typed` (mêmes données, vraie `DATE`) et `v_signed_amounts_demo` (la démo
des montants signés).

## Le point pédagogique : `amount` est signé

`SUM(amount)` donne le **solde net**, pas le volume échangé — les débits annulent les crédits.
`SELECT * FROM v_signed_amounts_demo;` met les quatre lectures côte à côte :

| Lecture | Résultat (`status = 'completed'`) |
|---|---|
| `SUM(amount)` brut | `3651.10` — le net |
| crédits seuls | `4600.00` |
| débits seuls | `-948.90` |
| `SUM(ABS(amount))` | `5548.90` — le volume réel |

Sans le filtre de statut, le net tombe à `3440.90` : `pending` et `failed` ne sont pas des flux.

Les transactions 8 et 9 sont les deux faces d'un même virement interne (`-300` puis `+300`, sans
commerçant) : elles s'annulent dans `SUM(amount)`.

## Les choix de portage

**`amount` est en `NUMERIC(12,2)`**, là où la plateforme utilise `REAL`. Les solutions du cours
écrivent `ROUND(SUM(amount), 2)` et PostgreSQL n'a pas de `round(double precision, integer)` : en
`double precision`, la requête échouerait. `NUMERIC` fait passer les solutions telles quelles et
supprime les arrondis flottants.

**`opened_at` et `transaction_date` restent en TEXT** (`'YYYY-MM-DD'`) — même arbitrage que
`scheduled_at` dans [CareAccess](../careaccess/). `transactions_typed` expose la vraie `DATE`.

Le chapitre 3.3 part d'une table à plat `releve` (`transaction_id, account_id, customer_name,
account_type, amount, status`) pour dérouler la normalisation jusqu'en 3NF — c'est un support
papier, elle n'est pas dans la base.
