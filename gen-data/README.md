
# Data Generator for PostgreSQL / WarehousePG

This Python script generates and inserts fake data into a specified PostgreSQL or Greenplum table, including support for partitioned tables (range and list partitions).

---

## Prerequisites

- Python 3.7+
- PostgreSQL or Greenplum database with accessible tables.
- Required Python packages listed in `requirements.txt`.

---

## Installation

1. Clone the repo:

```bash
git clone https://github.com/warehouse-pg/whpg-docker.git
cd whpg-docker/gen-data
````

3. Install dependencies:

```bash
pip install -r requirements.txt
```

---

## Usage

Run the script:

```bash
python generate_data.py
```

You will be prompted to enter:

* Database connection details (host, port, username, password, dbname).
* Schema name (default: `public`).
* Table name.
* Number of rows to generate.
* Batch insert size.

---

## How it works

1. The script queries the database schema to retrieve the target table's column names and data types.
2. It detects whether the table is partitioned and tries to extract partition key columns and valid partition values.
3. For each row, it generates appropriate fake data per column.
4. Inserts data in batches to improve performance.
5. Prints a final summary of inserted rows.

---

## Troubleshooting

* **Error about partition keys:** The script uses database metadata to determine partitions. If you have a custom partitioning scheme, you might need to adjust the `get_partition_info` function.
* **Missing modules:** Run `pip install -r requirements.txt`.
* **Connection errors:** Verify your connection parameters and network access to the database.

---

## Dependencies

* [psycopg2-binary](https://pypi.org/project/psycopg2-binary/)
* [Faker](https://pypi.org/project/Faker/)
