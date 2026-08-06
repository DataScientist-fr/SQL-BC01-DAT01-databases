# CareAccess — raccourcis

.PHONY: up down load psql ui

up:        ## Démarrer la base
	docker compose up -d
	@echo "Attente du chargement..." && sleep 3
	@docker compose logs db 2>/dev/null | grep "CareAccess chargé" || echo "  (relancer make logs dans quelques secondes)"

down:      ## Arrêter (les données sont conservées)
	docker compose down

load:      ## (Re)charger les données CareAccess — idempotent, DROP puis CREATE
	@docker compose exec -T db psql -U careaccess -d careaccess \
		-v ON_ERROR_STOP=1 --quiet < data/careaccess.sql
	@echo "  → data/careaccess.sql chargé"

ui:        ## Adminer sur http://localhost:8081 (serveur db, user/pass/base : careaccess)
	docker compose --profile ui up -d
	@echo "  → http://localhost:8081"

psql:      ## Console interactive
	docker compose exec db psql -U careaccess -d careaccess

