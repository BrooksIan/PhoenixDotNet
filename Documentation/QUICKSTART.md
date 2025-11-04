# Quick Start Guide

## Prerequisites Checklist

- [ ] Docker and Docker Compose installed
- [ ] (Optional) .NET 8.0 SDK installed (only if running locally)
- [ ] (Optional) Apache Phoenix ODBC Driver installed (only if running locally)

## Deployment Options

### Option 1: Container Deployment (Recommended - Easiest)

Deploy both Phoenix and the application in containers:

```bash
# Build and start all services
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d

# View logs
docker-compose logs -f phoenix-app

# Stop services
docker-compose down
```

That's it! The application will connect to Phoenix automatically using Docker networking.

See [DOCKER.md](./DOCKER.md) for more details.

### Option 2: Local Development

## Step-by-Step Setup (Local Development)

### 1. Start Phoenix Services

```bash
# Start OPDB Docker container (includes Phoenix Query Server)
docker-compose up -d

# Verify it's running
docker ps

# Check logs if needed
docker-compose logs -f opdb-docker
```

### 2. Wait for Phoenix to be Ready

Phoenix Query Server typically takes 30-60 seconds to start. Wait until you see:
- Port 8765 is listening
- No errors in docker logs

You can test connectivity:
```bash
# On macOS/Linux
nc -zv localhost 8765

# Or check if port is listening
lsof -i :8765
```

### 3. Configure Connection String

Edit `appsettings.json`:

```json
{
  "Phoenix": {
    "Server": "localhost",
    "Port": "8765",
    "ConnectionString": "Driver={Phoenix};Server=localhost;Port=8765"
  }
}
```

**Important:** The exact driver name depends on your ODBC driver installation:
- If using a vendor-specific driver, update the Driver name
- If using a JDBC-ODBC bridge, the connection string format may differ
- Some systems require a DSN setup instead

### 4. Install ODBC Driver (Platform-Specific)

#### macOS
```bash
# Option 1: Use a Phoenix ODBC driver if available
# Option 2: Use a JDBC-ODBC bridge
# Option 3: Use unixODBC with a Phoenix driver

# Install unixODBC (via Homebrew)
brew install unixodbc

# Configure driver in /etc/odbcinst.ini
```

#### Linux
```bash
# Install unixODBC
sudo apt-get install unixodbc unixodbc-dev  # Ubuntu/Debian
sudo yum install unixODBC unixODBC-devel    # RHEL/CentOS

# Configure driver in /etc/odbcinst.ini
```

#### Windows
1. Download and install Phoenix ODBC Driver
2. Register driver in ODBC Data Source Administrator
3. Update connection string with driver name

### 5. Build and Run

```bash
# Restore NuGet packages
dotnet restore

# Build the project
dotnet build

# Run the application
dotnet run
```

## Expected Output

If everything is configured correctly, you should see:

```
=== Apache Phoenix .NET ODBC Example ===

Connected to Apache Phoenix Query Server

Example 1: Listing all tables in the database
-------------------------------------------
| TABLE_NAME      |
|-----------------|
| SYSTEM.CATALOG  |
| SYSTEM.SEQUENCE |
...

Example 2: Creating a sample table
-----------------------------------
Table 'users' created successfully (or already exists)

Example 3: Inserting sample data
--------------------------------
Sample data inserted successfully

Example 4: Querying data from users table
----------------------------------------
| ID | USERNAME  | EMAIL            | CREATED_DATE |
|----|-----------|------------------|--------------|
| 1  | john_doe  | john@example.com | 2024-01-01   |

Total rows: 1
...
```

## Troubleshooting

### Connection Errors

**"Driver not found"**
- Verify ODBC driver is installed: `odbcinst -q -d` (Unix) or check ODBC Data Sources (Windows)
- Update driver name in appsettings.json to match installed driver

**"Cannot connect to server"**
- Verify Phoenix is running: `docker ps`
- Check port 8765: `telnet localhost 8765` or `nc -zv localhost 8765`
- View container logs: `docker-compose logs opdb-docker`

**"Table not found"**
- Phoenix table names are case-sensitive
- Try uppercase: `SELECT * FROM USERS`
- Check if table exists: `SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = 'u'`

### Alternative: Using JDBC-ODBC Bridge

If direct ODBC connection doesn't work, you can use a JDBC-ODBC bridge:

1. Install a JDBC-ODBC bridge driver
2. Update connection string to use the bridge driver
3. Configure JDBC connection parameters

## Next Steps

- Explore Phoenix SQL syntax: https://phoenix.apache.org/language/
- Try more complex queries
- Create additional tables and relationships
- Implement data access layer patterns
- Deploy to production using Docker containers (see [DOCKER.md](./DOCKER.md))

## Getting Help

- Check Apache Phoenix documentation: https://phoenix.apache.org/
- Review Phoenix Query Server guide: https://phoenix.apache.org/server.html
- Check docker logs: `docker-compose logs`
