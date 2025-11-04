using Microsoft.AspNetCore.Mvc;
using PhoenixDotNet;
using System.Data;

namespace PhoenixDotNet.Controllers;

/// <summary>
/// REST API controller for Phoenix and HBase operations
/// 
/// Provides HTTP endpoints for:
/// - Phoenix SQL operations (queries, commands, metadata)
/// - HBase REST API operations (table management, schema operations)
/// 
/// All endpoints return JSON responses with standardized error handling.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class PhoenixController : ControllerBase
{
    private readonly PhoenixConnection _phoenixConnection;
    private readonly PhoenixRestClient _phoenixRestClient; // Keep for fallback if needed
    private readonly HBaseRestClient _hbaseClient;
    private bool _useOdbc = true; // Flag to track if ODBC is available

    /// <summary>
    /// Initializes a new instance of the PhoenixController class
    /// </summary>
    /// <param name="phoenixConnection">Phoenix ODBC connection for querying Phoenix Query Server (primary)</param>
    /// <param name="phoenixRestClient">Phoenix REST API client (fallback if ODBC unavailable)</param>
    /// <param name="hbaseClient">HBase REST API client for direct HBase operations</param>
    public PhoenixController(PhoenixConnection phoenixConnection, PhoenixRestClient phoenixRestClient, HBaseRestClient hbaseClient)
    {
        _phoenixConnection = phoenixConnection ?? throw new ArgumentNullException(nameof(phoenixConnection));
        _phoenixRestClient = phoenixRestClient ?? throw new ArgumentNullException(nameof(phoenixRestClient));
        _hbaseClient = hbaseClient ?? throw new ArgumentNullException(nameof(hbaseClient));
        
        // Try to initialize ODBC connection, fallback to REST if it fails
        try
        {
            _phoenixConnection.Open();
            _useOdbc = true;
        }
        catch
        {
            // ODBC not available, will use REST API as fallback
            _useOdbc = false;
        }
    }

    /// <summary>
    /// Retrieves all tables in the Phoenix database
    /// </summary>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - columns: Array of column metadata (name, type)
    /// - rows: Array of table information dictionaries
    /// - rowCount: Number of tables found
    /// - message: Helpful message if no tables found
    /// </returns>
    /// <response code="200">Successfully retrieved table list</response>
    /// <response code="500">Internal server error (connection failure, Phoenix server error)</response>
    [HttpGet("tables")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetTables()
    {
        try
        {
            DataTable tables;
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                tables = await Task.Run(() => _phoenixConnection.GetTables());
            }
            else
            {
                await EnsureConnectionAsync();
                tables = await _phoenixRestClient.GetTablesAsync();
            }
            var result = ConvertDataTableToJson(tables);
            
            // If no tables found, provide helpful message
            if (tables.Rows.Count == 0 && tables.Columns.Count == 0)
            {
                return Ok(new 
                { 
                    columns = new List<object>(),
                    rows = new List<Dictionary<string, object?>>(),
                    rowCount = 0,
                    message = "No tables found in Phoenix. Create a table using: POST /api/phoenix/execute with SQL: CREATE TABLE ..."
                });
            }
            
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves column information for a specific table
    /// </summary>
    /// <param name="tableName">Name of the table to retrieve columns for. Case-sensitive.</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - columns: Array of column metadata (name, type)
    /// - rows: Array of column information dictionaries
    /// - rowCount: Number of columns found
    /// </returns>
    /// <response code="200">Successfully retrieved column information</response>
    /// <response code="500">Internal server error (table not found, connection failure)</response>
    /// <remarks>
    /// Table names in Phoenix are case-sensitive. Use uppercase names or quoted names.
    /// Example: "EXAMPLE_TABLE" or "example_table" (quoted)
    /// </remarks>
    [HttpGet("tables/{tableName}/columns")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetColumns(string tableName)
    {
        try
        {
            DataTable columns;
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                columns = await Task.Run(() => _phoenixConnection.GetColumns(tableName));
            }
            else
            {
                await EnsureConnectionAsync();
                columns = await _phoenixRestClient.GetColumnsAsync(tableName);
            }
            var result = ConvertDataTableToJson(columns);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Executes a SQL SELECT query and returns results
    /// </summary>
    /// <param name="request">Query request containing the SQL SELECT statement</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - columns: Array of column metadata (name, type)
    /// - rows: Array of result row dictionaries
    /// - rowCount: Number of rows returned
    /// - message: Helpful message if no results (query executed successfully but returned no data)
    /// </returns>
    /// <response code="200">Query executed successfully</response>
    /// <response code="400">Bad request (SQL query is missing or invalid)</response>
    /// <response code="500">Internal server error (SQL syntax error, table not found, connection failure)</response>
    /// <remarks>
    /// This endpoint is for SELECT queries only. Use /execute for DDL/DML commands.
    /// Trailing semicolons are automatically removed.
    /// Maximum result set size: 10,000 rows (configurable in PhoenixRestClient)
    /// </remarks>
    [HttpPost("query")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 400)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> ExecuteQuery([FromBody] QueryRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Sql))
        {
            return BadRequest(new { error = "SQL query is required" });
        }

        try
        {
            DataTable results;
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                // Remove trailing semicolon for ODBC (same as REST)
                var sql = request.Sql.TrimEnd().TrimEnd(';').TrimEnd();
                results = await Task.Run(() => _phoenixConnection.ExecuteQuery(sql));
            }
            else
            {
                await EnsureConnectionAsync();
                results = await _phoenixRestClient.ExecuteQueryAsync(request.Sql);
            }
            var result = ConvertDataTableToJson(results);
            return Ok(result);
        }
        catch (Exception ex)
        {
            // Provide helpful error messages for common issues
            var errorMessage = ex.Message;
            var suggestion = "";
            
            // Check if it's a table not found error
            if (errorMessage.Contains("Table undefined") || 
                errorMessage.Contains("TableNotFoundException") || 
                errorMessage.Contains("Table not found"))
            {
                suggestion = "The table does not exist. Create it using: POST /api/phoenix/execute with SQL: CREATE TABLE ... " +
                            "Example: CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username VARCHAR(50), email VARCHAR(100))";
            }
            
            return StatusCode(500, new 
            { 
                error = errorMessage,
                suggestion = string.IsNullOrEmpty(suggestion) ? null : suggestion
            });
        }
    }

    /// <summary>
    /// Executes a non-query SQL statement (DDL/DML commands)
    /// </summary>
    /// <param name="request">Query request containing the SQL statement to execute</param>
    /// <returns>
    /// HTTP 200 OK with success message
    /// </returns>
    /// <response code="200">Command executed successfully</response>
    /// <response code="400">Bad request (SQL statement is missing or invalid)</response>
    /// <response code="500">Internal server error (SQL syntax error, table not found, connection failure)</response>
    /// <remarks>
    /// Supported SQL statements:
    /// - CREATE TABLE, CREATE VIEW
    /// - UPSERT (Phoenix's INSERT/UPDATE)
    /// - DELETE
    /// - DROP TABLE, DROP VIEW
    /// - ALTER TABLE
    /// Trailing semicolons are automatically removed.
    /// </remarks>
    [HttpPost("execute")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 400)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> ExecuteNonQuery([FromBody] QueryRequest request)
    {
        if (string.IsNullOrWhiteSpace(request?.Sql))
        {
            return BadRequest(new { error = "SQL statement is required" });
        }

        try
        {
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                // Remove trailing semicolon for ODBC (same as REST)
                var sql = request.Sql.TrimEnd().TrimEnd(';').TrimEnd();
                await Task.Run(() => _phoenixConnection.ExecuteNonQuery(sql));
            }
            else
            {
                await EnsureConnectionAsync();
                await _phoenixRestClient.ExecuteNonQueryAsync(request.Sql);
            }
            return Ok(new { message = "Command executed successfully" });
        }
        catch (Exception ex)
        {
            // Provide helpful error messages for common issues
            var errorMessage = ex.Message;
            var suggestion = "";
            
            // Check if it's a table not found error
            if (errorMessage.Contains("Table undefined") || 
                errorMessage.Contains("TableNotFoundException") || 
                errorMessage.Contains("Table not found"))
            {
                suggestion = "The table does not exist. Create it first using CREATE TABLE statement. " +
                            "Example: CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username VARCHAR(50), email VARCHAR(100))";
            }
            
            return StatusCode(500, new 
            { 
                error = errorMessage,
                suggestion = string.IsNullOrEmpty(suggestion) ? null : suggestion
            });
        }
    }

    /// <summary>
    /// Health check endpoint for monitoring application availability
    /// </summary>
    /// <returns>
    /// HTTP 200 OK with health status and timestamp
    /// </returns>
    /// <response code="200">Application is healthy and responding</response>
    /// <remarks>
    /// This endpoint does not check Phoenix connection status, only application availability.
    /// Use this for load balancer health checks and monitoring systems.
    /// </remarks>
    [HttpGet("health")]
    [ProducesResponseType(typeof(object), 200)]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", timestamp = DateTime.UtcNow });
    }

    /// <summary>
    /// Creates a sensor information table with predefined schema using HBase REST API
    /// </summary>
    /// <param name="request">Optional request containing table name and namespace. If null, uses defaults.</param>
    /// <returns>
    /// HTTP 200 OK if table was created, HTTP 409 Conflict if table already exists
    /// </returns>
    /// <response code="200">Table created successfully</response>
    /// <response code="409">Table already exists</response>
    /// <response code="500">Internal server error (HBase API error, connection failure)</response>
    /// <remarks>
    /// Creates a table with predefined column families:
    /// - metadata: Sensor metadata (type, location, manufacturer, etc.)
    /// - readings: Sensor readings (timestamped measurements)
    /// - status: Sensor status (active, last_seen, battery_level, etc.)
    /// 
    /// Default table name: "sensor_info"
    /// Default namespace: "default"
    /// </remarks>
    [HttpPost("hbase/tables/sensor")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 409)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> CreateSensorTable([FromBody] CreateSensorTableRequest? request = null)
    {
        try
        {
            var tableName = request?.TableName ?? "sensor_info";
            var @namespace = request?.Namespace ?? "default";
            
            var created = await _hbaseClient.CreateSensorTableAsync(tableName, @namespace);
            
            if (created)
            {
                return Ok(new 
                { 
                    message = $"Sensor table '{@namespace}:{tableName}' created successfully",
                    tableName = tableName,
                    @namespace = @namespace,
                    columnFamilies = new[] { "metadata", "readings", "status" }
                });
            }
            else
            {
                return Conflict(new 
                { 
                    message = $"Sensor table '{@namespace}:{tableName}' already exists",
                    tableName = tableName,
                    @namespace = @namespace
                });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Checks if a table exists in HBase using HBase REST API
    /// </summary>
    /// <param name="tableName">Name of the table to check</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - tableName: Name of the table
    /// - namespace: Namespace of the table
    /// - exists: Boolean indicating if table exists
    /// </returns>
    /// <response code="200">Check completed successfully</response>
    /// <response code="500">Internal server error (HBase API error, connection failure)</response>
    [HttpGet("hbase/tables/{tableName}/exists")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> TableExists(string tableName, [FromQuery] string @namespace = "default")
    {
        try
        {
            var exists = await _hbaseClient.TableExistsAsync(tableName, @namespace);
            return Ok(new 
            { 
                tableName = tableName,
                @namespace = @namespace,
                exists = exists
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves table schema information from HBase using HBase REST API
    /// </summary>
    /// <param name="tableName">Name of the table to get schema for</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - tableName: Name of the table
    /// - namespace: Namespace of the table
    /// - schema: JSON string containing table schema (column families, properties)
    /// </returns>
    /// <response code="200">Schema retrieved successfully</response>
    /// <response code="404">Table not found (schema will be null)</response>
    /// <response code="500">Internal server error (HBase API error, connection failure)</response>
    [HttpGet("hbase/tables/{tableName}/schema")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 404)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetTableSchema(string tableName, [FromQuery] string @namespace = "default")
    {
        try
        {
            var schema = await _hbaseClient.GetTableSchemaAsync(tableName, @namespace);
            return Ok(new 
            { 
                tableName = tableName,
                @namespace = @namespace,
                schema = schema
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Inserts data into an HBase table using HBase REST API
    /// </summary>
    /// <param name="tableName">Name of the table to insert data into (used if request.TableName is null)</param>
    /// <param name="request">Request containing row key, column family, column, value, and optional namespace</param>
    /// <returns>
    /// HTTP 200 OK with success message and inserted data details
    /// </returns>
    /// <response code="200">Data inserted successfully</response>
    /// <response code="400">Bad request (missing required fields)</response>
    /// <response code="500">Internal server error (HBase API error, connection failure, table not found)</response>
    /// <remarks>
    /// The row key, column family, column, and value are Base64-encoded in the HBase REST API format.
    /// This method inserts a single cell value. For multiple cells, make multiple requests or use Phoenix SQL.
    /// </remarks>
    [HttpPut("hbase/tables/{tableName}/data")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 400)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> PutData(string tableName, [FromBody] PutDataRequest request)
    {
        try
        {
            var inserted = await _hbaseClient.PutDataAsync(
                request.TableName ?? tableName,
                request.RowKey,
                request.ColumnFamily,
                request.Column,
                request.Value,
                request.Namespace ?? "default"
            );
            
            if (inserted)
            {
                return Ok(new 
                { 
                    message = $"Data inserted successfully into {request.Namespace ?? "default"}:{request.TableName ?? tableName}",
                    rowKey = request.RowKey,
                    columnFamily = request.ColumnFamily,
                    column = request.Column,
                    value = request.Value
                });
            }
            else
            {
                return StatusCode(500, new { error = "Failed to insert data" });
            }
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Creates a Phoenix view on an HBase table
    /// </summary>
    /// <param name="request">Request containing view name, HBase table name, namespace, and column definitions</param>
    /// <returns>
    /// HTTP 200 OK if view was created successfully
    /// HTTP 400 Bad Request if request is invalid or HBase table doesn't exist
    /// HTTP 500 Internal Server Error if view creation fails
    /// </returns>
    /// <response code="200">View created successfully</response>
    /// <response code="400">Bad request (missing required fields, HBase table not found)</response>
    /// <response code="500">Internal server error (Phoenix SQL error, connection failure)</response>
    /// <remarks>
    /// This endpoint:
    /// 1. Validates that the HBase table exists
    /// 2. Generates a CREATE VIEW SQL statement
    /// 3. Executes the SQL statement via Phoenix
    /// 
    /// The view will map Phoenix columns to the HBase table structure.
    /// The first column with IsPrimaryKey=true will be the PRIMARY KEY (typically the row key).
    /// 
    /// Example request:
    /// {
    ///   "viewName": "sensor_readings_view",
    ///   "hBaseTableName": "sensor_readings",
    ///   "namespace": "default",
    ///   "columns": [
    ///     { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
    ///     { "name": "sensor_type", "type": "VARCHAR", "isPrimaryKey": false },
    ///     { "name": "timestamp", "type": "BIGINT", "isPrimaryKey": false },
    ///     { "name": "temperature", "type": "DOUBLE", "isPrimaryKey": false }
    ///   ]
    /// }
    /// </remarks>
    [HttpPost("views")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 400)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> CreateView([FromBody] CreateViewRequest request)
    {
        if (request == null)
        {
            return BadRequest(new { error = "Request body is required" });
        }

        if (string.IsNullOrWhiteSpace(request.ViewName))
        {
            return BadRequest(new { error = "ViewName is required" });
        }

        if (string.IsNullOrWhiteSpace(request.HBaseTableName))
        {
            return BadRequest(new { error = "HBaseTableName is required" });
        }

        if (request.Columns == null || request.Columns.Count == 0)
        {
            return BadRequest(new { error = "At least one column definition is required" });
        }

        try
        {
            // Verify HBase table exists
            var @namespace = string.IsNullOrWhiteSpace(request.Namespace) ? "default" : request.Namespace;
            var tableExists = await _hbaseClient.TableExistsAsync(request.HBaseTableName, @namespace);
            
            if (!tableExists)
            {
                return BadRequest(new 
                { 
                    error = $"HBase table '{@namespace}:{request.HBaseTableName}' does not exist",
                    suggestion = $"Create the table first using: POST /api/phoenix/hbase/tables/sensor or POST /api/phoenix/hbase/tables/{request.HBaseTableName}"
                });
            }

            // Build CREATE VIEW SQL statement
            var columnDefinitions = new List<string>();
            var primaryKeyColumn = request.Columns.FirstOrDefault(c => c.IsPrimaryKey);
            
            if (primaryKeyColumn == null)
            {
                // If no primary key is specified, use the first column
                primaryKeyColumn = request.Columns[0];
            }

            foreach (var column in request.Columns)
            {
                var columnDef = $"{column.Name} {column.Type}";
                // Only mark the primary key column (or first column if none specified)
                if (column == primaryKeyColumn)
                {
                    columnDef += " PRIMARY KEY";
                }
                columnDefinitions.Add(columnDef);
            }

            // Construct the CREATE VIEW SQL
            var columnsSql = string.Join(", ", columnDefinitions);
            var hbaseTableRef = $"\"{@namespace}:{request.HBaseTableName}\"";
            var createViewSql = $"CREATE VIEW IF NOT EXISTS {request.ViewName} ({columnsSql}) AS SELECT * FROM {hbaseTableRef}";

            // Execute the CREATE VIEW statement
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                await Task.Run(() => _phoenixConnection.ExecuteNonQuery(createViewSql));
            }
            else
            {
                await EnsureConnectionAsync();
                await _phoenixRestClient.ExecuteNonQueryAsync(createViewSql);
            }

            return Ok(new 
            { 
                message = $"Phoenix view '{request.ViewName}' created successfully on HBase table '{@namespace}:{request.HBaseTableName}'",
                viewName = request.ViewName,
                hBaseTableName = request.HBaseTableName,
                @namespace = @namespace,
                sql = createViewSql
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves all views in the Phoenix database
    /// </summary>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - columns: Array of column metadata (name, type)
    /// - rows: Array of view information dictionaries
    /// - rowCount: Number of views found
    /// - message: Helpful message if no views found
    /// </returns>
    /// <response code="200">Successfully retrieved view list</response>
    /// <response code="500">Internal server error (connection failure, Phoenix server error)</response>
    /// <remarks>
    /// This endpoint queries SYSTEM.CATALOG to filter only views (TABLE_TYPE = 'v').
    /// Views are read-only query interfaces to underlying tables, typically used for HBase-native tables.
    /// </remarks>
    [HttpGet("views")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetViews()
    {
        try
        {
            DataTable views;
            var query = "SELECT TABLE_NAME, TABLE_SCHEM, TABLE_TYPE FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' ORDER BY TABLE_NAME";
            
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                views = await Task.Run(() => _phoenixConnection.ExecuteQuery(query));
            }
            else
            {
                await EnsureConnectionAsync();
                views = await _phoenixRestClient.ExecuteQueryAsync(query);
            }
            
            var result = ConvertDataTableToJson(views);
            
            // If no views found, provide helpful message
            if (views.Rows.Count == 0)
            {
                return Ok(new 
                { 
                    columns = result.GetType().GetProperty("columns")?.GetValue(result) ?? new List<object>(),
                    rows = new List<Dictionary<string, object?>>(),
                    rowCount = 0,
                    message = "No views found in Phoenix. Create a view using: POST /api/phoenix/views"
                });
            }
            
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves detailed information about a specific view
    /// </summary>
    /// <param name="viewName">Name of the view to retrieve details for. Case-sensitive.</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - viewName: Name of the view
    /// - columns: Array of column information
    /// - rowCount: Number of columns
    /// </returns>
    /// <response code="200">Successfully retrieved view information</response>
    /// <response code="404">View not found</response>
    /// <response code="500">Internal server error (connection failure)</response>
    /// <remarks>
    /// View names in Phoenix are case-sensitive. Use uppercase names or quoted names.
    /// This endpoint returns the same information as GET /api/phoenix/views/{viewName}/columns.
    /// </remarks>
    [HttpGet("views/{viewName}")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 404)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetView(string viewName)
    {
        try
        {
            // First verify the view exists
            var viewExistsQuery = "SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' AND TABLE_NAME = ?";
            DataTable viewCheck;
            
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                // ODBC doesn't support parameterized queries easily, so use string interpolation (safe here as viewName is validated)
                viewCheck = await Task.Run(() => _phoenixConnection.ExecuteQuery($"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' AND TABLE_NAME = '{viewName.ToUpper()}'"));
            }
            else
            {
                await EnsureConnectionAsync();
                viewCheck = await _phoenixRestClient.ExecuteQueryAsync($"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' AND TABLE_NAME = '{viewName.ToUpper()}'");
            }
            
            if (viewCheck.Rows.Count == 0)
            {
                return NotFound(new 
                { 
                    error = $"View '{viewName}' not found",
                    suggestion = "List all views using: GET /api/phoenix/views"
                });
            }
            
            // Get column information
            DataTable columns;
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                columns = await Task.Run(() => _phoenixConnection.GetColumns(viewName));
            }
            else
            {
                await EnsureConnectionAsync();
                columns = await _phoenixRestClient.GetColumnsAsync(viewName);
            }
            
            var result = ConvertDataTableToJson(columns);
            return Ok(new
            {
                viewName = viewName,
                columns = result.GetType().GetProperty("columns")?.GetValue(result) ?? new List<object>(),
                rows = result.GetType().GetProperty("rows")?.GetValue(result) ?? new List<Dictionary<string, object?>>(),
                rowCount = columns.Rows.Count
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves column information for a specific view
    /// </summary>
    /// <param name="viewName">Name of the view to retrieve columns for. Case-sensitive.</param>
    /// <returns>
    /// HTTP 200 OK with JSON response containing:
    /// - columns: Array of column metadata (name, type)
    /// - rows: Array of column information dictionaries
    /// - rowCount: Number of columns found
    /// </returns>
    /// <response code="200">Successfully retrieved column information</response>
    /// <response code="404">View not found</response>
    /// <response code="500">Internal server error (view not found, connection failure)</response>
    /// <remarks>
    /// View names in Phoenix are case-sensitive. Use uppercase names or quoted names.
    /// This is a convenience endpoint that provides the same functionality as GET /api/phoenix/tables/{viewName}/columns
    /// but specifically for views.
    /// </remarks>
    [HttpGet("views/{viewName}/columns")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 404)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetViewColumns(string viewName)
    {
        try
        {
            // First verify the view exists
            var viewExistsQuery = $"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' AND TABLE_NAME = '{viewName.ToUpper()}'";
            DataTable viewCheck;
            
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                viewCheck = await Task.Run(() => _phoenixConnection.ExecuteQuery(viewExistsQuery));
            }
            else
            {
                await EnsureConnectionAsync();
                viewCheck = await _phoenixRestClient.ExecuteQueryAsync(viewExistsQuery);
            }
            
            if (viewCheck.Rows.Count == 0)
            {
                return NotFound(new 
                { 
                    error = $"View '{viewName}' not found",
                    suggestion = "List all views using: GET /api/phoenix/views"
                });
            }
            
            // Get column information
            DataTable columns;
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                columns = await Task.Run(() => _phoenixConnection.GetColumns(viewName));
            }
            else
            {
                await EnsureConnectionAsync();
                columns = await _phoenixRestClient.GetColumnsAsync(viewName);
            }
            
            var result = ConvertDataTableToJson(columns);
            return Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Drops a Phoenix view
    /// </summary>
    /// <param name="viewName">Name of the view to drop. Case-sensitive.</param>
    /// <returns>
    /// HTTP 200 OK if view was dropped successfully
    /// HTTP 404 Not Found if view doesn't exist
    /// HTTP 500 Internal Server Error if view drop fails
    /// </returns>
    /// <response code="200">View dropped successfully</response>
    /// <response code="404">View not found</response>
    /// <response code="500">Internal server error (Phoenix SQL error, connection failure)</response>
    /// <remarks>
    /// Dropping a view does not affect the underlying table data.
    /// View names in Phoenix are case-sensitive.
    /// </remarks>
    [HttpDelete("views/{viewName}")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 404)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> DropView(string viewName)
    {
        try
        {
            // First verify the view exists
            var viewExistsQuery = $"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'v' AND TABLE_NAME = '{viewName.ToUpper()}'";
            DataTable viewCheck;
            
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                viewCheck = await Task.Run(() => _phoenixConnection.ExecuteQuery(viewExistsQuery));
            }
            else
            {
                await EnsureConnectionAsync();
                viewCheck = await _phoenixRestClient.ExecuteQueryAsync(viewExistsQuery);
            }
            
            if (viewCheck.Rows.Count == 0)
            {
                return NotFound(new 
                { 
                    error = $"View '{viewName}' not found",
                    suggestion = "List all views using: GET /api/phoenix/views"
                });
            }
            
            // Drop the view
            var dropSql = $"DROP VIEW IF EXISTS {viewName}";
            
            if (_useOdbc)
            {
                EnsureOdbcConnection();
                await Task.Run(() => _phoenixConnection.ExecuteNonQuery(dropSql));
            }
            else
            {
                await EnsureConnectionAsync();
                await _phoenixRestClient.ExecuteNonQueryAsync(dropSql);
            }
            
            return Ok(new 
            { 
                message = $"View '{viewName}' dropped successfully",
                viewName = viewName
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    /// <summary>
    /// Ensures that the Phoenix ODBC connection is open before executing operations
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown when ODBC connection cannot be established
    /// </exception>
    /// <remarks>
    /// This method attempts to open the ODBC connection if not already open.
    /// If ODBC is not available, sets _useOdbc to false to fallback to REST API.
    /// </remarks>
    private void EnsureOdbcConnection()
    {
        if (!_useOdbc)
        {
            throw new InvalidOperationException("ODBC connection is not available. Falling back to REST API.");
        }

        try
        {
            if (_phoenixConnection == null)
            {
                throw new InvalidOperationException("PhoenixConnection is not initialized.");
            }

            // PhoenixConnection.Open() is synchronous, but we're in an async context
            // The connection state is checked internally by PhoenixConnection
            _phoenixConnection.Open();
        }
        catch (Exception ex)
        {
            // If ODBC fails, disable it and fallback to REST
            _useOdbc = false;
            throw new InvalidOperationException($"Failed to establish Phoenix ODBC connection: {ex.Message}. Will fallback to REST API.", ex);
        }
    }

    /// <summary>
    /// Ensures that the Phoenix REST API connection is open before executing operations
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection cannot be established after retries
    /// </exception>
    /// <remarks>
    /// This method attempts to open the REST API connection if not already open.
    /// If the connection is already open, returns immediately.
    /// Connection errors are re-thrown to be handled by the calling method.
    /// </remarks>
    private async Task EnsureConnectionAsync()
    {
        try
        {
            await _phoenixRestClient.OpenAsync();
        }
        catch (InvalidOperationException)
        {
            // If connection is already open, this will return early, so we can ignore
            // If it's a real connection error, it will be caught and handled by the calling method
        }
        catch (Exception ex)
        {
            // Log the error but don't throw here - let the actual operation handle it
            // This allows us to see the real error when the operation fails
            throw new InvalidOperationException($"Failed to establish Phoenix REST API connection: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Converts a DataTable to a JSON-serializable object structure
    /// </summary>
    /// <param name="dataTable">The DataTable to convert</param>
    /// <returns>
    /// A dictionary containing:
    /// - columns: Array of column metadata objects with name and type
    /// - rows: Array of dictionaries representing rows (column name -> value)
    /// - rowCount: Number of rows in the result set
    /// - message: Optional helpful message if no results but query succeeded
    /// </returns>
    /// <remarks>
    /// DBNull values are converted to null for JSON serialization.
    /// If the result set is empty but has columns, a helpful message is included.
    /// </remarks>
    private static object ConvertDataTableToJson(System.Data.DataTable dataTable)
    {
        var columns = new List<object>();
        foreach (System.Data.DataColumn column in dataTable.Columns)
        {
            columns.Add(new
            {
                name = column.ColumnName,
                type = column.DataType.Name
            });
        }

        var rows = new List<Dictionary<string, object?>>();
        foreach (System.Data.DataRow row in dataTable.Rows)
        {
            var rowDict = new Dictionary<string, object?>();
            foreach (System.Data.DataColumn column in dataTable.Columns)
            {
                rowDict[column.ColumnName] = row[column] == DBNull.Value ? null : row[column];
            }
            rows.Add(rowDict);
        }

        var result = new Dictionary<string, object>
        {
            ["columns"] = columns,
            ["rows"] = rows,
            ["rowCount"] = dataTable.Rows.Count
        };

        // Add helpful message if no results but query executed successfully
        if (dataTable.Rows.Count == 0 && dataTable.Columns.Count > 0)
        {
            result["message"] = "Query executed successfully but returned no results. This may indicate no data exists matching the query criteria.";
        }

        return result;
    }
}

/// <summary>
/// Request model for SQL query/command execution
/// </summary>
public class QueryRequest
{
    /// <summary>
    /// SQL statement to execute (SELECT query or DDL/DML command)
    /// </summary>
    public string Sql { get; set; } = string.Empty;
}

/// <summary>
/// Request model for creating a sensor information table
/// </summary>
public class CreateSensorTableRequest
{
    /// <summary>
    /// Name of the table to create (default: "sensor_info")
    /// </summary>
    public string TableName { get; set; } = "sensor_info";

    /// <summary>
    /// HBase namespace for the table (default: "default")
    /// </summary>
    public string Namespace { get; set; } = "default";
}

    /// <summary>
    /// Request model for inserting data into an HBase table
    /// </summary>
    public class PutDataRequest
    {
        /// <summary>
        /// Optional table name (if not provided, uses tableName from route)
        /// </summary>
        public string? TableName { get; set; }

        /// <summary>
        /// Row key for the data to insert
        /// </summary>
        public string RowKey { get; set; } = string.Empty;

        /// <summary>
        /// Column family name
        /// </summary>
        public string ColumnFamily { get; set; } = string.Empty;

        /// <summary>
        /// Column qualifier name
        /// </summary>
        public string Column { get; set; } = string.Empty;

        /// <summary>
        /// Value to insert
        /// </summary>
        public string Value { get; set; } = string.Empty;

        /// <summary>
        /// Optional HBase namespace (default: "default" if not specified)
        /// </summary>
        public string? Namespace { get; set; }
    }

    /// <summary>
    /// Request model for creating a Phoenix view on an HBase table
    /// </summary>
    public class CreateViewRequest
    {
        /// <summary>
        /// Name of the Phoenix view to create
        /// </summary>
        public string ViewName { get; set; } = string.Empty;

        /// <summary>
        /// Name of the HBase table to create the view on
        /// </summary>
        public string HBaseTableName { get; set; } = string.Empty;

        /// <summary>
        /// HBase namespace (default: "default")
        /// </summary>
        public string Namespace { get; set; } = "default";

        /// <summary>
        /// List of column definitions for the view
        /// Each column should have: name (string) and type (string, e.g., "VARCHAR", "INTEGER", "BIGINT", "DOUBLE")
        /// The first column should be the PRIMARY KEY (typically the row key)
        /// </summary>
        public List<ViewColumnDefinition> Columns { get; set; } = new();
    }

    /// <summary>
    /// Column definition for a Phoenix view
    /// </summary>
    public class ViewColumnDefinition
    {
        /// <summary>
        /// Column name
        /// </summary>
        public string Name { get; set; } = string.Empty;

        /// <summary>
        /// Column data type (e.g., "VARCHAR", "INTEGER", "BIGINT", "DOUBLE", "BOOLEAN")
        /// </summary>
        public string Type { get; set; } = "VARCHAR";

        /// <summary>
        /// Whether this column is the PRIMARY KEY (typically the row key)
        /// </summary>
        public bool IsPrimaryKey { get; set; } = false;
    }

