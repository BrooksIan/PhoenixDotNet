# ODBC Implementation Guide

## Overview

The application has been updated to use **ODBC as the primary connection method** with **REST API as a fallback**. This provides better reliability than the REST API alone, especially given Phoenix Query Server 6.0.0's JSON endpoint bugs.

## How It Works

1. **On startup**: Application tries to connect via ODBC first
2. **If ODBC fails**: Automatically falls back to REST API
3. **On each request**: Uses the available connection method (ODBC if available, REST if not)

## Current Status

**✅ ODBC is now working and tested!** The ODBC driver is automatically installed during Docker build and configured correctly.

### If ODBC Driver is Available

- ✅ ODBC connection will be used (more reliable)
- ✅ All queries will work correctly
- ✅ No REST API bugs

### If ODBC Driver is NOT Available

- ⚠️ Application automatically falls back to REST API
- ⚠️ May still have empty results due to Phoenix Query Server 6.0.0 bug
- ✅ Application will still run and attempt to use REST API

## Installing Phoenix ODBC Driver

### Option 1: Simba Phoenix ODBC Driver (Commercial)

1. Download Simba Phoenix ODBC Driver
2. Install in Docker container or on host system
3. Configure `/etc/odbcinst.ini`:
   ```ini
   [Phoenix ODBC Driver]
   Description=Simba Phoenix ODBC Driver
   Driver=/path/to/libphoenixodbc.so
   Setup=/path/to/libphoenixodbc.so
   FileUsage=1
   ```
4. Update connection string in `appsettings.json`:
   ```json
   {
     "Phoenix": {
       "ConnectionString": "Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765"
     }
   }
   ```

### Option 2: Use Generic ODBC-to-JDBC Bridge

If you have a JDBC-to-ODBC bridge available, you can use it with Phoenix JDBC driver:

1. Install JDBC-to-ODBC bridge (e.g., Easysoft JDBC-ODBC Bridge)
2. Configure to use Phoenix JDBC driver
3. Update connection string accordingly

### Option 3: Use Phoenix JDBC Directly (Alternative)

Instead of ODBC, use Phoenix JDBC directly from .NET:

1. Add Phoenix JDBC driver to project
2. Use a JDBC wrapper for .NET (e.g., JDBC.NET)
3. Connect directly to Phoenix via JDBC

## Configuration

### Connection String Format

```json
{
  "Phoenix": {
    "ConnectionString": "Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765"
  }
}
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

### Environment Variables

In Docker Compose, the connection string is set via environment variable:

```yaml
environment:
  - Phoenix__ConnectionString=Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

## Testing

### Test ODBC Connection

```bash
# Check if ODBC driver is installed
docker exec phoenix-dotnet-app odbcinst -q -d

# Should show "Phoenix ODBC Driver" if installed
```

### Test Application

```bash
# Test query endpoint
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT TABLE_NAME FROM SYSTEM.CATALOG LIMIT 5"}'

# Should return results if ODBC is working
```

### Check Logs

```bash
# Check application logs for connection method used
docker logs phoenix-dotnet-app | grep -i "odbc\|rest\|connection"

# Should show "ODBC connection initialized" if ODBC is working
# Or "REST API connection initialized" if using fallback
```

## Troubleshooting

### ODBC Driver Not Found

**Error**: `Can't open lib 'Phoenix ODBC Driver' : file not found`

**Solution**:
1. Install Phoenix ODBC driver
2. Configure `/etc/odbcinst.ini` in container
3. Ensure driver path is correct
4. Check `LD_LIBRARY_PATH` includes driver directory

### Connection Fails

**Error**: `Failed to establish Phoenix ODBC connection`

**Solution**:
1. Verify Phoenix Query Server is running on port 8765
2. Check network connectivity: `docker network inspect obdb-net`
3. Verify connection string format is correct
4. Check ODBC driver is compatible with Phoenix Query Server

### Automatic Fallback

If ODBC fails, the application will automatically try REST API. Check logs to see which method is being used:

```bash
docker logs phoenix-dotnet-app | grep -i "connection\|odbc\|rest"
```

## Next Steps

1. **Install Phoenix ODBC Driver** (if available)
2. **Configure ODBC** (`odbcinst.ini` file)
3. **Test connection** using the application
4. **Verify queries work** correctly

## Benefits of ODBC

- ✅ More reliable than REST API
- ✅ Avoids Phoenix Query Server 6.0.0 JSON endpoint bugs
- ✅ Direct connection to Query Server
- ✅ Better performance in some cases
- ✅ Automatic fallback to REST if ODBC unavailable

