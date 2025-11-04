# Phoenix Table Creation Guide

This guide explains how to create tables in HBase using Apache Phoenix SQL syntax.

## Overview

Apache Phoenix provides a SQL interface over HBase. When you create a table using Phoenix SQL, Phoenix automatically creates the underlying HBase table structure.

## Creating testtable

The `testtable` is a sample table created to demonstrate Phoenix table creation and operations.

### Table Schema

```sql
CREATE TABLE IF NOT EXISTS testtable (
    id INTEGER NOT NULL,
    name VARCHAR(100),
    email VARCHAR(255),
    age INTEGER,
    created_date DATE,
    active BOOLEAN,
    CONSTRAINT pk_testtable PRIMARY KEY (id)
);
```

### Table Structure

- **id** (INTEGER, PRIMARY KEY): Unique identifier for each record
- **name** (VARCHAR(100)): Person's name
- **email** (VARCHAR(255)): Email address
- **age** (INTEGER): Age in years
- **created_date** (DATE): Date when record was created
- **active** (BOOLEAN): Active status flag

### Creating the Table

#### Option 1: Using the Application

The application automatically creates `testtable` when you run it:

```bash
dotnet run
```

#### Option 2: Using SQL Script

Execute the SQL script:

```bash
# If you have a Phoenix SQL client
sqlline.py localhost:8765 < tests/create_testtable_phoenix.sql
```

#### Option 3: Using Phoenix Query Server

Connect to Phoenix Query Server on port 8765 and execute:

```sql
CREATE TABLE IF NOT EXISTS testtable (
    id INTEGER NOT NULL,
    name VARCHAR(100),
    email VARCHAR(255),
    age INTEGER,
    created_date DATE,
    active BOOLEAN,
    CONSTRAINT pk_testtable PRIMARY KEY (id)
);
```

### Inserting Sample Data

```sql
UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (1, 'John Doe', 'john.doe@example.com', 30, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (2, 'Jane Smith', 'jane.smith@example.com', 25, CURRENT_DATE(), true);

UPSERT INTO testtable (id, name, email, age, created_date, active) 
VALUES (3, 'Bob Johnson', 'bob.johnson@example.com', 35, CURRENT_DATE(), false);
```

### Querying the Table

```sql
-- Select all records
SELECT * FROM testtable ORDER BY id;

-- Select active records only
SELECT * FROM testtable WHERE active = true;

-- Count records
SELECT COUNT(*) as total_records FROM testtable;

-- Query by email
SELECT * FROM testtable WHERE email = 'john.doe@example.com';
```

## Adding Binary-Encoded Data (Phoenix-Compatible)

Phoenix uses a binary encoding format for storing data in HBase. When you insert data via Phoenix SQL, it automatically handles the binary encoding, making the data readable in Phoenix queries.

### Understanding Binary Encoding

When you insert data via Phoenix SQL:

- **Row keys** are binary-encoded based on the primary key data type (e.g., INTEGER keys appear as `\x80\x00\x00\x01` for ID 1)
- **Column qualifiers** are binary-encoded (e.g., `\x80\x0B`, `\x80\x0C` for column positions)
- **Values** are encoded according to their data types (VARCHAR as strings, DATE as binary timestamps, etc.)

### Adding Binary-Encoded Data via Phoenix SQL

The recommended way to add binary-encoded data that's readable in Phoenix is to use Phoenix SQL via the REST API:

```bash
# Insert data via Phoenix SQL (automatically binary-encoded)
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO USERS (id, username, email, created_date) VALUES (7, '\''grace_lee'\'', '\''grace@example.com'\'', CURRENT_DATE())"
  }'
```

**Example: Adding multiple rows to USERS table:**

```bash
# Row 1
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO USERS (id, username, email, created_date) VALUES (7, '\''grace_lee'\'', '\''grace@example.com'\'', CURRENT_DATE())"}'

# Row 2
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO USERS (id, username, email, created_date) VALUES (8, '\''henry_taylor'\'', '\''henry@example.com'\'', CURRENT_DATE())"}'

# Row 3
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO USERS (id, username, email, created_date) VALUES (9, '\''ivy_williams'\'', '\''ivy@example.com'\'', CURRENT_DATE())"}'
```

### Verifying Binary-Encoded Data

1. **View in HBase shell** (binary format):

   ```bash
   docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "scan 'USERS'"
   ```

   You'll see binary-encoded row keys like `\x80\x00\x00\x07` and column qualifiers like `\x80\x0B`, `\x80\x0C`.

2. **Query via Phoenix SQL** (readable format):

   ```bash
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql": "SELECT * FROM USERS WHERE id >= 7 ORDER BY id"}'
   ```

   Phoenix automatically decodes the binary data and returns readable values.

