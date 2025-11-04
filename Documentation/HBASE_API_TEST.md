# HBase API Testing Guide

## Overview

The HBase API integration has been added to the PhoenixDotNet application. This document provides instructions for testing the HBase REST API endpoints.

## Prerequisites

1. **Application Restart Required**: After adding the HBase API endpoints, restart the application to load the new routes:
   ```bash
   # If running via Docker Compose
   docker-compose restart phoenix-app
   
   # If running locally
   # Stop the current process (Ctrl+C) and restart:
   dotnet run
   ```

2. **HBase REST API**: Ensure HBase REST API (Stargate) is running and accessible on port 8080 (or configured port).

## Endpoints

### 1. Create Sensor Table
**Endpoint**: `POST /api/phoenix/hbase/tables/sensor`

**Request Body** (optional):
```json
{
  "tableName": "SENSOR_INFO",
  "namespace": "default"
}
```

**Example**:
```bash
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{"tableName": "SENSOR_INFO", "namespace": "default"}'
```

**Success Response** (200):
```json
{
  "message": "Sensor table 'default:SENSOR_INFO' created successfully",
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "columnFamilies": ["metadata", "readings", "status"]
}
```

**Conflict Response** (409 - Table already exists):
```json
{
  "message": "Sensor table 'default:SENSOR_INFO' already exists",
  "tableName": "SENSOR_INFO",
  "namespace": "default"
}
```

### 2. Check if Table Exists
**Endpoint**: `GET /api/phoenix/hbase/tables/{tableName}/exists?namespace={namespace}`

**Example**:
```bash
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/exists?namespace=default
```

**Response** (200):
```json
{
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "exists": true
}
```

### 3. Get Table Schema
**Endpoint**: `GET /api/phoenix/hbase/tables/{tableName}/schema?namespace={namespace}`

**Example**:
```bash
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/schema?namespace=default
```

**Response** (200):
```json
{
  "tableName": "SENSOR_INFO",
  "namespace": "default",
  "schema": "{...HBase schema JSON...}"
}
```

## Sensor Table Schema

The sensor table is created with three column families:

1. **metadata**: Sensor metadata
   - type (e.g., temperature, humidity, pressure)
   - location (e.g., room1, building-a)
   - manufacturer
   - model
   - installation_date

2. **readings**: Sensor readings (timestamped measurements)
   - Timestamp-based columns for measurements
   - Values stored as strings or numbers

3. **status**: Sensor status information
   - active (boolean)
   - last_seen (timestamp)
   - battery_level (for battery-powered sensors)
   - error_count

## Testing Steps

### Step 1: Restart the Application

```bash
# If using Docker Compose
docker-compose restart phoenix-app

# Or rebuild and restart
docker-compose up --build -d phoenix-app
```

### Step 2: Verify Health Endpoint

```bash
curl http://localhost:8099/api/phoenix/health
```

Expected: `{"status":"healthy","timestamp":"..."}`

### Step 3: Test Create Sensor Table

```bash
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{"tableName": "SENSOR_INFO", "namespace": "default"}'
```

### Step 4: Check if Table Exists

```bash
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/exists?namespace=default
```

### Step 5: Get Table Schema

```bash
curl http://localhost:8099/api/phoenix/hbase/tables/SENSOR_INFO/schema?namespace=default
```

## Using the Test Script

A test script is provided: `test_hbase_api.sh`

```bash
# Make it executable
chmod +x test_hbase_api.sh

# Run the tests
./test_hbase_api.sh
```

## Troubleshooting

### Issue: Endpoints return HTML instead of JSON

**Solution**: The application needs to be restarted to load the new routes.

```bash
docker-compose restart phoenix-app
```

### Issue: HTTP 405 Method Not Allowed

**Solution**: Check that the HTTP method matches the endpoint:
- POST for creating tables
- GET for checking existence and getting schema

### Issue: Connection to HBase REST API fails

**Possible Causes**:
1. HBase REST API (Stargate) is not running
2. Wrong port configuration in `appsettings.json`
3. Network connectivity issues

**Check**:
```bash
# Verify HBase REST API is accessible
curl http://localhost:8080

# Check docker-compose logs
docker-compose logs opdb-docker | grep -i hbase
```

### Issue: Table creation fails with HTTP 500

**Possible Causes**:
1. HBase REST API endpoint format mismatch
2. HBase REST API version compatibility
3. Authentication/authorization issues

**Solution**: Check the HBase REST API documentation for your version and adjust the endpoint format in `HBaseRestClient.cs` if needed.

## Configuration

HBase configuration is in `appsettings.json`:

```json
{
  "HBase": {
    "Server": "localhost",
    "Port": "8080"
  }
}
```

For Docker Compose, use `opdb-docker` instead of `localhost`:

```json
{
  "HBase": {
    "Server": "opdb-docker",
    "Port": "8080"
  }
}
```

## Important Notes

### Phoenix Encoding Format

**⚠️ Important:** If you're inserting data into Phoenix tables (tables created via Phoenix SQL), you should use Phoenix SQL (UPSERT) instead of HBase REST API. Phoenix uses a sophisticated binary encoding scheme that requires:

- Binary-encoded row keys (e.g., INTEGER `1` → `\x80\x00\x00\x01`)
- Binary-encoded column qualifiers (e.g., `USERNAME` → `\x80\x0B`)
- Binary-encoded values based on data types

Direct HBase REST API inserts create readable text format, which doesn't match Phoenix's binary encoding and won't be visible in Phoenix queries.

**For Phoenix Tables:**
- ✅ Use Phoenix SQL (UPSERT) via `/api/phoenix/execute`
- ❌ Avoid direct HBase REST API insertion

**For HBase-Native Tables:**
- ✅ Use HBase REST API for data insertion
- ✅ Create Phoenix views to query via SQL

For more details, see [README_TABLES.md](./README_TABLES.md#direct-hbase-insertion-with-phoenix-encoding).

### HBase REST API Format

- The HBase REST API endpoint format may vary depending on HBase version and whether Stargate is used
- If you encounter issues, check the HBase REST API documentation for your specific version
- The current implementation uses the Stargate REST API format (`/{namespace}:{table}/schema`)
- For different HBase REST API implementations, you may need to adjust the endpoint paths in `HBaseRestClient.cs`

