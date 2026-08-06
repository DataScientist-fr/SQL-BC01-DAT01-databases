# SQL BC01-DAT01 — un serveur, toutes les bases du cours

# Bases découvertes depuis sql/ : `make load` les traite toutes,
# `make load DB=fintrust` n'en traite qu'une.
DATABASES := $(notdir $(patsubst %/,%,$(wildcard sql/*/)))
DB ?= $(DATABASES)

.PHONY: up down load psql ls ui logs reset

up:        ## Démarrer le serveur (crée et charge les bases au tout premier démarrage)
	docker compose up -d
	@echo "Attente du chargement..." && sleep 5
	@docker compose logs db 2>/dev/null | grep "chargé" || echo "  (relancer make logs dans quelques secondes)"

down:      ## Arrêter (les données sont conservées)
	docker compose down

load:      ## (Re)charger les données — toutes les bases, ou make load DB=fintrust
	@for db in $(DB); do \
		docker compose exec -T db psql -U $$db -d $$db \
			-v ON_ERROR_STOP=1 --quiet < sql/$$db/$$db.sql; \
		echo "  → sql/$$db/$$db.sql chargé"; \
	done

psql:      ## Console interactive — make psql DB=fintrust
	docker compose exec db psql -U $(firstword $(DB)) -d $(firstword $(DB))

ls:        ## Lister les bases du serveur et leur propriétaire
	@docker compose exec -T db psql -U admin -d postgres -tAF' · ' \
		-c "SELECT datname, pg_get_userbyid(datdba) FROM pg_database \
		    WHERE NOT datistemplate AND datname <> 'postgres' ORDER BY 1"

ui:        ## Adminer sur http://localhost:8081 (serveur db)
	docker compose --profile ui up -d
	@echo "  → http://localhost:8081"

logs:      ## Logs du serveur
	docker compose logs db

reset:     ## Repartir d'un cluster vierge — DÉTRUIT les données
	docker compose down -v
	$(MAKE) up
