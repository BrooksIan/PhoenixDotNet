# Phoenix Views Guide

This guide explains how to create and use Phoenix views for querying data in your application.

## Overview

Phoenix views provide a read-only query interface to underlying tables. Views are useful for:

1. **Simplifying Complex Queries**: Create views that encapsulate complex joins or calculations
2. **Security**: Limit column access by exposing only specific columns
3. **Logical Data Structures**: Create views that match your application's data model
4. **Abstraction**: Abstract away underlying table structure changes

## Views Created for testtable

### 1. active_users_view

Shows only active users with essential information:

```sql
CREATE VIEW IF NOT EXISTS active_users_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date
FROM testtable
WHERE active = true;
```

**Usage**:
```sql
SELECT * FROM active_users_view ORDER BY name;
```

**Columns**:
- id
- name
- email
- age
- created_date

### 2. user_summary_view

Provides a comprehensive view with calculated age group:

```sql
CREATE VIEW IF NOT EXISTS user_summary_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    CASE 
        WHEN age < 30 THEN 'Young'
        WHEN age >= 30 AND age < 50 THEN 'Middle-aged'
        ELSE 'Senior'
    END AS age_group
FROM testtable;
```

**Usage**:
```sql
SELECT * FROM user_summary_view WHERE age_group = 'Young';
```

**Columns**:
- id
- name
- email
- age
- created_date
- active
- age_group (calculated)

### 3. user_details_view

Shows all users with a calculated status field:

```sql
CREATE VIEW IF NOT EXISTS user_details_view AS
SELECT 
    id,
    name,
    email,
    age,
    created_date,
    active,
    CASE 
        WHEN active = true THEN 'Active User'
        ELSE 'Inactive User'
    END AS status
FROM testtable;
```

**Usage**:
```sql
SELECT * FROM user_details_view;
```

### 4. user_statistics_view

Provides aggregated statistics:

```sql
CREATE VIEW IF NOT EXISTS user_statistics_view AS
SELECT 
    COUNT(*) AS total_users,
    SUM(CASE WHEN active = true THEN 1 ELSE 0 END) AS active_users,
    SUM(CASE WHEN active = false THEN 1 ELSE 0 END) AS inactive_users,
    AVG(age) AS average_age,
    MIN(age) AS min_age,
    MAX(age) AS max_age
FROM testtable;
```

**Usage**:
```sql
SELECT * FROM user_statistics_view;
```

## Creating Views

### Option 1: Using the Dedicated /views Endpoint (Recommended for HBase Tables)

For HBase tables, use the dedicated `/api/phoenix/views` endpoint:

```bash
# Create a Phoenix view for an HBase table
# ⚠️ CRITICAL: viewName and hBaseTableName must be UPPERCASE and match exactly
curl -X POST http://localhost:8099/api/phoenix/views \
  -H "Content-Type: application/json" \
  -d '{
    "viewName": "SENSOR_READINGS",
    "hBaseTableName": "SENSOR_READINGS",
    "namespace": "default",
    "columns": [
      { "name": "sensor_id", "type": "VARCHAR", "isPrimaryKey": true },
      { "name": "timestamp", "type": "BIGINT", "isPrimaryKey": false },
      { "name": "temperature", "type": "DOUBLE", "isPrimaryKey": false },
      { "name": "humidity", "type": "DOUBLE", "isPrimaryKey": false }
    ]
  }'
```

**Benefits:**
- ✅ Automatically validates that the HBase table exists
- ✅ Generates the CREATE VIEW SQL statement for you
- ✅ Handles column mapping automatically
- ✅ Provides clear error messages if the table doesn't exist

### Option 2: Using the /execute Endpoint

For Phoenix tables or views with custom SQL logic, use the `/api/phoenix/execute` endpoint:

```bash
# Create a view using raw SQL
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS active_users_view AS SELECT * FROM testtable WHERE active = true"
  }'
```

### Option 3: Using the Application

The application automatically creates views when you run it:

```bash
dotnet run
```

