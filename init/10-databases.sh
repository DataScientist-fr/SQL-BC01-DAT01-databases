#!/bin/sh
# ============================================================
#  Création des bases du cours — joué UNE fois, au premier
#  démarrage du cluster (volume pgdata vide).
# ============================================================
#
#  CONVENTION : un dossier /sql/<nom>/ = une base <nom>, un rôle
#  <nom>, un mot de passe <nom>. Ajouter une base au cours revient
#  donc à déposer sql/<nom>/<nom>.sql — rien à modifier ici.
#
#  Le fichier SQL est joué EN TANT QUE <nom>, pas en tant qu'admin :
#  sinon les tables appartiendraient à admin et l'utilisateur de la
#  base ne pourrait ni les modifier ni les supprimer (et depuis
#  PostgreSQL 15, le schéma public appartient au propriétaire de la
#  base — c'est aussi ce qui lui donne le droit d'y créer).
# ============================================================

set -eu

for dir in /sql/*/; do
    db=$(basename "$dir")

    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
CREATE ROLE $db LOGIN PASSWORD '$db';
CREATE DATABASE $db OWNER $db;
-- Étanchéité entre bases : $db est la seule à pouvoir se connecter à $db.
-- admin passe outre, c'est un superuser.
REVOKE CONNECT ON DATABASE $db FROM PUBLIC;
GRANT  CONNECT ON DATABASE $db TO $db;
SQL

    psql -v ON_ERROR_STOP=1 --username "$db" --dbname "$db" -f "/sql/$db/$db.sql"
done
