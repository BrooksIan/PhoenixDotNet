using PhoenixDotNet;

namespace PhoenixDotNet;

/// <summary>
/// Background service to initialize Phoenix connection on application startup
/// 
/// This service implements IHostedService to run as a background service.
/// It waits for HBase/Phoenix to fully initialize, then attempts to establish
/// a connection to Phoenix Query Server via ODBC (primary) or REST API (fallback).
/// 
/// Features:
/// - Initial wait period: 30 seconds (allows HBase/Phoenix initialization)
/// - Non-blocking: Application startup continues even if connection fails
/// - Graceful failure: Connection errors are logged but don't block startup
/// - Tries ODBC first, falls back to REST API if ODBC unavailable
/// 
/// Connection Lifecycle:
/// - If connection fails on startup, it will be attempted on first API request
/// - This ensures the application starts quickly even if Phoenix is still initializing
/// </summary>
public class PhoenixConnectionInitializer : IHostedService
{
    private readonly PhoenixConnection _phoenixConnection;
    private readonly PhoenixRestClient _phoenixRestClient;
    private readonly ILogger<PhoenixConnectionInitializer>? _logger;

    /// <summary>
    /// Initializes a new instance of PhoenixConnectionInitializer
    /// </summary>
    /// <param name="phoenixConnection">Phoenix ODBC connection (primary)</param>
    /// <param name="phoenixRestClient">Phoenix REST API client (fallback)</param>
    /// <param name="logger">Optional logger for connection status messages</param>
    public PhoenixConnectionInitializer(PhoenixConnection phoenixConnection, PhoenixRestClient phoenixRestClient, ILogger<PhoenixConnectionInitializer>? logger = null)
    {
        _phoenixConnection = phoenixConnection ?? throw new ArgumentNullException(nameof(phoenixConnection));
        _phoenixRestClient = phoenixRestClient ?? throw new ArgumentNullException(nameof(phoenixRestClient));
        _logger = logger;
    }

    /// <summary>
    /// Starts the background service and initializes Phoenix connection
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation</param>
    /// <returns>Task representing the asynchronous operation</returns>
    /// <remarks>
    /// This method:
    /// 1. Waits 30 seconds for HBase/Phoenix to fully initialize
    /// 2. Attempts to open Phoenix connection
    /// 3. Logs success or failure (but doesn't throw exceptions)
    /// 
    /// If connection fails, the application continues to run. Connection will be
    /// attempted again on first API request if needed.
    /// 
    /// Initialization Time:
    /// HBase/Phoenix typically takes 30-60 seconds to fully initialize after container start.
    /// The 30-second wait plus PhoenixRestClient's retry logic (up to 10 attempts, 15s delays)
    /// accommodates this initialization period.
    /// </remarks>
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        // Wait for HBase/Phoenix to fully initialize (typically takes 30-60 seconds)
        _logger?.LogInformation("Waiting for HBase/Phoenix to fully initialize (30 seconds)...");
        await Task.Delay(TimeSpan.FromSeconds(30), cancellationToken);
        
        try
        {
            _logger?.LogInformation("Initializing Phoenix ODBC connection...");
            // Try ODBC first (more reliable)
            _phoenixConnection.Open();
            _logger?.LogInformation("Phoenix ODBC connection initialized successfully");
        }
        catch (Exception ex)
        {
            _logger?.LogWarning(ex, "Failed to connect to Phoenix via ODBC. Will try REST API on first request.");
            // Try REST API as fallback
            try
            {
                _logger?.LogInformation("Trying Phoenix REST API connection...");
                await _phoenixRestClient.OpenAsync();
                _logger?.LogInformation("Phoenix REST API connection initialized successfully");
            }
            catch (Exception restEx)
            {
                _logger?.LogWarning(restEx, "Failed to connect to Phoenix via REST API. Connection will be attempted on first request.");
                _logger?.LogWarning("Note: Phoenix Query Server 6.0.0 has known issues with JSON endpoint. Consider using ODBC or a different version.");
            }
        }
    }

    /// <summary>
    /// Stops the background service
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation</param>
    /// <returns>Task representing the asynchronous operation</returns>
    /// <remarks>
    /// This method is called when the application is shutting down.
    /// The Phoenix connection will be closed when PhoenixRestClient is disposed.
    /// </remarks>
    public Task StopAsync(CancellationToken cancellationToken)
    {
        return Task.CompletedTask;
    }
}

