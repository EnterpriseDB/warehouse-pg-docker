
#  WarehousePG: Build from src

This Docker VM uses a Rocky Linux 8 image, clones the warehouse-pg main branch, and builds it from source.

## Docker Build and Run Instructions

## 1. Clone the Repository
Clone this repository and navigate to the `build-from-src` directory:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd build-from-src
```

### 2. Build the Docker Image

Use the following command to build the Docker image, specifying the secret `EDB_REPO_TOKEN`:

```bash
docker build --platform linux/amd64 -t whpg-src-build .
```

### 3. Run the Docker Container

Once built, run the container:

```bash
docker run --hostname master --name master -it whpg-src-build
```
Inside the container:

1. `warehouse-pg` repo gets cloned to `/tmp/warehouse-pg` 

2. It creates a demo cluster on a single node with the following configuration. 

```bash
gpadmin=# select * from gp_segment_configuration ;
 dbid | content | role | preferred_role | mode | status | port | hostname | address |                               datadir

------+---------+------+----------------+------+--------+------+----------+---------+----------------------------------------------------------
-----------
    1 |      -1 | p    | p              | n    | u      | 7000 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/qddir/demoDataDir
-1
    3 |       1 | p    | p              | s    | u      | 7003 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast2/demoDataD
ir1
    6 |       1 | m    | m              | s    | u      | 7006 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast_mirror2/de
moDataDir1
    4 |       2 | p    | p              | s    | u      | 7004 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast3/demoDataD
ir2
    7 |       2 | m    | m              | s    | u      | 7007 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast_mirror3/de
moDataDir2
    2 |       0 | p    | p              | s    | u      | 7002 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast1/demoDataD
ir0
    5 |       0 | m    | m              | s    | u      | 7005 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/dbfast_mirror1/de
moDataDir0
    8 |      -1 | m    | m              | s    | u      | 7001 | master   | master  | /tmp/warehouse-pg/gpAux/gpdemo/datadirs/standby
(8 rows)

gpadmin=# show optimizer;
 optimizer
-----------
 on
(1 row)

```

### 4. Rebuild The Cluster: 

```bash
cd /tmp/warehouse-pg

# Configure build environment
./configure --prefix=/usr/local/greenplum-db --enable-depend --with-python --enable-orca 

#Compile and install 
make -j8 
make -j8 install

#Source greenplum path
source /usr/local/greenplum-db/greenplum_path.sh

#Start demo cluster
make create-demo-cluster
```

### 5. Clean All Generated Files: 

```bash
make distclean
```

### 4. Reconnect to the Container

If you want to reconnect:

```bash
docker exec -it master /bin/bash
```

If the container isn’t running:

```bash
docker start master
docker exec -it master /bin/bash
```

### 5. Starting and Stopping the Container

- **To start the container**:

  ```bash
  docker start master
  ```

- **To stop the container**:

  ```bash
  docker stop master
  ```