import psycopg2
from psycopg2.extras import execute_values
from faker import Faker
import random
import getpass
import datetime
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

def insert_fake_data(db_params, schema, table_name, num_rows=10000, batch_size=1000, is_partition_table=False):
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

    partition_info = None
    if is_partition_table:
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

def daterange(start_date, end_date):
    for n in range(int((end_date - start_date).days)):
        yield start_date + datetime.timedelta(n)

def clean_date_expr(expr):
    """Strip surrounding quotes and ::date cast from date strings."""
    if not expr:
        return None
    match = re.match(r"'(\d{4}-\d{2}-\d{2})'(::date)?", expr.strip())
    return match.group(1) if match else None

def get_partition_info(cur, table_name):
    cur.execute("SELECT version();")
    version = cur.fetchone()[0]
    is_gp7 = 'Greenplum Database 7' in version

    if is_gp7:
        # GP7: modern PostgreSQL-style partitions
        cur.execute("""
            SELECT
                a.attname AS partition_key_column,
                pg_get_expr(t.relpartbound, t.oid) AS partition_bounds
            FROM pg_class pt
            JOIN pg_partitioned_table ppt ON pt.oid = ppt.partrelid
            JOIN pg_attribute a ON a.attrelid = pt.oid AND a.attnum = ANY(ppt.partattrs)
            JOIN pg_inherits i ON i.inhparent = pt.oid
            JOIN pg_class t ON t.oid = i.inhrelid
            WHERE pt.relkind = 'p' AND pt.relname = %s
        """, (table_name,))
    else:
        # GP6: Use pg_get_expr to extract text from partition boundary expressions
        cur.execute("""
            SELECT
                a.attname AS partition_key_column,
                pg_get_expr(pr.parrangestart, p.parrelid) AS rangestart,
                pg_get_expr(pr.parrangeend, p.parrelid) AS rangeend,
                pr.parlistvalues AS listvalues,
                pr.parisdefault AS isdefault
            FROM pg_partition p
            JOIN pg_partition_rule pr ON pr.paroid = p.oid
            JOIN pg_class c ON c.oid = p.parrelid
            JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(p.paratts)
            WHERE c.relname = %s
        """, (table_name,))

    rows = cur.fetchall()
    if not rows:
        print("❌ No partitions found.")
        return None

    partition_column = rows[0][0]
    values = []

    for row in rows:
        if is_gp7:
            bounds = row[1]
            print("Partition Bound String:", bounds)
            # GP7: date range FROM('...') TO('...')
            match_date = re.search(r"FROM\s+\('([^']+)'\)\s+TO\s+\('([^']+)'\)", bounds)
            if match_date:
                start = datetime.datetime.strptime(match_date.group(1), '%Y-%m-%d').date()
                end = datetime.datetime.strptime(match_date.group(2), '%Y-%m-%d').date()
                for d in daterange(start, end):
                    values.append(d.isoformat())
                continue
            # GP7: integer range
            match_int = re.search(r"FROM\s+\((\d+)\)\s+TO\s+\((\d+)\)", bounds)
            if match_int:
                values.extend(range(int(match_int.group(1)), int(match_int.group(2))))
                continue
            # GP7: list partitions
            match_list = re.findall(r"IN\s*\((.*?)\)", bounds)
            if match_list:
                for val in match_list:
                    for p in val.split(','):
                        cleaned = p.strip().strip("'").strip('"')
                        values.append(cleaned)
                continue
            # GP7: hash partitions
            if 'MODULUS' in bounds and 'REMAINDER' in bounds:
                print("Detected HASH partition — allowing unrestricted values.")
                return {"column": partition_column, "values": None}
            print("⚠️ Skipped unmatched partition:", bounds)
        else:
            _, rangestart, rangeend, listvals, is_default = row
            print(f"GP6 partition row: start={rangestart}, end={rangeend}, list={listvals}, default={is_default}")

            # Skip default partitions—they accept everything not in others
            if is_default:
                print("Skipping DEFAULT partition.")
                continue
            start = clean_date_expr(rangestart)
            end = clean_date_expr(rangeend)
            # Range partitions (text that could be date or number)
            if start and end:
                try:
                    start_date = datetime.datetime.strptime(start, '%Y-%m-%d').date()
                    end_date = datetime.datetime.strptime(end, '%Y-%m-%d').date()
                    for d in daterange(start_date, end_date):
                        values.append(d.isoformat())
                except ValueError as ve:
                    print(f"⚠️ Date format error: {ve}")
            else:
                print(f"⚠️ Could not clean date expressions: {rangestart} to {rangeend}")

            # List partitions
            if listvals:
                for partval in listvals.split(','):
                    cleaned = partval.strip().strip("'").strip('"')
                    values.append(cleaned)
                continue

            print("⚠️ Skipped unmatched GP6 partition row.")

    values = sorted(set(values))
    if not values:
        print(f"⚠️ No valid partition values found for column '{partition_column}'.")
        return None

    return {"column": partition_column, "values": values}

def main():
    print("ENTER HOST DETAILS:")
    print("===========================")
    host = input("Host (default 'localhost'): ") or 'localhost'
    port = input("Port (default 5432): ") or '5432'
    print("===========================")
    print("\n")
    print("ENTER DB CONNECTION PARAMETERS: ")
    print("===========================")
    dbname = input("Database name: ")
    user = input("Username: ")
    password = getpass.getpass("Password: ")

    schema = input("Schema name (default 'public'): ") or 'public'
    table = input("Table name: ")

    partition_input = input("Is this partition table? (y/n): ").strip().lower()
    is_partition_table = partition_input in ('y', 'yes', 'true', '1')
    num_rows = int(input("Number of rows to generate: "))
    batch_size = int(input("Batch insert size (e.g. 1000): "))
    print("===========================")
    print("\n")
    db_params = {
        'dbname': dbname,
        'user': user,
        'password': password,
        'host': host,
        'port': port
    }
    insert_fake_data(db_params, schema, table, num_rows, batch_size, is_partition_table)

if __name__ == '__main__':
    main()