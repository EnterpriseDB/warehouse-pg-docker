BUILD_VERSION="0.1"
BUILD_IMAGE_TITLE="WarehousePG 7 Database"
BUILD_IMAGE_DESCRIPTION="WarehousePG 7.x Database image"


TCP_PORT="6432"


include ../token.mk


CURRENT_UID := $(shell id -u)

AIDB_SRC        ?= $(abspath $(CURDIR)/../../aidb)
AIDB_OUT        ?= $(CURDIR)/aidb-out
AIDB_BUILDER    ?= whpg7-aidb-builder


all:
	@echo ""
	@echo "WarehousePG 7.x multi-node setup, built from RPMs"
	@echo ""
	@echo "build:      (Re)build the image"
	@echo "run:        Start the image"
	@echo "status:     Show Docker compose status"
	@echo "psql:       Connect to the WarehousePG Database in the image"
	@echo "access:     Get a shell in the image"
	@echo "logs:       Show the Docker log for the image"
	@echo "stop:       Stop the image"
	@echo "clean:      Remove all artifacts"
	@echo "build-aidb: Build the AIDB extension against WHPG (produces ./aidb-out)"
	@echo "copy-aidb:  Copy AIDB artifacts into the running DB containers"

build:
	@# Docker may create the data directories already - as root
	mkdir -p $(shell pwd)/data
	@for i in coordinator standby seg1 seg2 gpfdist; do mkdir -p data/$$i data/$$i/data data/$$i/gpadmin_ssh data/$$i/root_ssh data/$$i/etc_ssh; done
	DOCKER_BUILDKIT=1 docker compose up --build --no-start --remove-orphans
	docker image prune -f
	docker buildx prune -f

