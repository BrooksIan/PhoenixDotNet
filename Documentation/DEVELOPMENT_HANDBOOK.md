# PhoenixDotNet Development Handbook
## Complete Handoff Guide for Development Teams

This comprehensive handbook provides everything your development team needs to successfully take over, understand, develop, and maintain the PhoenixDotNet project.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Overview](#project-overview)
3. [Component Architecture](#component-architecture)
4. [Component Descriptions](#component-descriptions)
5. [Architecture Diagram](#architecture-diagram)
6. [Project Structure Glossary](#project-structure-glossary)
7. [Technology Stack](#technology-stack)
8. [Development Workflow](#development-workflow)
9. [Configuration Guide](#configuration-guide)
10. [API Reference](#api-reference)
11. [Testing Guide](#testing-guide)
12. [Deployment Guide](#deployment-guide)
13. [Troubleshooting](#troubleshooting)
14. [Examples and Use Cases](#examples-and-use-cases)
15. [Key Decisions and Rationale](#key-decisions-and-rationale)
16. [Future Enhancements](#future-enhancements)

---

## Executive Summary

**PhoenixDotNet** is a .NET 8.0 web application that provides a REST API and SQL Search GUI for Apache Phoenix. It connects to Phoenix Query Server using the REST API (Avatica protocol) without requiring ODBC drivers, making it cross-platform and easy to deploy.

### Key Features
- ✅ REST API for Phoenix operations (no ODBC required)
- ✅ Web-based SQL query interface
- ✅ HBase REST API integration
- ✅ Automatic connection management with retry logic
- ✅ Docker containerization support
- ✅ Comprehensive error handling and logging

### Quick Start
```bash
# Start everything with Docker Compose
docker-compose up --build

# Access points:
# - API: http://localhost:8099/api/phoenix/*
# - GUI: http://localhost:8100
```

### Additional Resources for Developers

**New to the project?** Check out these essential guides:

- **[ONBOARDING_CHECKLIST.md](./ONBOARDING_CHECKLIST.md)** - Step-by-step onboarding guide for new developers
- **[CODE_STYLE_GUIDELINES.md](./CODE_STYLE_GUIDELINES.md)** - Coding standards and best practices
- **[QUICK_REFERENCE.md](./QUICK_REFERENCE.md)** - Quick reference cheat sheet for common operations
- **[COMMON_TASKS.md](./COMMON_TASKS.md)** - Step-by-step guides for common development tasks
- **[CONTRIBUTING.md](./CONTRIBUTING.md)** - Contribution guidelines and workflow

---

## Project Overview

### What is PhoenixDotNet?

PhoenixDotNet is a middleware application that bridges .NET applications with Apache Phoenix/HBase infrastructure. It provides:

1. **REST API Layer**: Exposes Phoenix operations via HTTP REST endpoints
2. **Web Interface**: SQL query GUI for interactive database operations
3. **Connection Management**: Handles Phoenix Query Server connections with automatic retry
4. **HBase Integration**: Direct HBase REST API operations for table management

### Why This Project Exists

Apache Phoenix traditionally requires ODBC drivers for .NET integration, which:
- Are platform-specific and difficult to install
- Require complex configuration
- May not be available for all platforms

PhoenixDotNet solves this by using Phoenix Query Server's REST API (Avatica protocol), which:
- Works on any platform with HTTP support
- Requires no driver installation
- Uses standard HTTP/JSON communication
- Is easier to deploy in containers

### Target Use Cases

1. **Data Query Interface**: Web-based SQL query tool for analysts and developers
2. **REST API Backend**: API layer for applications needing Phoenix/HBase access
3. **Microservices Integration**: Lightweight service for Phoenix operations in microservices architecture
4. **Development and Testing**: Local development environment for Phoenix-based applications

---

## Component Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    PhoenixDotNet Application                     │
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────┐             │
│  │   Web API Layer  │         │   Web GUI Layer  │             │
│  │  (Port 8099)     │         │  (Port 8100)     │             │
│  └────────┬─────────┘         └────────┬─────────┘             │
│           │                            │                        │
│           └────────────┬───────────────┘                        │
│                        │                                        │
│              ┌─────────▼─────────┐                              │
│              │  PhoenixController │                              │
│              │  (API Endpoints)   │                              │
│              └─────────┬─────────┘                              │
│                        │                                        │
│        ┌───────────────┼───────────────┐                        │
│        │                               │                        │
│  ┌─────▼──────┐              ┌────────▼──────┐                 │
│  │PhoenixRest │              │HBaseRestClient│                 │
│  │   Client   │              │               │                 │
│  └─────┬──────┘              └───────┬───────┘                 │
│        │                              │                          │
└────────┼──────────────────────────────┼──────────────────────────┘
         │                              │
         │ HTTP/JSON                    │ HTTP/JSON
         │ (Avatica Protocol)            │ (REST API)
         │                              │
┌────────▼──────────┐        ┌─────────▼──────────┐
│ Phoenix Query     │        │  HBase REST API     │
│ Server (Port 8765) │        │  (Port 8080)       │
└────────┬──────────┘        └─────────┬──────────┘
         │                              │
         └──────────────┬───────────────┘
                        │
              ┌─────────▼─────────┐
              │  Apache Phoenix    │
              │  (HBase Layer)     │
              └────────────────────┘
```

---

## Component Descriptions

### 1. Core Application Components

#### `Program.cs`
**Purpose**: Application entry point and service configuration

**Responsibilities**:
- Configures ASP.NET Core web application
- Registers services (PhoenixRestClient, HBaseRestClient)
- Sets up dependency injection
- Configures HTTP request pipeline
- Configures Kestrel to listen on multiple ports (8099 for API, 8100 for GUI)
- Registers background services (PhoenixConnectionInitializer)

**Key Features**:
- Environment-based configuration (Development, Production)
- Swagger/OpenAPI support in development
- Static file serving for GUI
- CORS configuration (if needed)

**Location**: Root directory

---

#### `PhoenixController.cs`
**Purpose**: REST API controller for Phoenix operations

**Responsibilities**:
- Exposes HTTP endpoints for Phoenix operations
- Handles HTTP requests and responses
- Converts DataTable results to JSON
- Manages connection lifecycle
- Provides error handling and HTTP status codes

**Endpoints**:
- `GET /api/phoenix/health` - Health check
- `GET /api/phoenix/tables` - List all tables
- `GET /api/phoenix/tables/{tableName}/columns` - Get table columns
- `POST /api/phoenix/query` - Execute SELECT queries
- `POST /api/phoenix/execute` - Execute DDL/DML commands
- `POST /api/phoenix/hbase/tables/sensor` - Create HBase sensor table
- `GET /api/phoenix/hbase/tables/{tableName}/exists` - Check table existence
- `GET /api/phoenix/hbase/tables/{tableName}/schema` - Get table schema

**Location**: `Controllers/P`

---

#### `PhoenixRestClient.cs`
**Purpose**: Client for communicating with Phoenix Query Server via REST API

**Responsibilities**:
- Manages connection to Phoenix Query Server
- Implements Avatica protocol (JSON format)
- Executes SQL queries and commands
- Converts Avatica responses to .NET DataTable
- Handles connection retry logic (up to 10 attempts, 15-second delays)
- Manages connection lifecycle (open/close)

**Key Methods**:
- `OpenAsync()` - Opens connection to Phoenix Query Server
- `CloseAsync()` - Closes connection
- `ExecuteQueryAsync(string sql)` - Executes SELECT queries, returns DataTable
- `ExecuteQueryAsListAsync(string sql)` - Executes SELECT queries, returns List<Dictionary>
- `ExecuteNonQueryAsync(string sql)` - Executes DDL/DML commands
- `GetTablesAsync()` - Gets list of all tables
- `GetColumnsAsync(string tableName)` - Gets column information for a table
- `PrintDataTable(DataTable)` - Utility method for console output

**Protocol Details**:
- Uses Avatica JSON protocol
- Base URL: `http://{server}:{port}/json`
- Connection ID management
- Request format: `{"request": "prepareAndExecute", "connectionId": "...", "sql": "..."}`

**Error Handling**:
- Automatic retry with exponential backoff
- Detailed error messages with troubleshooting guidance
- Handles Protocol Buffer errors (Phoenix 6.0+ compatibility)

**Location**: Root directory

---

#### `HBaseRestClient.cs`
**Purpose**: Client for direct HBase REST API operations

**Responsibilities**:
- Communicates with HBase REST API (Stargate)
- Creates HBase tables with column families
- Checks table existence
- Retrieves table schemas
- Inserts data into HBase tables

**Key Methods**:
- `CreateTableAsync(string tableName, List<string> columnFamilies, string namespace)` - Creates HBase table
- `CreateSensorTableAsync(string tableName, string namespace)` - Creates pre-configured sensor table
- `TableExistsAsync(string tableName, string namespace)` - Checks if table exists
- `GetTableSchemaAsync(string tableName, string namespace)` - Gets table schema
- `ListTablesAsync(string namespace)` - Lists tables in namespace
- `PutDataAsync(...)` - Inserts data into HBase table

**Configuration**:
- Base URL: `http://{server}:{port}`
- Uses JSON format for requests/responses
- Supports namespaces (default: "default")

**Location**: Root directory

---

#### `PhoenixConnectionInitializer.cs`
**Purpose**: Background service for initializing Phoenix connection on startup

**Responsibilities**:
- Waits for HBase/Phoenix to fully initialize (30 seconds)
- Attempts to establish Phoenix connection on application startup
- Logs connection status
- Does not block application startup if connection fails

**Key Features**:
- Initial wait period: 30 seconds (allows HBase/Phoenix initialization)
- Connection attempts in background
- Graceful failure handling (connection attempted on first request if startup fails)
- Logging for debugging

**Location**: Root directory

---

### 2. Configuration Components

#### `appsettings.json`
**Purpose**: Base configuration file

**Configuration Sections**:
```json
{
  "Phoenix": {
    "Server": "localhost",
    "Port": "8765",
    "ConnectionString": "Driver={Phoenix ODBC Driver};Server=localhost;Port=8765"
  },
  "HBase": {
    "Server": "localhost",
    "Port": "8080"
  }
}
```

**Note**: ConnectionString is included for reference but not used by PhoenixRestClient (uses REST API instead).

**Location**: Root directory

---

#### `appsettings.Development.json`
**Purpose**: Development environment configuration

**Typical Settings**:
- Localhost connections
- Debug logging enabled
- Swagger UI enabled

**Location**: Root directory

---

#### `appsettings.Production.json`
**Purpose**: Production environment configuration

**Typical Settings**:
- Container service names (e.g., `opdb-docker`)
- Production logging levels
- Security settings

**Location**: Root directory

---

#### `hbase-site.xml`
**Purpose**: HBase configuration file (mounted to Phoenix container)

**Key Configuration**:
- JSON serialization enabled for Phoenix Query Server
- Connection settings
- Timeout configurations

**Location**: Root directory

---

#### `PhoenixDotNet.csproj`
**Purpose**: .NET project file with dependencies

**Dependencies**:
- Microsoft.Extensions.Configuration (8.0.0)
- Microsoft.Extensions.Configuration.Json (8.0.0)
- Microsoft.Extensions.Configuration.EnvironmentVariables (8.0.0)
- System.Data.Odbc (8.0.0) - Note: Not actively used, kept for compatibility
- System.Net.Http.Json (8.0.0)
- Swashbuckle.AspNetCore (6.5.0) - Swagger/OpenAPI

**Target Framework**: .NET 8.0

**Location**: Root directory

---

### 3. Web Interface Components

#### `wwwroot/index.html`
**Purpose**: SQL Search GUI web interface

**Features**:
- Interactive SQL query editor
- Execute query button (for SELECT statements)
- Execute command button (for DDL/DML)
- List tables button
- Quick query buttons (pre-filled common queries)
- Results display in formatted table
- Error message display
- Status messages (success/error/info)

**JavaScript Functions**:
- `executeQuery()` - Executes SELECT queries
- `executeCommand()` - Executes DDL/DML commands
- `listTables()` - Lists all tables
- `setQuery(query)` - Sets query text
- `clearResults()` - Clears results display
- `displayResults(data)` - Formats and displays query results

**API Integration**:
- Uses `/api/phoenix/query` endpoint for queries
- Uses `/api/phoenix/execute` endpoint for commands
- Uses `/api/phoenix/tables` endpoint for table listing

**Location**: `wwwroot/`

---

### 4. Docker Components

#### `Dockerfile`
**Purpose**: Multi-stage Docker build for application container

**Stages**:
1. **Build Stage**: Uses .NET 8.0 SDK to compile application
2. **Publish Stage**: Publishes application
3. **Runtime Stage**: Uses .NET 8.0 ASP.NET runtime

**Key Features**:
- Installs unixODBC and unixODBC-dev (for ODBC support if needed)
- Installs curl (for health checks)
- Creates ODBC driver directory structure
- Sets LD_LIBRARY_PATH for ODBC drivers
- Copies published application
- Sets entry point to run PhoenixDotNet.dll

**Location**: Root directory

---

#### `docker-compose.yml`
**Purpose**: Docker Compose configuration for full stack deployment

**Services**:

1. **opdb-docker** (Apache Phoenix/HBase):
   - Image: `cloudera/opdb-docker:latest`
   - Ports: 8765 (Phoenix Query Server), 8080 (HBase REST), 9090/9095 (Web UIs), 2181 (Zookeeper), 16010/16020 (HBase UIs)
   - Volumes: Mounts `hbase-site.xml` for JSON serialization
   - Environment: `PQS_ENABLED=true`
   - Network: `obdb-net`

2. **phoenix-app** (.NET Application):
   - Build: Uses Dockerfile
   - Ports: 8099 (API), 8100 (GUI)
   - Depends on: `opdb-docker`
   - Health check: Checks `/api/phoenix/health` endpoint
   - Environment: Phoenix server configuration
   - Network: `obdb-net`

**Network**: `obdb-net` (bridge network)

**Location**: Root directory

---

### 5. Documentation Components

#### Documentation Directory Structure

**Location**: `Documentation/`

**Files**:
- `README.md` - Documentation index
- `QUICKSTART.md` - Quick start guide
- `DOCKER.md` - Docker deployment guide
- `SETUP.md` - Docker build setup and ODBC configuration
- `DEPLOYMENT.md` - Production deployment guide
- `SECURITY.md` - Security policy and best practices
- `README_REST_API.md` - REST API reference
- `README_TABLES.md` - Table operations guide
- `README_VIEWS.md` - Phoenix views documentation
- `HBASE_API_TEST.md` - HBase API testing guide
- `TROUBLESHOOTING.md` - Troubleshooting guide
- `PHOENIX_ODBC_SETUP.md` - ODBC driver setup guide
- `ODBC_IMPLEMENTATION.md` - ODBC implementation details

---

### 6. Examples and Testing Components

#### Examples Directory

**Location**: `examples/`

**Files**:
- `complete_example.sh` - Complete workflow example (table + view creation)
- `create_table_and_view_example.sh` - Table and view creation example

---

#### Tests Directory

**Location**: `tests/`

**Test Scripts**:
- `smoke_test.sh` - Quick verification test
- `test_connectivity.sh` - Connectivity testing
- `test_api_endpoints.sh` - API endpoint testing
- `test_database_operations.sh` - Database CRUD operations testing
- `test_hbase_api.sh` - HBase REST API testing
- `diagnostic.sh` - Comprehensive diagnostic report
- `troubleshoot.sh` - Automated troubleshooting
- `run_all_tests.sh` - Run all test suites

**SQL Scripts**:
- `create_testtable.sql` - Test table creation
- `create_testtable_phoenix.sql` - Phoenix test table creation
- `create_view.sql` - View creation
- `create_views_phoenix.sql` - Phoenix views creation

**Documentation**:
- `Documentation/TESTING_GUIDE.md` - Comprehensive testing guide

---

### 7. Additional Components

#### `phoenix-mcp-server-by-cdata/`
**Purpose**: Java-based MCP (Model Context Protocol) server for Phoenix

**Description**: Separate Java project that provides MCP integration for Phoenix. This is a complementary component and not required for the main .NET application.

**Location**: `phoenix-mcp-server-by-cdata/`

---

## Architecture Diagram

### Detailed Component Interaction

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Client Layer                                    │
│                                                                           │
│  ┌──────────────┐              ┌──────────────┐                         │
│  │  Web Browser │              │  REST Client │                         │
│  │  (Port 8100) │              │  (Port 8099)│                         │
│  └──────┬───────┘              └──────┬───────┘                         │
└─────────┼─────────────────────────────┼─────────────────────────────────┘
          │                             │
          │ HTTP                        │ HTTP
          │                             │
┌─────────▼─────────────────────────────▼─────────────────────────────────┐
│                    PhoenixDotNet Application                            │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐   │
│  │                    ASP.NET Core Web Application                  │   │
│  │                    (Program.cs)                                │   │
│  └────────────────────────────┬───────────────────────────────────┘   │
│                               │                                         │
│  ┌────────────────────────────▼───────────────────────────────────┐   │
│  │              PhoenixController (REST API)                       │   │
│  │  - GET /api/phoenix/tables                                     │   │
│  │  - GET /api/phoenix/tables/{name}/columns                      │   │
│  │  - POST /api/phoenix/query                                     │   │
│  │  - POST /api/phoenix/execute                                   │   │
│  │  - POST /api/phoenix/hbase/tables/*                            │   │
│  └──────────────┬──────────────────────────┬───────────────────────┘   │
│                 │                          │                           │
│  ┌──────────────▼──────────┐   ┌──────────▼──────────┐               │
│  │   PhoenixRestClient     │   │  HBaseRestClient     │               │
│  │                         │   │                      │               │
│  │  - OpenAsync()          │   │  - CreateTableAsync()│               │
│  │  - ExecuteQueryAsync()  │   │  - TableExistsAsync()│              │
│  │  - ExecuteNonQueryAsync()│   │  - GetTableSchemaAsync()│            │
│  │  - GetTablesAsync()     │   │                      │               │
│  │  - GetColumnsAsync()    │   │                      │               │
│  └──────────────┬──────────┘   └──────────┬──────────┘               │
│                 │                          │                           │
│  ┌──────────────▼──────────────────────────▼──────────┐              │
│  │         PhoenixConnectionInitializer                │              │
│  │         (Background Service)                        │              │
│  │         - Waits 30s for HBase init                  │              │
│  │         - Attempts connection on startup            │              │
│  └─────────────────────────────────────────────────────┘              │
└──────────────────┬──────────────────────────┬─────────────────────────┘
                   │                          │
                   │ HTTP/JSON                │ HTTP/JSON
                   │ (Avatica Protocol)       │ (REST API)
                   │                          │
┌──────────────────▼──────────┐   ┌───────────▼──────────┐
│  Phoenix Query Server       │   │  HBase REST API       │
│  (Port 8765)                │   │  (Port 8080)         │
│                             │   │                      │
│  - Avatica Protocol         │   │  - Table Management  │
│  - JSON/Protobuf            │   │  - Schema Operations │
│  - Connection Management    │   │  - Data Operations    │
└──────────────┬─────────────┘   └───────────┬──────────┘
               │                              │
               └──────────────┬───────────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Apache Phoenix   │
                    │  (HBase Layer)    │
                    └───────────────────┘
```

### Data Flow Example: Query Execution

```
1. Client Request
   │
   ▼
2. PhoenixController.ExecuteQuery()
   │
   ▼
3. PhoenixRestClient.OpenAsync() [if not connected]
   │  - Retry logic (up to 10 attempts, 15s delays)
   │  - Connection ID management
   │
   ▼
4. PhoenixRestClient.ExecuteQueryAsync()
   │  - Builds Avatica request: {"request": "prepareAndExecute", ...}
   │  - Sends HTTP POST to Phoenix Query Server
   │
   ▼
5. Phoenix Query Server
   │  - Processes SQL query
   │  - Returns Avatica response with results
   │
   ▼
6. PhoenixRestClient.ConvertToDataTable()
   │  - Parses Avatica response
   │  - Converts to .NET DataTable
   │
   ▼
7. PhoenixController.ConvertDataTableToJson()
   │  - Converts DataTable to JSON format
   │
   ▼
8. HTTP Response to Client
   │  - JSON with columns, rows, rowCount
```

---

## Project Structure Glossary

### Root Directory Files

| File/Directory | Purpose | Type |
|---------------|---------|------|
| `Program.cs` | Application entry point and configuration | C# |
| `PhoenixRestClient.cs` | Phoenix Query Server REST client | C# |
| `HBaseRestClient.cs` | HBase REST API client | C# |
| `PhoenixConnectionInitializer.cs` | Background service for connection initialization | C# |
| `PhoenixDotNet.csproj` | .NET project file with dependencies | XML |
| `appsettings.json` | Base configuration file | JSON |
| `appsettings.Development.json` | Development environment configuration | JSON |
| `appsettings.Production.json` | Production environment configuration | JSON |
| `hbase-site.xml` | HBase configuration (mounted to Phoenix container) | XML |
| `hbase-site.xml.original` | Original HBase configuration backup | XML |
| `Dockerfile` | Multi-stage Docker build configuration | Dockerfile |
| `docker-compose.yml` | Docker Compose configuration for full stack | YAML |
| `README.md` | Main project documentation | Markdown |
| `odbc.ini.example` | Example ODBC configuration file | INI |
| `odbcinst.ini.example` | Example ODBC driver configuration | INI |
| `PhoenixDotNet.code-workspace` | VS Code workspace configuration | JSON |

### Directory Structure

#### `Controllers/`
**Purpose**: ASP.NET Core API controllers

| File | Purpose |
|------|---------|
| `PhoenixController.cs` | REST API controller for Phoenix operations |

---

#### `wwwroot/`
**Purpose**: Static web files served by ASP.NET Core

| File | Purpose |
|------|---------|
| `index.html` | SQL Search GUI web interface |

---

#### `Documentation/`
**Purpose**: Comprehensive project documentation

| File | Purpose |
|------|---------|
| `README.md` | Documentation index |
| `QUICKSTART.md` | Quick start guide |
| `DOCKER.md` | Docker deployment guide |
| `SETUP.md` | Docker build setup and ODBC configuration |
| `DEPLOYMENT.md` | Production deployment guide |
| `SECURITY.md` | Security policy and best practices |
| `README_REST_API.md` | REST API reference |
| `README_TABLES.md` | Table operations guide |
| `README_VIEWS.md` | Phoenix views documentation |
| `HBASE_API_TEST.md` | HBase API testing guide |
| `TROUBLESHOOTING.md` | Troubleshooting guide |
| `PHOENIX_ODBC_SETUP.md` | ODBC driver setup guide |
| `ODBC_IMPLEMENTATION.md` | ODBC implementation details |

---

#### `examples/`
**Purpose**: Example scripts and documentation

| File | Purpose |
|------|---------|
| `complete_example.sh` | Complete workflow example script |
| `create_table_and_view_example.sh` | Table and view creation example |

---

#### `tests/`
**Purpose**: Test scripts and SQL test files

| File | Purpose |
|------|---------|
| `smoke_test.sh` | Quick verification test |
| `test_connectivity.sh` | Connectivity testing |
| `test_api_endpoints.sh` | API endpoint testing |
| `test_database_operations.sh` | Database CRUD operations testing |
| `test_hbase_api.sh` | HBase REST API testing |
| `diagnostic.sh` | Comprehensive diagnostic report |
| `troubleshoot.sh` | Automated troubleshooting |
| `run_all_tests.sh` | Run all test suites |
| `create_testtable.sql` | Test table creation SQL |
| `create_testtable_phoenix.sql` | Phoenix test table creation SQL |
| `create_view.sql` | View creation SQL |
| `create_views_phoenix.sql` | Phoenix views creation SQL |
| `Documentation/TESTING_GUIDE.md` | Comprehensive testing guide |

---

#### `phoenix-mcp-server-by-cdata/`
**Purpose**: Java-based MCP server for Phoenix (complementary component)

| File/Directory | Purpose |
|---------------|---------|
| `pom.xml` | Maven project configuration |
| `src/main/java/` | Java source code |
| `src/test/java/` | Java test code |
| `target/` | Compiled Java classes |

---

#### `data/`
**Purpose**: Data directory (empty by default, used for data storage if needed)

---

## Technology Stack

### Core Technologies

| Technology | Version | Purpose |
|-----------|---------|---------|
| .NET | 8.0 | Application framework |
| ASP.NET Core | 8.0 | Web framework |
| C# | 10.0+ | Programming language |

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| Microsoft.Extensions.Configuration | 8.0.0 | Configuration management |
| Microsoft.Extensions.Configuration.Json | 8.0.0 | JSON configuration |
| Microsoft.Extensions.Configuration.EnvironmentVariables | 8.0.0 | Environment variable configuration |
| System.Net.Http.Json | 8.0.0 | HTTP client with JSON support |
| Swashbuckle.AspNetCore | 6.5.0 | Swagger/OpenAPI documentation |

### External Services

| Service | Version | Purpose |
|---------|---------|---------|
| Apache Phoenix Query Server | 6.0+ | SQL query interface for HBase |
| Apache HBase | 2.x+ | NoSQL database |
| Cloudera OPDB Docker | latest | Containerized Phoenix/HBase |

### Development Tools

| Tool | Purpose |
|------|---------|
| Docker | Containerization |
| Docker Compose | Multi-container orchestration |
| curl | HTTP testing |
| jq | JSON parsing (optional) |

---

## Development Workflow

> **Note**: For detailed step-by-step guides on common tasks, see [COMMON_TASKS.md](./COMMON_TASKS.md).  
> For quick command reference, see [QUICK_REFERENCE.md](./QUICK_REFERENCE.md).

### Local Development Setup

1. **Prerequisites**:
   ```bash
   # Install .NET 8.0 SDK
   # Install Docker and Docker Compose
   ```

2. **Start Phoenix/HBase**:
   ```bash
   docker-compose up -d opdb-docker
   # Wait 60-90 seconds for initialization
   ```

3. **Configure Application**:
   ```bash
   # Edit appsettings.json or appsettings.Development.json
   # Set Phoenix.Server to "localhost"
   # Set Phoenix.Port to "8765"
   ```

4. **Run Application**:
   ```bash
   dotnet restore
   dotnet build
   dotnet run
   ```

5. **Access Application**:
   - API: http://localhost:8099/api/phoenix/*
   - GUI: http://localhost:8100
   - Swagger: http://localhost:8099/swagger (development only)

### Docker Development

1. **Build and Run**:
   ```bash
   docker-compose up --build
   ```

2. **View Logs**:
   ```bash
   docker-compose logs -f phoenix-app
   ```

3. **Stop Services**:
   ```bash
   docker-compose down
   ```

### Code Structure Guidelines

1. **Controllers**: Handle HTTP requests/responses
2. **Clients**: Handle external service communication
3. **Services**: Business logic (if needed)
4. **Models**: Data transfer objects (if needed)

### Testing Workflow

1. **Run Smoke Test**:
   ```bash
   cd tests && ./smoke_test.sh
   ```

2. **Run Full Test Suite**:
   ```bash
   cd tests && ./run_all_tests.sh
   ```

3. **Troubleshoot Issues**:
   ```bash
   cd tests && ./troubleshoot.sh
   ```

---

## Configuration Guide

### Application Configuration

#### Phoenix Configuration

```json
{
  "Phoenix": {
    "Server": "localhost",        // Phoenix Query Server hostname
    "Port": "8765",               // Phoenix Query Server port
    "ConnectionString": "..."     // Not used (for reference only)
  }
}
```

**Environment Variables**:
- `Phoenix__Server` - Phoenix Query Server hostname
- `Phoenix__Port` - Phoenix Query Server port

#### HBase Configuration

```json
{
  "HBase": {
    "Server": "localhost",        // HBase REST API hostname
    "Port": "8080"                // HBase REST API port
  }
}
```

**Environment Variables**:
- `HBase__Server` - HBase REST API hostname
- `HBase__Port` - HBase REST API port

### Docker Configuration

#### docker-compose.yml

**Service Configuration**:
- `opdb-docker`: Phoenix/HBase container
- `phoenix-app`: .NET application container

**Network**: `obdb-net` (bridge network)

**Ports**:
- 8099: Phoenix .NET API
- 8100: SQL Search GUI
- 8765: Phoenix Query Server
- 8080: HBase REST API

---

## API Reference

### Phoenix Operations

#### Health Check
```http
GET /api/phoenix/health
```

**Response**:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-01T00:00:00Z"
}
```

---

#### List Tables
```http
GET /api/phoenix/tables
```

**Response**:
```json
{
  "columns": [
    {"name": "TABLE_NAME", "type": "String"},
    {"name": "TABLE_TYPE", "type": "String"},
    {"name": "TABLE_SCHEM", "type": "String"}
  ],
  "rows": [
    {"TABLE_NAME": "SYSTEM.CATALOG", "TABLE_TYPE": "SYSTEM TABLE", "TABLE_SCHEM": "SYSTEM"}
  ],
  "rowCount": 1
}
```

---

#### Get Table Columns
```http
GET /api/phoenix/tables/{tableName}/columns
```

**Example**:
```http
GET /api/phoenix/tables/TESTTABLE/columns
```

**Response**:
```json
{
  "columns": [
    {"name": "COLUMN_NAME", "type": "String"},
    {"name": "DATA_TYPE", "type": "Int32"}
  ],
  "rows": [
    {"COLUMN_NAME": "ID", "DATA_TYPE": 4}
  ],
  "rowCount": 1
}
```

---

#### Execute Query
```http
POST /api/phoenix/query
Content-Type: application/json

{
  "sql": "SELECT * FROM SYSTEM.CATALOG LIMIT 10"
}
```

**Response**:
```json
{
  "columns": [...],
  "rows": [...],
  "rowCount": 10
}
```

---

#### Execute Command
```http
POST /api/phoenix/execute
Content-Type: application/json

{
  "sql": "CREATE TABLE IF NOT EXISTS testtable (id INTEGER PRIMARY KEY, name VARCHAR(100))"
}
```

**Response**:
```json
{
  "message": "Command executed successfully"
}
```

---

#### Adding Data to Tables

The best way to add rows to a table depends on whether it's a **Phoenix table** or an **HBase-native table**.

**For Phoenix Tables (Created via Phoenix SQL):**

✅ **Use Phoenix SQL (UPSERT) - Recommended**

Phoenix tables use binary encoding that cannot be replicated via HBase shell. Always use Phoenix SQL:

```http
POST /api/phoenix/execute
Content-Type: application/json

{
  "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (7, 'grace_lee', 'grace@example.com', CURRENT_DATE())"
}
```

**Benefits:**
- ✅ Automatically handles binary encoding
- ✅ Ensures data integrity and type safety
- ✅ Works immediately with Phoenix queries
- ✅ No manual encoding required

**For HBase-Native Tables (Created via HBase Shell):**

✅ **Use HBase Shell/REST API + Phoenix Views**

For HBase-native tables, insert data via HBase shell or REST API, then create a Phoenix view to query it:

```bash
# Insert via HBase shell
# ⚠️ IMPORTANT: Use UPPERCASE for table names to match Phoenix view naming requirements
docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<EOF
put 'EMPLOYEE_DATA', '1', 'info:name', 'Alice'
put 'EMPLOYEE_DATA', '1', 'info:score', '100'
EOF
```

Or via HBase REST API:

```http
PUT /api/phoenix/hbase/tables/EMPLOYEE_DATA/data
Content-Type: application/json

{
  "rowKey": "1",
  "columnFamily": "info",
  "column": "name",
  "value": "Alice",
  "namespace": "default"
}
```

Then create a Phoenix view:

```http
POST /api/phoenix/views
Content-Type: application/json

{
  "viewName": "EMPLOYEE_DATA",
  "hBaseTableName": "EMPLOYEE_DATA",
  "namespace": "default",
  "columns": [
    { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
    { "name": "name", "type": "VARCHAR", "columnFamily": "info" },
    { "name": "score", "type": "INTEGER", "columnFamily": "info" }
  ]
}
```

**Quick Decision Guide:**

| Table Type | Insert Method | Query Method |
|------------|--------------|--------------|
| **Phoenix table** (created via `CREATE TABLE`) | Phoenix SQL (UPSERT) | Phoenix SQL (SELECT) |
| **HBase-native table** (created via `create 'table'`) | HBase shell/REST API | Phoenix View or direct HBase query |

**Important Notes:**
- ⚠️ **Don't mix methods**: For Phoenix tables, always use Phoenix SQL (UPSERT). HBase shell inserts won't work correctly with Phoenix queries due to encoding differences.
- ⚠️ **HBase shell limitation**: HBase shell treats escape sequences like `\x80` as literal strings, not binary bytes, so it cannot replicate Phoenix's binary encoding.
- ✅ **Phoenix views**: For HBase-native tables, Phoenix views provide SQL access without requiring data migration.

For more details, see [README_TABLES.md](./README_TABLES.md).

---

### HBase Operations

#### Create Sensor Table
```http
POST /api/phoenix/hbase/tables/sensor
Content-Type: application/json

{
  "tableName": "SENSOR_INFO",
  "namespace": "default"
}
```

**Response**:
```json
{
  "message": "Sensor table 'default:SENSOR_INFO' created successfully",
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "columnFamilies": ["metadata", "readings", "status"]
}
```

---

#### Check Table Exists
```http
GET /api/phoenix/hbase/tables/{tableName}/exists?namespace=default
```

**Response**:
```json
{
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "exists": true
}
```

---

#### Get Table Schema
```http
GET /api/phoenix/hbase/tables/{tableName}/schema?namespace=default
```

**Response**:
```json
{
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "schema": "{...}"
}
```

---

## Testing Guide

### Quick Start

```bash
# Run all tests
cd tests && ./run_all_tests.sh

# Quick verification
cd tests && ./smoke_test.sh

# Troubleshoot issues
cd tests && ./troubleshoot.sh
```

### Test Scripts

See `Documentation/TESTING_GUIDE.md` for comprehensive testing documentation.

---

## Deployment Guide

### Docker Deployment (Recommended)

```bash
# Build and start all services
docker-compose up --build -d

# View logs
docker-compose logs -f phoenix-app

# Stop services
docker-compose down
```

See `Documentation/DOCKER.md` for detailed deployment instructions.

---

## Troubleshooting

### Common Issues

1. **Connection Failures**
   - Check Phoenix Query Server is running
   - Verify port 8765 is accessible
   - Wait 60-90 seconds for HBase/Phoenix initialization
   - Check logs: `docker-compose logs opdb-docker`

2. **Protocol Errors**
   - Phoenix 6.0+ uses Protobuf by default
   - Ensure `hbase-site.xml` has JSON serialization enabled
   - Check `hbase-site.xml` is mounted in docker-compose.yml

3. **Table Not Found**
   - Phoenix table names are case-sensitive
   - Use uppercase names or quoted names
   - Check SYSTEM.CATALOG for actual table names

See `Documentation/TROUBLESHOOTING.md` for comprehensive troubleshooting guide.

---

## Examples and Use Cases

### Example 1: Create Table and Insert Data

```bash
# Create table
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql":"CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name VARCHAR(100), email VARCHAR(255))"}'

# Insert data
curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql":"UPSERT INTO users (id, name, email) VALUES (1, '\''John Doe'\'', '\''john@example.com'\'')"}'

# Query data
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM USERS"}'
```

### Example 2: Complete Workflow

See `examples/complete_example.sh` for a complete workflow example.

---

## Key Decisions and Rationale

### 1. REST API Instead of ODBC

**Decision**: Use Phoenix Query Server REST API instead of ODBC drivers.

**Rationale**:
- Cross-platform compatibility
- No driver installation required
- Easier containerization
- Standard HTTP/JSON communication

### 2. Avatica Protocol

**Decision**: Use Avatica JSON protocol for communication.

**Rationale**:
- Standard protocol for Phoenix Query Server
- JSON format is human-readable
- Good error messages
- Works with standard HTTP clients

### 3. Background Connection Initialization

**Decision**: Use background service for connection initialization.

**Rationale**:
- Non-blocking application startup
- Allows HBase/Phoenix initialization time
- Graceful failure handling
- Connection attempted on first request if startup fails

### 4. Dual Port Configuration

**Decision**: Run API on port 8099 and GUI on port 8100.

**Rationale**:
- Separation of concerns
- Easy to proxy API separately
- Allows different authentication/authorization
- Clear distinction between API and UI

---

## Future Enhancements

### Potential Improvements

1. **Authentication/Authorization**
   - Add authentication middleware
   - Support for API keys
   - User-based access control

2. **Performance Optimization**
   - Connection pooling
   - Query result caching
   - Async query execution

3. **Additional Features**
   - Batch query execution
   - Query history
   - Export query results
   - Query templates

4. **Monitoring and Observability**
   - Metrics collection (Prometheus)
   - Distributed tracing
   - Health check improvements

5. **Protocol Buffer Support**
   - Add Protobuf support for Phoenix 6.0+
   - Automatic protocol detection
   - Fallback to JSON if Protobuf fails

---

## Additional Resources

### Documentation

- Main README: `README.md`
- Documentation Index: `Documentation/README.md`
- Quick Start: `Documentation/QUICKSTART.md`
- Docker Guide: `Documentation/DOCKER.md`
- REST API Reference: `Documentation/README_REST_API.md`
- Troubleshooting: `Documentation/TROUBLESHOOTING.md`
- Testing Guide: `Documentation/TESTING_GUIDE.md`

### External Resources

- [Apache Phoenix Documentation](https://phoenix.apache.org/)
- [Phoenix Query Server Guide](https://phoenix.apache.org/server.html)
- [Avatica Protocol Documentation](https://calcite.apache.org/avatica/docs/)
- [HBase REST API Documentation](https://hbase.apache.org/book.html#_rest)
- [ASP.NET Core Documentation](https://docs.microsoft.com/en-us/aspnet/core/)

---

## Contact and Support

For questions or issues:
1. Review troubleshooting documentation
2. Check test scripts for diagnostics
3. Review example scripts for usage patterns
4. Check Docker logs for detailed error messages

---

## Conclusion

This handbook provides comprehensive information for development teams to successfully work with PhoenixDotNet. All components, configurations, and workflows are documented to ensure smooth handoff and continued development.

**Key Takeaways**:
- ✅ REST API approach (no ODBC required)
- ✅ Docker-first deployment
- ✅ Comprehensive error handling
- ✅ Well-documented examples and tests
- ✅ Clear separation of concerns

**Next Steps for New Team**:
1. Read this handbook completely
2. Review examples in `examples/` directory
3. Run test suite to verify setup
4. Explore codebase starting with `Program.cs` and `PhoenixController.cs`
5. Review API documentation in `Documentation/README_REST_API.md`

---

**Document Version**: 1.0  
**Last Updated**: 2024  
**Maintained By**: Development Team

