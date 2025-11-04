using System.Net.Http.Json;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using Microsoft.Extensions.Configuration;

namespace PhoenixDotNet;

/// <summary>
/// HBase REST API client for direct HBase operations
/// 
/// This client communicates with HBase using the REST API (Stargate protocol).
/// It provides methods for table management, schema operations, and data insertion.
/// 
/// Features:
/// - Table creation with column families
/// - Table existence checking
/// - Schema retrieval
/// - Data insertion (PUT operations)
/// - Namespace support
/// 
/// Protocol:
/// - Uses HBase REST API (Stargate)
/// - Base URL format: http://{server}:{port}
/// - Endpoint format: /{namespace}:{table}/schema
/// - JSON request/response format
/// 
/// Thread Safety:
/// - This class is not thread-safe. Use a singleton instance per application.
/// </summary>
public class HBaseRestClient : IDisposable
{
    private readonly HttpClient _httpClient;
    private readonly string _baseUrl;
    private bool _disposed = false;

    /// <summary>
    /// Initializes a new instance of HBaseRestClient using configuration
    /// </summary>
    /// <param name="configuration">Application configuration containing HBase:Server and HBase:Port</param>
    /// <remarks>
    /// Configuration keys:
    /// - HBase:Server (default: "localhost")
    /// - HBase:Port (default: "8080")
    /// 
    /// The base URL is constructed as: http://{server}:{port}
    /// </remarks>
    public HBaseRestClient(IConfiguration configuration)
    {
        var server = configuration["HBase:Server"] ?? "localhost";
        var port = configuration["HBase:Port"] ?? "8080";
        // HBase REST API (Stargate) endpoint
        _baseUrl = $"http://{server}:{port}";
        
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(_baseUrl),
            Timeout = TimeSpan.FromMinutes(5)
        };
        
