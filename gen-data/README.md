
# Data Generator for PostgreSQL / WarehousePG

This Python script generates and inserts fake data into a specified PostgreSQL or WarehousePG table, including support for partitioned tables (range and list partitions).

---

## Prerequisites

- Python 3.7+
- PostgreSQL or WarehousePG database with accessible tables.
- Required Python packages listed in `requirements.txt`.

---

## Installation

1. Clone the repo:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd whpg-docker/gen-data
````

3. Build and start the container

```bash
docker compose up --build --detach
```

4. Access the `data-host` Host

```bash
docker exec -it data-host /bin/bash
```
---

## Run the script


```bash
python generate_data.py
```

You will be prompted to enter:

* Host Name and Port
* Database connection Params (username, password, dbname).
* Schema name (default: `public`).
* Table name.
* If the table is Partitioned
* Number of rows to generate.
* Batch insert size.

Example:

```bash
ENTER HOST DETAILS:
===========================
Host (default 'localhost'): cdw
Port (default 5432):
===========================


ENTER DB CONNECTION PARAMETERS:
===========================
Database name: gpadmin
Username: gpadmin
Password:
Schema name (default 'public'):
Table name: listpart
Is this partition table? (y/n): y
Number of rows to generate: 100
Batch insert size (e.g. 1000): 10
===========================

Inserted 100 rows...
✅ Inserted 100 rows into public.listpart.
```
---

## How it works

1. This script runs in its own container and can easily to other containers which are present in the same docker network, which in this case is
    `whpg-network`. So you insert data in your `single_node` or `multi_node` cluster here using this container.
2. The script queries the database schema to retrieve the target table's column names and data types.
3. It detects whether the table is partitioned and tries to extract partition key columns and valid partition values.
4. For each row, it generates appropriate fake data per column.
5. Inserts data in batches to improve performance.
6. Prints a final summary of inserted rows.
7. You can use this to generate data for both WHPG v6.27.1 and v7.2.1

---

## Troubleshooting

* **Error about partition keys:** The script uses database metadata to determine partitions. If you have a custom partitioning scheme, you might need to adjust the `get_partition_info` function.
* **Missing modules:** Run `pip install -r requirements.txt`.
* **Connection errors:** Verify your connection parameters and network access to the database.

---

## Dependencies

* [psycopg2-binary](https://pypi.org/project/psycopg2-binary/)
* [Faker](https://pypi.org/project/Faker/)
