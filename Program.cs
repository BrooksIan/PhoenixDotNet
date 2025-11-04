/// <summary>
/// PhoenixDotNet Application Entry Point
/// 
/// This application provides a REST API and SQL Search GUI for Apache Phoenix.
/// It connects to Phoenix Query Server using ODBC (primary) or REST API (fallback).
/// 
/// Architecture:
/// - Port 8099: REST API endpoints for Phoenix operations
/// - Port 8100: Web-based SQL query interface (GUI)
/// 
/// Services Registered:
/// - PhoenixConnection: Singleton service for Phoenix Query Server communication via ODBC (primary)
/// - PhoenixRestClient: Singleton service for Phoenix Query Server communication via REST (fallback)
/// - HBaseRestClient: Singleton service for HBase REST API operations
/// - PhoenixConnectionInitializer: Background service for connection initialization
/// </summary>
using Microsoft.Extensions.Configuration;
using PhoenixDotNet;

// Load configuration from environment variable or default to Development
var environment = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT") ?? "Development";
var builder = WebApplication.CreateBuilder(args);

// Configure configuration sources in order of precedence:
// 1. Environment variables (highest priority)
// 2. appsettings.{environment}.json (environment-specific)
// 3. appsettings.json (base configuration)
builder.Configuration
    .SetBasePath(Directory.GetCurrentDirectory())
    .AddJsonFile("appsettings.json", optional: false, reloadOnChange: true)
    .AddJsonFile($"appsettings.{environment}.json", optional: true, reloadOnChange: true)
    .AddEnvironmentVariables();

// Add ASP.NET Core services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Register PhoenixConnection as a singleton service (ODBC-based)
// This is more reliable than REST API for Phoenix Query Server 6.0.0
// Singleton ensures single instance for connection management and performance
builder.Services.AddSingleton<PhoenixConnection>(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    return new PhoenixConnection(configuration);
});

// Also register PhoenixRestClient as a fallback (for HBase operations that still need REST)
builder.Services.AddSingleton<PhoenixRestClient>(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    return new PhoenixRestClient(configuration);
});

// Register HBaseRestClient as a singleton service
// Singleton ensures single instance for connection pooling
builder.Services.AddSingleton<HBaseRestClient>(serviceProvider =>
{
    var configuration = serviceProvider.GetRequiredService<IConfiguration>();
    return new HBaseRestClient(configuration);
});

// Register background service to initialize Phoenix connection on startup
// This service waits 30 seconds for HBase/Phoenix initialization, then attempts connection
builder.Services.AddHostedService<PhoenixConnectionInitializer>();

// Build the application
var app = builder.Build();

// Enable static file serving for the SQL Search GUI (wwwroot/index.html)
app.UseStaticFiles();

// Configure Swagger/OpenAPI documentation (only in development environment)
// Swagger UI available at: http://localhost:8099/swagger
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Configure HTTP pipeline middleware
app.UseHttpsRedirection();
app.UseAuthorization();

// Map API controllers to routes
// Controllers are discovered via convention: [Route("api/[controller]")]
app.MapControllers();

// Map default route to serve the SQL Search GUI
// Falls back to index.html for any unmatched routes
app.MapFallbackToFile("index.html");

// Configure Kestrel to listen on multiple ports
// Port 8099: REST API endpoints
// Port 8100: SQL Search GUI (also accessible via 8099)
app.Urls.Add("http://0.0.0.0:8099");  // API port
app.Urls.Add("http://0.0.0.0:8100");  // GUI port

// Output startup information to console
Console.WriteLine("Phoenix .NET API is starting...");
Console.WriteLine("");
Console.WriteLine("API endpoints available at:");
Console.WriteLine("  - GET  http://localhost:8099/api/phoenix/tables");
Console.WriteLine("  - GET  http://localhost:8099/api/phoenix/tables/{tableName}/columns");
Console.WriteLine("  - POST http://localhost:8099/api/phoenix/query");
Console.WriteLine("  - POST http://localhost:8099/api/phoenix/execute");
Console.WriteLine("  - GET  http://localhost:8099/api/phoenix/health");
Console.WriteLine("  - POST http://localhost:8099/api/phoenix/hbase/tables/sensor (Create sensor table via HBase API)");
Console.WriteLine("  - GET  http://localhost:8099/api/phoenix/hbase/tables/{tableName}/exists (Check if table exists)");
Console.WriteLine("  - GET  http://localhost:8099/api/phoenix/hbase/tables/{tableName}/schema (Get table schema)");
Console.WriteLine("  - POST http://localhost:8099/api/phoenix/views (Create Phoenix view for HBase table)");
Console.WriteLine("");
Console.WriteLine("SQL Search GUI available at:");
Console.WriteLine("  - http://localhost:8100");
Console.WriteLine("  - http://localhost:8099 (also available)");
if (app.Environment.IsDevelopment())
{
    Console.WriteLine("  - Swagger UI: http://localhost:8099/swagger");
}

// Start the application and block until shutdown
app.Run();
