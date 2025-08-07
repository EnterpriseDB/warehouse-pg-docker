import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import random
import getpass
import re

fake = Faker()

def generate_value(data_type, char_max_length=None, column_name=None, partition_info=None):
    name = column_name.lower()

    # Match valid partition values if this is the partition column
    if partition_info and name == partition_info['column'].lower():
        if partition_info['values'] is not None:
            return random.choice(partition_info['values'])
        else:
            print(f"Generating unrestricted value for HASH partition column '{name}'")

    if 'email' in name:
        return fake.email()
    if 'name' in name:
        return fake.name()
    if 'phone' in name:
        return fake.phone_number()
    if 'address' in name:
        return fake.address()
    if 'date' in name:
        return fake.date()
    if 'time' in name:
        return fake.date_time()

    if data_type in ('integer', 'bigint', 'smallint'):
        return random.randint(1, 1000)
    elif data_type in ('numeric', 'decimal', 'real', 'double precision'):
        return round(random.uniform(1, 1000), 2)
    elif data_type in ('text', 'character varying', 'character'):
        if char_max_length:
            value = fake.word()
            return value[:char_max_length]
        else:
            return fake.sentence(nb_words=6)
    elif data_type == 'boolean':
        return random.choice([True, False])
    elif data_type == 'date':
        return fake.date()
    elif data_type in ('timestamp without time zone', 'timestamp with time zone'):
        return fake.date_time()
    else:
        return fake.word()

def insert_fake_data(db_params, schema, table_name, num_rows=10000, batch_size=1000):
    try:
        conn = psycopg2.connect(**db_params)
        cur = conn.cursor()
    except Exception as e:
        print(f"Error connecting to database: {e}")
        return

    cur.execute("""
        SELECT column_name, data_type, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = %s AND table_name = %s
        ORDER BY ordinal_position
    """, (schema, table_name))

    columns = cur.fetchall()
    if not columns:
        print(f"Table {schema}.{table_name} not found or has no columns.")
        cur.close()
        conn.close()
        return

    col_names = [col[0] for col in columns]
    insert_query = f"INSERT INTO {schema}.{table_name} ({', '.join(col_names)}) VALUES %s"
    partition_info = get_partition_info(cur, table_name)

    #print("partition info is --- ", partition_info)

    rows = []
    inserted_count = 0

    try:
        for i in range(num_rows):
            row = []
            for col_name, data_type, char_max_len in columns:
                val = generate_value(data_type, char_max_len, col_name, partition_info)
                row.append(val)
            rows.append(tuple(row))

            if len(rows) >= batch_size:
                execute_values(cur, insert_query, rows)
                conn.commit()
                inserted_count += len(rows) 
                print(f"Inserted {inserted_count} rows...", end='\r')
                rows = []

        if rows:
            execute_values(cur, insert_query, rows)
            conn.commit()
            print(f"\n Inserted {num_rows} rows.")

    except Exception as e:
        print(f"Error inserting data: {e}")

    print(f"\n✅ Inserted {inserted_count} rows into {schema}.{table_name}.")

    cur.close()
    conn.close()

def get_partition_info(cur, table_name):
    """
    Detects partition column and valid bounds for range partitions.
    Supports Greenplum/PostgreSQL.
    """
    cur.execute("""
        SELECT
            a.attname AS partition_key_column,
            pg_get_expr(t.relpartbound, t.oid) AS partition_bounds
        FROM
            pg_class pt
        JOIN
            pg_partitioned_table ppt ON pt.oid = ppt.partrelid
        JOIN
            pg_attribute a ON a.attrelid = pt.oid AND a.attnum = ANY(ppt.partattrs)
        JOIN
            pg_inherits i ON i.inhparent = pt.oid
        JOIN
            pg_class t ON t.oid = i.inhrelid
        WHERE
            pt.relkind = 'p'
            AND pt.relname = %s
    """, (table_name,))

    rows = cur.fetchall()
    if not rows:
        return None

    partition_column = rows[0][0]  # first column of first row is the partition column name
    values = []

    for _, bounds in rows:
        print("Partition Bound String:", bounds)

        bounds_clean = bounds.strip().upper()

        # Skip DEFAULT
        if bounds_clean == 'DEFAULT':
            print("Skipping DEFAULT partition.")
            continue

        # HASH Partition (no restriction needed)
        if 'MODULUS' in bounds_clean and 'REMAINDER' in bounds_clean:
            print("Detected HASH partition — allowing unrestricted values.")
            return {
                "column": partition_column,
                "values": None
            }

        # RANGE partition
        match_range = re.search(r"FROM\s+\((\d+)\)\s+TO\s+\((\d+)\)", bounds)
        if match_range:
            start = int(match_range.group(1))
            end = int(match_range.group(2))
            values.extend(range(start, end))
            continue

        # LIST partition
        match_list = re.findall(r"IN\s*\((.*?)\)", bounds)
        if match_list:
            for val in match_list:
                parts = val.split(',')
                for p in parts:
                    cleaned = p.strip().strip("'").strip('"')
                    values.append(cleaned)
            continue

        print(f"⚠️ Skipped unmatched partition bound: {bounds}")

    values = sorted(set(values))
    if not values:
        print(f"⚠️ No valid partition values found for column '{partition_column}'.")
        return None

    return {
        "column": partition_column,
        "values": values
    }

def main():
    print("🔐  Enter database connection details: 🔐 ")
    dbname = input("Database name: ")
    user = input("Username: ")
    password = getpass.getpass("Password: ")
    host = input("Host (default 'localhost'): ") or 'localhost'
    port = input("Port (default 5432): ") or '5432'

    schema = input("Schema name (default 'public'): ") or 'public'
    table = input("Table name: ")
    num_rows = int(input("Number of rows to generate: "))
    batch_size = int(input("Batch insert size (e.g. 1000): "))

    db_params = {
        'dbname': dbname,
        'user': user,
        'password': password,
        'host': host,
        'port': port
    }
    insert_fake_data(db_params, schema, table, num_rows, batch_size)

if __name__ == '__main__':
    main()