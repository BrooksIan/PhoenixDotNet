# Common Tasks Guide

Step-by-step guides for common development tasks in PhoenixDotNet.

## Table of Contents

1. [Adding a New API Endpoint](#adding-a-new-api-endpoint)
2. [Adding a New Phoenix Client Method](#adding-a-new-phoenix-client-method)
3. [Adding a New HBase Client Method](#adding-a-new-hbase-client-method)
4. [Modifying Configuration](#modifying-configuration)
5. [Adding Logging](#adding-logging)
6. [Handling Errors](#handling-errors)
7. [Testing Your Changes](#testing-your-changes)
8. [Deploying Changes](#deploying-changes)

---

## Adding a New API Endpoint

### Step 1: Add Method to Controller

```csharp
/// <summary>
/// Gets the application version
/// </summary>
/// <returns>HTTP 200 OK with version information</returns>
[HttpGet("version")]
[ProducesResponseType(typeof(object), 200)]
public IActionResult GetVersion()
{
    var version = typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown";
    return Ok(new { version = version });
}
```

### Step 2: Test the Endpoint

```bash
# Test via curl
curl http://localhost:8099/api/phoenix/version

# Test via Swagger
# Open http://localhost:8099/swagger and test the endpoint
```

### Step 3: Update Documentation

- Add endpoint to `Documentation/README_REST_API.md`
- Add endpoint to `Documentation/DEVELOPMENT_HANDBOOK.md`
- Update `README.md` if needed

---

## Adding a New Phoenix Client Method

### Step 1: Add Method to PhoenixRestClient

```csharp
/// <summary>
/// Executes a SQL query with custom timeout
/// </summary>
/// <param name="sql">SQL SELECT statement</param>
/// <param name="timeoutSeconds">Timeout in seconds</param>
/// <returns>DataTable containing query results</returns>
public async Task<DataTable> ExecuteQueryWithTimeoutAsync(string sql, int timeoutSeconds)
{
    if (_connectionId == null)
    {
        throw new InvalidOperationException("Connection is not open. Call OpenAsync() first.");
    }

    sql = sql.TrimEnd().TrimEnd(';').TrimEnd();

    var request = new Dictionary<string, object>
    {
        ["request"] = "prepareAndExecute",
        ["connectionId"] = _connectionId,
        ["sql"] = sql,
        ["maxRowCount"] = 10000,
        ["maxRowsTotal"] = 10000
    };

    using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(timeoutSeconds));
    var response = await _httpClient.PostAsJsonAsync("", request, cts.Token);
    
    // ... rest of implementation
}
```

### Step 2: Add Method to Controller (if needed)

```csharp
[HttpPost("query-with-timeout")]
public async Task<IActionResult> ExecuteQueryWithTimeout(
    [FromBody] QueryWithTimeoutRequest request)
{
    try
    {
        await EnsureConnectionAsync();
        var results = await _phoenixClient.ExecuteQueryWithTimeoutAsync(
            request.Sql, 
            request.TimeoutSeconds);
        return Ok(ConvertDataTableToJson(results));
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Step 3: Test the Method

```bash
curl -X POST http://localhost:8099/api/phoenix/query-with-timeout \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM SYSTEM.CATALOG LIMIT 10","timeoutSeconds":30}'
```

---

## Adding a New HBase Client Method

### Step 1: Add Method to HBaseRestClient

```csharp
/// <summary>
/// Deletes a table from HBase
/// </summary>
/// <param name="tableName">Name of the table to delete</param>
/// <param name="namespace">HBase namespace (default: "default")</param>
/// <returns>True if table was deleted successfully</returns>
public async Task<bool> DeleteTableAsync(string tableName, string @namespace = "default")
{
    try
    {
        var endpoint = $"/{@namespace}:{tableName}/schema";
        var response = await _httpClient.DeleteAsync(endpoint);
        response.EnsureSuccessStatusCode();
        return true;
    }
    catch (Exception ex)
    {
        throw new InvalidOperationException($"Error deleting table {@namespace}:{tableName}: {ex.Message}", ex);
    }
}
```

### Step 2: Add Method to Controller (if needed)

```csharp
[HttpDelete("hbase/tables/{tableName}")]
public async Task<IActionResult> DeleteTable(
    string tableName, 
    [FromQuery] string @namespace = "default")
{
    try
    {
        var deleted = await _hbaseClient.DeleteTableAsync(tableName, @namespace);
        if (deleted)
        {
            return Ok(new { message = $"Table {@namespace}:{tableName} deleted successfully" });
        }
        return NotFound(new { error = $"Table {@namespace}:{tableName} not found" });
    }
    catch (Exception ex)
    {
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Step 3: Test the Method

```bash
curl -X DELETE http://localhost:8099/api/phoenix/hbase/tables/test_table?namespace=default
```

---

## Modifying Configuration

### Step 1: Add Configuration Key

Edit `appsettings.json`:

```json
{
  "Phoenix": {
    "Server": "localhost",
    "Port": "8765",
    "TimeoutSeconds": 300
  }
}
```

### Step 2: Read Configuration in Code

```csharp
public PhoenixRestClient(IConfiguration configuration)
{
    var server = configuration["Phoenix:Server"] ?? "localhost";
    var port = configuration["Phoenix:Port"] ?? "8765";
    var timeoutSeconds = int.Parse(configuration["Phoenix:TimeoutSeconds"] ?? "300");
    
    // Use timeoutSeconds in your code
}
```

### Step 3: Update Documentation

- Document new configuration key in XML comments
- Update `Documentation/DEVELOPMENT_HANDBOOK.md` if needed

---

## Adding Logging

### Step 1: Inject Logger

```csharp
public class PhoenixController : ControllerBase
{
    private readonly ILogger<PhoenixController> _logger;

    public PhoenixController(
        PhoenixRestClient phoenixClient,
        HBaseRestClient hbaseClient,
        ILogger<PhoenixController> logger)
    {
        _phoenixClient = phoenixClient;
        _hbaseClient = hbaseClient;
        _logger = logger;
    }
}
```

### Step 2: Add Logging Statements

```csharp
[HttpGet("tables")]
public async Task<IActionResult> GetTables()
{
    try
    {
        _logger.LogInformation("Retrieving list of tables");
        await EnsureConnectionAsync();
        var tables = await _phoenixClient.GetTablesAsync();
        _logger.LogInformation("Retrieved {Count} tables", tables.Rows.Count);
        return Ok(ConvertDataTableToJson(tables));
    }
    catch (Exception ex)
    {
        _logger.LogError(ex, "Error retrieving tables");
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Step 3: View Logs

```bash
# View application logs
docker logs -f phoenix-dotnet-app

# Or if running locally
# Logs appear in console output
```

---

## Handling Errors

### Step 1: Identify Error Types

- **Connection Errors**: InvalidOperationException
- **SQL Errors**: HttpRequestException from Phoenix Query Server
- **Validation Errors**: ArgumentException, ArgumentNullException
- **Configuration Errors**: InvalidOperationException

### Step 2: Add Error Handling

```csharp
[HttpPost("query")]
public async Task<IActionResult> ExecuteQuery([FromBody] QueryRequest request)
{
    // Validate input
    if (string.IsNullOrWhiteSpace(request?.Sql))
    {
        return BadRequest(new { error = "SQL query is required" });
    }

    try
    {
        await EnsureConnectionAsync();
        var results = await _phoenixClient.ExecuteQueryAsync(request.Sql);
        return Ok(ConvertDataTableToJson(results));
    }
    catch (InvalidOperationException ex) when (ex.Message.Contains("Connection"))
    {
        _logger?.LogError(ex, "Connection error executing query");
        return StatusCode(503, new { error = "Phoenix connection unavailable", details = ex.Message });
    }
    catch (HttpRequestException ex)
    {
        _logger?.LogError(ex, "Phoenix Query Server error");
        return StatusCode(502, new { error = "Phoenix Query Server error", details = ex.Message });
    }
    catch (Exception ex)
    {
        _logger?.LogError(ex, "Unexpected error executing query");
        return StatusCode(500, new { error = ex.Message });
    }
}
```

### Step 3: Test Error Scenarios

```bash
# Test with invalid SQL
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM NONEXISTENT_TABLE"}'

# Test with missing SQL
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Testing Your Changes

### Step 1: Run Unit Tests (if available)

```bash
dotnet test
```

### Step 2: Run Integration Tests

```bash
cd tests
./smoke_test.sh
./test_api_endpoints.sh
```

### Step 3: Manual Testing

1. Start the application
2. Test via Swagger UI: http://localhost:8099/swagger
3. Test via SQL GUI: http://localhost:8100
4. Test via curl commands
5. Check logs for errors

### Step 4: Test Error Scenarios

- Test with invalid input
- Test with missing data
- Test with connection failures
- Test with Phoenix server errors

---

## Deploying Changes

### Step 1: Build Docker Image

```bash
docker build -t phoenix-dotnet-app:latest .
```

### Step 2: Test Locally

```bash
docker-compose up --build
```

### Step 3: Verify Deployment

```bash
# Check containers are running
docker-compose ps

# Check health endpoint
curl http://localhost:8099/api/phoenix/health

# Run smoke tests
cd tests && ./smoke_test.sh
```

### Step 4: Push to Registry (if applicable)

```bash
docker tag phoenix-dotnet-app:latest registry.example.com/phoenix-dotnet-app:latest
docker push registry.example.com/phoenix-dotnet-app:latest
```

---

## Code Review Checklist

Before submitting code:

- [ ] Code follows style guidelines
- [ ] All public APIs have XML documentation
- [ ] Error handling is implemented
- [ ] Logging is added where appropriate
- [ ] Tests are written and passing
- [ ] No compiler warnings
- [ ] Code is formatted consistently
- [ ] Unused code is removed
- [ ] Configuration is externalized (no hardcoded values)
- [ ] Security considerations are addressed

---

## Common Patterns

### Pattern 1: Ensure Connection Before Operation

```csharp
private async Task EnsureConnectionAsync()
{
    try
    {
        await _phoenixClient.OpenAsync();
    }
    catch (InvalidOperationException)
    {
        // Connection already open, ignore
    }
    catch (Exception ex)
    {
        throw new InvalidOperationException($"Failed to establish connection: {ex.Message}", ex);
    }
}
```

### Pattern 2: Convert DataTable to JSON

```csharp
private static object ConvertDataTableToJson(DataTable dataTable)
{
    var columns = dataTable.Columns.Cast<DataColumn>()
        .Select(c => new { name = c.ColumnName, type = c.DataType.Name })
        .ToList();

    var rows = dataTable.Rows.Cast<DataRow>()
        .Select(r => dataTable.Columns.Cast<DataColumn>()
            .ToDictionary(c => c.ColumnName, c => r[c] == DBNull.Value ? null : r[c]))
        .ToList();

    return new { columns, rows, rowCount = dataTable.Rows.Count };
}
```

### Pattern 3: Retry Logic

```csharp
int maxRetries = 10;
int delaySeconds = 15;

for (int attempt = 1; attempt <= maxRetries; attempt++)
{
    try
    {
        // Operation
        return result;
    }
    catch (Exception ex)
    {
        if (attempt < maxRetries)
        {
            _logger?.LogWarning(ex, "Attempt {Attempt}/{MaxRetries} failed. Retrying...", attempt, maxRetries);
            await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
        }
        else
        {
            throw new InvalidOperationException($"Failed after {maxRetries} attempts", ex);
        }
    }
}
```

---

## Getting Help

If you get stuck:

1. Check `Documentation/TROUBLESHOOTING.md`
2. Run diagnostic script: `cd tests && ./diagnostic.sh`
3. Check logs: `docker logs phoenix-dotnet-app`
4. Review examples in `examples/` directory
5. Ask your team lead or colleagues

---

**Remember**: When in doubt, refer to existing code patterns in the codebase.

