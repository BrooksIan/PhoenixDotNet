# Code Style Guidelines

This document outlines the coding standards and best practices for the PhoenixDotNet project.

## General Principles

1. **Clarity over Cleverness**: Write code that is easy to understand
2. **Consistency**: Follow existing patterns in the codebase
3. **Documentation**: Document all public APIs and complex logic
4. **Error Handling**: Always handle errors gracefully with meaningful messages
5. **Testing**: Write tests for new features and bug fixes

## C# Coding Standards

### Naming Conventions

- **Classes**: PascalCase (e.g., `PhoenixRestClient`, `PhoenixController`)
- **Methods**: PascalCase (e.g., `ExecuteQueryAsync`, `GetTablesAsync`)
- **Properties**: PascalCase (e.g., `ConnectionId`, `BaseUrl`)
- **Private fields**: camelCase with underscore prefix (e.g., `_httpClient`, `_connectionId`)
- **Parameters**: camelCase (e.g., `tableName`, `sql`)
- **Local variables**: camelCase (e.g., `result`, `dataTable`)
- **Constants**: PascalCase (e.g., `MaxRetries`, `DefaultTimeout`)
- **Interfaces**: PascalCase with "I" prefix (e.g., `IDisposable`, `IHostedService`)

### Code Formatting

- Use 4 spaces for indentation (not tabs)
- Use meaningful variable names
- Limit line length to 120 characters (soft limit)
- Use braces for all control structures (even single-line if statements)
- Add blank lines between logical sections

### XML Documentation

All public classes, methods, and properties should have XML documentation comments:

```csharp
/// <summary>
/// Executes a SQL SELECT query and returns the results as a DataTable
/// </summary>
/// <param name="sql">SQL SELECT statement to execute</param>
/// <returns>DataTable containing query results</returns>
/// <exception cref="InvalidOperationException">Thrown when connection is not open</exception>
/// <remarks>
/// This method automatically removes trailing semicolons.
/// Maximum result set size: 10,000 rows.
/// </remarks>
public async Task<DataTable> ExecuteQueryAsync(string sql)
{
    // Implementation
}
```

### Async/Await Patterns

- Always use async/await for I/O operations
- Use `Task` return type for async methods that don't return values
- Use `Task<T>` return type for async methods that return values
- Avoid mixing async and sync code unnecessarily
- Use `ConfigureAwait(false)` in library code (optional)

**Example:**
```csharp
public async Task<DataTable> ExecuteQueryAsync(string sql)
{
    var response = await _httpClient.PostAsJsonAsync("", request);
    var result = await response.Content.ReadAsStringAsync();
    return ConvertToDataTable(result);
}
```

### Error Handling

- Always use try-catch blocks for operations that can fail
- Provide meaningful error messages
- Include context in error messages (e.g., table name, SQL statement)
- Log errors before throwing exceptions
- Use specific exception types when appropriate

**Example:**
```csharp
try
{
    await _phoenixClient.OpenAsync();
    var results = await _phoenixClient.ExecuteQueryAsync(sql);
    return Ok(ConvertDataTableToJson(results));
}
catch (InvalidOperationException ex)
{
    return StatusCode(500, new { error = $"Connection failed: {ex.Message}" });
}
catch (Exception ex)
{
    _logger?.LogError(ex, "Unexpected error executing query: {Sql}", sql);
    return StatusCode(500, new { error = ex.Message });
}
```

### Null Handling

- Use null-conditional operators (`?.`, `??`) when appropriate
- Use null-forgiving operator (`!`) sparingly and only when you're certain
- Check for null before using objects
- Use `ArgumentNullException` for null parameters

**Example:**
```csharp
public PhoenixRestClient(IConfiguration configuration)
{
    _phoenixClient = phoenixClient ?? throw new ArgumentNullException(nameof(phoenixClient));
    var server = configuration["Phoenix:Server"] ?? "localhost";
    var port = configuration["Phoenix:Port"] ?? "8765";
}
```

### Resource Management

- Implement `IDisposable` for classes that manage resources
- Use `using` statements for disposable objects
- Always dispose HttpClient, file streams, etc.

**Example:**
```csharp
public class PhoenixRestClient : IDisposable
{
    private readonly HttpClient _httpClient;
    private bool _disposed = false;

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
```

## Project-Specific Patterns

### Configuration

- Use `IConfiguration` for application configuration
- Provide sensible defaults for configuration values
- Document configuration keys in XML comments

**Example:**
```csharp
/// <summary>
/// Configuration keys:
/// - Phoenix:Server (default: "localhost")
/// - Phoenix:Port (default: "8765")
/// </summary>
public PhoenixRestClient(IConfiguration configuration)
{
    var server = configuration["Phoenix:Server"] ?? "localhost";
    var port = configuration["Phoenix:Port"] ?? "8765";
}
```

### Dependency Injection

- Register services as singletons for stateless services
- Use constructor injection (not property injection)
- Validate dependencies in constructors

**Example:**
```csharp
public PhoenixController(PhoenixRestClient phoenixClient, HBaseRestClient hbaseClient)
{
    _phoenixClient = phoenixClient ?? throw new ArgumentNullException(nameof(phoenixClient));
    _hbaseClient = hbaseClient ?? throw new ArgumentNullException(nameof(hbaseClient));
}
```

### API Controllers

