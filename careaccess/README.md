# CareAccess sur PostgreSQL

Base de travail pour préparer les **sessions live du cours SQL BC01-DAT01-01** (DataScientist.fr).
Données extraites de la base de test réelle de la plateforme : **6 patients, 3 praticiens, 7 rendez-vous, 14 événements**.

> ⚠️ Les exercices de la plateforme tournent en **SQLite**, pas en PostgreSQL. Les solutions du module M1
> donnent ici le même résultat — **sauf l'ordre des NULL au tri**, qui est inversé. Voir plus bas.

## Les commandes

```bash
make up      # démarrer la base (charge les données au tout premier démarrage)
make load    # (re)charger data/careaccess.sql — idempotent, DROP puis CREATE
make psql    # console psql interactive
make ui      # interface web Adminer → http://localhost:8081
make down    # arrêter (le volume est conservé)
```

`make up` affiche la ligne de contrôle :

```
CareAccess chargé : 6 patients, 3 praticiens, 7 rendez-vous, 14 événements
```

Si elle manque ou si les volumes sont faux, le chargement **échoue bruyamment** plutôt que de laisser
une base à moitié remplie. Dans ce cas : `make load`.

## Se connecter

| | |
|---|---|
| Hôte / port | `localhost:5433` |
| Base · utilisateur · mot de passe | `careaccess` (les trois) |

Le port **5433** est délibéré : il évite le conflit avec un PostgreSQL local déjà sur 5432.

### Interface web (Adminer)

`make ui` → http://localhost:8081. Sur l'écran de connexion :

| Champ | Valeur |
|---|---|
| Système | **PostgreSQL** |
| Serveur | `db` |
| Utilisateur | `careaccess` |
| Mot de passe | `careaccess` |
| Base de données | `careaccess` |

Le serveur est `db` (nom du service Docker), pas `localhost` : Adminer tourne dans le même réseau que la base.
`make down` arrête aussi Adminer.

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

Deux vues : `appointments_typed` (mêmes données, vrais `TIMESTAMP`) et `v_fanout_demo` (la démo 14 vs 7).

**`scheduled_at` est en TEXT** parce que SQLite n'a pas de type date : le cours stocke `'YYYY-MM-DD HH:MM'`.
Le typage est conservé pour que les solutions produisent exactement le même résultat que sur la plateforme.

**La locale est `C`** pour deux raisons : l'image alpine ne fournit pas `fr_FR.UTF-8`, et SQLite trie en
`BINARY` — la locale `C` reproduit ce comportement. Conséquence : majuscules avant minuscules, accents après le `z`.

## Les écarts avec la plateforme

| | SQLite (plateforme) | PostgreSQL (ici) |
|---|---|---|
| **NULL au tri `ASC` / `DESC`** | tête / queue | **queue / tête** |
| **`LIKE`** | insensible à la casse | **sensible** — `ILIKE` sinon |
| **Typage** | indicatif | **strict** |
| **Clés étrangères** | désactivées par défaut | actives d'office |
| **`LIMIT m, n`** | accepté | **rejeté** |

Les deux à retenir pour animer :

1. **L'ordre des NULL est inversé.** L'exercice 1.4 EX01 sort Sofia Rossi en *première* ligne sur la plateforme, en *dernière* ici.
2. **`LIKE 'lille'`** renvoie 2 lignes sur la plateforme et **0 ici**. Forme portable : `LOWER(city) LIKE LOWER('lille')`.

## Structure

```
├── docker-compose.yml
├── Makefile
└── data/
    └── careaccess.sql   # schéma + données + vues + contrôle de volumétrie
```

`careaccess.sql` est monté dans `docker-entrypoint-initdb.d` (premier démarrage) **et** rejoué par
`make load`. Une seule source de vérité. Pour repartir d'un volume vide : `docker compose down -v && make up`.
