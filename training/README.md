
# WarehousePG Interactive Training VM 

This guide will help you set up a WarehousePG Database from the start.

## 1. Prerequisites  
Make sure you have the following installed:  
- Docker  
- Docker Compose  

## 2. Clone the Repository
Clone this repository and navigate to the `multi-node` directory:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd training
```

### 3. Export your EDB Repos 2.0 Token

If you are using `zshrc`

```bash
echo 'export EDB_REPO_TOKEN=<YOUR TOKEN>' >> ~/.zshrc
source ~/.zshrc
```

If you are using `bash`

```bash
echo 'export EDB_REPO_TOKEN=<YOUR TOKEN>' >> ~/.bashrc
source ~/.bashrc
```

## 3. Build the WarehousePG Docker Image
Build the WarehousePG Docker image using the following command:

```bash
docker build --secret id=EDB_REPO_TOKEN --platform linux/amd64 --no-cache -t whpg-training .
```

## 4. Start the WarehousePG Cluster
Start the cluster using Docker Compose:  

```bash
docker compose -f docker-compose.yml up --detach
```

This may take few minutes. 

This will start the following containers:  
- **master** → WarehousePG Master Node
- **sdw1** → WarehousePG Segment Node 1
- **sdw2** → WarehousePG Segment Node 2


## 5. Connect to Master Host

 
```bash
docker exec -it master /bin/bash
```


## 6. Interactive WarehousePG Database Setup Script

This repository includes `training.sh`, an interactive script to help you install and configure a multi-node WarehousePG Database environment for training.

## Script Overview: `training.sh`

`training.sh` serves as a guided walkthrough, providing sequential instructions to set up the WarehousePG database manually. 

### The script provides instructions to:

- Create and configure the `gpadmin` user
- Set up **passwordless SSH** between nodes
- Create and configure data directories
- Install `warehouse-pg` database
- Initialize the cluster with `gpinitsystem`

### How to use:

Run the script and follow the on-screen instructions:

```
/tmp/training.sh
```

## 7. Stopping and Restarting the Cluster  

- **Stop without removing data**:  

  ```bash
  docker compose -f docker-compose.yml stop
  ```

- **Restart the cluster with existing data**:  

  ```bash
  docker compose -f docker-compose.yml start

  docker exec -it master /bin/bash

  gpstart -a
  ```

  Database needs to be manually restarted after this using `gpstart -a`

- **Remove everything (including data)**:  

  Following command will stop the multi-container deployment and also remove the network and volumes that belong to the containers. Running this command means it will delete the containers as well as remove the volumes that the containers are associated with.

  ```bash
  docker compose -f docker-compose.yml down -v
  ```


## 8. Notes  

- **Build** the Docker image before running the cluster.  