### Key Points

- ✅ **Use Phoenix SQL** to insert data into Phoenix tables - it handles binary encoding automatically
- ✅ **Binary-encoded data** is readable in Phoenix queries via SQL
- ✅ **HBase shell scans** show the binary format, but Phoenix queries decode it correctly
- ⚠️ **Direct HBase shell inserts** (using `put` commands) create readable text format, which may not work correctly with Phoenix queries depending on your table structure

### Example: USERS Table Binary Encoding

For the USERS table with schema:

- `id INTEGER` (PRIMARY KEY)
- `username VARCHAR(50)`
- `email VARCHAR(100)`
- `created_date DATE`

Phoenix encodes:

- Row key `id=7` as: `\x80\x00\x00\x07`
- Column qualifiers:
  - `username` → `\x80\x0B`
  - `email` → `\x80\x0C`
  - `created_date` → `\x80\x0D`
- Values: VARCHAR stored as strings, DATE stored as binary timestamps

When querying via Phoenix SQL, all data is automatically decoded and returned in readable format.

## Direct HBase Insertion with Phoenix Encoding

### Challenge: Matching Phoenix's Encoding Format

While it's possible to insert data directly into HBase using HBase shell or HBase REST API, matching Phoenix's binary encoding format is complex and not recommended for production use.

### Why Direct Insertion is Complex

Phoenix uses a sophisticated binary encoding scheme that requires:

1. **Proper Row Key Encoding**:
   - INTEGER row keys are encoded as `\x80\x00\x00\xXX` (binary format)
   - The encoding format varies by data type (INTEGER, VARCHAR, DATE, etc.)

2. **Column Qualifier Encoding**:
   - Phoenix maps column names to encoded qualifiers (e.g., `\x80\x0B` for USERNAME)
   - The encoding is internal to Phoenix and requires access to Phoenix's encoding utilities

3. **Value Encoding**:
   - Data types are encoded in specific binary formats
   - VARCHAR values are stored as UTF-8 strings
   - DATE values are stored as binary timestamps
   - INTEGER values have specific binary representations

### Requirements for Direct HBase Insertion with Phoenix Encoding

To insert data directly into HBase matching Phoenix's encoding format, you would need:

- **A Java program using HBase's Java API** to insert binary data
- **Access to Phoenix's internal encoding utilities** to properly encode row keys, column qualifiers, and values
- **Proper binary byte manipulation** to handle the complex encoding schemes

**Note:** HBase shell treats escape sequences like `\x80` as literal strings, not binary bytes, making direct insertion via shell commands ineffective for matching Phoenix's encoding.

### Recommended Approach: Use Phoenix SQL (UPSERT)

**For production use, Phoenix SQL (UPSERT) is strongly recommended** because it:

- ✅ **Ensures correct encoding** - Phoenix automatically handles all binary encoding
- ✅ **Maintains data integrity** - Ensures data is properly formatted and readable by Phoenix queries
- ✅ **Simplifies development** - No need to understand Phoenix's internal encoding schemes
- ✅ **Provides type safety** - Phoenix validates data types and handles conversions
- ✅ **Works seamlessly** - Data inserted via Phoenix SQL is immediately visible in Phoenix queries

### Example: Inserting Data via Phoenix SQL

```bash
# Insert data using Phoenix SQL (recommended)
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (4, '\''david_wilson'\'', '\''david@example.com'\'', CURRENT_DATE())"
  }'
```

The data inserted via Phoenix SQL is automatically encoded correctly and is immediately visible through Phoenix queries.

## Adding Rows via HBase Shell and Querying via Phoenix

When you insert data directly via HBase shell (using `put` commands), the data is stored in readable text format, not Phoenix's binary encoding. **Phoenix views are the recommended approach** to query this data in Phoenix.

### Why Use Phoenix Views for HBase-Inserted Data?

- ✅ **Data Format Mismatch**: HBase shell inserts create readable text format, which doesn't match Phoenix's binary encoding
- ✅ **SQL Access**: Phoenix views provide SQL querying capabilities over HBase tables
- ✅ **Schema Mapping**: Views map HBase column families and columns to SQL-friendly column names
- ✅ **No Data Migration**: Views work directly with existing HBase data without requiring data conversion

### Complete Workflow: HBase Shell Insert → Phoenix View Query

#### Step 1: Create HBase Table via HBase Shell

⚠️ **IMPORTANT:** Use UPPERCASE for table names to match Phoenix view naming requirements.

```bash
docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<EOF
create 'EMPLOYEE_DATA', 'info', 'contact', 'status'
EOF
```

#### Step 2: Insert Data via HBase Shell

