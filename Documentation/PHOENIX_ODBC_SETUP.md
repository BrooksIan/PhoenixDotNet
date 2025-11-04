# Phoenix ODBC Driver Setup Guide

This guide provides instructions for installing and configuring the Phoenix ODBC driver based on the official documentation from Hortonworks and Cloudera.

## Documentation References

- **Hortonworks Phoenix ODBC Driver User Guide**: [phoenix-ODBC-guide.pdf](https://hortonworks.com/wp-content/uploads/2016/08/phoenix-ODBC-guide.pdf)
- **Cloudera Phoenix ODBC Driver**: [Cloudera Documentation](https://docs.cloudera.com/cdp-private-cloud-base/7.3.1/phoenix-access-data/topics/phoenix-download-other-drivers.html)

## Overview

Apache Phoenix provides an ODBC driver that allows applications to connect to Phoenix Query Server using the ODBC interface. The driver connects to Phoenix Query Server (PQS) which runs on port 8765 by default.

### Key Points from Documentation

1. **Driver Availability**:
   - Hortonworks Phoenix ODBC Driver (Hortonworks distribution)
   - Cloudera Phoenix ODBC Driver (Cloudera distribution)
   - Both drivers are similar in functionality
   - Cloudera requires Enterprise Support Subscription for download

2. **Connection Architecture**:
   - Applications connect to Phoenix Query Server (PQS) on port 8765
   - PQS uses Avatica API and Google Protocol Buffers
   - ODBC driver acts as a bridge between ODBC calls and Phoenix Query Server

3. **Linux Installation Requirements**:
   - Install unixODBC (already done in Dockerfile)
   - Install Phoenix ODBC driver library
   - Set `LD_LIBRARY_PATH` environment variable
   - Configure `/etc/odbcinst.ini` to register the driver
   - Configure `/etc/odbc.ini` for DSNs (optional - can use DSN-less connections)
   - Configure `hortonworks.phoenix.ini` for driver settings

## Linux Driver Installation Steps

### Step 1: Download Phoenix ODBC Driver

**Option A: Hortonworks Phoenix ODBC Driver**
- Download from Hortonworks website (if available)
- Look for Linux x64 driver package

**Option B: Cloudera Phoenix ODBC Driver**
- Requires Cloudera Enterprise Support Subscription
- Download from: [Phoenix ODBC Connector for Cloudera Operational Database](https://docs.cloudera.com/cdp-private-cloud-base/7.3.1/phoenix-access-data/topics/phoenix-download-other-drivers.html)

**Option C: Third-Party Drivers**
- Search for "avatica" and your programming language
- See: [Apache Calcite Avatica](https://calcite.apache.org/avatica/)

### Step 2: Install Driver in Container

The driver typically includes:
- `.so` library files (e.g., `libphoenixodbc_sb64.so`)
- Configuration files (DSMessages.xml, PhoenixODBC.did, etc.)
- Error message files (in ErrorMessages/en-US/ directory)
- Documentation

**Platform Requirement:** The container must be built for x86_64 platform (linux/amd64) to use the ODBC driver.

**Installation Process**:
1. Extract the driver package
2. Copy driver library to `/usr/lib/x86_64-linux-gnu/odbc/` or `/usr/local/lib/`
3. Set `LD_LIBRARY_PATH` to include driver library path
4. Register driver in `/etc/odbcinst.ini`
5. (Optional) Configure DSN in `/etc/odbc.ini`

### Step 3: Configure odbcinst.ini

Add the Phoenix ODBC driver to `/etc/odbcinst.ini`:

```ini
[Phoenix ODBC Driver]
Description=Hortonworks Phoenix ODBC Driver
Driver=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
Setup=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
FileUsage=1
```

**Driver Name Options** (depending on version):
- `Phoenix ODBC Driver`
- `Hortonworks Phoenix ODBC Driver`
- `Phoenix`

### Step 4: Configure Connection String

Based on the documentation, connection strings can be:

**DSN-less Connection**:
```
Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

**DSN Connection** (if configured in odbc.ini):
```
DSN=MyPhoenixDSN;UID=username;PWD=password
```

### Step 5: Configure hortonworks.phoenix.ini (Optional)

Create `/etc/hortonworks.phoenix.ini` for driver-specific settings:

```ini
[Driver]
Host=opdb-docker
Port=8765
```

**Note:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in configuration files.

## Dockerfile Integration

To include the Phoenix ODBC driver in your Docker image:

### Option 1: Manual Installation (Recommended for Development)

1. Download driver package manually
2. Place driver files in a `drivers/` directory in your project
3. Update Dockerfile to copy and install driver

### Option 2: Download During Build (Requires Download URL)

If you have a download URL, you can download during build:

```dockerfile
# Download and install Phoenix ODBC driver
RUN curl -L -o phoenix-odbc.tar.gz <DOWNLOAD_URL> && \
    tar -xzf phoenix-odbc.tar.gz && \
    cp phoenix-odbc/lib/*.so /usr/lib/x86_64-linux-gnu/odbc/ && \
    rm -rf phoenix-odbc phoenix-odbc.tar.gz
```

### Option 3: Use Multi-Stage Build with Driver

Copy driver from a base image that has it pre-installed.

## Configuration Files

### odbcinst.ini

```ini
[Phoenix ODBC Driver]
Description=Hortonworks Phoenix ODBC Driver
Driver=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
Setup=/usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
FileUsage=1
```

### odbc.ini (Optional - for DSN)

```ini
[MyPhoenixDSN]
Driver=Phoenix ODBC Driver
Description=Phoenix Connection
Server=opdb-docker
Port=8765
```

### Connection String in appsettings.json

```json
{
  "Phoenix": {
    "Server": "opdb-docker",
    "Port": "8765",
    "ConnectionString": "Driver={Phoenix ODBC Driver};Host=opdb-docker;Port=8765"
  }
}
```

**Important:** The Hortonworks Phoenix ODBC driver uses `Host=` instead of `Server=` in the connection string.

## Testing the Connection

### Using odbcinst

```bash
# List installed drivers
odbcinst -q -d

# List DSNs
odbcinst -q -s
```

### Using isql (if available)

```bash
isql -v "Driver={Phoenix ODBC Driver};Server=opdb-docker;Port=8765"
```

### Using .NET Application

The application will test the connection when it runs. Check logs for connection status.

## Troubleshooting

### Driver Not Found

**Error**: `Can't open lib 'Phoenix' : file not found`

**Solutions**:
1. Verify driver is installed: `odbcinst -q -d`
2. Check driver path in odbcinst.ini
3. Verify `LD_LIBRARY_PATH` includes driver directory
4. Check file permissions on driver library

### Connection Failed

**Error**: `Cannot connect to server`

**Solutions**:
1. Verify Phoenix Query Server is running: `docker-compose ps opdb-docker`
2. Check port 8765 is accessible: `nc -zv opdb-docker 8765`
3. Verify network connectivity between containers
4. Check firewall rules

### Authentication Issues

If Phoenix requires authentication:
- Add authentication parameters to connection string
- Configure authentication in hortonworks.phoenix.ini
- See driver documentation for authentication options

## Alternative: Using JDBC-ODBC Bridge

If Phoenix ODBC driver is not available, you can use a JDBC-ODBC bridge:

1. Install JDBC-ODBC bridge driver
2. Use Phoenix JDBC driver through the bridge
3. Configure connection string accordingly

## Resources

- [Hortonworks Phoenix ODBC Guide](https://hortonworks.com/wp-content/uploads/2016/08/phoenix-ODBC-guide.pdf)
- [Cloudera Phoenix ODBC Documentation](https://docs.cloudera.com/cdp-private-cloud-base/7.3.1/phoenix-access-data/topics/phoenix-download-other-drivers.html)
- [Apache Phoenix Documentation](https://phoenix.apache.org/)
- [Apache Calcite Avatica](https://calcite.apache.org/avatica/)

## Next Steps

1. Obtain Phoenix ODBC driver (download from Cloudera or Hortonworks)
2. Update Dockerfile to install driver
3. Configure odbcinst.ini with correct driver path
4. Update connection string with correct driver name
5. Test connection using odbcinst or application