run:	checksudo checklabsrunning
	@mkdir -p data
	@sudo chown `id -un`:`id -gn` data data/* ; true
	@for i in coordinator standby seg1 seg2 gpfdist; do mkdir -p data/$$i data/$$i/data data/$$i/gpadmin_ssh data/$$i/root_ssh data/$$i/etc_ssh; done
	@# Docker Desktop for Mac's file-share bridge lazily registers newly-
	@# created deeply-nested directories. `docker compose up` fails with
	@# "mkdir <path>: no such file or directory" on freshly-mkdir'd bind-
	@# mount sources — but a plain `docker run -v <path>:/x` on the same
	@# path first pokes the bridge into registering it. Prime each of the
	@# five sources before compose gets to them.
#	@echo ">>> Priming Docker Desktop file-share for bind-mount sources"
#	@for i in coordinator standby seg1 seg2 gpfdist; do \
#		docker run --rm --platform=linux/amd64 \
#			-v $(shell pwd)/data/$$i/data:/x \
#			alpine true; \
#	done
	DOCKER_BUILDKIT=1 docker compose up --detach

status:
	docker compose ps

psql:
	@echo ""
	@echo "Use:"
	@echo ""
	@printf "make psql-coordinator\t\tConnect psql to coordinator host"
	@printf "make psql-standby\t\tConnect psql to standby host"
	@echo ""

psql-coordinator:
	psql -h 127.0.0.1 -p 6432 -U gpadmin postgres

psql-standby:
	psql -h 127.0.0.1 -p 6433 -U gpadmin postgres

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
	@echo ""
	@echo "Use:"
	@echo ""
	@printf "make logs-coordinator\t\tShow logs from coordinator host\n"
	@printf "make logs-standby\t\tShow logs from standby host\n"
	@printf "make logs-seg1\t\t\tShow logs from segment host 1\n"
	@printf "make logs-seg2\t\t\tShow logs from segment host 2\n"
	@printf "make logs-gpfdist\t\t\tShow logs from gpfdist host\n"
	@echo ""

logs-coordinator:
	docker compose logs -f coordinator

logs-standby:
	docker compose logs -f standby

logs-seg1:
	docker compose logs -f seg1

logs-seg2:
	docker compose logs -f seg2

logs-gpfdist:
	docker compose logs -f gpfdist

access:
	@echo ""
	@echo "Use:"
	@echo ""
	@printf "make access-coordinator\t\tConnect to coordinator host\n"
	@printf "make access-standby\t\tConnect to standby host\n"
	@printf "make access-seg1\t\tConnect to segment host 1\n"
	@printf "make access-seg2\t\tConnect to segment host 2\n"
	@printf "make access-gpfdist\t\tConnect to gpfdist host\n"
	@echo ""

access-coordinator:
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@echo "psql command is:"
	@echo "  psql whpgtest"
	@docker compose exec coordinator /bin/bash

access-standby:
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@echo "psql command is:"
	@echo "  psql whpgtest"
	@docker compose exec standby /bin/bash

access-seg1:
	@echo ""
	@#echo "Segment databases running on ports: "`docker compose exec seg1 netstat -pan 2> /dev/null | grep postgres | grep 0.0.0.0:60 | awk '{print $$4;}' | cut -f2 -d: | xargs`
	@echo "Segment databases running on ports: "`docker compose exec seg1 /home/gpadmin/list-seg-ports.sh`
	@echo ""
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@echo "psql command is (plus port):"
	@echo "  PGOPTIONS='-c gp_session_role=utility' psql -d whpgtest -p "
	@docker compose exec seg1 /bin/bash

access-seg2:
	@echo ""
	@#echo "Segment databases running on ports: "`docker compose exec seg2 netstat -pan 2> /dev/null | grep postgres | grep 0.0.0.0:60 | awk '{print $$4;}' | cut -f2 -d: | xargs`
	@echo "Segment databases running on ports: "`docker compose exec seg2 /home/gpadmin/list-seg-ports.sh`
	@echo ""
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@echo "psql command is (plus port):"
	@echo "  PGOPTIONS='-c gp_session_role=utility' psql -d whpgtest -p "
	@docker compose exec seg2 /bin/bash

access-gpfdist:
	@echo "Don't forget to run:"
	@echo "  source /usr/local/greenplum-db/greenplum_path.sh"
	@docker compose exec gpfdist /bin/bash

checksudo:
	@if ! sudo -n true 2>/dev/null; then \
		echo "Note: Entering a sudo password might be required ..."; \
		echo "      The data/ directory contains files owned by another user"; \
		echo "      This was caused by the Docker lab changing ownership of files"; \
		echo ""; \
	fi

checklabsrunning:
	../labs-are-running.sh

build-aidb:
	@if [ ! -d "$(AIDB_SRC)" ]; then \
		echo "ERROR: AIDB source not found at $(AIDB_SRC)"; \
		echo "Set AIDB_SRC=/path/to/aidb on the make command line."; \
		exit 1; \
	fi
	@if [ -z "$$GH_API_TOKEN" ]; then \
		echo "ERROR: GH_API_TOKEN is not set."; \
		echo "Needed to clone EDB's private pgrx / pgfs repos."; \
		exit 1; \
	fi
	DOCKER_BUILDKIT=1 docker build \
		--platform=linux/amd64 \
		--secret id=edbtoken_secret,env=EDBTOKEN \
		--secret id=edbrepository_secret,env=EDBREPOSITORY \
		--secret id=gh_token,env=GH_API_TOKEN \
		-f aidb-builder.Dockerfile \
		-t $(AIDB_BUILDER) .
	@mkdir -p $(AIDB_OUT)
	docker run --rm --platform=linux/amd64 \
		-e GH_API_TOKEN \
		-v $(AIDB_SRC):/src:ro \
		-v $(AIDB_OUT):/out \
		-v whpg7-aidb-cargo-target:/tmp/target \
		-v whpg7-aidb-cargo-registry:/opt/cargo/registry \
		$(AIDB_BUILDER)

copy-aidb:
	./aidb-install.sh $(AIDB_OUT)

.PHONY:	all build run logs stop clean cleanall status checksudo checklabsrunning
.PHONY: psql psql-coordinator psql-standby psql-seg1 psql-seg2
.PHONY: access access-coordinator access-seg1 access-seg2 access-gpfdist
.PHONY: build-aidb copy-aidb
.PHONY: logs logs-coordinator logs-seg1 logs-seg2 logs-gpfdist
