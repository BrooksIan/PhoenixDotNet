# Quick Reference Guide

A cheat sheet for common operations and commands in PhoenixDotNet.

## Quick Start Commands

```bash
# Start everything
docker-compose up --build

# Start Phoenix only
docker-compose up -d opdb-docker

# Build and run application
dotnet build && dotnet run

# Run tests
cd tests && ./smoke_test.sh
```

## API Endpoints Quick Reference

### Phoenix Operations

```bash
# Health check
curl http://localhost:8099/api/phoenix/health

# List tables
curl http://localhost:8099/api/phoenix/tables

# Get table columns
curl http://localhost:8099/api/phoenix/tables/TABLENAME/columns

# Execute query
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM SYSTEM.CATALOG LIMIT 10"}'

# Execute command
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql":"CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY)"}'
```

### HBase Operations

```bash
# Create sensor table
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{"tableName":"SENSOR_INFO","namespace":"default"}'

# Check if table exists
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/exists?namespace=default

# Get table schema
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/schema?namespace=default
```

## Docker Commands

```bash
# View all containers
docker-compose ps

# View logs
docker-compose logs -f phoenix-app
docker-compose logs -f opdb-docker

# Stop all services
docker-compose down

# Restart a service
docker-compose restart phoenix-app

# Execute command in container
docker-compose exec phoenix-app /bin/bash
```

## .NET Commands

```bash
# Restore packages
dotnet restore

# Build project
dotnet build

# Run application
dotnet run

# Clean build
dotnet clean && dotnet build

# Run tests (if test project exists)
dotnet test
```

## Common SQL Queries

### Phoenix System Queries

```sql
-- List all tables
SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'u' ORDER BY TABLE_NAME

-- List all tables (including views)
SELECT TABLE_NAME, TABLE_TYPE FROM SYSTEM.CATALOG ORDER BY TABLE_NAME

-- Get table columns
SELECT COLUMN_NAME, DATA_TYPE, COLUMN_SIZE 
FROM SYSTEM.CATALOG 
WHERE TABLE_NAME = 'TABLENAME' 
ORDER BY ORDINAL_POSITION

-- Count rows in table
SELECT COUNT(*) FROM TABLENAME
```

### Data Operations

```sql
-- Create table
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(255)
)

-- Insert/Update (UPSERT)
UPSERT INTO users (id, name, email) 
VALUES (1, 'John Doe', 'john@example.com')

-- Query data
SELECT * FROM users WHERE id = 1

-- Create view (for Phoenix tables)
CREATE VIEW active_users AS 
SELECT id, name, email 
FROM users 
WHERE active = true

-- Create view for HBase table (using REST API)
-- ⚠️ CRITICAL: View names MUST be UPPERCASE and match HBase table name exactly
# POST /api/phoenix/views
{
  "viewName": "MY_HBASE_TABLE",
  "hBaseTableName": "MY_HBASE_TABLE",
  "namespace": "default",
  "columns": [
    { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
    { "name": "column1", "type": "VARCHAR", "isPrimaryKey": false }
  ]
}

-- Query view
SELECT * FROM active_users ORDER BY name
```

**Important Notes:**

1. **For Phoenix tables**: Always use Phoenix SQL (UPSERT) to insert data. Direct HBase insertion via HBase shell creates readable text format that doesn't match Phoenix's binary encoding and won't be visible in Phoenix queries. See [README_TABLES.md](../Documentation/README_TABLES.md#direct-hbase-insertion-with-phoenix-encoding) for details.

2. **⚠️ CRITICAL - For HBase table views**: 
   - **View names MUST be UPPERCASE** (e.g., `MUSCLE_CARS`, not `muscle_cars`)
   - **View name MUST match HBase table name exactly** (case-sensitive)
   - Both the HBase table and view must use the same uppercase name
   - Example: If HBase table is `EMPLOYEE_DATA`, view must be `EMPLOYEE_DATA` (not `employee_data` or `EMPLOYEE_VIEW`)

## Configuration Reference

### appsettings.json

