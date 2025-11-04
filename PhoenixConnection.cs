using System.Data;
using System.Data.Odbc;
using Microsoft.Extensions.Configuration;

namespace PhoenixDotNet;

/// <summary>
/// Helper class for managing Apache Phoenix ODBC connections and queries
/// 
/// This class provides ODBC-based connectivity to Phoenix Query Server.
/// Note: This class is provided for compatibility but PhoenixRestClient (REST API)
/// is the recommended approach as it doesn't require ODBC drivers.
/// 
/// Features:
/// - ODBC connection management
/// - SQL query execution
/// - DataTable conversion
/// - Connection state management
/// 
/// Thread Safety:
/// - This class is not thread-safe. Use a singleton instance per application.
/// </summary>
public class PhoenixConnection : IDisposable
{
    private readonly string _connectionString;
    private OdbcConnection? _connection;
    private bool _disposed = false;

    /// <summary>
    /// Initializes a new instance of PhoenixConnection using configuration
    /// </summary>
    /// <param name="configuration">Application configuration containing Phoenix:ConnectionString</param>
    /// <exception cref="InvalidOperationException">
    /// Thrown when Phoenix:ConnectionString is not found in configuration
    /// </exception>
    /// <remarks>
    /// Configuration key: Phoenix:ConnectionString
    /// 
    /// Connection string format: "Driver={Phoenix ODBC Driver};Server=localhost;Port=8765"
    /// </remarks>
    public PhoenixConnection(IConfiguration configuration)
    {
        _connectionString = configuration["Phoenix:ConnectionString"] 
            ?? throw new InvalidOperationException("Phoenix connection string not found in configuration");
    }

    /// <summary>
    /// Initializes a new instance of PhoenixConnection using a connection string
    /// </summary>
    /// <param name="connectionString">ODBC connection string for Phoenix</param>
    /// <exception cref="ArgumentNullException">
    /// Thrown when connectionString is null
    /// </exception>
    /// <remarks>
    /// Connection string format: "Driver={Phoenix ODBC Driver};Server=localhost;Port=8765"
    /// 
    /// Note: The ODBC driver must be installed and configured on the system.
    /// </remarks>
    public PhoenixConnection(string connectionString)
    {
        _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
    }

    /// <summary>
    /// Opens a connection to Phoenix Query Server using ODBC
    /// </summary>
    /// <exception cref="InvalidOperationException">
    /// Thrown when ODBC driver is not found or connection fails
    /// </exception>
    /// <remarks>
    /// This method:
    /// - Creates an ODBC connection if not already created
    /// - Opens the connection if not already open
    /// - Provides helpful error messages if ODBC driver is not found
    /// 
    /// ODBC Driver Requirements:
    /// - Phoenix ODBC driver must be installed
    /// - Driver must be configured in /etc/odbcinst.ini (Linux/macOS)
    /// - Connection string must reference the correct driver name
    /// 
    /// Note: If ODBC driver is not available, consider using PhoenixRestClient instead.
    /// </remarks>
    public void Open()
    {
        if (_connection == null)
        {
            _connection = new OdbcConnection(_connectionString);
        }

        if (_connection.State != ConnectionState.Open)
        {
            try
            {
                _connection.Open();
                Console.WriteLine("Connected to Apache Phoenix Query Server");
            }
            catch (OdbcException ex) when (ex.Message.Contains("Can't open lib") || ex.Message.Contains("file not found"))
            {
                Console.WriteLine("ERROR: Phoenix ODBC driver not found!");
                Console.WriteLine("The Phoenix ODBC driver must be installed and configured.");
                Console.WriteLine("\nTo fix this issue:");
                Console.WriteLine("1. Download Phoenix ODBC driver from Cloudera or Hortonworks");
                Console.WriteLine("2. Install the driver library (.so file) in the container");
                Console.WriteLine("3. Configure /etc/odbcinst.ini with the driver path");
                Console.WriteLine("4. Ensure LD_LIBRARY_PATH includes the driver directory");
                Console.WriteLine("\nSee TROUBLESHOOTING.md for detailed instructions.");
                throw new InvalidOperationException(
                    "Phoenix ODBC driver not found. Please install and configure the driver. " +
                    "See TROUBLESHOOTING.md for instructions.", ex);
            }
        }
    }

    /// <summary>
    /// Closes the ODBC connection to Phoenix Query Server
    /// </summary>
    /// <remarks>
    /// This method:
    /// - Closes the connection if it's currently open
    /// - Does nothing if connection is already closed or null
    /// </remarks>
    public void Close()
    {
        if (_connection?.State == ConnectionState.Open)
        {
            _connection.Close();
            Console.WriteLine("Disconnected from Apache Phoenix Query Server");
        }
    }

