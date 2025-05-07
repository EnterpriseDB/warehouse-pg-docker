
#  WarehousePG Single-Node Setup with Docker

This Docker VM sets up WarehousePG on Rocky Linux 8. To install a different version, simply modify the Dockerfile accordingly.

## Docker Build and Run Instructions

### 1. Clone the Repository
Clone this repository and navigate to the `single-node` directory:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd single-node
```

### 2. Export your EDB Repos 2.0 Token

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

### 3. Enable Docker BuildKit

First, enable Docker BuildKit to improve the build performance and capabilities:

```bash
export DOCKER_BUILDKIT=1
```

### 4. Create Data Directories 

```
mkdir -p datadirs/master datadirs/primary datadirs/mirror
```

### 5. Build the Docker Image

Use the following command to build the Docker image, specifying the secret `EDB_REPO_TOKEN`:

```bash
docker build --secret id=EDB_REPO_TOKEN --platform linux/amd64 --no-cache -t warehousepg-el8 .
```

### 6. Start the WarehousePG Cluster 

After building the image, you can start the cluster using Docker Compose:

```bash
docker compose -f docker-compose.yml up --detach
```
Note: This process may take a few minutes.

This will start the following:

`mdw` - A single-node WarehousePG cluster with PXF installed. Hadoop is configured as well and can be started manually.
Refer to [Configuring PXF with WarehousePG](#configuring-pxf-with-warehousepg) to setup PXF and Hadoop.

### 7. Connect Back to the Container

To connect back to the running Docker container, use the following command:

```bash
docker exec -it mdw /bin/bash
```

If it doesn't work, start the container and then connect again:

```bash
docker start mdw
docker exec -it mdw /bin/bash
```

### 8. Starting and Stopping the Container

- **To start the container**:

  ```bash
  docker start mdw
  ```

- **To stop the container**:

  ```bash
  docker stop mdw
  ```

## Configuring PXF with WarehousePG

1. PXF is already installed. Start PXF by running the follwing command:

```bash
pxf start
```
2. Create PXF extension in WarehousePG: 

```bash
psql

create extension PXF; 
```

3. Create an `external table` to read from Hadoop File System: 

```bash
CREATE EXTERNAL TABLE pxf_ext_tbl(id int, name text, age int)
  LOCATION ('pxf://data/sample.csv?PROFILE=hdfs:csv&server=srvr_hdfs')
FORMAT 'CSV' (delimiter=E',');
```

4. Create a server-specific directory:

The above external table uses `server=srvr_hdfs`. Create a directory with this name under `$PXF_BASE/servers` : 

```bash
mkdir -p $PXF_BASE/servers/srvr_hdfs
```

5. Copy `core-site.xml` from `$PXF_HOME/templates`

```bash
cp $PXF_HOME/templates/core-site.xml $PXF_BASE/servers/srvr_hdfs
```

6. Restart the PXF: 

```bash
pxf restart
```

This `core-site.xml` contains the following: 

```bash
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://0.0.0.0:8020</value>
    </property>
</configuration>
```

This is the default configuration where we will run the hadoop services. 


## Setting Up Hadoop and Loading Data

To Start hadoop namenode and datanode:
1. `sudo su - hadoop`
2. `/opt/hadoop/sbin/start-dfs.sh`

3. Create data directories in Hadoop:

```bash
 hdfs dfs -mkdir /data
 hdfs dfs -mkdir -p /data/write_data
``` 

4. Create a data file in `/tmp` directory. This file contains the columns as per our external table:

```bash
echo -e "1,John Doe,30\n2,Jane Smith,25\n3,Emily Johnson,35" > /tmp/sample.csv
```

5. Copy your data file to `/data` directory:

```bash
hdfs dfs -put /tmp/sample.csv /data
```

6. List the file(s) in `/data` directory:

```bash
hdfs dfs -ls /data
```

7. Exit `hadoop` user:

```bash
exit
```

Now you are back to the `gpadmin` user where `warehouse-pg` and PXF are running. 


## Retrieving Hadoop Data

Our external table is configured to fetch data from hadoop. Run a select query on the external table: 

```bash
select * from pxf_ext_tbl;
```

Results: 

```bash
gpadmin=# select * from pxf_ext_tbl;
 id |     name      | age
----+---------------+-----
  1 | John Doe      |  30
  2 | Jane Smith    |  25
  3 | Emily Johnson |  35
(3 rows)
```

## Writing data To Hadoop from WarehousePG

1. Create a writable external table. This table will write data to `/data/pxf_data` in hadoop: 

```bash

create writable external table w_pxf_data(id int, name text)
LOCATION ('pxf://data/pxf_data?PROFILE=hdfs:csv&server=srvr_hdfs')
FORMAT 'CSV' (delimiter=E',');


insert into w_pxf_data values (1, 'Mac'),(2,'Windows'),(3,'OSX'),(4,'Android');

``` 

2. Read from the data we just wrote into hadoop. Create a readable (default) external table and query this table: 

```bash
create external table r_pxf_data(id int, name text)
LOCATION ('pxf://data/pxf_data?PROFILE=hdfs:csv&server=srvr_hdfs')
FORMAT 'CSV' (delimiter=E',');
```

```bash
select * from r_pxf_data;
 id |  name
----+---------
  1 | Mac
  3 | OSX
  4 | Android
  2 | Windows
(4 rows)
```

## What We did here:

- Ran WarehousePG in a Docker container.
- Integrated Hadoop with WarehousePG using PXF.
- Read and wrote data to/from Hadoop via external tables.