```bash
docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'EMPLOYEE_DATA', '1', 'info:name', 'Alice'
put 'EMPLOYEE_DATA', '1', 'info:score', '100'
put 'EMPLOYEE_DATA', '1', 'contact:email', 'alice@example.com'
put 'EMPLOYEE_DATA', '1', 'status:status', 'active'

put 'EMPLOYEE_DATA', '2', 'info:name', 'Bob'
put 'EMPLOYEE_DATA', '2', 'info:score', '200'
put 'EMPLOYEE_DATA', '2', 'contact:email', 'bob@example.com'
put 'EMPLOYEE_DATA', '2', 'status:status', 'active'
EOF
```

#### Step 3: Verify Data in HBase

```bash
docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "scan 'EMPLOYEE_DATA'"
```

You'll see readable text format like:

```text
ROW              COLUMN+CELL
1                column=info:name, timestamp=..., value=Alice
1                column=info:score, timestamp=..., value=100
```

#### Step 4: Create Phoenix View

### ⚠️ CRITICAL: View Name Requirements for HBase Tables

**Before creating a Phoenix view on an HBase table, you MUST:**

1. **Use UPPERCASE for both HBase table and view names**: Phoenix requires uppercase names (e.g., `EMPLOYEE_DATA`, not `employee_data`).
2. **Match names exactly**: The view name must exactly match the HBase table name (case-sensitive).

**Example:**
```bash
# Create HBase table with UPPERCASE name
create 'EMPLOYEE_DATA', 'info', 'contact', 'status'

# Create Phoenix view with the SAME UPPERCASE name
CREATE VIEW "EMPLOYEE_DATA" (
    "rowkey" VARCHAR PRIMARY KEY,
    "info"."name" VARCHAR,
    ...
)
```

##### Option A: Using the dedicated `/views` endpoint (Recommended)

```bash
curl -X POST http://localhost:8099/api/phoenix/views \
  -H "Content-Type: application/json" \
  -d '{
    "viewName": "EMPLOYEE_DATA",
    "hBaseTableName": "EMPLOYEE_DATA",
    "namespace": "default",
    "columns": [
      { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
      { "name": "name", "type": "VARCHAR", "isPrimaryKey": false, "columnFamily": "info" },
      { "name": "score", "type": "INTEGER", "isPrimaryKey": false, "columnFamily": "info" },
      { "name": "email", "type": "VARCHAR", "isPrimaryKey": false, "columnFamily": "contact" },
      { "name": "status", "type": "VARCHAR", "isPrimaryKey": false, "columnFamily": "status" }
    ]
  }'
```

**Important:** The `viewName` and `hBaseTableName` must match exactly (same case). Use uppercase for both.

##### Option B: Using SQL directly

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS \"EMPLOYEE_DATA\" (\"rowkey\" VARCHAR PRIMARY KEY, \"info\".\"name\" VARCHAR, \"info\".\"score\" INTEGER, \"contact\".\"email\" VARCHAR, \"status\".\"status\" VARCHAR)"
  }'
```

**Important Phoenix View Syntax for HBase Tables:**

- Use **double quotes** around all identifiers: `"EMPLOYEE_DATA"`, `"rowkey"`, etc.
- **View name MUST be UPPERCASE** and match the HBase table name exactly
- Map column families using **dot notation**: `"info"."name"`, `"contact"."email"`
- The `rowkey` must be declared as **PRIMARY KEY**
- Column family names must match HBase exactly (case-sensitive)

#### Step 5: Query Data via Phoenix View

```bash
# Get all rows (view name matches table name: EMPLOYEE_DATA)
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EMPLOYEE_DATA ORDER BY rowkey"
  }'

# Filter with WHERE clause
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EMPLOYEE_DATA WHERE status = '\''active'\''"
  }'

# Query with specific columns
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, name, email, score FROM EMPLOYEE_DATA WHERE score > 150"
  }'