    /// <summary>
    /// Executes a SQL SELECT query and returns the results as a DataTable
    /// </summary>
    /// <param name="sql">SQL SELECT statement to execute</param>
    /// <returns>
    /// DataTable containing query results with columns and rows
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call Open() first.
    /// </exception>
    /// <exception cref="OdbcException">
    /// Thrown when SQL execution fails (syntax error, table not found, etc.)
    /// </exception>
    /// <remarks>
    /// This method uses ODBC DataAdapter to fill a DataTable with query results.
    /// The connection must be open before calling this method.
    /// </remarks>
    public DataTable ExecuteQuery(string sql)
    {
        if (_connection == null || _connection.State != ConnectionState.Open)
        {
            throw new InvalidOperationException("Connection is not open. Call Open() first.");
        }

        using var command = new OdbcCommand(sql, _connection);
        using var adapter = new OdbcDataAdapter(command);
        var dataTable = new DataTable();
        
        adapter.Fill(dataTable);
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
    /// Thrown when connection is not open. Call Open() first.
    /// </exception>
    /// <exception cref="OdbcException">
    /// Thrown when SQL execution fails (syntax error, table not found, etc.)
    /// </exception>
    /// <remarks>
    /// This is a convenience method that calls ExecuteQuery() and converts the DataTable
    /// to a list of dictionaries for easier JSON serialization or dictionary-based access.
    /// 
    /// DBNull values are preserved as null in the dictionaries.
    /// </remarks>
    public List<Dictionary<string, object?>> ExecuteQueryAsList(string sql)
    {
        var dataTable = ExecuteQuery(sql);
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
    /// Number of affected rows. Returns 0 for DDL statements or when not available.
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call Open() first.
    /// </exception>
    /// <exception cref="OdbcException">
    /// Thrown when SQL execution fails (syntax error, table not found, etc.)
    /// </exception>
    /// <remarks>
    /// This method uses ODBC Command ExecuteNonQuery() to execute DDL/DML statements.
    /// 
    /// Supported Statements:
    /// - DDL: CREATE TABLE, CREATE VIEW, DROP TABLE, DROP VIEW, ALTER TABLE
    /// - DML: UPSERT (Phoenix's INSERT/UPDATE), DELETE
    /// 
    /// Note: Phoenix uses UPSERT instead of separate INSERT and UPDATE statements.
    /// </remarks>
    public int ExecuteNonQuery(string sql)
    {
        if (_connection == null || _connection.State != ConnectionState.Open)
        {
            throw new InvalidOperationException("Connection is not open. Call Open() first.");
        }

        using var command = new OdbcCommand(sql, _connection);
        return command.ExecuteNonQuery();
    }

    /// <summary>
    /// Retrieves a list of all user tables in the Phoenix database
    /// </summary>
    /// <returns>
    /// DataTable containing table information with TABLE_NAME column
    /// </returns>
    /// <exception cref="InvalidOperationException">
    /// Thrown when connection is not open. Call Open() first.
    /// </exception>
    /// <exception cref="OdbcException">
    /// Thrown when query execution fails
    /// </exception>
    /// <remarks>
    /// This method queries SYSTEM.CATALOG for user tables (TABLE_TYPE = 'u').
    /// Results are ordered by TABLE_NAME.
    /// </remarks>
    public DataTable GetTables()
    {
        // Query for user tables - try multiple approaches to find tables
        // First try: user tables with TABLE_TYPE = 'u'
        var tables = ExecuteQuery("SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'u' ORDER BY TABLE_NAME");
        
        // If no results, try without filtering by TABLE_TYPE
        if (tables.Rows.Count == 0)
        {
            tables = ExecuteQuery("SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM FROM SYSTEM.CATALOG WHERE TABLE_SCHEM IS NULL ORDER BY TABLE_NAME");
        }
        
        // If still no results, try getting all tables
        if (tables.Rows.Count == 0)
        {
            tables = ExecuteQuery("SELECT TABLE_NAME, TABLE_TYPE, TABLE_SCHEM FROM SYSTEM.CATALOG ORDER BY TABLE_NAME LIMIT 100");
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
    /// Thrown when connection is not open. Call Open() first.
    /// </exception>
    /// <exception cref="OdbcException">
    /// Thrown when query execution fails or table not found
    /// </exception>
    /// <remarks>
    /// This method queries SYSTEM.CATALOG for column metadata.
    /// Results are ordered by ORDINAL_POSITION to maintain column order.
    /// 
    /// Table Name Case Sensitivity:
    /// Phoenix table names are case-sensitive. Use uppercase names or quoted names.
    /// Example: "EXAMPLE_TABLE" or "example_table" (quoted)
    /// </remarks>
    public DataTable GetColumns(string tableName)
    {
        var sql = $@"SELECT COLUMN_NAME, DATA_TYPE, COLUMN_SIZE, IS_NULLABLE 
                     FROM SYSTEM.CATALOG 
                     WHERE TABLE_NAME = '{tableName}' 
                     ORDER BY ORDINAL_POSITION";
        return ExecuteQuery(sql);
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
    /// Releases all resources used by the PhoenixConnection
    /// </summary>
    /// <remarks>
    /// This method:
    /// - Closes the ODBC connection if open
    /// - Disposes the OdbcConnection
    /// - Marks the instance as disposed
    /// 
    /// This method is safe to call multiple times.
    /// </remarks>
    public void Dispose()
    {
        if (!_disposed)
        {
            Close();
            _connection?.Dispose();
            _disposed = true;
        }
    }
}