### Option 4: Using SQL Script

Execute the SQL script:

```bash
# If you have a Phoenix SQL client
sqlline.py localhost:8765 < tests/create_views_phoenix.sql
```

### Option 5: Using Phoenix Query Server

Connect to Phoenix Query Server on port 8765 and execute the SQL from `tests/create_views_phoenix.sql`.

## Querying Views in the Application

### Using PhoenixConnection

```csharp
// Query active_users_view
var query = "SELECT * FROM active_users_view ORDER BY name";
var results = phoenix.ExecuteQuery(query);
PhoenixConnection.PrintDataTable(results);

// Query with WHERE clause
var filteredQuery = "SELECT * FROM user_summary_view WHERE age_group = 'Young'";
var filteredResults = phoenix.ExecuteQuery(filteredQuery);
PhoenixConnection.PrintDataTable(filteredResults);

// Get statistics
var statsQuery = "SELECT * FROM user_statistics_view";
var stats = phoenix.ExecuteQuery(statsQuery);
PhoenixConnection.PrintDataTable(stats);
```

### Example Queries

#### Get All Active Users
```csharp
var query = "SELECT * FROM active_users_view ORDER BY name";
var results = phoenix.ExecuteQuery(query);
```

#### Get Users by Age Group
```csharp
var query = "SELECT name, email, age_group FROM user_summary_view WHERE age_group = 'Young'";
var results = phoenix.ExecuteQuery(query);
```

#### Get User Statistics
```csharp
var query = "SELECT * FROM user_statistics_view";
var results = phoenix.ExecuteQuery(query);
```

#### Search Users by Name
```csharp
var query = "SELECT * FROM active_users_view WHERE name LIKE '%John%'";
var results = phoenix.ExecuteQuery(query);
```

#### Get Users by Age Range
```csharp
var query = "SELECT * FROM user_summary_view WHERE age BETWEEN 25 AND 35";
var results = phoenix.ExecuteQuery(query);
```

## View Management

### List All Views

```sql
SELECT TABLE_NAME FROM SYSTEM.CATALOG 
WHERE TABLE_TYPE = 'v' 
ORDER BY TABLE_NAME;
```

### Get View Schema

```sql
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_SIZE, IS_NULLABLE 
FROM SYSTEM.CATALOG 
WHERE TABLE_NAME = 'ACTIVE_USERS_VIEW' 
ORDER BY ORDINAL_POSITION;
```

### Drop a View

```sql
DROP VIEW IF EXISTS active_users_view;
```

**Warning**: Dropping a view does not affect the underlying table data.

## Important Notes

### ⚠️ CRITICAL: Views on HBase Tables

**For Phoenix views created on HBase-native tables (not Phoenix tables), there are two critical requirements:**

1. **View Names MUST be UPPERCASE**: Phoenix requires all view names to be in uppercase (e.g., `MUSCLE_CARS`, not `muscle_cars`).

2. **View Name MUST Match HBase Table Name Exactly**: The view name must exactly match the HBase table name (case-sensitive). If your HBase table is `MUSCLE_CARS`, the view must also be `MUSCLE_CARS`. This is a hard requirement - Phoenix will not recognize the view if the names don't match exactly.

**Example:**
```bash
# HBase table created with uppercase name
create 'MUSCLE_CARS', 'info', 'specs', 'details'

# Phoenix view MUST use the same uppercase name
CREATE VIEW "MUSCLE_CARS" (
    "rowkey" VARCHAR PRIMARY KEY,
    "info"."manufacturer" VARCHAR,
    ...
)
```

**Why this matters:**
- If you create an HBase table as `muscle_cars` (lowercase) and try to create a view as `MUSCLE_CARS` (uppercase), Phoenix will not recognize the underlying HBase table.
- If you query `SELECT * FROM muscle_cars` (unquoted), Phoenix converts it to uppercase `MUSCLE_CARS`, so the view must be uppercase to work with unquoted queries.

**Best Practice:** Always create HBase tables with uppercase names to match Phoenix view naming conventions.

