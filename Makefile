
include token.mk


all:
	@echo "Available targets:"
	@echo ""
	@printf "\tbuild-everything\t\tBuilds all images (makes them available for a testing)\n"
	@printf "\tclean-docker\t\t\tRemove all Docker artifacts\n"
	@echo ""

docker-running:
	@docker info > /dev/null 2>&1 && echo "Docker is running!" > /dev/null || echo "Docker is not running!"
	@docker info > /dev/null 2>&1 && echo "Docker is running!" > /dev/null || exit 1

build-everything:	docker-running
	cd WarehousePG6-from-source-RH7-single-node/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-source-RH9-single-node/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-source-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 build
	cd WarehousePG6-from-RPMs-RH7-single-node/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-RPMs-RH9-single-node/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-RPMs-RH9-multi-node/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-RPMs-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 build
	cd WarehousePG7-from-RPMs-RH9-single-node-not-installed/ && make MAKELEVEL=0 build

stop-everything:	docker-running
	cd WarehousePG6-from-source-RH7-single-node/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-source-RH9-single-node/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-source-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 stop
	cd WarehousePG6-from-RPMs-RH7-single-node/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-RPMs-RH9-single-node/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-RPMs-RH9-multi-node/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-RPMs-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 stop
	cd WarehousePG7-from-RPMs-RH9-single-node-not-installed/ && make MAKELEVEL=0 stop

clean-everything:	docker-running
	cd WarehousePG6-from-source-RH7-single-node/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-source-RH9-single-node/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-source-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 clean
	cd WarehousePG6-from-RPMs-RH7-single-node/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-RPMs-RH9-single-node/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-RPMs-RH9-multi-node/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-RPMs-RH9-multi-node-standby-mirrors/ && make MAKELEVEL=0 clean
	cd WarehousePG7-from-RPMs-RH9-single-node-not-installed/ && make MAKELEVEL=0 clean

clean-docker:
	docker image prune --all --force
	docker network prune --force
	docker system prune --all --force

.PHONY: all
.PHONY: docker-running build-everything stop-everything clean-everything
.PHONY: clean-data clean-docker