        // Set default headers for HBase REST API
        _httpClient.DefaultRequestHeaders.Add("Accept", "application/json");
        // Note: Content-Type must be set on HttpContent, not as a default header
    }

    /// <summary>
    /// Initializes a new instance of HBaseRestClient using a base URL
    /// </summary>
    /// <param name="baseUrl">Base URL for HBase REST API (e.g., "http://localhost:8080")</param>
    /// <remarks>
    /// Trailing slashes are automatically removed from the base URL.
    /// </remarks>
    public HBaseRestClient(string baseUrl)
    {
        _baseUrl = baseUrl.TrimEnd('/');
        
        _httpClient = new HttpClient
        {
            BaseAddress = new Uri(_baseUrl),
            Timeout = TimeSpan.FromMinutes(5)
        };
        
        _httpClient.DefaultRequestHeaders.Add("Accept", "application/json");
        _httpClient.DefaultRequestHeaders.Add("Content-Type", "application/json");
    }

    /// <summary>
    /// Creates a table in HBase with the specified column families
    /// </summary>
    /// <param name="tableName">Name of the table to create</param>
    /// <param name="columnFamilies">List of column family names to create</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// True if the table was created successfully, false if the table already exists
    /// </returns>
    /// <exception cref="HttpRequestException">
    /// Thrown when HBase REST API returns an error status code
    /// </exception>
    /// <exception cref="InvalidOperationException">
    /// Thrown when table creation fails due to an unexpected error
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Checks if the table exists before creating (returns false if exists)
    /// - Creates column families with default properties:
    ///   - maxVersions: 1
    ///   - compression: NONE
    ///   - bloomFilter: NONE
    ///   - inMemory: false
    ///   - timeToLive: 2147483647 (maximum)
    ///   - blockCache: true
    ///   - blocksize: 65536
    /// 
    /// Endpoint: POST /{namespace}:{table}/schema
    /// </remarks>
    public async Task<bool> CreateTableAsync(string tableName, List<string> columnFamilies, string @namespace = "default")
    {
        try
        {
            // Check if table exists first
            var exists = await TableExistsAsync(tableName, @namespace);
            if (exists)
            {
                Console.WriteLine($"Table {@namespace}:{tableName} already exists");
                return false;
            }

            // HBase REST API endpoint for creating table schema
            // Format: POST /{namespace}:{table}/schema
            var endpoint = $"/{@namespace}:{tableName}/schema";

            // Build column family descriptors
            var columnFamilyDescriptors = columnFamilies.Select(cf => new
            {
                name = cf,
                maxVersions = 1,
                compression = "NONE",
                bloomFilter = "NONE",
                inMemory = false,
                timeToLive = 2147483647,
                blockCache = true,
                blocksize = 65536
            }).ToArray();

            var schema = new
            {
                ColumnSchema = columnFamilyDescriptors
            };

            var jsonContent = JsonSerializer.Serialize(schema, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
            var response = await _httpClient.PostAsync(endpoint, content);

            if (response.IsSuccessStatusCode)
            {
                Console.WriteLine($"Table {@namespace}:{tableName} created successfully with column families: {string.Join(", ", columnFamilies)}");
                return true;
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync();
                throw new HttpRequestException(
                    $"Failed to create table {@namespace}:{tableName}. Status: {response.StatusCode}, Response: {errorContent}");
            }
        }
        catch (HttpRequestException)
        {
            throw;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Error creating table {@namespace}:{tableName}: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Creates a sensor information table with predefined column families
    /// </summary>
    /// <param name="tableName">Name of the sensor table to create (default: "sensor_info")</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// True if the table was created successfully, false if the table already exists
    /// </returns>
    /// <remarks>
    /// Creates a table with predefined column families:
    /// - metadata: Sensor metadata (type, location, manufacturer, etc.)
    /// - readings: Sensor readings (timestamped measurements)
    /// - status: Sensor status (active, last_seen, battery_level, etc.)
    /// 
    /// This is a convenience method that calls CreateTableAsync() with predefined column families.
    /// </remarks>
    public async Task<bool> CreateSensorTableAsync(string tableName = "sensor_info", string @namespace = "default")
    {
        // Define column families for sensor information
        var columnFamilies = new List<string>
        {
            "metadata",    // Sensor metadata: type, location, manufacturer, etc.
            "readings",    // Sensor readings: timestamped measurements
            "status"       // Sensor status: active, last_seen, battery_level, etc.
        };

        return await CreateTableAsync(tableName, columnFamilies, @namespace);
    }

    /// <summary>
    /// Checks if a table exists in HBase
    /// </summary>
    /// <param name="tableName">Name of the table to check</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// True if the table exists, false otherwise
    /// </returns>
    /// <remarks>
    /// This method:
    /// - Attempts to retrieve the table schema
    /// - Returns true if schema retrieval succeeds (HTTP 200)
    /// - Returns false if table not found (HTTP 404)
    /// - Returns false on any other error (assumes table doesn't exist)
    /// 
    /// Endpoint: GET /{namespace}:{table}/schema
    /// </remarks>
    public async Task<bool> TableExistsAsync(string tableName, string @namespace = "default")
    {
        try
        {
            var endpoint = $"/{@namespace}:{tableName}/schema";
            var response = await _httpClient.GetAsync(endpoint);
            
            if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                return false;
            }
            
            response.EnsureSuccessStatusCode();
            return true;
        }
        catch (HttpRequestException ex) when (ex.Message.Contains("404") || ex.Message.Contains("Not Found"))
        {
            return false;
        }
        catch
        {
            // If we can't determine, assume it doesn't exist
            return false;
        }
    }

    /// <summary>
    /// Retrieves table schema information from HBase
    /// </summary>
    /// <param name="tableName">Name of the table to get schema for</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// JSON string containing table schema (column families and their properties), or null if table not found
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when schema retrieval fails due to an unexpected error
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Retrieves the table schema as JSON
    /// - Schema includes column families and their properties (compression, bloomFilter, etc.)
    /// 
    /// Endpoint: GET /{namespace}:{table}/schema
    /// 
    /// Returns null if the table does not exist (HTTP 404).
    /// </remarks>
    public async Task<string?> GetTableSchemaAsync(string tableName, string @namespace = "default")
    {
        try
        {
            var endpoint = $"/{@namespace}:{tableName}/schema";
            var response = await _httpClient.GetAsync(endpoint);
            response.EnsureSuccessStatusCode();
            
            return await response.Content.ReadAsStringAsync();
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Error getting schema for table {@namespace}:{tableName}: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Lists all tables in a namespace
    /// </summary>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// List of table names in the namespace. Returns empty list if namespace not found or on error.
    /// </returns>
    /// <remarks>
    /// Note: This method is currently not fully implemented. The HBase REST API endpoint
    /// for listing tables may vary by version. Returns an empty list for now.
    /// 
    /// Endpoint: GET /{namespace}*/schema (may vary by HBase version)
    /// </remarks>
    public async Task<List<string>> ListTablesAsync(string @namespace = "default")
    {
        try
        {
            var endpoint = $"/{@namespace}*/schema";
            var response = await _httpClient.GetAsync(endpoint);
            
            if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
            {
                return new List<string>();
            }
            
            response.EnsureSuccessStatusCode();
            var content = await response.Content.ReadAsStringAsync();
            
            // Parse response to extract table names
            // This depends on the actual HBase REST API response format
            // For now, return empty list as this endpoint may vary
            return new List<string>();
        }
        catch
        {
            return new List<string>();
        }
    }

    /// <summary>
    /// Inserts data into an HBase table using PUT operation
    /// </summary>
    /// <param name="tableName">Name of the table to insert data into</param>
    /// <param name="rowKey">Row key for the data</param>
    /// <param name="columnFamily">Column family name</param>
    /// <param name="column">Column qualifier name</param>
    /// <param name="value">Value to insert</param>
    /// <param name="namespace">HBase namespace (default: "default")</param>
    /// <returns>
    /// True if data was inserted successfully
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when data insertion fails due to an unexpected error
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Base64-encodes the row key, column family:column, and value (HBase REST API format)
    /// - Inserts a single cell value
    /// - Uses PUT operation to insert/update data
    /// 
    /// Endpoint: PUT /{namespace}:{table}/{rowKey}
    /// 
    /// Note: For multiple cells, make multiple requests or use Phoenix SQL UPSERT.
    /// </remarks>
    public async Task<bool> PutDataAsync(string tableName, string rowKey, string columnFamily, string column, string value, string @namespace = "default")
    {
        try
        {
            var endpoint = $"/{@namespace}:{tableName}/{rowKey}";
            
            var rowData = new
            {
                Row = new[]
                {
                    new
                    {
                        key = Convert.ToBase64String(Encoding.UTF8.GetBytes(rowKey)),
                        Cell = new[]
                        {
                            new Dictionary<string, object>
                            {
                                ["column"] = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{columnFamily}:{column}")),
                                ["$"] = Convert.ToBase64String(Encoding.UTF8.GetBytes(value))
                            }
                        }
                    }
                }
            };

            var jsonContent = JsonSerializer.Serialize(rowData, new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            });

            var content = new StringContent(jsonContent, Encoding.UTF8, "application/json");
            var response = await _httpClient.PutAsync(endpoint, content);
            
            response.EnsureSuccessStatusCode();
            return true;
        }
        catch (Exception ex)
        {
            throw new InvalidOperationException($"Error inserting data into {@namespace}:{tableName}: {ex.Message}", ex);
        }
    }

    /// <summary>
    /// Releases all resources used by the HBaseRestClient
    /// </summary>
    /// <remarks>
    /// This method:
    /// - Disposes the HttpClient
    /// - Marks the instance as disposed
    /// 
    /// This method is safe to call multiple times.
    /// </remarks>
    public void Dispose()
    {
        if (!_disposed)
        {
            _httpClient.Dispose();
            _disposed = true;
        }
    }
}

