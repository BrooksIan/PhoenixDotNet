# ODBC Connector Installation Guide

## Overview

The ODBC connector has been configured to automatically install during Docker image build. The Hortonworks Phoenix ODBC driver (version 1.0.8.1011) will be extracted from the RPM file and installed in the container.

## What Was Configured

### Files Created/Updated

1. **`Dockerfile`** - Updated to:
   - Install `rpm2cpio` and `cpio` tools for RPM extraction
   - Extract and install Phoenix ODBC driver from RPM
   - Copy `odbcinst.ini` configuration file

2. **`odbcinst.ini`** - ODBC driver configuration file
   - Registers the Phoenix ODBC driver
   - Points to `/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc_sb64.so`

3. **`install_odbc.sh`** - Installation script
   - Extracts RPM file
   - Finds and copies driver library files
   - Copies configuration files (DSMessages.xml, PhoenixODBC.did, etc.)
   - Sets correct permissions

4. **`verify_odbc.sh`** - Verification script
   - Checks if ODBC driver is installed
   - Verifies configuration
   - Tests connection

## Installation Steps

### Step 1: Build Docker Image

The ODBC driver will be automatically installed when you build the Docker image:

```bash
docker-compose build phoenix-app
```

Or build everything:

```bash
docker-compose build
```

### Step 2: Start Services

```bash
docker-compose up -d
```

### Step 3: Verify ODBC Installation

Run the verification script:

```bash
./verify_odbc.sh
```

Or manually check:

```bash
# Check if driver is registered
docker exec phoenix-dotnet-app odbcinst -q -d

# Check if driver library exists
docker exec phoenix-dotnet-app ls -lh /usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc_sb64.so

# Check if configuration files are installed
docker exec phoenix-dotnet-app ls -la /usr/lib/x86_64-linux-gnu/odbc/en-US/

# Check configuration
docker exec phoenix-dotnet-app cat /etc/odbcinst.ini
```

### Step 4: Test Connection

```bash
# Test health endpoint
curl http://localhost:8099/api/phoenix/health

# Test a query
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT TABLE_NAME FROM SYSTEM.CATALOG LIMIT 5"}'
```

## Configuration

### Connection String

The connection string is already configured in `docker-compose.yml`:

```yaml
environment:
  - Phoenix__ConnectionString=Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

### Driver Name

The driver name `Phoenix ODBC Driver` must match the name in `/etc/odbcinst.ini` (which it does).

## How It Works

1. **Build Time**: During Docker image build:
   - Container is built for x86_64 platform (required for ODBC driver compatibility)
   - RPM file is copied to container
   - `install_odbc.sh` extracts the RPM
   - Driver library files are copied to `/usr/lib/x86_64-linux-gnu/odbc/`
   - Configuration files (DSMessages.xml, PhoenixODBC.did, etc.) are copied to `/usr/lib/x86_64-linux-gnu/odbc/en-US/`
   - `odbcinst.ini` is copied to `/etc/`

2. **Runtime**: When container starts:
   - Application tries to connect via ODBC first
   - If ODBC fails, automatically falls back to REST API
   - Connection method is logged in application logs

## Troubleshooting

### Driver Not Found

If you see "Can't open lib 'Phoenix ODBC Driver' : file not found":

1. Check if driver library exists:
   ```bash
   docker exec phoenix-dotnet-app ls -la /usr/lib/x86_64-linux-gnu/odbc/
   ```

2. Check if driver is registered:
   ```bash
   docker exec phoenix-dotnet-app odbcinst -q -d
   ```

3. Check `odbcinst.ini`:
   ```bash
   docker exec phoenix-dotnet-app cat /etc/odbcinst.ini
   ```

4. Rebuild the image:
   ```bash
   docker-compose build --no-cache phoenix-app
   ```

### Manual Installation

If automatic installation fails, you can manually install:

```bash
# Copy RPM into container
docker cp ODBC/1.0.8.1011/Linux/HortonworksPhoenix-64bit-1.0.8.1011-1.rpm phoenix-dotnet-app:/tmp/phoenix-odbc.rpm

# Copy installation script
docker cp install_odbc.sh phoenix-dotnet-app:/tmp/install_odbc.sh

# Run installation
docker exec phoenix-dotnet-app bash /tmp/install_odbc.sh
```

### Check Application Logs

```bash
# Check which connection method is being used
docker logs phoenix-dotnet-app | grep -i "odbc\|rest\|connection"

# Should show:
# - "ODBC connection initialized" if ODBC is working
# - "REST API connection initialized" if using fallback
```

## Expected Behavior

### With ODBC Driver Installed (Current Status: ✅ Working)

- ✅ Application uses ODBC connection (more reliable)
- ✅ All queries work correctly (including SELECT queries)
- ✅ No REST API bugs
- ✅ Better performance
- ✅ Successfully tested and verified

### Without ODBC Driver (Fallback)

- ⚠️ Application automatically uses REST API
- ⚠️ May have empty results due to Phoenix Query Server 6.0.0 bug
- ✅ Application still runs and attempts queries

## Files

- `ODBC/1.0.8.1011/Linux/HortonworksPhoenix-64bit-1.0.8.1011-1.rpm` - ODBC driver RPM file
- `odbcinst.ini` - ODBC driver configuration
- `install_odbc.sh` - Installation script
- `verify_odbc.sh` - Verification script
- `Dockerfile` - Updated with ODBC installation steps

## Next Steps

1. **Build the image**: `docker-compose build phoenix-app`
2. **Start services**: `docker-compose up -d`
3. **Verify installation**: `./verify_odbc.sh`
4. **Test queries**: Use the API endpoints to verify ODBC is working

For more details, see:
- [ODBC_IMPLEMENTATION.md](./ODBC_IMPLEMENTATION.md) - Implementation details
- [PHOENIX_ODBC_SETUP.md](./PHOENIX_ODBC_SETUP.md) - Setup guide
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Troubleshooting guide