### General View Notes

1. **Views are Read-Only**: Views in Phoenix are read-only. You cannot INSERT, UPDATE, or DELETE through views.

2. **Views are Virtual**: Views don't store data - they query the underlying table each time they're accessed.

3. **Performance**: Views add a small overhead since they query the underlying table. However, Phoenix optimizes view queries.

4. **Column Names**: View column names are case-sensitive. Use uppercase or lowercase consistently.

5. **Dependencies**: Views depend on the underlying table. If you drop the table, the views will fail.

6. **Updates**: Changes to the underlying table are immediately reflected in views.

## Best Practices

1. **Use Descriptive Names**: Name views clearly to indicate their purpose (e.g., `active_users_view`)

2. **Limit Columns**: Only include columns that are needed to reduce data transfer

3. **Add Filters**: Use WHERE clauses in views to filter data at the view level

4. **Document Views**: Document what each view provides and when to use it

5. **Test Views**: Test views thoroughly before using them in production

## Troubleshooting

### View Not Found

**Error**: `Table/View 'ACTIVE_USERS_VIEW' not found`

**Solutions**:
1. Verify view exists: `SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v'`
2. Check view name spelling (case-sensitive)
3. Create the view if it doesn't exist

### Query Fails

**Error**: `Error executing query on view`

**Solutions**:
1. Verify underlying table exists
2. Check view definition syntax
3. Verify all columns in view exist in underlying table
4. Check view permissions

### Performance Issues

**Solutions**:
1. Add indexes to underlying table columns used in view WHERE clauses
2. Limit columns in view to only what's needed
3. Use views with filters to reduce data scanned

## Creating Views for HBase Tables

### ⚠️ CRITICAL REQUIREMENTS

**Before creating a Phoenix view on an HBase table, you MUST:**

1. **Use UPPERCASE for both HBase table and view names**: Phoenix requires uppercase names (e.g., `MUSCLE_CARS`, not `muscle_cars`).
2. **Match names exactly**: The view name must exactly match the HBase table name (case-sensitive).

**Example:**
```bash
# Step 1: Create HBase table with UPPERCASE name
create 'MUSCLE_CARS', 'info', 'specs', 'details'

# Step 2: Create Phoenix view with the SAME UPPERCASE name
CREATE VIEW "MUSCLE_CARS" (
    "rowkey" VARCHAR PRIMARY KEY,
    "info"."manufacturer" VARCHAR,
    ...
)
```

### Using the `/api/phoenix/views` Endpoint

When creating views for HBase tables, use the dedicated `/api/phoenix/views` endpoint:

```bash
curl -X POST http://localhost:8099/api/phoenix/views \
  -H "Content-Type: application/json" \
  -d '{
    "viewName": "MY_HBASE_TABLE",
    "hBaseTableName": "MY_HBASE_TABLE",
    "namespace": "default",
    "columns": [
      { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
      { "name": "column1", "type": "VARCHAR", "isPrimaryKey": false },
      { "name": "column2", "type": "INTEGER", "isPrimaryKey": false }
    ]
  }'
```

**Important:** The `viewName` and `hBaseTableName` must match exactly (same case). Use uppercase for both.

This endpoint:
- Validates that the HBase table exists before creating the view
- Generates the CREATE VIEW SQL statement automatically
- Maps Phoenix columns to HBase table structure
- Returns helpful error messages if the table doesn't exist

For more details on creating HBase tables, see [README_TABLES.md](./README_TABLES.md).

## Files

- `tests/create_views_phoenix.sql`: Complete SQL script to create all views
- `tests/create_view.sql`: Simplified version with basic views
- `Program.cs`: Application code that creates and queries views
- `examples/create_table_and_view_example.sh`: Example script showing view creation for HBase tables

## Resources

- [Apache Phoenix Documentation](https://phoenix.apache.org/)
- [Phoenix SQL Reference](https://phoenix.apache.org/language/)
- [Phoenix Views](https://phoenix.apache.org/language/index.html#views)