```

### Key Differences: HBase Shell vs Phoenix SQL Inserts

| Aspect | HBase Shell Insert | Phoenix SQL Insert |
|--------|-------------------|-------------------|
| **Data Format** | Readable text | Binary-encoded |
| **Query Method** | Requires Phoenix view | Direct Phoenix SQL query |
| **Row Key** | String (e.g., `'1'`) | Binary-encoded (e.g., `\x80\x00\x00\x01`) |
| **Column Qualifiers** | Readable (e.g., `info:name`) | Binary-encoded (e.g., `\x80\x0B`) |
| **Use Case** | Direct HBase operations | Phoenix-native operations |

### When to Use Each Approach

#### Use HBase Shell + Phoenix View

- ✅ You need direct control over HBase table structure
- ✅ You're inserting data from external systems via HBase REST API
- ✅ You have existing HBase tables with data
- ✅ You want to maintain HBase-native operations

#### Use Phoenix SQL (binary-encoded)

- ✅ You're building a Phoenix-native application
- ✅ You need Phoenix indexes and secondary indexes
- ✅ You want automatic type conversion and validation
- ✅ You need full Phoenix SQL features (joins, aggregations, etc.)

### Example: USERS Table with HBase Shell Insert

If you want to add rows to the USERS table via HBase shell and query via Phoenix:

```bash
# Insert via HBase shell (readable format)
docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'USERS', '10', '0:USERNAME', 'jack_jones'
put 'USERS', '10', '0:EMAIL', 'jack@example.com'
put 'USERS', '10', '0:CREATED_DATE', '2025-11-04'
EOF
```

**Note:** Since USERS is a Phoenix table (created via Phoenix SQL), it uses binary encoding. HBase shell inserts may not work correctly with Phoenix queries. For Phoenix tables, **always use Phoenix SQL** to insert data.

**For HBase-native tables** (created via HBase shell), use the Phoenix view approach shown above.

### Troubleshooting

#### Issue: View creation fails with "Table undefined"

**This is usually caused by a name mismatch!**

- Verify HBase table exists: `scan 'TABLE_NAME'`
- **CRITICAL**: Check that both the HBase table name and view name are UPPERCASE and match exactly (case-sensitive)
- Ensure table is in the correct namespace (default if not specified)
- **Solution**: If your HBase table is `my_table`, recreate it as `MY_TABLE`, then create the view as `MY_TABLE`

**Example fix:**
```bash
# If table was created as lowercase
drop 'my_table'  # Drop old table
create 'MY_TABLE', 'info'  # Create with uppercase
# Then create view as "MY_TABLE"
```

#### Issue: View returns no data

- Verify HBase data exists: `scan 'table_name'`
- Check column family and column names match exactly
- Ensure view definition uses correct column family mapping

#### Issue: Column not found

- Use double quotes: `"info"."name"` not `info.name`
- Verify column family and column exist in HBase: `describe 'table_name'`

For more details on Phoenix views, see [README_VIEWS.md](./README_VIEWS.md).

## Phoenix SQL vs HBase

### Phoenix SQL

- Uses SQL syntax (CREATE TABLE, SELECT, INSERT, etc.)
- Provides schema and data types
- Automatic HBase table creation
- Supports indexes, joins, and complex queries

### Direct HBase

- Uses HBase shell commands
- No schema definition
- Manual column family creation
- More complex for application developers

## Important Notes

1. **Primary Key**: Phoenix requires a PRIMARY KEY constraint. This becomes the HBase row key.

2. **Data Types**: Phoenix supports standard SQL data types:
   - INTEGER, BIGINT, TINYINT, SMALLINT
   - VARCHAR, CHAR
   - DATE, TIME, TIMESTAMP
   - DECIMAL, DOUBLE, FLOAT
   - BOOLEAN
   - BINARY, VARBINARY

3. **UPSERT**: Phoenix uses `UPSERT` instead of `INSERT` or `UPDATE`. UPSERT will insert if the row doesn't exist, or update if it does.

4. **Case Sensitivity**: Phoenix table names are case-sensitive. Use uppercase or lowercase consistently.

5. **Indexes**: You can create indexes on columns for faster queries:

   ```sql
   CREATE INDEX idx_testtable_email ON testtable (email);
   ```

## Verifying Table Creation

### Check if Table Exists

```sql
SELECT TABLE_NAME FROM SYSTEM.CATALOG 
WHERE TABLE_TYPE = 'u' AND TABLE_NAME = 'TESTTABLE';
```

### Get Table Schema

```sql
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_SIZE, IS_NULLABLE 
FROM SYSTEM.CATALOG 
WHERE TABLE_NAME = 'TESTTABLE' 
ORDER BY ORDINAL_POSITION;
```

### List All Tables

```sql
SELECT TABLE_NAME FROM SYSTEM.CATALOG 
WHERE TABLE_TYPE = 'u' 
ORDER BY TABLE_NAME;
```

## Dropping the Table

To drop the table (remove it):

```sql
DROP TABLE IF EXISTS testtable;
```

**Warning**: This will delete all data in the table!

## Files

- `tests/create_testtable_phoenix.sql`: Complete SQL script to create testtable
- `tests/create_testtable.sql`: Simplified version

## Resources

- [Apache Phoenix Documentation](https://phoenix.apache.org/)
- [Phoenix SQL Reference](https://phoenix.apache.org/language/)
- [Phoenix Data Types](https://phoenix.apache.org/language/datatypes.html)
