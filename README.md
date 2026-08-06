# SQL BC01-DAT01 — le serveur de bases du cours

**Un seul serveur PostgreSQL** contenant toutes les bases utilisées dans le cours
*SQL : Interroger et modéliser des données relationnelles* (DataScientist.fr).
Un utilisateur par base, plus un `admin` qui accède à tout.

```bash
make up      # démarrer le serveur (crée et charge les bases au premier démarrage)
make ls      # lister les bases présentes
make psql DB=fintrust
```

## Les bases

| Base | Contenu | Chapitres |
|---|---|---|
| [`careaccess`](sql/careaccess/) | 6 patients, 3 praticiens, 7 rendez-vous, 14 événements | 1.1 → 2.3, 3.4, 6.1 → 6.3 |
| [`fintrust`](sql/fintrust/) | 3 comptes, 4 commerçants, 10 transactions | 2.1, 2.3, 3.1 → 3.3 |

**ShopFlow** (chapitres 4.x et 5.x) reste à porter.

## Se connecter

| Hôte / port | `localhost:5433` |
|---|---|
| Base · utilisateur · mot de passe | **le nom de la base pour les trois** (`fintrust` / `fintrust` / `fintrust`) |
| Accès à toutes les bases | `admin` / `admin` |

Le port **5433** est délibéré : il évite le conflit avec un PostgreSQL local déjà sur 5432.

Les bases sont **étanches** : `fintrust` ne peut pas se connecter à `careaccess`. Seul `admin`,
superuser du cluster, passe partout.

```bash
psql -h localhost -p 5433 -U fintrust -d fintrust     # ok
psql -h localhost -p 5433 -U fintrust -d careaccess   # permission denied
```

### Interface web (Adminer)

`make ui` → http://localhost:8081. Sur l'écran de connexion :

| Champ | Valeur |
|---|---|
| Système | **PostgreSQL** |
| Serveur | `db` |
| Utilisateur · mot de passe · base | le nom de la base (ou `admin` / `admin` pour tout voir) |

Le serveur est `db` (nom du service Docker), pas `localhost` : Adminer tourne dans le même réseau
que la base. `make down` arrête aussi Adminer.

## Les commandes

```bash
make up                  # démarrer
make load                # (re)charger toutes les bases — idempotent, DROP puis CREATE
make load DB=fintrust    # (re)charger une seule base
make psql DB=careaccess  # console psql
make ls                  # bases du serveur et leur propriétaire
make ui                  # Adminer → http://localhost:8081
make logs                # logs du serveur
make down                # arrêter (le volume est conservé)
make reset               # repartir d'un cluster vierge — DÉTRUIT les données
```

`make up` affiche la ligne de contrôle de chaque base :

```
  CareAccess chargé : 6 patients, 3 praticiens, 7 rendez-vous, 14 événements
  FinTrust chargé : 3 comptes, 4 commerçants, 10 transactions
```

Si une ligne manque ou si les volumes sont faux, le chargement **échoue bruyamment** plutôt que de
laisser une base à moitié remplie. Dans ce cas : `make load`.

## Ajouter une base

Le nom du dossier sous `sql/` **est** le nom de la base, du rôle et du mot de passe.

```bash
mkdir sql/shopflow
$EDITOR sql/shopflow/shopflow.sql   # DROP … CASCADE en tête, pour rester rejouable
make reset
```

`init/10-databases.sh` boucle sur `sql/*/` : rien à modifier dans `docker-compose.yml` ni dans le
`Makefile`. Le fichier SQL est joué **en tant que l'utilisateur de la base**, donc les tables lui
appartiennent.

## Les écarts avec la plateforme

Les exercices du cours tournent en **SQLite**. Les solutions donnent ici le même résultat, sauf :

| | SQLite (plateforme) | PostgreSQL (ici) |
|---|---|---|
| **NULL au tri `ASC` / `DESC`** | tête / queue | **queue / tête** |
| **`LIKE`** | insensible à la casse | **sensible** — `ILIKE` sinon |
| **Typage** | indicatif | **strict** |
| **Clés étrangères** | désactivées par défaut | actives d'office |
| **`LIMIT m, n`** | accepté | **rejeté** |

Les deux à retenir pour animer :

1. **L'ordre des NULL est inversé.** L'exercice 1.4 EX01 sort Sofia Rossi en *première* ligne sur la
   plateforme, en *dernière* ici.
2. **`LIKE 'lille'`** renvoie 2 lignes sur la plateforme et **0 ici**. Forme portable :
   `LOWER(city) LIKE LOWER('lille')`.

La **locale du cluster est `C`**, pour deux raisons : l'image alpine ne fournit pas `fr_FR.UTF-8`,
et SQLite trie en `BINARY` — la locale `C` reproduit ce comportement. Conséquence : majuscules avant
minuscules, accents après le `z`.

## Structure

```
├── docker-compose.yml
├── Makefile
├── init/
│   └── 10-databases.sh   # rôles + bases + chargement, au premier démarrage
└── sql/
    ├── careaccess/careaccess.sql
    └── fintrust/fintrust.sql
```

Chaque `.sql` est monté dans le conteneur (`./sql:/sql:ro`) et sert **deux fois** : au premier
démarrage via `init/`, et à la demande via `make load`. Une seule source de vérité par base.
