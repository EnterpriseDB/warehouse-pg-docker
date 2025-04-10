
# WarehousePG Multi-Node Setup with Docker

This guide will help you set up a multi-node WarehousePG Database using Docker Compose.

## 1. Prerequisites  
Make sure you have the following installed:  
- Docker  
- Docker Compose  

## 2. Clone the Repository
Clone this repository and navigate to the `multi-node` directory:

```bash
git clone https://github.com/hpedb/warehousepg-docker.git
cd multi-node
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

## 4. Create Required Data Directories
Create the directories required for data persistence:  

```bash
mkdir -p datadirs/master
mkdir -p datadirs/sdw1_primary1 datadirs/sdw1_primary2 datadirs/sdw1_mirror1 datadirs/sdw1_mirror2
mkdir -p datadirs/sdw2_primary1 datadirs/sdw2_primary2 datadirs/sdw2_mirror1 datadirs/sdw2_mirror2
```

## 5. Build the WarehousePG Docker Image
Build the WarehousePG Docker image using the following command:

```bash
docker build --secret id=EDB_REPO_TOKEN --platform linux/amd64 --no-cache -t warehousepg-multi-node .
```

## 6. Start the WarehousePG Cluster
Start the cluster using Docker Compose:  

```bash
docker compose -f docker-compose.yml up --detach
```

This may take few minutes. 

This will start the following containers:  
- **mdw** → WarehousePG Master Node
- **sdw1** → WarehousePG Segment Node 1
- **sdw2** → WarehousePG Segment Node 2


## 7. Connect to Master Host

 
```bash
docker exec -it mdw /bin/bash
```

## 8. Stopping and Restarting the Cluster  

- **Stop without removing data**:  

  ```bash
  docker compose -f docker-compose.yml stop
  ```

- **Restart the cluster with existing data**:  

  ```bash
  docker compose -f docker-compose.yml start

  docker exec -it mdw /bin/bash

  gpstart -a
  ```

  Database needs to be manually restarted after this using `gpstart -a`

- **Remove everything (including data)**:  

  Following command will stop the multi-container deployment and also remove the network and volumes that belong to the containers. Running this command means it will delete the containers as well as remove the volumes that the containers are associated with.

  ```bash
  docker compose -f docker-compose.yml down -v
  ```

  This will not remove the `datadirs` from your host machine, so these needs to be removed manually.

  ```bash
  rm -rf datadirs/
  ```

## 9. Directory Structure  

```
multi-node/
│── docker-compose.yml
│── Dockerfile                  # Dockerfile for building the WarehousePG image
│── datadirs/                   # Persistent storage for WarehousePG data
│   ├── master/                 # Master node data
│   ├── sdw1_primary1/          # Primary segment data (sdw1)
│   ├── sdw1_primary2/       
│   ├── sdw1_mirror1/           # Mirror segment data (sdw1)
│   ├── sdw1_mirror2/       
│   ├── sdw2_primary1/          # Primary segment data (sdw2)
│   ├── sdw2_primary2/       
│   ├── sdw2_mirror1/           # Mirror segment data (sdw2)
│   ├── sdw2_mirror2/       
└── README.md
```

## 10. Notes  

- **Build** the Docker image before running the cluster.  
- Data is persisted in the `datadirs/` folder.  
- To reset the cluster, delete the `datadirs/` folder.  

