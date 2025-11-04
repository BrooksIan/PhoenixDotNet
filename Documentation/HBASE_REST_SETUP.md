# HBase REST API Setup Guide

## Overview

HBase REST API (Stargate) and Thrift services can be enabled to provide REST API access to HBase. This guide shows how to enable and use these services.

## Enable HBase Services

### Start HBase Thrift

```bash
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start thrift
```

### Start HBase REST (Stargate)

```bash
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start rest
```

### Verify Services are Running

```bash
docker exec opdb-docker ps aux | grep -E 'thrift|rest'
```

Expected output should show:
- `ThriftServer` process
- `RESTServer` process

## Service Ports

- **HBase REST API**: Port 8080 (inside container)
- **HBase Thrift**: Port 9090, 9095 (inside container)

## Network Configuration

The HBase REST API runs on port 8080 **inside the container**. To access it from the phoenix-app container:

1. **Use Docker network hostname**: `opdb-docker:8080` (not `localhost:8080`)
2. **Update appsettings.Production.json**:
   ```json
   {
     "HBase": {
       "Server": "opdb-docker",
       "Port": "8080"
     }
   }
   ```

## Testing HBase REST API

### From Inside opdb-docker Container

```bash
# Get version
docker exec opdb-docker curl -s http://localhost:8080/version

# Check table schema
docker exec opdb-docker curl -s http://localhost:8080/default/table_name/schema
```

### From phoenix-app Container

```bash
# Test connection
docker exec phoenix-dotnet-app curl -s http://opdb-docker:8080/version

# Use API endpoint
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{"tableName":"test_table","namespace":"default"}'
```

## Complete Workflow with HBase REST API

### Step 1: Enable Services

```bash
./examples/enable_hbase_services.sh
```

### Step 2: Create Table via REST API

```bash
curl -X POST http://localhost:8099/api/phoenix/hbase/tables/sensor \
  -H "Content-Type: application/json" \
  -d '{
    "tableName": "my_table",
    "namespace": "default"
  }'
```

### Step 3: Insert Data via REST API

```bash
curl -X PUT http://localhost:8099/api/phoenix/hbase/tables/my_table/data \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "1",
    "columnFamily": "metadata",
    "column": "name",
    "value": "Alice",
    "namespace": "default"
  }'
```

### Step 4: Query via Phoenix

```bash
curl -X POST http://localhost:8099/api/phoenix/query \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT rowkey, \"metadata\".\"name\" FROM \"my_table\" ORDER BY rowkey"
  }'
```

## Troubleshooting

### Issue: Connection Refused on localhost:8080

**Problem:** The application tries to connect to `localhost:8080` but HBase REST is in a different container.

**Solution:**
1. Ensure `appsettings.Production.json` uses `opdb-docker` as the server:
   ```json
   {
     "HBase": {
       "Server": "opdb-docker",
       "Port": "8080"
     }
   }
   ```
2. Restart the phoenix-app container:
   ```bash
   docker-compose restart phoenix-app
   ```

### Issue: Service Not Starting

**Error:** "rest running as process X. Stop it first."

**Solution:**
```bash
# Stop existing service
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh stop rest

# Start again
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start rest
```

### Issue: Service Starts but Not Accessible

**Solution:**
1. Check if service is listening:
   ```bash
   docker exec opdb-docker netstat -tlnp | grep 8080
   ```
2. Check logs:
   ```bash
   docker exec opdb-docker tail -50 /opt/hbase/logs/hbase--rest-opdb-docker.log
   ```

## Service Management

### Start Services
```bash
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start thrift
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start rest
```

### Stop Services
```bash
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh stop thrift
docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh stop rest
```

### Check Status
```bash
docker exec opdb-docker ps aux | grep -E 'thrift|rest'
```

## Recommendation

For production use, consider:
1. **Adding services to docker-compose.yml** so they start automatically
2. **Exposing ports** if needed for external access
3. **Using environment variables** for configuration

## Summary

✅ **HBase Thrift**: Enabled for Thrift API access  
✅ **HBase REST**: Enabled for REST API access  
✅ **Network**: Use `opdb-docker:8080` from phoenix-app container  
✅ **Configuration**: Update `appsettings.Production.json` to use `opdb-docker` hostname  

The HBase REST API is now available for creating tables and inserting data programmatically!

