using System.Data;
using System.Net.Http.Json;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;

namespace PhoenixDotNet;

/// <summary>
/// Phoenix REST API client using Avatica protocol
/// 
/// This client connects to Phoenix Query Server via HTTP/JSON using the Avatica protocol.
/// It provides methods for executing SQL queries and commands against Apache Phoenix.
/// 
/// Features:
/// - Automatic connection management with retry logic (up to 10 attempts, 15-second delays)
/// - Connection ID management for session state
/// - Automatic type conversion from Avatica types to .NET types
/// - DataTable conversion for easy data manipulation
/// - Detailed error messages with troubleshooting guidance
/// 
/// Protocol:
/// - Uses Avatica JSON protocol (not Protobuf)
/// - Base URL format: http://{server}:{port}/json
/// - Request format: {"request": "prepareAndExecute", "connectionId": "...", "sql": "..."}
/// 
/// Thread Safety:
/// - This class is not thread-safe. Use a singleton instance per application.
/// </summary>
public class PhoenixRestClient : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private string? _connectionId;
    private int _statementIdCounter = 0;
    private bool _disposed = false;

    /// <summary>
    /// Initializes a new instance of PhoenixRestClient using configuration
    /// </summary>
    /// <param name="configuration">Application configuration containing Phoenix:Server and Phoenix:Port</param>
    /// <remarks>
    /// Configuration keys:
    /// - Phoenix:Server (default: "localhost")
    /// - Phoenix:Port (default: "8765")
    /// 
    /// The base URL is constructed as: http://{server}:{port}/json
    /// </remarks>
    public PhoenixRestClient(IConfiguration configuration)
    {
        var server = configuration["Phoenix:Server"] ?? "localhost";
        var port = configuration["Phoenix:Port"] ?? "8765";
        // Phoenix Query Server JSON endpoint
        _baseUrl = $"http://{server}:{port}/json";
        
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(_baseUrl),
            Timeout = TimeSpan.FromMinutes(5)
        };
    }

    /// <summary>
    /// Initializes a new instance of PhoenixRestClient using a base URL
    /// </summary>
    /// <param name="baseUrl">Base URL for Phoenix Query Server (e.g., "http://localhost:8765/json")</param>
    /// <remarks>
    /// If the base URL doesn't end with "/json", it will be automatically appended.
    /// </remarks>
    public PhoenixRestClient(string baseUrl)
    {
        // Ensure base URL ends with /json for Phoenix Query Server
        _baseUrl = baseUrl.TrimEnd('/');
        if (!_baseUrl.EndsWith("/json"))
        {
            _baseUrl = _baseUrl + "/json";
        }
        
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(_baseUrl),
            Timeout = TimeSpan.FromMinutes(5)
        };
    }

    /// <summary>
    /// Opens a connection to Phoenix Query Server
    /// </summary>
    /// <returns>Task representing the asynchronous operation</returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection fails after all retry attempts (up to 10 attempts, 15-second delays)
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Generates a unique connection ID (GUID)
    /// - Sends an "openConnection" request to Phoenix Query Server
    /// - Retries up to 10 times with 15-second delays if connection fails
    /// - Provides detailed error messages including protocol mismatch detection
    /// 
    /// If already connected, returns immediately without reconnecting.
    /// 
    /// Initialization Time:
    /// HBase/Phoenix may take 60-90 seconds to fully initialize. The retry logic accommodates this.
    /// </remarks>
    public async Task OpenAsync()
    {
        if (_connectionId != null)
        {
            return; // Already connected
        }

        _connectionId = Guid.NewGuid().ToString();
        
        // Avatica protocol format for openConnection
        var request = new Dictionary<string, object>
        {
            ["request"] = "openConnection",
            ["connectionId"] = _connectionId,
            ["info"] = new Dictionary<string, object>()
        };

        // Retry connection up to 10 times with delays (increased for HBase initialization)
        int maxRetries = 10;
        int delaySeconds = 15;  // Increased delay to allow HBase/Phoenix to fully initialize
        
        for (int attempt = 1; attempt <= maxRetries; attempt++)
        {
            try
            {
                // Use StringContent for JSON to ensure proper content type
                var jsonContent = JsonSerializer.Serialize(request);
                var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
                var response = await _httpClient.PostAsync("", content);
                response.EnsureSuccessStatusCode();
                var result = await response.Content.ReadAsStringAsync();
                Console.WriteLine($"Connected to Apache Phoenix Query Server at {_baseUrl}");
                return;
            }
            catch (HttpRequestException ex)
            {
                var responseText = "";
                try
                {
                    var response = await _httpClient.PostAsync("", new StringContent(
                        JsonSerializer.Serialize(request), Encoding.UTF8, "application/json"));
                    responseText = await response.Content.ReadAsStringAsync();
                }
                catch { }
                
                if (attempt < maxRetries)
                {
                    Console.WriteLine($"Connection attempt {attempt}/{maxRetries} failed. Retrying in {delaySeconds} seconds...");
                    if (!string.IsNullOrEmpty(responseText))
                    {
                        Console.WriteLine($"Response: {responseText.Substring(0, Math.Min(200, responseText.Length))}");
                    }
                    await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
                }
                else
                {
                    var errorMessage = $"Failed to connect to Phoenix Query Server at {_baseUrl} after {maxRetries} attempts. " +
                        "Please verify that Phoenix Query Server is running and accessible. " +
                        $"Check: docker-compose logs opdb-docker";
                    
                    if (!string.IsNullOrEmpty(responseText))
                    {
                        errorMessage += $"\n\nServer Response: {responseText.Substring(0, Math.Min(500, responseText.Length))}";
                        
                        // Check if it's a protocol mismatch error
                        if (responseText.Contains("InvalidProtocolBufferException") || responseText.Contains("InvalidWireTypeException"))
                        {
                            errorMessage += "\n\nNOTE: Phoenix Query Server 6.0.0 uses Protobuf as the default transport mechanism. " +
                                "The JSON endpoint may not be properly configured. " +
                                "This error typically indicates that the server is trying to parse JSON as Protobuf. " +
                                "Consider:\n" +
                                "1. Waiting longer for HBase/Phoenix to fully initialize (can take 60+ seconds)\n" +
                                "2. Verifying Phoenix Query Server configuration for JSON endpoint support\n" +
                                "3. Using Protobuf protocol if JSON is not available in this version";
                        }
                    }
                    
                    throw new InvalidOperationException(errorMessage, ex);
                }
            }
        }
    }

    /// <summary>
    /// Closes the connection to Phoenix Query Server
    /// </summary>
    /// <returns>Task representing the asynchronous operation</returns>
    /// <remarks>
    /// This method:
    /// - Sends a "closeConnection" request to Phoenix Query Server
    /// - Clears the connection ID
    /// - Ignores errors during close operation
    /// 
    /// If not connected, returns immediately.
    /// </remarks>
    public async Task CloseAsync()
    {
        if (_connectionId == null)
        {
            return;
        }

        var request = new Dictionary<string, object>
        {
            ["request"] = "closeConnection",
            ["connectionId"] = _connectionId
        };

        try
        {
            var jsonContent = JsonSerializer.Serialize(request);
            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
            await _httpClient.PostAsync("", content);
            Console.WriteLine("Disconnected from Apache Phoenix Query Server");
        }
        catch
        {
            // Ignore errors during close
        }
        finally
        {
            _connectionId = null;
        }
    }

    /// <summary>
    /// Executes a SQL SELECT query and returns the results as a DataTable
    /// </summary>
    /// <param name="sql">SQL SELECT statement to execute</param>
    /// <returns>
    /// DataTable containing query results with columns and rows.
    /// Returns empty DataTable if no results or query returns no rows.
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call OpenAsync() first.
    /// </exception>
    /// <exception cref="HttpRequestException">
    /// Thrown when Phoenix Query Server returns an error status code.
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Automatically removes trailing semicolons (Phoenix doesn't accept them in REST API)
    /// - Uses "prepareAndExecute" Avatica request
    /// - Limits results to 10,000 rows (maxRowCount and maxRowsTotal)
    /// - Converts Avatica response to .NET DataTable
    /// - Maps Avatica types to .NET types automatically
    /// 
    /// Maximum Result Set:
    /// Results are limited to 10,000 rows. Use WHERE clauses or LIMIT to manage result sizes.
    /// 
    /// Empty Results:
    /// If the query executes successfully but returns no rows, an empty DataTable with columns is returned.
    /// </remarks>
    public async Task<DataTable> ExecuteQueryAsync(string sql)
    {
        if (_connectionId == null)
        {
            throw new InvalidOperationException("Connection is not open. Call OpenAsync() first.");
        }

        // Remove trailing semicolon if present (Phoenix doesn't accept semicolons in REST API)
        sql = sql.TrimEnd().TrimEnd(';').TrimEnd();

        // Phoenix Query Server 6.0.0 has a bug with prepareAndExecute on JSON endpoint
        // Use separate prepare and execute steps instead
        // Step 1: Prepare the statement
        var statementId = ++_statementIdCounter;
        var prepareRequest = new Dictionary<string, object>
        {
            ["request"] = "prepare",
            ["connectionId"] = _connectionId,
            ["sql"] = sql
        };

        var prepareResponse = await _httpClient.PostAsJsonAsync("", prepareRequest);
        
        if (!prepareResponse.IsSuccessStatusCode)
        {
            var errorContent = await prepareResponse.Content.ReadAsStringAsync();
            throw new HttpRequestException(
                $"Phoenix Query Server returned error during prepare: {prepareResponse.StatusCode} - {errorContent}. " +
                $"This usually means the Phoenix Query Server is not ready or there's a connection issue.");
        }

        var prepareResponseText = await prepareResponse.Content.ReadAsStringAsync();
        var prepareResult = JsonSerializer.Deserialize<AvaticaPrepareResponse>(prepareResponseText, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        // Extract statement handle from prepare response
        var statementHandle = prepareResult?.Statement?.Id;
        if (statementHandle == null)
        {
            throw new HttpRequestException(
                $"Phoenix Query Server did not return a statement handle in prepare response. Response: {prepareResponseText.Substring(0, Math.Min(500, prepareResponseText.Length))}");
        }

        // Step 2: Execute the prepared statement
        // Phoenix expects statementHandle as an object with connectionId and id
        // Note: Phoenix only accepts maxRowCount, not maxRowsTotal
        // parameterValues is required even if empty
        var executeRequest = new Dictionary<string, object>
        {
            ["request"] = "execute",
            ["statementHandle"] = new Dictionary<string, object>
            {
                ["connectionId"] = _connectionId,
                ["id"] = statementHandle
            },
            ["parameterValues"] = new object[0],
            ["maxRowCount"] = 10000
        };

        var executeResponse = await _httpClient.PostAsJsonAsync("", executeRequest);
        
        if (!executeResponse.IsSuccessStatusCode)
        {
            // Clean up statement on error
            try
            {
                var closeRequest = new Dictionary<string, object>
                {
                    ["request"] = "closeStatement",
                    ["statementHandle"] = new Dictionary<string, object>
                    {
                        ["connectionId"] = _connectionId,
                        ["id"] = statementHandle
                    }
                };
                await _httpClient.PostAsJsonAsync("", closeRequest);
            }
            catch { }

            var errorContent = await executeResponse.Content.ReadAsStringAsync();
            throw new HttpRequestException(
                $"Phoenix Query Server returned error during execute: {executeResponse.StatusCode} - {errorContent}. " +
                $"This usually means the Phoenix Query Server is not ready or there's a connection issue.");
        }

        var executeResponseText = await executeResponse.Content.ReadAsStringAsync();
        var executeResult = JsonSerializer.Deserialize<AvaticaResponse>(executeResponseText, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
        
        // Clean up statement after execution
        try
        {
            var closeRequest = new Dictionary<string, object>
            {
                ["request"] = "closeStatement",
                ["statementHandle"] = new Dictionary<string, object>
                {
                    ["connectionId"] = _connectionId,
                    ["id"] = statementHandle
                }
            };
            await _httpClient.PostAsJsonAsync("", closeRequest);
        }
        catch { }
        
        if (executeResult?.Results == null || executeResult.Results.Length == 0)
        {
            Console.WriteLine($"DEBUG: No results in execute response. Response: {executeResponseText.Substring(0, Math.Min(500, executeResponseText.Length))}");
            return new DataTable();
        }

        var dataTable = ConvertToDataTable(executeResult.Results[0]);
        
        // Log if we got columns but no rows (helps debug empty result issues)
        if (dataTable.Columns.Count > 0 && dataTable.Rows.Count == 0)
        {
            Console.WriteLine($"DEBUG: Query returned {dataTable.Columns.Count} columns but 0 rows. SQL: {sql.Substring(0, Math.Min(100, sql.Length))}");
        }
        
        return dataTable;
    }

    /// <summary>
    /// Executes a SQL SELECT query and returns the results as a list of dictionaries
    /// </summary>
    /// <param name="sql">SQL SELECT statement to execute</param>
    /// <returns>
    /// List of dictionaries where each dictionary represents a row.
    /// Dictionary keys are column names, values are column values.
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call OpenAsync() first.
    /// </exception>
    /// <exception cref="HttpRequestException">
    /// Thrown when Phoenix Query Server returns an error status code.
    /// </exception>
    /// <remarks>
    /// This is a convenience method that calls ExecuteQueryAsync() and converts the DataTable
    /// to a list of dictionaries for easier JSON serialization or dictionary-based access.
    /// 
    /// DBNull values are preserved as null in the dictionaries.
    /// </remarks>
    public async Task<List<Dictionary<string, object?>>> ExecuteQueryAsListAsync(string sql)
    {
        var dataTable = await ExecuteQueryAsync(sql);
        var results = new List<Dictionary<string, object?>>();

        foreach (DataRow row in dataTable.Rows)
        {
            var rowDict = new Dictionary<string, object?>();
            foreach (DataColumn column in dataTable.Columns)
            {
                rowDict[column.ColumnName] = row[column];
            }
            results.Add(rowDict);
        }

        return results;
    }

    /// <summary>
    /// Executes a non-query SQL statement (DDL/DML commands)
    /// </summary>
    /// <param name="sql">SQL statement to execute (CREATE, INSERT, UPDATE, DELETE, UPSERT, DROP, ALTER, etc.)</param>
    /// <returns>
    /// Number of affected rows. Returns 0 if not available or for DDL statements.
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call OpenAsync() first.
    /// </exception>
    /// <exception cref="HttpRequestException">
    /// Thrown when Phoenix Query Server returns an error status code.
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Automatically removes trailing semicolons
    /// - Uses separate prepare and execute steps (workaround for Phoenix 6.0.0 JSON endpoint bug)
    /// - Returns the number of affected rows if available in the response
    /// 
    /// Supported Statements:
    /// - DDL: CREATE TABLE, CREATE VIEW, DROP TABLE, DROP VIEW, ALTER TABLE
    /// - DML: UPSERT (Phoenix's INSERT/UPDATE), DELETE
    /// 
    /// Note: Phoenix uses UPSERT instead of separate INSERT and UPDATE statements.
    /// </remarks>
    public async Task<int> ExecuteNonQueryAsync(string sql)
    {
        if (_connectionId == null)
        {
            throw new InvalidOperationException("Connection is not open. Call OpenAsync() first.");
        }

        // Remove trailing semicolon if present (Phoenix doesn't accept semicolons in REST API)
        sql = sql.TrimEnd().TrimEnd(';').TrimEnd();

        // Phoenix Query Server 6.0.0 has a bug with prepareAndExecute on JSON endpoint
        // Use separate prepare and execute steps instead
        // Step 1: Prepare the statement
        var prepareRequest = new Dictionary<string, object>
        {
            ["request"] = "prepare",
            ["connectionId"] = _connectionId,
            ["sql"] = sql
        };

        var prepareResponse = await _httpClient.PostAsJsonAsync("", prepareRequest);
        
        if (!prepareResponse.IsSuccessStatusCode)
        {
            var errorContent = await prepareResponse.Content.ReadAsStringAsync();
            throw new HttpRequestException(
                $"Phoenix Query Server returned error during prepare: {prepareResponse.StatusCode} - {errorContent}. " +
                $"This usually means the Phoenix Query Server is not ready or there's a connection issue.");
        }

        var prepareResponseText = await prepareResponse.Content.ReadAsStringAsync();
        var prepareResult = JsonSerializer.Deserialize<AvaticaPrepareResponse>(prepareResponseText, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });

        // Extract statement handle from prepare response
        var statementHandle = prepareResult?.Statement?.Id;
        if (statementHandle == null)
        {
            throw new HttpRequestException(
                $"Phoenix Query Server did not return a statement handle in prepare response. Response: {prepareResponseText.Substring(0, Math.Min(500, prepareResponseText.Length))}");
        }

        // Step 2: Execute the prepared statement
        // Phoenix expects statementHandle as an object with connectionId and id
        // Note: Phoenix only accepts maxRowCount, not maxRowsTotal
        // parameterValues is required even if empty
        var executeRequest = new Dictionary<string, object>
        {
            ["request"] = "execute",
            ["statementHandle"] = new Dictionary<string, object>
            {
                ["connectionId"] = _connectionId,
                ["id"] = statementHandle
            },
            ["parameterValues"] = new object[0],
            ["maxRowCount"] = 0
        };

        var executeResponse = await _httpClient.PostAsJsonAsync("", executeRequest);
        
        if (!executeResponse.IsSuccessStatusCode)
        {
            // Clean up statement on error
            try
            {
                var closeRequest = new Dictionary<string, object>
                {
                    ["request"] = "closeStatement",
                    ["statementHandle"] = new Dictionary<string, object>
                    {
                        ["connectionId"] = _connectionId,
                        ["id"] = statementHandle
                    }
                };
                await _httpClient.PostAsJsonAsync("", closeRequest);
            }
            catch { }

            var errorContent = await executeResponse.Content.ReadAsStringAsync();
            throw new HttpRequestException(
                $"Phoenix Query Server returned error during execute: {executeResponse.StatusCode} - {errorContent}. " +
                $"This usually means the Phoenix Query Server is not ready or there's a connection issue.");
        }

        var executeResponseText = await executeResponse.Content.ReadAsStringAsync();
        var executeResult = JsonSerializer.Deserialize<AvaticaResponse>(executeResponseText, new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        });
        
        // Clean up statement after execution
        try
        {
            var closeRequest = new Dictionary<string, object>
            {
                ["request"] = "closeStatement",
                ["statementHandle"] = new Dictionary<string, object>
                {
                    ["connectionId"] = _connectionId,
                    ["id"] = statementHandle
                }
            };
            await _httpClient.PostAsJsonAsync("", closeRequest);
        }
        catch { }
        
        // Return number of affected rows if available
        return executeResult?.Results?[0]?.UpdateCount ?? 0;
    }

    /// <summary>
    /// Retrieves a list of all tables in the Phoenix database
    /// </summary>
    /// <returns>
    /// DataTable containing table information with columns:
    /// - TABLE_NAME: Name of the table
    /// - TABLE_TYPE: Type of the table (e.g., 'u' for user tables)
    /// - TABLE_SCHEM: Schema name (may be null)
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call OpenAsync() first.
    /// </exception>
    /// <remarks>
    /// This method uses a multi-strategy approach to find tables:
    /// 1. First tries to find user tables (TABLE_TYPE = 'u')
    /// 2. If no results, tries tables where TABLE_SCHEM IS NULL
    /// 3. If still no results, gets all tables (limited to 100)
    /// 
    /// The method queries SYSTEM.CATALOG which is Phoenix's metadata catalog.
    /// </remarks>
    public async Task<DataTable> GetTablesAsync()
    {
        // Query for user tables - try multiple approaches to find tables
        // First try: user tables with TABLE_TYPE = 'u'
        var tables = await ExecuteQueryAsync(
            "SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM " +
            "FROM SYSTEM.CATALOG " +
            "WHERE TABLE_TYPE = 'u' " +
            "ORDER BY TABLE_NAME");
        
        // If no results, try without filtering by TABLE_TYPE
        if (tables.Rows.Count == 0)
        {
            tables = await ExecuteQueryAsync(
                "SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM " +
                "FROM SYSTEM.CATALOG " +
                "WHERE TABLE_SCHEM IS NULL " +
                "ORDER BY TABLE_NAME");
        }
        
        // If still no results, try getting all tables
        if (tables.Rows.Count == 0)
        {
            tables = await ExecuteQueryAsync(
                "SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM " +
                "FROM SYSTEM.CATALOG " +
                "ORDER BY TABLE_NAME LIMIT 100");
        }
        
        return tables;
    }

    /// <summary>
    /// Retrieves column information for a specific table
    /// </summary>
    /// <param name="tableName">Name of the table to get columns for. Case-sensitive.</param>
    /// <returns>
    /// DataTable containing column information with columns:
    /// - COLUMN_NAME: Name of the column
    /// - DATA_TYPE: Data type of the column
    /// - COLUMN_SIZE: Size/length of the column
    /// - IS_NULLABLE: Whether the column allows NULL values
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call OpenAsync() first.
    /// </exception>
    /// <exception cref="ArgumentException">
    /// Thrown when tableName is null or empty.
    /// </exception>
    /// <remarks>
    /// This method queries SYSTEM.CATALOG for column metadata.
    /// Results are ordered by ORDINAL_POSITION to maintain column order.
    /// 
    /// Table Name Case Sensitivity:
    /// Phoenix table names are case-sensitive. Use uppercase names or quoted names.
    /// Example: "EXAMPLE_TABLE" or "example_table" (quoted)
    /// </remarks>
    public async Task<DataTable> GetColumnsAsync(string tableName)
    {
        var sql = $@"SELECT COLUMN_NAME, DATA_TYPE, COLUMN_SIZE, IS_NULLABLE 
                     FROM SYSTEM.CATALOG 
                     WHERE TABLE_NAME = '{tableName}' 
                     ORDER BY ORDINAL_POSITION";
        return await ExecuteQueryAsync(sql);
    }

    /// <summary>
    /// Converts an Avatica response result to a .NET DataTable
    /// </summary>
    /// <param name="result">Avatica result from Phoenix Query Server response</param>
    /// <returns>
    /// DataTable with columns and rows populated from the Avatica response.
    /// Returns empty DataTable if result has no signature or columns.
    /// </returns>
    /// <remarks>
    /// This method:
    /// - Creates columns based on Avatica signature (column name, type)
    /// - Maps Avatica types to .NET types using GetDataType()
    /// - Ensures unique column names (appends suffix if duplicate)
    /// - Converts row values using ConvertValue() for type conversion
    /// - Handles DBNull values appropriately
    /// 
    /// Column Name Priority:
    /// Uses columnName if available, otherwise label, otherwise name, otherwise generates a name.
    /// </remarks>
    private DataTable ConvertToDataTable(AvaticaResult result)
    {
        var dataTable = new DataTable();

        if (result.Signature?.Columns == null || result.Signature.Columns.Length == 0)
        {
            return dataTable;
        }

        // Create columns
        foreach (var column in result.Signature.Columns)
        {
            var dataType = GetDataType(column.Type?.Name ?? "VARCHAR");
            // Use columnName if available, otherwise use label, otherwise use name
            var columnName = column.ColumnName ?? column.Label ?? column.Name ?? $"Column{dataTable.Columns.Count + 1}";
            
            // Ensure unique column names
            if (dataTable.Columns.Contains(columnName))
            {
                columnName = $"{columnName}_{dataTable.Columns.Count + 1}";
            }
            
            dataTable.Columns.Add(columnName, dataType);
        }

        // Add rows
        if (result.FirstFrame?.Rows != null)
        {
            foreach (var row in result.FirstFrame.Rows)
            {
                var dataRow = dataTable.NewRow();
                for (int i = 0; i < Math.Min(row.Length, dataTable.Columns.Count); i++)
                {
                    var value = ConvertValue(row[i], dataTable.Columns[i].DataType);
                    dataRow[i] = value ?? DBNull.Value;
                }
                dataTable.Rows.Add(dataRow);
            }
        }

        return dataTable;
    }

    /// <summary>
    /// Maps an Avatica type name to a .NET Type
    /// </summary>
    /// <param name="avaticaType">Avatica type name (e.g., "INTEGER", "VARCHAR", "TIMESTAMP")</param>
    /// <returns>
    /// Corresponding .NET Type. Defaults to typeof(string) for unknown types.
    /// </returns>
    /// <remarks>
    /// Supported Avatica types:
    /// - INTEGER, INT → int
    /// - BIGINT → long
    /// - SMALLINT → short
    /// - TINYINT → byte
    /// - DOUBLE → double
    /// - FLOAT, REAL → float
    /// - DECIMAL, NUMERIC → decimal
    /// - BOOLEAN, BIT → bool
    /// - DATE → DateTime
    /// - TIME → TimeSpan
    /// - TIMESTAMP → DateTime
    /// - BINARY, VARBINARY → byte[]
    /// - All other types → string
    /// </remarks>
    private Type GetDataType(string avaticaType)
    {
        return avaticaType.ToUpper() switch
        {
            "INTEGER" or "INT" => typeof(int),
            "BIGINT" => typeof(long),
            "SMALLINT" => typeof(short),
            "TINYINT" => typeof(byte),
            "DOUBLE" => typeof(double),
            "FLOAT" or "REAL" => typeof(float),
            "DECIMAL" or "NUMERIC" => typeof(decimal),
            "BOOLEAN" or "BIT" => typeof(bool),
            "DATE" => typeof(DateTime),
            "TIME" => typeof(TimeSpan),
            "TIMESTAMP" => typeof(DateTime),
            "BINARY" or "VARBINARY" => typeof(byte[]),
            _ => typeof(string)
        };
    }

    /// <summary>
    /// Converts a JSON value to the specified .NET type
    /// </summary>
    /// <param name="value">JSON value to convert (can be JsonElement or primitive type)</param>
    /// <param name="targetType">Target .NET type to convert to</param>
    /// <returns>
    /// Converted value of the target type, or null if value is null or JsonValueKind.Null
    /// </returns>
    /// <remarks>
    /// This method handles:
    /// - JsonElement values (from JSON deserialization)
    /// - Primitive types (string, number, boolean)
    /// - Null values (returns null)
    /// 
    /// Uses Convert.ChangeType() for type conversion, which handles most standard conversions.
    /// </remarks>
    private object? ConvertValue(object? value, Type targetType)
    {
        if (value == null || value is JsonElement { ValueKind: JsonValueKind.Null })
        {
            return null;
        }

        if (value is JsonElement jsonElement)
        {
            return jsonElement.ValueKind switch
            {
                JsonValueKind.String => Convert.ChangeType(jsonElement.GetString(), targetType),
                JsonValueKind.Number => Convert.ChangeType(jsonElement.GetRawText(), targetType),
                JsonValueKind.True => true,
                JsonValueKind.False => false,
                JsonValueKind.Null => null,
                _ => jsonElement.ToString()
            };
        }

        return Convert.ChangeType(value, targetType);
    }

    /// <summary>
    /// Prints a DataTable to the console in a formatted table format
    /// </summary>
    /// <param name="dataTable">DataTable to print</param>
    /// <remarks>
    /// This utility method:
    /// - Calculates column widths based on header and data
    /// - Prints a formatted table with borders
    /// - Displays "No rows returned." if table is empty
    /// - Shows total row count at the end
    /// 
    /// Format:
    /// | Column1 | Column2 | Column3 |
    /// |---------|---------|---------|
    /// | Value1  | Value2  | Value3  |
    /// 
    /// Total rows: 1
    /// </remarks>
    public static void PrintDataTable(DataTable dataTable)
    {
        if (dataTable.Rows.Count == 0)
        {
            Console.WriteLine("No rows returned.");
            return;
        }

        // Calculate column widths
        var columnWidths = new Dictionary<string, int>();
        foreach (DataColumn column in dataTable.Columns)
        {
            columnWidths[column.ColumnName] = Math.Max(column.ColumnName.Length, 15);
            foreach (DataRow row in dataTable.Rows)
            {
                var valueLength = row[column]?.ToString()?.Length ?? 0;
                columnWidths[column.ColumnName] = Math.Max(columnWidths[column.ColumnName], valueLength);
            }
        }

        // Print header
        var header = "|";
        var separator = "|";
        foreach (DataColumn column in dataTable.Columns)
        {
            var width = columnWidths[column.ColumnName];
            header += $" {column.ColumnName.PadRight(width)} |";
            separator += $" {new string('-', width)} |";
        }
        Console.WriteLine(header);
        Console.WriteLine(separator);

        // Print rows
        foreach (DataRow row in dataTable.Rows)
        {
            var rowLine = "|";
            foreach (DataColumn column in dataTable.Columns)
            {
                var width = columnWidths[column.ColumnName];
                var value = row[column]?.ToString() ?? "NULL";
                rowLine += $" {value.PadRight(width)} |";
            }
            Console.WriteLine(rowLine);
        }

        Console.WriteLine($"\nTotal rows: {dataTable.Rows.Count}");
    }

    /// <summary>
    /// Releases all resources used by the PhoenixRestClient
    /// </summary>
    /// <remarks>
    /// This method:
    /// - Closes the Phoenix connection if open
    /// - Disposes the HttpClient
    /// - Marks the instance as disposed
    /// 
    /// This method is safe to call multiple times.
    /// </remarks>
    public void Dispose()
    {
        if (!_disposed)
        {
            CloseAsync().GetAwaiter().GetResult();
            _httpClient.Dispose();
            _disposed = true;
        }
    }
}

