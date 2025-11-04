# Phoenix REST API Client Guide

This guide explains how to use the Phoenix REST API client instead of ODBC to connect to Apache Phoenix.

## Overview

Phoenix Query Server (PQS) exposes a REST API using the Avatica protocol. This allows you to connect to Phoenix without requiring ODBC drivers. The REST API uses HTTP/JSON for communication.

## Benefits of REST API

1. **No ODBC Driver Required**: Works without installing Phoenix ODBC driver
2. **Cross-Platform**: Works on any platform that supports HTTP
3. **Easy Integration**: Simple HTTP requests with JSON
4. **No Dependencies**: Only requires HTTP client library

## Using PhoenixRestClient

### Basic Usage

```csharp
using PhoenixDotNet;

// Create REST client
var phoenix = new PhoenixRestClient(configuration);

// Connect to Phoenix
await phoenix.OpenAsync();

// Execute query
var results = await phoenix.ExecuteQueryAsync("SELECT * FROM testtable");

// Print results
PhoenixRestClient.PrintDataTable(results);

// Close connection
await phoenix.CloseAsync();
```

### Configuration

Update `appsettings.json`:

```json
{
  "Phoenix": {
    "Server": "opdb-docker",
    "Port": "8765"
  }
}
```

The REST client uses `http://{Server}:{Port}` as the base URL.

### Running with REST API

To use the REST API client instead of ODBC:

```bash
# Option 1: Run ProgramRest.cs directly
dotnet run --project . -- ProgramRest.cs

# Option 2: Update Program.cs to use PhoenixRestClient
# Replace PhoenixConnection with PhoenixRestClient
```

## Example: Complete Application with REST API

See `ProgramRest.cs` for a complete example that:
- Creates tables
- Inserts data
- Queries data
- Creates views
- Queries views

## API Methods

### OpenAsync()

Opens a connection to Phoenix Query Server:

```csharp
await phoenix.OpenAsync();
```

### CloseAsync()

Closes the connection:

```csharp
await phoenix.CloseAsync();
```

### ExecuteQueryAsync(string sql)

Executes a SELECT query and returns DataTable:

```csharp
var results = await phoenix.ExecuteQueryAsync("SELECT * FROM testtable");
```

### ExecuteQueryAsListAsync(string sql)

Executes a SELECT query and returns list of dictionaries:

```csharp
var results = await phoenix.ExecuteQueryAsListAsync("SELECT * FROM testtable");
foreach (var row in results)
{
    Console.WriteLine($"{row["name"]} - {row["email"]}");
}
```

### ExecuteNonQueryAsync(string sql)

Executes non-query statements (CREATE, INSERT, UPDATE, DELETE):

```csharp
await phoenix.ExecuteNonQueryAsync("CREATE TABLE testtable (id INTEGER PRIMARY KEY, name VARCHAR)");
await phoenix.ExecuteNonQueryAsync("UPSERT INTO testtable VALUES (1, 'John')");
```

### GetTablesAsync()

Gets list of all tables:

```csharp
var tables = await phoenix.GetTablesAsync();
```

### GetColumnsAsync(string tableName)

Gets column information for a table:

```csharp
var columns = await phoenix.GetColumnsAsync("testtable");
```

## Avatica Protocol

Phoenix Query Server uses the Avatica protocol for communication:

1. **Open Connection**: `POST /` with `{"request": "openConnection", "connectionId": "..."}`
2. **Execute Statement**: `POST /` with `{"request": "execute", "connectionId": "...", "statement": "..."}`
3. **Close Connection**: `POST /` with `{"request": "closeConnection", "connectionId": "..."}`

The REST client handles all Avatica protocol details automatically.

## Error Handling

The REST client provides detailed error messages:

```csharp
try
{
    await phoenix.OpenAsync();
}
catch (InvalidOperationException ex)
{
    Console.WriteLine($"Connection failed: {ex.Message}");
    // Check if Phoenix Query Server is running
    // Verify server address and port
}
```

