# Troubleshooting Guide

This guide helps you resolve common issues when connecting to Apache Phoenix from .NET applications.

> **📖 If you're setting up for the first time, see [QUICKSTART.md](./QUICKSTART.md) for step-by-step instructions.**

## Quick Reference

For detailed troubleshooting information, see the sections below. Common issues include:
- Connection errors
- Docker container issues
- Protocol errors
- Table not found errors
- ODBC driver issues

---

## Common Issues

### 1. "Response status code does not indicate success: 500 (Server Error)"

**Cause**: Phoenix Query Server may not be fully initialized or there's a protocol mismatch

**Solution**: 
- Wait 60-90 seconds for HBase/Phoenix to fully initialize after container start
- Check logs: `docker logs opdb-docker` and `docker logs phoenix-dotnet-app`
- Verify Phoenix Query Server is running: `docker ps | grep opdb-docker`

### 2. "InvalidProtocolBufferException" or "InvalidWireTypeException"

**Cause**: Phoenix Query Server 6.0.0 uses Protobuf as default transport. JSON endpoint may not be properly configured

**Solution**:
- Wait longer for initialization (application now waits 30+ seconds automatically)
- Check if `hbase-site.xml` is properly mounted with JSON serialization enabled
- Verify Phoenix Query Server version supports JSON protocol
- See configuration in `docker-compose.yml` for `hbase-site.xml` mounting

### 3. "Cannot connect to server"

**Solution**:
- Verify Phoenix Query Server is running: `docker ps`
- Check port 8765 is accessible: `docker exec opdb-docker curl http://localhost:8765`
- Verify the server address in `appsettings.json` matches Docker network hostname
- Check network connectivity: `docker network inspect phoenixdotnet_obdb-net`

### 4. "Table not found"

**Solution**:
- Ensure tables exist in Phoenix
- Check table names are case-sensitive (try uppercase)
- Verify schema names if using schemas
- Use `GET /api/phoenix/tables` to list available tables

### 5. Connection Initialization Failures

**Solution**:
- The application automatically retries connections up to 10 times with 15-second delays
- Initial wait time: 30 seconds before first connection attempt
- Check logs for detailed error messages: `docker logs phoenix-dotnet-app`

---

## Docker Issues

### Container not starting

**Solution**:
- Check Docker is running: `docker ps`
- View logs: `docker-compose logs`
- Ensure ports 8099, 8100, 8765 are not already in use
- Check container health: `docker-compose ps`

### Port conflicts

**Solution**:
- Change port mappings in `docker-compose.yml` if needed
- Update `appsettings.json` to match new ports
- Default ports:
  - 8099: Phoenix .NET API
  - 8100: SQL Search GUI
  - 8765: Phoenix Query Server

### Slow initialization

**Solution**:
- HBase/Phoenix takes 60-90 seconds to fully initialize
- Application waits automatically, but you can check status:
  ```bash
  docker logs opdb-docker | grep -i "started\|ready"
  docker logs phoenix-dotnet-app | grep -i "connected\|initialized"
  ```

### hbase-site.xml configuration

**Solution**:
- The `hbase-site.xml` file is mounted into the container to enable JSON serialization
- Verify the file exists and is readable: `docker exec opdb-docker cat /opt/hbase/conf/hbase-site.xml`

---

## Additional Troubleshooting Resources

For more detailed troubleshooting information, see:
- Complete error resolution guide (below)
- Driver installation instructions
- Alternative connection methods (JDBC bridge, REST API)
- Debugging steps and verification checklist

---

## Error: "Can't open lib 'Phoenix' : file not found"

### Problem

You're seeing this error:
```
ERROR [01000] [unixODBC][Driver Manager]Can't open lib 'Phoenix' : file not found
```

This means the Phoenix ODBC driver library is not installed or not properly configured in your container.

### Solution 1: Install Phoenix ODBC Driver

The Phoenix ODBC driver must be installed separately. Follow these steps:

#### Step 1: Obtain Phoenix ODBC Driver

