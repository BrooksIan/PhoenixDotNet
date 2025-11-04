# HBase API Guide: Create Table and Insert Data

## Overview

This guide shows how to create an HBase table and insert data using the HBase REST API, then create a Phoenix view to query it.

## Important Note

The Cloudera OPDB Docker container may not have HBase REST API (Stargate) enabled by default on port 8080. The recommended approach is to use Phoenix SQL to create tables and insert data, which automatically creates the underlying HBase table.

## Recommended Approach: Use Phoenix SQL

Since HBase REST API may not be available, use Phoenix SQL to create tables and insert data:

### Step 1: Create HBase Table via Phoenix SQL

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE TABLE IF NOT EXISTS user_data (rowkey VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER, status VARCHAR)"
  }'
```

This automatically creates the underlying HBase table.

### Step 2: Insert 3 Rows of Data

```bash
# Row 1
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO user_data VALUES ('\''1'\'', '\''Alice'\'', 100, '\''active'\'')"
  }'

# Row 2
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO user_data VALUES ('\''2'\'', '\''Bob'\'', 200, '\''active'\'')"
  }'

# Row 3
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO user_data VALUES ('\''3'\'', '\''Charlie'\'', 50, '\''inactive'\'')"
  }'
```

### Step 3: Wait for Data to Commit

```bash
sleep 5
```

### Step 4: Query the Table

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM USER_DATA ORDER BY rowkey"
  }'
```

### Step 5: Create Phoenix View

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW user_data_view AS SELECT * FROM user_data WHERE status = '\''active'\''"
  }'
```

### Step 6: Query the View

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM USER_DATA_VIEW ORDER BY rowkey"
  }'
```

## Complete Example Script

Run the complete example:

```bash
./examples/create_table_and_view_with_data.sh
```

This script:
1. Creates an HBase table via Phoenix SQL
2. Inserts 3 rows of data
3. Verifies the data is present
4. Creates a Phoenix view
5. Queries the view to verify data is visible

## Alternative: Using HBase REST API (If Available)

If HBase REST API is available, you can use:

### Create Table

```bash
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{
    "tableName": "user_data",
    "namespace": "default"
  }'
```

### Insert Data

```bash
curl -X PUT http://localhost:8099/api/phoenix/hbase/tables/user_data/data \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "1",
    "columnFamily": "metadata",
    "column": "name",
    "value": "Alice",
    "namespace": "default"
  }'
```

## Troubleshooting

### Issue: "Connection refused" on HBase REST API

**Solution**: The HBase REST API may not be enabled in the opdb-docker container. Use Phoenix SQL instead:

1. Create tables using Phoenix SQL
2. Insert data using Phoenix SQL
3. Create views using Phoenix SQL

### Issue: Data inserted but queries return empty

**Solution**: 
1. Wait 5-10 seconds after inserting data
2. Phoenix auto-commits, but may need time
3. Try querying again with uppercase table name: `SELECT * FROM USER_DATA`

### Issue: Tables not showing in GUI

**Solution**:
1. Click "List Tables" button in the GUI
2. Or query: `SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'u' ORDER BY TABLE_NAME`
3. Use uppercase table names when querying

## Key Points

1. **Phoenix SQL automatically creates HBase tables** - No need for separate HBase table creation
2. **Wait after inserts** - Phoenix needs time to commit data (5-10 seconds)
3. **Use uppercase table names** - Phoenix converts unquoted names to uppercase
4. **Views are read-only** - You cannot INSERT/UPDATE/DELETE through views
5. **Views filter data** - Views can filter data (e.g., `WHERE status = 'active'`)