- Use `[ApiController]` attribute
- Use `[Route("api/[controller]")]` for route templates
- Use `[ProducesResponseType]` attributes for Swagger documentation
- Return appropriate HTTP status codes
- Use `IActionResult` for flexibility

**Example:**
```csharp
[ApiController]
[Route("api/[controller]")]
public class PhoenixController : ControllerBase
{
    [HttpGet("tables")]
    [ProducesResponseType(typeof(object), 200)]
    [ProducesResponseType(typeof(object), 500)]
    public async Task<IActionResult> GetTables()
    {
        // Implementation
    }
}
```

### Logging

- Use structured logging when available
- Log at appropriate levels (Information, Warning, Error)
- Include context in log messages (e.g., table name, SQL statement)
- Don't log sensitive information (passwords, connection strings)

**Example:**
```csharp
_logger?.LogInformation("Executing query: {Sql}", sql);
_logger?.LogError(ex, "Failed to execute query: {Sql}", sql);
```

### Retry Logic

- Implement retry logic for transient failures
- Use exponential backoff for retries
- Log retry attempts
- Provide clear error messages after all retries fail

**Example:**
```csharp
int maxRetries = 10;
int delaySeconds = 15;

for (int attempt = 1; attempt <= maxRetries; attempt++)
{
    try
    {
        var response = await _httpClient.PostAsync("", content);
        response.EnsureSuccessStatusCode();
        return;
    }
    catch (HttpRequestException ex)
    {
        if (attempt < maxRetries)
        {
            Console.WriteLine($"Connection attempt {attempt}/{maxRetries} failed. Retrying in {delaySeconds} seconds...");
            await Task.Delay(TimeSpan.FromSeconds(delaySeconds));
        }
        else
        {
            throw new InvalidOperationException($"Failed after {maxRetries} attempts", ex);
        }
    }
}
```

## File Organization

### File Structure

- One class per file
- File name matches class name
- Group related files in directories

### Using Statements

- Order using statements:
  1. System namespaces
  2. Third-party namespaces
  3. Project namespaces
- Use global usings when appropriate (in .csproj)

**Example:**
```csharp
using System;
using System.Net.Http;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using PhoenixDotNet;
```

## Code Comments

### When to Comment

- **Complex Logic**: Explain why, not what
- **Business Rules**: Document business logic and constraints
- **Workarounds**: Document temporary fixes and known issues
- **Public APIs**: Always document public methods and classes

### Comment Style

- Use XML documentation comments for public APIs
- Use inline comments for complex logic
- Keep comments up to date with code changes
- Remove commented-out code (use Git history instead)

**Example:**
```csharp
// Remove trailing semicolon if present (Phoenix doesn't accept semicolons in REST API)
sql = sql.TrimEnd().TrimEnd(';').TrimEnd();

// Use prepareAndExecute for direct SQL execution (Avatica JSON protocol)
var request = new Dictionary<string, object>
{
    ["request"] = "prepareAndExecute",
    ["connectionId"] = _connectionId,
    ["sql"] = sql
};
```

## Testing Standards

### Unit Tests

- Write unit tests for business logic
- Test both success and failure scenarios
- Use descriptive test names
- Arrange-Act-Assert pattern

**Example:**
```csharp
[Fact]
public async Task ExecuteQueryAsync_WithValidSql_ReturnsDataTable()
{
    // Arrange
    var client = new PhoenixRestClient("http://localhost:8765/json");
    await client.OpenAsync();
    
    // Act
    var result = await client.ExecuteQueryAsync("SELECT * FROM SYSTEM.CATALOG LIMIT 1");
    
    // Assert
    Assert.NotNull(result);
    Assert.True(result.Columns.Count > 0);
}
```

### Integration Tests

- Test API endpoints with real Phoenix server
- Use test fixtures for setup/teardown
- Clean up test data after tests

## Git Commit Conventions

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(api): Add version endpoint

Add GET /api/phoenix/version endpoint to return application version.

Fixes #123
```

```
fix(client): Handle null response in ExecuteQueryAsync

Add null check for Avatica response to prevent NullReferenceException.

Closes #456
```

## Code Review Checklist

Before submitting code for review:

- [ ] Code follows naming conventions
- [ ] All public APIs have XML documentation
- [ ] Error handling is implemented
- [ ] Tests are written and passing
- [ ] No compiler warnings
- [ ] Code is formatted consistently
- [ ] Unused code is removed
- [ ] Comments are clear and helpful
- [ ] No hardcoded values (use configuration)
- [ ] No sensitive information in code

## IDE Configuration

### Visual Studio Code

Recommended extensions:
- C# Dev Kit
- C# Extensions
- .NET Core Test Explorer
- REST Client

### Visual Studio

Recommended settings:
- Enable XML documentation warnings
- Enable nullable reference types
- Use 4 spaces for indentation
- Enable code analysis

## Tools and Utilities

### Code Analysis

- Use built-in .NET analyzers
- Fix warnings before committing
- Use `dotnet format` for code formatting

### Linting

- Follow C# coding conventions
- Use EditorConfig for consistent formatting
- Run `dotnet build` before committing

## References

- [Microsoft C# Coding Conventions](https://docs.microsoft.com/en-us/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- [.NET Coding Standards](https://github.com/dotnet/runtime/blob/main/docs/coding-guidelines/coding-style.md)
- [ASP.NET Core Best Practices](https://docs.microsoft.com/en-us/aspnet/core/fundamentals/best-practices)

---

**Remember**: Code is read more often than it's written. Write for your future self and your teammates.

