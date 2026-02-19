BUILD_VERSION="0.1"
BUILD_IMAGE_TITLE="WarehousePG 6 Database"
BUILD_IMAGE_DESCRIPTION="WarehousePG 6.x Database image"


IMAGE_NAME="sne"
HOST_NAME="whpgdb-primary"
TCP_PORT="6432"


include ../token.mk


CURRENT_UID := $(shell id -u)


all:
	@echo ""
	@echo "WarehousePG 6.x, built from RPMs"
	@echo ""
	@echo "build:    (Re)build the image"
	@echo "run:      Start the image"
	@echo "status:   Show Docker compose status"
	@echo "psql:     Connect to the WarehousePG Database in the image"
	@echo "access:   Get a shell in the image"
	@echo "logs:     Show the Docker log for the image"
	@echo "stop:     Stop the image"
	@echo "clean:    Remove all artifacts"

build:
	mkdir -p $(shell pwd)/data
	DOCKER_BUILDKIT=1 docker compose up --build --no-start --remove-orphans
	docker image prune -f
	docker buildx prune -f

run:	checklabsrunning
	mkdir -p $(shell pwd)/data
	DOCKER_BUILDKIT=1 docker compose up --detach

status:
	docker compose ps

psql:
	psql -h 127.0.0.1 -p $(TCP_PORT) -U gpadmin postgres

stop:
	docker compose stop -t 5
	docker compose rm -f
	docker compose ps -a

clean:	stop checksudo
	@#sudo rm -rf data
	@if [ -d data ] && [ $$(find data -mindepth 1 -not -uid $(CURRENT_UID) -print -quit | wc -l) -gt 0 ]; then \
		sudo rm -rf data; \
	elif [ -d data ]; then \
		rm -rf data; \
	fi

cleanall:	clean
	docker image prune --all --force
	docker network prune --force
	docker system prune --all --force

logs:
	docker compose logs -f $(IMAGE_NAME)

access:
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@echo "psql command is:"
	@echo "  psql whpgtest"
	@docker compose exec $(IMAGE_NAME) /bin/bash

checksudo:
	@if ! sudo -n true 2>/dev/null; then \
		echo "Note: Entering a sudo password might be required ..."; \
		echo "      The data/ directory contains files owned by another user"; \
		echo "      This was caused by the Docker lab changing ownership of files"; \
		echo ""; \
	fi

checklabsrunning:
	../labs-are-running.sh

.PHONY:	all build run psql access logs stop clean cleanall status checksudo checklabsrunning