**Option A: Cloudera Phoenix ODBC Driver**
- Requires Cloudera Enterprise Support Subscription
- Download from: [Phoenix ODBC Connector for Cloudera Operational Database](https://docs.cloudera.com/cdp-private-cloud-base/7.3.1/phoenix-access-data/topics/phoenix-download-other-drivers.html)

**Option B: Hortonworks Phoenix ODBC Driver**
- Download from Hortonworks (if available)
- See: [Hortonworks Phoenix ODBC Guide](https://hortonworks.com/wp-content/uploads/2016/08/phoenix-ODBC-guide.pdf)

**Option C: Third-Party Drivers**
- Search for "avatica" and your programming language
- See: [Apache Calcite Avatica](https://calcite.apache.org/avatica/)

#### Step 2: Install Driver in Container

1. **Extract the driver package**:
   ```bash
   tar -xzf phoenix-odbc-driver.tar.gz
   ```

2. **Copy driver library to container**:
   ```bash
   # Copy .so file to driver directory
   cp phoenix-odbc/lib/*.so /usr/lib/x86_64-linux-gnu/odbc/
   # Copy configuration files (DSMessages.xml, PhoenixODBC.did, etc.)
   cp -r phoenix-odbc/ErrorMessages/en-US/* /usr/lib/x86_64-linux-gnu/odbc/en-US/
   cp phoenix-odbc/lib/*/*.did /usr/lib/x86_64-linux-gnu/odbc/
   ```

3. **Configure odbcinst.ini**:
   ```ini
   [Phoenix ODBC Driver]
   Description=Hortonworks Phoenix ODBC Driver
   Driver=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc_sb64.so
   Setup=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc_sb64.so
   FileUsage=1
   ```

4. **Set LD_LIBRARY_PATH** (already done in Dockerfile):
   ```bash
   export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu/odbc:${LD_LIBRARY_PATH}
   ```

5. **Verify driver installation**:
   ```bash
   odbcinst -q -d
   ```

#### Step 3: Update Dockerfile

Uncomment and update these lines in `Dockerfile`:

```dockerfile
# Copy Phoenix ODBC driver if available in drivers/ directory
COPY drivers/ /usr/lib/x86_64-linux-gnu/odbc/
COPY odbcinst.ini /etc/odbcinst.ini
```

#### Step 4: Update Connection String

Ensure your connection string uses the correct driver name:

```json
{
  "Phoenix": {
    "ConnectionString": "Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765"
  }
}
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

The driver name must match what's in `/etc/odbcinst.ini`.

### Solution 2: Use JDBC-ODBC Bridge (Alternative)

If you cannot obtain the Phoenix ODBC driver, you can use a JDBC-ODBC bridge:

1. **Install JDBC-ODBC Bridge**:
   ```bash
   apt-get install -y libodbc-java
   ```

2. **Configure ODBC to use JDBC bridge**:
   ```ini
   [JDBC-ODBC Bridge]
   Description=JDBC-ODBC Bridge
   Driver=/usr/lib/x86_64-linux-gnu/odbc/libjdbc-odbc.so
   ```

3. **Use Phoenix JDBC driver** through the bridge

### Solution 3: Use Phoenix Thin Client (Recommended for Development)

Instead of ODBC, you can use Phoenix's thin client directly:

1. **Install Phoenix Python client**:
   ```bash
   pip install phoenixdb
   ```

2. **Use Python script** to interact with Phoenix:
   ```python
   import phoenixdb
   conn = phoenixdb.connect('http://opdb-docker:8765', autocommit=True)
   cursor = conn.cursor()
   cursor.execute("SELECT * FROM testtable")
   ```

### Solution 4: Use REST API (Alternative)

Phoenix Query Server supports REST API:

```bash
curl -X POST http://opdb-docker:8765 \
  -H "Content-Type: application/json" \
  -d '{"statement":"SELECT * FROM testtable"}'
```

## Common Issues and Solutions

### Issue: Driver Not Found

**Error**: `Can't open lib 'Phoenix' : file not found`

**Solutions**:
1. Verify driver is installed: `odbcinst -q -d`
2. Check driver path in `/etc/odbcinst.ini`
3. Verify `LD_LIBRARY_PATH` includes driver directory
4. Check file permissions: `ls -la /usr/lib/x86_64-linux-gnu/odbc/`
5. Ensure driver name matches connection string

### Issue: Connection Failed

**Error**: `Cannot connect to server`

**Solutions**:
1. Verify Phoenix is running: `docker-compose ps opdb-docker`
2. Check port 8765 is accessible: `nc -zv opdb-docker 8765`
3. Verify network connectivity: `ping opdb-docker`
4. Check firewall rules
5. Verify connection string (server name, port)

### Issue: Wrong Driver Name

**Error**: `Driver not found` or `Can't open lib`

**Solutions**:
1. List installed drivers: `odbcinst -q -d`
2. Check `/etc/odbcinst.ini` for exact driver name
3. Update connection string to match driver name exactly
4. Common driver names:
   - `Phoenix ODBC Driver`
   - `Hortonworks Phoenix ODBC Driver`
   - `Phoenix`

### Issue: Permission Denied

**Error**: `Permission denied` or `Cannot open driver`

**Solutions**:
1. Check file permissions: `chmod 755 /usr/lib/x86_64-linux-gnu/odbc/*.so`
2. Verify ownership: `chown root:root /usr/lib/x86_64-linux-gnu/odbc/*.so`
3. Check `/etc/odbcinst.ini` permissions

### Issue: Library Dependencies Missing

**Error**: `libxxx.so: cannot open shared object file`

**Solutions**:
1. Install missing dependencies:
   ```bash
   apt-get install -y libssl-dev libcurl4-openssl-dev
   ```
2. Check library dependencies:
   ```bash
   ldd /usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
   ```

## Debugging Steps

### Step 1: Verify ODBC Installation

```bash
# Check unixODBC is installed
odbcinst --version

# List installed drivers
odbcinst -q -d

# List DSNs
odbcinst -q -s
```

### Step 2: Check Driver Configuration

```bash
# View odbcinst.ini
cat /etc/odbcinst.ini

# View odbc.ini (if using DSN)
cat /etc/odbc.ini
```

### Step 3: Test Connection

```bash
# Test with isql (if available)
isql -v "Driver={Phoenix ODBC Driver};Server=opdb-docker;Port=8765"

# Or test with odbcinst
odbcinst -j
```

### Step 4: Check Container Logs

```bash
# View application logs
docker-compose logs phoenix-app

# View Phoenix logs
docker-compose logs opdb-docker

# Follow logs
docker-compose logs -f phoenix-app
```

### Step 5: Check Environment Variables

```bash
# Check LD_LIBRARY_PATH
echo $LD_LIBRARY_PATH

# Check connection string
env | grep Phoenix
```

## Verification Checklist

Before running the application, verify:

- [ ] Phoenix ODBC driver is installed
- [ ] Driver is registered in `/etc/odbcinst.ini`
- [ ] `LD_LIBRARY_PATH` includes driver directory
- [ ] Driver name in connection string matches odbcinst.ini
- [ ] Phoenix Query Server is running on port 8765
- [ ] Network connectivity between containers
- [ ] File permissions on driver library
- [ ] All dependencies are installed

## Getting Help

If you're still experiencing issues:

1. **Check Documentation**:
   - [PHOENIX_ODBC_SETUP.md](./PHOENIX_ODBC_SETUP.md)
   - [README.md](../README.md) (root README)
   - [DOCKER.md](./DOCKER.md)

2. **Review Logs**:
   ```bash
   docker-compose logs phoenix-app
   docker-compose logs opdb-docker
   ```

3. **Test Manually**:
   ```bash
   docker-compose exec phoenix-app odbcinst -q -d
   docker-compose exec phoenix-app cat /etc/odbcinst.ini
   ```

4. **Contact Support**:
   - Cloudera Support (if using Cloudera driver)
   - Hortonworks Support (if using Hortonworks driver)
   - Apache Phoenix Community

## Common Phoenix Query Issues

### Issue: Empty Query Results

**Problem:** After inserting data, queries return empty results.

**Possible Causes:**
1. Phoenix Query Server connection issue
2. Transaction/commit timing - data needs time to be committed
3. Table structure mismatch
4. Query Server restart needed

**Solutions:**
1. **Wait longer after inserts** (5-10 seconds):
   ```bash
   # Insert data
   curl -X POST http://localhost:8099/api/phoenix/execute \
     -H "Content-Type: application/json" \
     -d '{"sql":"UPSERT INTO TABLE_NAME ..."}'
   
   # Wait 5-10 seconds
   sleep 10
   
   # Query
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql":"SELECT * FROM TABLE_NAME"}'
   ```

2. **Use uppercase table names** when querying:
   - Create: `CREATE TABLE users (...)` → Query: `SELECT * FROM USERS`

3. **Verify table structure matches**:
   ```bash
   curl http://localhost:8099/api/phoenix/tables/TABLE_NAME/columns
   ```

4. **Check HBase directly**:
   ```bash
   docker-compose exec opdb-docker /opt/hbase/bin/hbase shell <<< "scan 'TABLE_NAME'"
   ```

### Issue: Table Created But Not Appearing in List

**Problem:** Table created successfully but doesn't appear in `GET /api/phoenix/tables`.

**Important:** The table still exists and can be queried even if it doesn't appear in the list!

**Why This Happens:**
- Phoenix Query Server may not immediately update `SYSTEM.CATALOG` after table creation
- Catalog updates are asynchronous

**Solutions:**
1. **Query the table directly** (recommended):
   ```bash
   # Use UPPERCASE table name
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql":"SELECT * FROM TABLE_NAME"}'
   ```

2. **Query SYSTEM.CATALOG directly**:
   ```bash
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{
       "sql": "SELECT TABLE_NAME, TABLE_TYPE FROM SYSTEM.CATALOG WHERE (TABLE_TYPE = '\''u'\'' OR TABLE_TYPE = '\''v'\'') ORDER BY TABLE_NAME"
     }'
   ```

3. **Wait and query to register**:
   ```bash
   # Create table
   curl -X POST http://localhost:8099/api/phoenix/execute \
     -H "Content-Type: application/json" \
     -d '{"sql":"CREATE TABLE IF NOT EXISTS table_name (id VARCHAR PRIMARY KEY, name VARCHAR)"}'
   
   # Insert data
   curl -X POST http://localhost:8099/api/phoenix/execute \
     -H "Content-Type: application/json" \
     -d '{"sql":"UPSERT INTO TABLE_NAME (id, name) VALUES ('\''1'\'', '\''Test'\'')"}'
   
   # Query table (this helps register it)
   curl -X POST http://localhost:8099/api/phoenix/query \
     -H "Content-Type: application/json" \
     -d '{"sql":"SELECT * FROM TABLE_NAME LIMIT 1"}'
   
   # Wait a moment
   sleep 3
   
   # List tables
   curl http://localhost:8099/api/phoenix/tables
   ```

**Key Points:**
- Phoenix converts unquoted identifiers to UPPERCASE
- Always use UPPERCASE table names when querying: `TABLE_NAME` not `table_name`
- Don't rely on the list endpoint - query tables directly instead
- Tables exist and work even if they don't appear in the list

## Direct HBase Insertion Issues

### Issue: Data Inserted via HBase Shell Not Visible in Phoenix Queries

**Problem:** Data inserted directly into HBase using HBase shell or HBase REST API is not visible when querying through Phoenix SQL.

**Root Cause:**
Phoenix uses a sophisticated binary encoding scheme for storing data in HBase:
- **Row keys** are binary-encoded (e.g., INTEGER `1` → `\x80\x00\x00\x01`)
- **Column qualifiers** are binary-encoded (e.g., `USERNAME` → `\x80\x0B`)
- **Values** are encoded according to data types (DATE as binary timestamps, etc.)

Direct HBase inserts create readable text format, which doesn't match Phoenix's binary encoding.

**Solutions:**

1. **Use Phoenix SQL (UPSERT) - Recommended:**
   ```bash
   # Insert data using Phoenix SQL (handles encoding automatically)
   curl -X POST http://localhost:8099/api/phoenix/execute \
     -H "Content-Type: application/json" \
     -d '{
       "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (4, '\''david_wilson'\'', '\''david@example.com'\'', CURRENT_DATE())"
     }'
   ```
   ✅ **Benefits:**
   - Automatic binary encoding
   - Data immediately visible in Phoenix queries
   - Type safety and validation
   - Production-ready approach

2. **For HBase-Native Tables: Use Phoenix Views:**
   If you must insert data via HBase shell, create a Phoenix view to query it:
   ```bash
   # Create Phoenix view on HBase table
   curl -X POST http://localhost:8099/api/phoenix/views \
     -H "Content-Type: application/json" \
     -d '{
       "viewName": "my_view",
       "hBaseTableName": "my_hbase_table",
       "namespace": "default",
       "columns": [
         { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
         { "name": "column1", "type": "VARCHAR", "isPrimaryKey": false }
       ]
     }'
   ```
   See [README_VIEWS.md](./README_VIEWS.md) for details.

**Why Direct Insertion is Complex:**

To insert data directly into HBase matching Phoenix's encoding format, you would need:
- A Java program using HBase's Java API to insert binary data
- Access to Phoenix's internal encoding utilities
- Proper binary byte manipulation

**Note:** HBase shell treats escape sequences like `\x80` as literal strings, not binary bytes, making direct insertion via shell commands ineffective for matching Phoenix's encoding.

**For Production:**
- ✅ **Always use Phoenix SQL (UPSERT)** for Phoenix tables
- ✅ **Use Phoenix views** for HBase-native tables created via HBase shell
- ❌ **Avoid direct HBase insertion** into Phoenix tables unless you have a Java program with Phoenix encoding utilities

For more details, see [README_TABLES.md](./README_TABLES.md#direct-hbase-insertion-with-phoenix-encoding).

## Phoenix Query Server Version Issues

### Issue: Phoenix Query Server 6.0.0 JSON Endpoint Bug

**Problem:** Phoenix Query Server 6.0.0 (included in Cloudera OPDB Docker `latest`) has a bug with the JSON endpoint that prevents SELECT queries from working via REST API.

**Symptoms:**
- SELECT queries return empty results
- `prepareAndExecute` returns `missingStatement: true` for SELECT queries
- Separate `prepare` + `execute` returns `NullPointerException`

### Solutions

#### Solution 1: Use ODBC Instead (Recommended - ✅ Currently Working)

Since the REST API has issues, use ODBC directly which is more reliable:

1. **ODBC driver is automatically installed** during Docker build (see [ODBC_INSTALLATION.md](./ODBC_INSTALLATION.md))
2. **Connection string uses `Host=` instead of `Server=`** (Hortonworks driver requirement)
3. **Container must be x86_64 platform** (linux/amd64) for ODBC driver compatibility
4. The application already has `PhoenixConnection.cs` for ODBC support

**Pros:**
- ✅ More reliable than REST API
- ✅ Avoids Phoenix Query Server bugs entirely
- ✅ Direct connection to Phoenix
- ✅ All queries work correctly (including SELECT)
- ✅ Successfully tested and verified

**Cons:**
- Requires x86_64 container platform
- ODBC driver installation (automated in Docker build)

#### Solution 2: Manual JAR Replacement

Replace Phoenix Query Server JAR with an older version that doesn't have the bug:

1. **Download Phoenix 5.1.3** (or another version) full distribution
2. **Extract Query Server JAR** from the distribution
3. **Copy JAR into container**:
   ```bash
   docker cp phoenix-queryserver-5.1.3.jar opdb-docker:/opt/phoenix/
   ```
4. **Replace in container**:
   ```bash
   docker exec -it opdb-docker bash
   cd /opt/phoenix
   cp phoenix-queryserver-6.0.0.jar phoenix-queryserver-6.0.0.jar.backup
   rm phoenix-queryserver-6.0.0.jar
   ln -s phoenix-queryserver-5.1.3.jar phoenix-queryserver.jar
   exit
   ```
5. **Restart container**:
   ```bash
   docker restart opdb-docker
   sleep 60  # Wait for Query Server to start
   ```

**Recommended Approach:** Use Solution 1 (ODBC) because it's the most reliable and avoids Query Server bugs entirely.

## Resources

- [Hortonworks Phoenix ODBC Guide](https://hortonworks.com/wp-content/uploads/2016/08/phoenix-ODBC-guide.pdf)
- [Cloudera Phoenix ODBC Documentation](https://docs.cloudera.com/cdp-private-cloud-base/7.3.1/phoenix-access-data/topics/phoenix-download-other-drivers.html)
- [Apache Phoenix Documentation](https://phoenix.apache.org/)
- [unixODBC Documentation](http://www.unixodbc.org/)

