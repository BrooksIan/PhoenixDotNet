# Final Working Example: Direct HBase + Phoenix Views

## Complete Workflow

This demonstrates the **recommended approach for HBase-native tables**: Create HBase tables directly, insert data via HBase shell, then create Phoenix views for SQL querying.

## Important: When to Use This Approach

**Use HBase Shell + Phoenix Views when:**
- ✅ Creating HBase-native tables (not Phoenix tables)
- ✅ You need direct control over HBase table structure
- ✅ You're inserting data from external systems via HBase REST API
- ✅ You have existing HBase tables with readable text format data

**Use Phoenix SQL (UPSERT) when:**
- ✅ Working with Phoenix tables (created via Phoenix SQL)
- ✅ You need Phoenix indexes and secondary indexes
- ✅ You want automatic type conversion and validation
- ✅ You need binary-encoded data that's immediately queryable in Phoenix

**Note:** For Phoenix tables (created via Phoenix SQL), always use Phoenix SQL (UPSERT) to insert data. HBase shell inserts will not work correctly with Phoenix queries because Phoenix tables use binary encoding that cannot be replicated via HBase shell.

## Step 1: Create HBase Table via HBase Shell

⚠️ **IMPORTANT:** Use UPPERCASE for table names to match Phoenix view naming requirements.

```bash
docker-compose exec opdb-docker /opt/hbase/bin/hbase shell <<EOF
create 'EMPLOYEE_DATA', 'info', 'contact', 'status'
EOF
```

## Step 2: Insert Data via HBase Shell

```bash
docker-compose exec opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'EMPLOYEE_DATA', '1', 'info:name', 'Alice'
put 'EMPLOYEE_DATA', '1', 'info:score', '100'
put 'EMPLOYEE_DATA', '1', 'contact:email', 'alice@example.com'
put 'EMPLOYEE_DATA', '1', 'status:status', 'active'

put 'EMPLOYEE_DATA', '2', 'info:name', 'Bob'
put 'EMPLOYEE_DATA', '2', 'info:score', '200'
put 'EMPLOYEE_DATA', '2', 'contact:email', 'bob@example.com'
put 'EMPLOYEE_DATA', '2', 'status:status', 'active'

put 'EMPLOYEE_DATA', '3', 'info:name', 'Charlie'
put 'EMPLOYEE_DATA', '3', 'info:score', '150'
put 'EMPLOYEE_DATA', '3', 'contact:email', 'charlie@example.com'
put 'EMPLOYEE_DATA', '3', 'status:status', 'inactive'
EOF
```

## Step 3: Verify Data in HBase

```bash
docker-compose exec opdb-docker /opt/hbase/bin/hbase shell <<EOF
scan 'EMPLOYEE_DATA'
EOF
```

## Step 4: Create Phoenix View

⚠️ **CRITICAL:** View names MUST be UPPERCASE and MUST match HBase table name exactly.

Use the correct syntax for Phoenix views on HBase tables:

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS \"EMPLOYEE_DATA\" (\"rowkey\" VARCHAR PRIMARY KEY, \"info\".\"name\" VARCHAR, \"info\".\"score\" INTEGER, \"contact\".\"email\" VARCHAR, \"status\".\"status\" VARCHAR)"
  }'
```

**Key Points:**
- **View name MUST be UPPERCASE** and match HBase table name exactly: `"EMPLOYEE_DATA"` (not `employee_view` or `employee_data`)
- Use double quotes around column names: `"rowkey"`, `"name"`, etc.
- Map column families using dot notation: `"info"."name"`, `"contact"."email"`
- The `rowkey` is the HBase row key (primary key)

## Step 5: Query Phoenix View

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
    "sql": "SELECT * FROM EMPLOYEE_DATA WHERE \"status\".\"status\" = '\''active'\'' ORDER BY rowkey"
  }'
```

## Alternative: Query HBase Table Directly (Without View)

You can also query the HBase table directly without creating a view:

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"info\".\"name\", \"info\".\"score\", \"contact\".\"email\", \"status\".\"status\" FROM \"EMPLOYEE_DATA\" ORDER BY rowkey"
  }'
```

## Complete Example Script

Run the complete example:

```bash
./examples/hbase_direct_with_phoenix_view.sh
```

## Phoenix View Syntax for HBase Tables

### Basic Syntax

```sql
CREATE VIEW "view_name" (
    "rowkey" VARCHAR PRIMARY KEY,
    "column_family"."column" VARCHAR,
    ...
);
```

### Example

```sql
-- ⚠️ CRITICAL: View name MUST be UPPERCASE and match HBase table name exactly
CREATE VIEW "EMPLOYEE_DATA" (
    "rowkey" VARCHAR PRIMARY KEY,
    "info"."name" VARCHAR,
    "info"."score" INTEGER,
    "contact"."email" VARCHAR,
    "status"."status" VARCHAR
);
```

### Important Notes

1. **Double Quotes Required**: All identifiers must be in double quotes
2. **Column Family Mapping**: Use `"column_family"."column"` format
3. **Row Key**: The `rowkey` is the HBase row key (must be PRIMARY KEY)
4. **Case Sensitive**: HBase table and column names are case-sensitive
5. **No SELECT Clause**: Phoenix views on HBase tables don't use SELECT

## Troubleshooting

### Issue: View Creation Fails with "Table undefined"

**Error:** `Table undefined. tableName=employee_data`

**Solution:** 
- Ensure HBase table exists: `scan 'employee_data'`
- Verify table name matches exactly (case-sensitive)
- Check if Phoenix can see the table: `SELECT * FROM SYSTEM.CATALOG WHERE TABLE_NAME = 'EMPLOYEE_DATA'`

### Issue: Column Not Found

**Error:** `Column undefined. columnName=info.name`

**Solution:**
- Verify column family and column names match HBase exactly
- Use double quotes: `"info"."name"` not `info.name`
- Check HBase table structure: `describe 'employee_data'`

### Issue: View Returns No Data

**Possible Causes:**
1. Column family/column names don't match
2. Data type mismatches
3. View not properly created

**Solution:**
1. Verify HBase data: `scan 'employee_data'`
2. Check view definition matches HBase structure
3. Query HBase table directly first to verify data is accessible

## Summary

✅ **Create HBase-native tables** via HBase shell  
✅ **Insert data** via HBase shell (readable text format)  
✅ **Create Phoenix views** for SQL access  
✅ **Query data** via Phoenix views or directly from HBase tables  

This approach gives you:
- **Reliability**: Direct HBase operations guarantee data persistence
- **Flexibility**: Full control over HBase table structure
- **SQL Access**: Phoenix views provide SQL querying capabilities

**Important:** This approach is for **HBase-native tables**, not Phoenix tables. For Phoenix tables (created via Phoenix SQL), always use Phoenix SQL (UPSERT) to insert data, as Phoenix tables use binary encoding that cannot be replicated via HBase shell.