```json
{
  "Phoenix": {
    "Server": "localhost",
    "Port": "8765"
  },
  "HBase": {
    "Server": "localhost",
    "Port": "8080"
  }
}
```

### Environment Variables

```bash
export Phoenix__Server=opdb-docker
export Phoenix__Port=8765
export HBase__Server=opdb-docker
export HBase__Port=8080
export ASPNETCORE_ENVIRONMENT=Development
```

## Port Reference

| Service | Port | Purpose |
|---------|------|---------|
| Phoenix .NET API | 8099 | REST API endpoints |
| SQL Search GUI | 8100 | Web-based SQL interface |
| Phoenix Query Server | 8765 | Phoenix Query Server (Avatica) |
| HBase REST API | 8080 | HBase REST API (Stargate) |
| HBase Web UI | 9090, 9095 | HBase management UI |
| Zookeeper | 2181 | Zookeeper coordination |

## Troubleshooting Commands

```bash
# Check if Phoenix is running
docker ps | grep opdb-docker

# Check if port is listening
nc -zv localhost 8765
lsof -i :8765

# Test Phoenix connection
curl http://localhost:8765/json

# Test API health
curl http://localhost:8099/api/phoenix/health

# View container logs
docker logs opdb-docker | tail -50
docker logs phoenix-dotnet-app | tail -50

# Check network connectivity
docker network inspect phoenixdotnet_obdb-net
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Application entry | `Program.cs` | Application startup |
| API Controller | `Controllers/PhoenixController.cs` | REST API endpoints |
| Phoenix Client | `PhoenixRestClient.cs` | Phoenix Query Server client |
| HBase Client | `HBaseRestClient.cs` | HBase REST API client |
| SQL GUI | `wwwroot/index.html` | Web-based SQL interface |
| Configuration | `appsettings.json` | Application configuration |
| Docker Compose | `docker-compose.yml` | Container orchestration |
| HBase Config | `hbase-site.xml` | HBase configuration |

## Common Patterns

### C# Code Pattern

```csharp
// Using PhoenixRestClient
using var phoenix = new PhoenixRestClient(configuration);
await phoenix.OpenAsync();
var results = await phoenix.ExecuteQueryAsync("SELECT * FROM users");
await phoenix.CloseAsync();

// Using in Controller
await EnsureConnectionAsync();
var tables = await _phoenixClient.GetTablesAsync();
return Ok(ConvertDataTableToJson(tables));
```

### Error Handling Pattern

```csharp
try
{
    await _phoenixClient.OpenAsync();
    var results = await _phoenixClient.ExecuteQueryAsync(sql);
    return Ok(ConvertDataTableToJson(results));
}
catch (InvalidOperationException ex)
{
    return StatusCode(500, new { error = ex.Message });
}
```

## Phoenix SQL Tips

- Use **UPSERT** instead of INSERT/UPDATE
- Table names are **case-sensitive** (use uppercase or quoted)
- Remove trailing semicolons in REST API calls
- Use **SYSTEM.CATALOG** for metadata queries
- Wait 2-3 seconds after UPSERT before querying

## Key Differences from Standard SQL

| Standard SQL | Phoenix SQL |
|--------------|-------------|
| INSERT | UPSERT |
| UPDATE | UPSERT |
| Table names | Case-sensitive (uppercase) |
| Metadata | SYSTEM.CATALOG |
| Semicolons | Not accepted in REST API |

## Development Workflow

```bash
# 1. Start services
docker-compose up -d opdb-docker

# 2. Wait for initialization
sleep 90

# 3. Build and run
dotnet build && dotnet run

# 4. Test
curl http://localhost:8099/api/phoenix/health

# 5. Make changes
# ... edit code ...

# 6. Rebuild and test
dotnet build && dotnet run
```

## Useful Scripts

```bash
# Run all tests
cd tests && ./run_all_tests.sh

# Quick smoke test
cd tests && ./smoke_test.sh

# Troubleshoot issues
cd tests && ./troubleshoot.sh

# Generate diagnostics
cd tests && ./diagnostic.sh

# Complete example
cd examples && ./complete_example.sh
```

---

**Print this page** or keep it handy for quick reference during development!

