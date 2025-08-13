
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
### 3. Create Data Directories

```
mkdir -p datadirs/master datadirs/primary datadirs/mirror
```
### 4. Build WarehousePG Docker Image and Start the container

Run the following command to build the docker image and start the container.

```bash
DOCKER_BUILDKIT=1 docker compose up --build --detach
```
Note: This process may take a few minutes.

This will start the following:

`mdw` - A single-node WarehousePG `6.27.1` cluster with PXF installed. Hadoop is configured as well and can be started manually.
Refer to [Configuring PXF with WarehousePG](#configuring-pxf-with-warehousepg) to setup PXF and Hadoop.

### 5. Access the Master Host

```bash
docker exec -it mdw /bin/bash
```

- **Restart the cluster with existing data**:

  ```bash
  docker compose start

  docker exec -it mdw /bin/bash

  gpstart -a
  ```
- **Remove everything (including data)**:

  Following command will stop the deployment and also remove the network and volumes that belong to the containers. Running this command means it will delete the containers as well as remove the volumes that the containers are associated with.

  ```bash
  docker compose down -v
  ```

  This will not remove the `datadirs` from your host machine, so these needs to be removed manually.

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

## Hive Setup

To Start hive metastore:
1. `sudo su - hadoop`

```bash
schematool -initSchema -dbType derby
hive --service metastore &
```

`schematool -initSchema -dbType derby` This initialization of schema needs to be done only once. 

2. Generate sample data

```bash
echo -e "1\tAlice\n2\tCharlie\n3\tEmily" > /tmp/employee.txt
```

2. Create an Employee table in hive

```bash
hive


CREATE TABLE employee (
  id INT,
  name STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY '\t'
STORED AS TEXTFILE;
```

3. Run `Show tables;`  (optional)

4. Load data into the employee table 

```bash
LOAD DATA LOCAL INPATH '/tmp/employee.txt' INTO TABLE employee;
```

5. Select table

```bash
select * from employee;
```

6. Exit `hadoop` user:

```bash
exit
```
Now you are back to the `gpadmin` user where `warehouse-pg` and PXF are running. 


## Retrieving Hive Data

1. Create a hive server directory in $PXF_BASE/servers:

```bash
mkdir -p $PXF_BASE/servers/srvr_hive
```

2.  Copy `$PXF_HOME/templates/core-site.xml`  and `$PXF_HOME/templates/hive-site.xml` to `srvr_hive`

```bash
cp $PXF_HOME/templates/core-site.xml $PXF_BASE/servers/srvr_hive
cp $PXF_HOME/templates/hive-site.xml $PXF_BASE/servers/srvr_hive
```

Inspect the contents of `$PXF_BASE/servers/srvr_hive\hive-site.xml`. We are using same configuration in `$HIVE_HOME/conf/hive_site.xml` to run hive metastore.   

3. Restart pxf

```bash
pxf restart
```

4. Create an `external table` to read from Hive date using hive profile: 

```bash
CREATE EXTERNAL TABLE emp_hive (id int, name text)
  location ('pxf://default.employee?PROFILE=hive&SERVER=srvr_hive')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import');
```

5. Run select query to read the data:

```bash
select * from emp_hive ;
 id |  name
----+---------
  1 | Alice
  2 | Charlie
  3 | Emily
  (3 rows)
```
## What We did here:

- Ran WarehousePG in a Docker container.
- Integrated Hadoop with WarehousePG using PXF.
- Read and wrote data to/from Hadoop using PXF external tables.
- Read data from Hive using PXF external tables.

