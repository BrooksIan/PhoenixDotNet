# Onboarding Checklist for New Developers

This checklist will help new developers get up and running with the PhoenixDotNet project quickly.

## Pre-Flight Checklist

### 1. Prerequisites Verification

- [ ] **.NET 8.0 SDK** installed
  ```bash
  dotnet --version  # Should show 8.0.x or later
  ```
- [ ] **Docker Desktop** installed and running
  ```bash
  docker --version
  docker ps  # Should not error
  ```
- [ ] **Docker Compose** installed
  ```bash
  docker-compose --version
  ```
- [ ] **Git** installed and configured
  ```bash
  git --version
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```
- [ ] **IDE** installed (choose one):
  - [ ] Visual Studio 2022 (recommended for Windows)
  - [ ] Visual Studio Code with C# extension
  - [ ] JetBrains Rider
  - [ ] Visual Studio for Mac

### 2. Repository Setup

- [ ] Clone the repository
  ```bash
  git clone <repository-url>
  cd PhoenixDotNet
  ```
- [ ] Verify project structure
  ```bash
  ls -la  # Should see Program.cs, PhoenixDotNet.csproj, etc.
  ```
- [ ] Review project structure in `Documentation/DEVELOPMENT_HANDBOOK.md`

### 3. Environment Setup

- [ ] Review `appsettings.json` configuration
- [ ] Review `appsettings.Development.json` (if exists)
- [ ] Set environment variable (optional):
  ```bash
  export ASPNETCORE_ENVIRONMENT=Development
  ```

## Day 1: Getting Started

### Step 1: Start Phoenix/HBase Services

- [ ] Start Phoenix using Docker Compose
  ```bash
  docker-compose up -d opdb-docker
  ```
- [ ] Wait for Phoenix to initialize (60-90 seconds)
  ```bash
  docker logs -f opdb-docker
  # Wait until you see "Phoenix Query Server started" or similar
  ```
- [ ] Verify Phoenix is running
  ```bash
  docker ps | grep opdb-docker
  # Should show container running
  ```

### Step 2: Build and Run the Application

- [ ] Restore NuGet packages
  ```bash
  dotnet restore
  ```
- [ ] Build the project
  ```bash
  dotnet build
  ```
- [ ] Run the application
  ```bash
  dotnet run
  ```
- [ ] Verify application is running
  - [ ] API health check: http://localhost:8099/api/phoenix/health
  - [ ] SQL GUI: http://localhost:8100
  - [ ] Swagger UI: http://localhost:8099/swagger (if in Development)

### Step 3: Run Tests

- [ ] Navigate to tests directory
  ```bash
  cd tests
  ```
- [ ] Run smoke test
  ```bash
  ./smoke_test.sh
  ```
- [ ] Verify all tests pass

### Step 4: Explore the Codebase

- [ ] Read `Documentation/DEVELOPMENT_HANDBOOK.md`
- [ ] Review `Program.cs` - understand application entry point
- [ ] Review `Controllers/PhoenixController.cs` - understand API endpoints
- [ ] Review `PhoenixRestClient.cs` - understand Phoenix connection logic
- [ ] Review `HBaseRestClient.cs` - understand HBase operations
- [ ] Review `wwwroot/index.html` - understand SQL GUI

### Step 5: Try Examples

- [ ] Run a simple example
  ```bash
  cd examples
  ./complete_example.sh
  ```
- [ ] Verify example creates tables and views
- [ ] Query the created tables via API or GUI

## Week 1: Deep Dive

### Understanding the Architecture

- [ ] Study the architecture diagram in `README.md`
- [ ] Understand the data flow (Client → Controller → Client → Phoenix)
- [ ] Review Avatica protocol documentation
- [ ] Review HBase REST API documentation

### Code Exploration

- [ ] Set breakpoints in `PhoenixController.cs` and trace a request
- [ ] Set breakpoints in `PhoenixRestClient.cs` and trace connection
- [ ] Review error handling in all components
- [ ] Understand retry logic in `PhoenixRestClient.OpenAsync()`

### API Testing

- [ ] Test all API endpoints using Swagger UI
- [ ] Test API endpoints using curl
- [ ] Test API endpoints using the SQL GUI
- [ ] Review API responses and error messages

### Database Operations

- [ ] Create a test table
- [ ] Insert data using UPSERT
- [ ] Query data using SELECT
- [ ] Create a view
- [ ] Query the view
- [ ] Understand Phoenix SQL syntax differences

## Week 2: Development Tasks

### Task 1: Make a Simple Change

- [ ] Add a new API endpoint (e.g., `GET /api/phoenix/version`)
- [ ] Test the new endpoint
- [ ] Verify Swagger documentation updates

### Task 2: Add Error Handling

