# Phoenix Query Examples

## Overview

This guide shows how to query Phoenix with working examples.

## Query Endpoint

**URL:** `POST http://localhost:8099/api/phoenix/query`

**Content-Type:** `application/json`

## Basic Query Format

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"column_family\".\"column\" as alias FROM \"table_name\" ORDER BY rowkey"
  }'
```

## Working Examples

### Example 1: Query HBase Table with Column Family `cf1`

For table `test_hbase_direct` with column family `cf1`:

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"cf1\".\"name\" as name, \"cf1\".\"score\" as score FROM \"test_hbase_direct\" ORDER BY rowkey"
  }'
```

### Example 2: Query HBase Table with Multiple Column Families

For table `employee_data` with column families `info`, `contact`, `status`:

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"info\".\"name\" as name, \"info\".\"score\" as score, \"contact\".\"email\" as email, \"status\".\"status\" as status FROM \"employee_data\" ORDER BY rowkey"
  }'
```

### Example 3: Query with WHERE Clause

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"info\".\"name\" as name FROM \"employee_data\" WHERE \"status\".\"status\" = '\''active'\'' ORDER BY rowkey"
  }'
```

### Example 4: Count Rows

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT COUNT(*) as total FROM \"employee_data\""
  }'
```

### Example 5: Group By

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT \"status\".\"status\" as status, COUNT(*) as count FROM \"employee_data\" GROUP BY \"status\".\"status\""
  }'
```

### Example 6: Query with LIMIT

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"cf1\".\"name\" as name FROM \"test_hbase_direct\" ORDER BY rowkey LIMIT 2"
  }'
```

### Example 7: Query Phoenix View

If you've created a Phoenix view:

```bash
# ⚠️ IMPORTANT: View name must be UPPERCASE and match HBase table name exactly
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EMPLOYEE_DATA ORDER BY rowkey"
  }'
```

### Example 8: List All Tables

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT TABLE_NAME, TABLE_TYPE FROM SYSTEM.CATALOG WHERE (TABLE_TYPE = '\''u'\'' OR TABLE_TYPE = '\''v'\'') ORDER BY TABLE_NAME"
  }'
```

**Or use the API endpoint:**
```bash
curl http://localhost:8099/api/phoenix/tables
```

## Query Syntax Rules

### 1. Double Quotes and Uppercase Required

- **HBase table names:** `"EMPLOYEE_DATA"` (not `employee_data`) - must be UPPERCASE
- **Column families:** `"info"."name"` (not `info.name`)
- **View names:** `"EMPLOYEE_DATA"` (not `employee_view`) - must be UPPERCASE and match table name exactly

### 2. Column Family Syntax

When querying HBase tables:
- Format: `"column_family"."column"`
- Example: `"info"."name"`, `"cf1"."score"`

### 3. Row Key

- Always available as `rowkey` or `ROWKEY`
- Case-insensitive

### 4. Case Sensitivity

- HBase table names are case-sensitive
- Use exact case as created in HBase

## Using the GUI

1. **Open:** http://localhost:8100
2. **Enter SQL query** in the query box
3. **Click "Execute Query"** or press Enter
4. **View results** in the results table

### GUI Example Queries

```sql
-- Query test_hbase_direct table
SELECT rowkey, "cf1"."name" as name, "cf1"."score" as score FROM "test_hbase_direct" ORDER BY rowkey

-- Query employee_data table
SELECT rowkey, "info"."name" as name, "info"."score" as score, "contact"."email" as email, "status"."status" as status FROM "employee_data" ORDER BY rowkey

-- Filter active employees
SELECT rowkey, "info"."name" as name FROM "employee_data" WHERE "status"."status" = 'active' ORDER BY rowkey

-- Count by status
SELECT "status"."status" as status, COUNT(*) as count FROM "employee_data" GROUP BY "status"."status"
```

## Response Format

### Success Response

```json
{
  "columns": [
    {"name": "ROWKEY", "type": "String"},
    {"name": "NAME", "type": "String"},
    {"name": "SCORE", "type": "Int32"}
  ],
  "rows": [
    {"ROWKEY": "row1", "NAME": "Alice", "SCORE": 100},
    {"ROWKEY": "row2", "NAME": "Bob", "SCORE": 200}
  ],
  "rowCount": 2
}
```

### Empty Result

```json
{
  "columns": [],
  "rows": [],
  "rowCount": 0
}
```

### Error Response

```json
{
  "error": "Error message describing what went wrong"
}
```

## Quick Reference

### Query HBase Table
```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT rowkey, \"column_family\".\"column\" as alias FROM \"table_name\" ORDER BY rowkey"}'
```

### Query Phoenix View
```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM \"view_name\" ORDER BY rowkey"}'
```

### List Tables
```bash
curl http://localhost:8099/api/phoenix/tables
```

### Get Columns
```bash
curl http://localhost:8099/api/phoenix/tables/TABLE_NAME/columns
```

## Summary

✅ **Query HBase tables directly** - Use double quotes  
✅ **Query Phoenix views** - Same syntax as tables  
✅ **Use REST API** - POST /api/phoenix/query  
✅ **Use GUI** - http://localhost:8100  

**Key:** Phoenix can query HBase tables directly without creating views!