// Avatica Protocol Response Models
// These classes represent the Avatica JSON protocol response structure

/// <summary>
/// Avatica protocol response containing results
/// </summary>
internal class AvaticaResponse
{
    [JsonPropertyName("results")]
    public AvaticaResult[]? Results { get; set; }
    
    [JsonPropertyName("missingStatement")]
    public bool? MissingStatement { get; set; }
    
    [JsonPropertyName("response")]
    public string? Response { get; set; }
}

/// <summary>
/// Avatica prepare response containing statement handle
/// </summary>
internal class AvaticaPrepareResponse
{
    [JsonPropertyName("statement")]
    public AvaticaStatement? Statement { get; set; }
    
    [JsonPropertyName("response")]
    public string? Response { get; set; }
}

/// <summary>
/// Avatica statement handle
/// </summary>
internal class AvaticaStatement
{
    [JsonPropertyName("id")]
    public int? Id { get; set; }
    
    [JsonPropertyName("connectionId")]
    public string? ConnectionId { get; set; }
    
    [JsonPropertyName("signature")]
    public AvaticaSignature? Signature { get; set; }
}

/// <summary>
/// Avatica result containing signature, data frame, and update count
/// </summary>
internal class AvaticaResult
{
    /// <summary>
    /// Result signature containing column metadata
    /// </summary>
    [JsonPropertyName("signature")]
    public AvaticaSignature? Signature { get; set; }
    
