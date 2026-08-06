# CareAccess

Base de travail des modules M1, M2, 3.4 et M6 du cours SQL BC01-DAT01-01.
Données extraites de la base de test réelle de la plateforme :
**6 patients, 3 praticiens, 7 rendez-vous, 14 événements**.

Connexion, commandes et écarts SQLite → PostgreSQL : voir le [README racine](../../README.md).
Console : `make psql DB=careaccess`.

## Le schéma

```
patients (6)            practitioners (3)
    │                        │
    └────────┬───────────────┘
             ▼
       appointments (7)
             │
             ▼
    appointment_events (14)   ← grain le plus fin, source du fan-out
```

| Table | Une ligne = | NULL notable |
|---|---|---|
| `patients` | un patient | Amina Cherif `risk_level` · Sofia Rossi `city` · Yann Le Goff `birth_year` |
| `practitioners` | un praticien | — |
| `appointments` | un rendez-vous | — |
| `appointment_events` | un événement du cycle de vie | `actor` (événements système) |

Deux vues : `appointments_typed` (mêmes données, vrais `TIMESTAMP`) et `v_fanout_demo` (la démo
14 vs 7).

## Les choix de portage

**`scheduled_at` et `event_time` sont en TEXT** parce que SQLite n'a pas de type date : le cours
stocke `'YYYY-MM-DD HH:MM'`. Le typage est conservé pour que les solutions produisent exactement le
même résultat que sur la plateforme. `appointments_typed` expose les vrais `TIMESTAMP`.

L'exercice 6.2 EX01 fait créer une table `medications` par l'apprenant — elle n'est
volontairement pas dans le schéma de départ.