## Comparison: ODBC vs REST API

| Feature | ODBC | REST API |
|---------|------|----------|
| Driver Required | Yes | No |
| Setup Complexity | High | Low |
| Performance | High | Good |
| Cross-Platform | Limited | Yes |
| Dependencies | ODBC Driver | HTTP Client |
| Protocol | Binary | JSON/HTTP |

## Troubleshooting

### Connection Failed

**Error**: `Failed to connect to Phoenix Query Server`

**Solutions**:
1. Verify Phoenix Query Server is running: `docker-compose ps opdb-docker`
2. Check port 8765 is accessible: `curl http://opdb-docker:8765`
3. Verify network connectivity between containers
4. Check firewall rules

### Query Failed

**Error**: `Invalid query` or `Table not found`

**Solutions**:
1. Verify table exists: `SELECT TABLE_NAME FROM SYSTEM.CATALOG`
2. Check SQL syntax
3. Verify table name (case-sensitive)
4. Check view logs: `docker-compose logs opdb-docker`

### Response Parsing Error

**Error**: `Unable to parse response`

**Solutions**:
1. Check Phoenix Query Server version compatibility
2. Verify response format matches Avatica protocol
3. Check logs for detailed error messages

## Example Queries

### Create Table

```csharp
var sql = @"
    CREATE TABLE IF NOT EXISTS testtable (
        id INTEGER NOT NULL,
        name VARCHAR(100),
        email VARCHAR(255),
        PRIMARY KEY (id)
    )";
await phoenix.ExecuteNonQueryAsync(sql);
```

### Insert Data

```csharp
var sql = @"
    UPSERT INTO testtable (id, name, email) 
    VALUES (1, 'John Doe', 'john@example.com')";
await phoenix.ExecuteNonQueryAsync(sql);
```

### Query Data

```csharp
var sql = "SELECT * FROM testtable WHERE id = 1";
var results = await phoenix.ExecuteQueryAsync(sql);
PhoenixRestClient.PrintDataTable(results);
```

### Create View

**Option 1: For HBase tables (using dedicated endpoint):**

⚠️ **CRITICAL:** `viewName` and `hBaseTableName` must be UPPERCASE and match exactly.

```bash
# Using REST API
curl -X POST http://localhost:8099/api/phoenix/views \
  -H "Content-Type: application/json" \
  -d '{
    "viewName": "SENSOR_READINGS",
    "hBaseTableName": "SENSOR_READINGS",
    "namespace": "default",
    "columns": [
      { "name": "sensor_id", "type": "VARCHAR", "isPrimaryKey": true },
      { "name": "timestamp", "type": "BIGINT", "isPrimaryKey": false },
      { "name": "temperature", "type": "DOUBLE", "isPrimaryKey": false }
    ]
  }'
```

**Option 2: For Phoenix tables (using /execute endpoint):**

```csharp
var sql = @"
    CREATE VIEW IF NOT EXISTS active_users_view AS
    SELECT id, name, email
    FROM testtable
    WHERE active = true";
await phoenix.ExecuteNonQueryAsync(sql);
```

Or using REST API:

```bash
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS active_users_view AS SELECT id, name, email FROM testtable WHERE active = true"
  }'
```

### Query View

```csharp
var sql = "SELECT * FROM active_users_view ORDER BY name";
var results = await phoenix.ExecuteQueryAsync(sql);
```

## Resources

- [Apache Phoenix Query Server](https://phoenix.apache.org/server.html)
- [Apache Calcite Avatica](https://calcite.apache.org/avatica/)
- [Avatica Protocol](https://calcite.apache.org/avatica/docs/protocol_reference.html)

## Next Steps

1. Run `ProgramRest.cs` to see REST API in action
2. Update your application to use `PhoenixRestClient` instead of `PhoenixConnection`
3. Test all queries work with REST API
4. Deploy application using REST API (no ODBC driver needed)