- [ ] Add try-catch to a method
- [ ] Add logging for errors
- [ ] Test error scenarios

### Task 3: Add Unit Tests

- [ ] Create a test project (if not exists)
- [ ] Write a unit test for a method
- [ ] Run tests and verify they pass

### Task 4: Code Review

- [ ] Review a pull request (if available)
- [ ] Understand code review process
- [ ] Learn coding standards

## Essential Knowledge Areas

### Must Know

- [ ] **Phoenix SQL Syntax**: Differences from standard SQL (UPSERT, case sensitivity, etc.)
- [ ] **Avatica Protocol**: How Phoenix Query Server REST API works
- [ ] **HBase Concepts**: Column families, row keys, namespaces
- [ ] **ASP.NET Core**: Controllers, dependency injection, middleware
- [ ] **Docker**: Container basics, docker-compose, networking

### Should Know

- [ ] **Phoenix Views**: How views work and when to use them
- [ ] **HBase REST API**: Direct HBase operations
- [ ] **.NET DataTable**: Data manipulation and conversion
- [ ] **JSON Serialization**: How responses are formatted
- [ ] **Connection Management**: Retry logic, connection lifecycle

### Nice to Know

- [ ] **ODBC vs REST API**: Why REST API was chosen
- [ ] **Phoenix Query Server**: Internal architecture
- [ ] **HBase Architecture**: Master, RegionServer, Zookeeper
- [ ] **Performance Optimization**: Query optimization, connection pooling

## Common Tasks Reference

### Starting Development

```bash
# Start Phoenix
docker-compose up -d opdb-docker

# Wait for initialization
sleep 90

# Run application
dotnet run

# Run tests
cd tests && ./smoke_test.sh
```

### Debugging

```bash
# View application logs
docker logs -f phoenix-dotnet-app

# View Phoenix logs
docker logs -f opdb-docker

# Test API endpoint
curl http://localhost:8099/api/phoenix/health

# Test Phoenix connection
curl http://localhost:8765/json
```

### Making Changes

1. Create a feature branch
2. Make your changes
3. Test locally
4. Run tests
5. Commit changes
6. Create pull request

## Troubleshooting Quick Reference

### Connection Issues

- [ ] Check Phoenix is running: `docker ps | grep opdb-docker`
- [ ] Check port 8765: `nc -zv localhost 8765`
- [ ] Wait longer (HBase takes 60-90 seconds to initialize)
- [ ] Check logs: `docker logs opdb-docker`

### Build Issues

- [ ] Clean and rebuild: `dotnet clean && dotnet build`
- [ ] Restore packages: `dotnet restore`
- [ ] Check .NET version: `dotnet --version`

### API Issues

- [ ] Check application is running: `curl http://localhost:8099/api/phoenix/health`
- [ ] Check Swagger UI: http://localhost:8099/swagger
- [ ] Review error messages in response
- [ ] Check logs for detailed errors

## Resources to Bookmark

- [ ] **Project Documentation**: `Documentation/DEVELOPMENT_HANDBOOK.md`
- [ ] **API Reference**: `Documentation/README_REST_API.md`
- [ ] **Troubleshooting**: `Documentation/TROUBLESHOOTING.md`
- [ ] **Testing Guide**: `Documentation/TESTING_GUIDE.md`
- [ ] **Apache Phoenix Docs**: https://phoenix.apache.org/
- [ ] **Phoenix Query Server**: https://phoenix.apache.org/server.html
- [ ] **Avatica Protocol**: https://calcite.apache.org/avatica/docs/
- [ ] **HBase REST API**: https://hbase.apache.org/book.html#_rest
- [ ] **ASP.NET Core Docs**: https://docs.microsoft.com/en-us/aspnet/core/

## Questions to Ask Your Team Lead

- [ ] What is the Git workflow? (branching strategy, commit conventions)
- [ ] What is the code review process?
- [ ] What is the testing strategy?
- [ ] What is the deployment process?
- [ ] What are the coding standards?
- [ ] What tools are used for development?
- [ ] What is the issue tracking system?
- [ ] What is the communication channel for questions?

## Success Criteria

You're ready to contribute when you can:

- [ ] Start the application from scratch
- [ ] Run all tests successfully
- [ ] Make a simple code change
- [ ] Test your change using the API
- [ ] Understand the basic architecture
- [ ] Navigate the codebase confidently
- [ ] Debug common issues independently

## Next Steps

After completing this checklist:

1. Read `Documentation/DEVELOPMENT_HANDBOOK.md` thoroughly
2. Review code examples in `examples/` directory
3. Try modifying the code to understand it better
4. Ask questions - don't hesitate to reach out!
5. Start working on small tasks to build confidence

---

**Welcome to the team!** 🎉

If you have questions or need help, don't hesitate to ask. The team is here to support you.