    /// <summary>
    /// First frame of data rows
    /// </summary>
    [JsonPropertyName("firstFrame")]
    public AvaticaFrame? FirstFrame { get; set; }
    
    /// <summary>
    /// Number of affected rows (for DML statements)
    /// </summary>
    [JsonPropertyName("updateCount")]
    public int? UpdateCount { get; set; }
}

/// <summary>
/// Avatica signature containing column definitions
/// </summary>
internal class AvaticaSignature
{
    /// <summary>
    /// Array of column definitions
    /// </summary>
    [JsonPropertyName("columns")]
    public AvaticaColumn[]? Columns { get; set; }
}

/// <summary>
/// Avatica column definition with name and type information
/// </summary>
internal class AvaticaColumn
{
    /// <summary>
    /// Column name
    /// </summary>
    [JsonPropertyName("name")]
    public string? Name { get; set; }
    
    /// <summary>
    /// Column name (alternative property)
    /// </summary>
    [JsonPropertyName("columnName")]
    public string? ColumnName { get; set; }
    
    /// <summary>
    /// Column label (for SELECT aliases)
    /// </summary>
    [JsonPropertyName("label")]
    public string? Label { get; set; }
    
    /// <summary>
    /// Column type information
    /// </summary>
    [JsonPropertyName("type")]
    public AvaticaType? Type { get; set; }
}

/// <summary>
/// Avatica type definition
/// </summary>
internal class AvaticaType
{
    /// <summary>
    /// Type name (e.g., "VARCHAR", "INTEGER", "TIMESTAMP")
    /// </summary>
    [JsonPropertyName("name")]
    public string? Name { get; set; }
}

/// <summary>
/// Avatica frame containing data rows
/// </summary>
internal class AvaticaFrame
{
    /// <summary>
    /// Array of rows, where each row is an array of column values
    /// </summary>
    [JsonPropertyName("rows")]
    public object[][]? Rows { get; set; }
}

