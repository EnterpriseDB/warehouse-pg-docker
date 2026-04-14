# WarehousePG Docker Setup

This repository provides Docker configurations for setting up WarehousePG in both single-node and multi-node configurations.

## Container Restart

Currently none of the Docker labs will survive a container restart. This setup is not meant for production use.

While the data directories for all segment databases are mapped to the Docker host, this is meant for inspecting the directories, not to support a container restart.

## Table of Contents

- `WarehousePG6-from-RPMs-RH7-single-node`: WarehousePG v6, single node, installed from RPMs
- `WarehousePG6-from-source-RH7-single-node`: WarehousePG v6, single node, built from source code
- `WarehousePG7-from-RPMs-RH9-multi-node`: WarehousePG v7, coordinator + 2 segment hosts, installed from RPMs
- `WarehousePG7-from-RPMs-RH9-multi-node-standby-mirrors`: WarehousePG v7, coordinator + 2 segment hosts, standby coordinator and mirrors enabled, installed from RPMs
- `WarehousePG7-from-RPMs-RH9-single-node`: WarehousePG v7, single node, installed from RPMs
- `WarehousePG7-from-RPMs-RH9-single-node-not-installed`: WarehousePG v7, single node, installed from RPMs, database not configured (for trying out install options)
- `WarehousePG7-from-source-RH9-single-node`: WarehousePG v7, single node, built from source code

The `RH7` labs are using [CentOS](https://en.wikipedia.org/wiki/CentOS) 7, the `RH9` labs are using [Rocky Linux](https://en.wikipedia.org/wiki/Rocky_Linux) 9.

## Installation

You need an EDB token in order to download RPM packages:

To get a token:

- go to `https://enterprisedb.com/`
- Sign in
- Go to "My Account" (in the upper right corner)
- Select "Account Settings" from Dropdown
- Under "Profile", copy the first line, that's the "Repos 2.0" token
- Create the file "~/.edb-token" and copy the token into the file

Your token matches a specific repository. You should have received this information along with the token.
For EDB employees the personal token is for the "dev" repository.
Create the file "~/.edb-repository", add one of: "dev", "staging_gpsupp", "gpsupp".

Check your Docker settings, allow enough disk space, RAM and CPU for Docker.
For building all images consider 50-60 GB disk space.

Note: the containers build from source do not need an EDB token.

## Single Node Setup

A single node setup includes the coordinator and multiple segment databases (2 in this case) in a single machine or container. No network setup is required.

The following setups are single node:

- `WarehousePG6-from-RPMs-RH7-single-node`
- `WarehousePG6-from-source-RH7-single-node`
- `WarehousePG7-from-RPMs-RH9-single-node`
- `WarehousePG7-from-RPMs-RH9-single-node-not-installed`
- `WarehousePG7-from-source-RH9-single-node`

## Multi Node Setup

A multi node setup includes multiple machines or containers. One system is used for the coordinator, other systems for segment databases (2 segment hosts with 2 segment databases each in this case). Network connectivity is required, and provided by Docker.

The following setups are multi-node:

- `WarehousePG7-from-RPMs-RH9-multi-node` (no standby coordinator, no mirror segments)
- `WarehousePG7-from-RPMs-RH9-multi-node-standby-mirrors` (includes standby coordinator, includes mirror segments)

## Interactive Training

For detailed instructions on setting up WarehousePG from scratch, please refer to the [training](training.md) document.

The `WarehousePG7-from-RPMs-RH9-single-node-not-installed` lab can be used here, this container has the RPM packages pre-installed, but WarehousePG is not configured. Necessary files are available in `/home/gpadmin` in the container (use `make access` to drop into a shell once the container is started).

## Build WarehousePG From Source

The containers `WarehousePG6-from-source-RH7-single-node` and `WarehousePG7-from-source-RH9-single-node` build WarehousePG from source. Refer to the `Dockerfile` in each directory for detailed instructions how to build the database from source.
