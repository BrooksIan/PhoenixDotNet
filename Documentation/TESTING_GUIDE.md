# Testing Guide

This guide provides comprehensive instructions for testing the PhoenixDotNet application and a glossary of all available test scripts.

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Test Scripts Glossary](#test-scripts-glossary)
- [Running Tests](#running-tests)
- [Understanding Test Results](#understanding-test-results)
- [Troubleshooting](#troubleshooting)
- [Environment Variables](#environment-variables)

## Quick Start

### Run All Tests

The fastest way to run all tests:

```bash
cd tests
./run_all_tests.sh
```

### Quick Verification

For a quick check that everything is working:

```bash
cd tests
./smoke_test.sh
```

### Troubleshoot Issues

If you encounter issues:

```bash
cd tests
./troubleshoot.sh
```

## Prerequisites

Before running tests, ensure:

1. **Application is Running**
   - The PhoenixDotNet application should be running on port 8099
   - Check: `curl http://localhost:8099/api/phoenix/health`

2. **Phoenix Query Server is Running**
   - Phoenix should be accessible on port 8765
   - Check: `nc -zv localhost 8765`

3. **Docker (if using containers)**
   - Docker containers should be running
   - Check: `docker-compose ps`

4. **Required Tools**
   - `curl` - for HTTP requests
   - `nc` (netcat) - for port checking
   - `jq` (optional) - for JSON parsing (recommended)
   - `bash` - all scripts are bash scripts

## Test Scripts Glossary

### Quick Tests

#### `smoke_test.sh`
**Purpose**: Quick verification that basic functionality is working

**What it tests**:
- Application health check
- Phoenix connection
- Query execution
- Execute command functionality

**When to use**:
- After deployment
- Quick system check
- Before running full test suite

**Example**:
```bash
./smoke_test.sh
```

**Expected output**:
- ✓ Application is responding
- ✓ Phoenix connection is working
- ✓ Query execution is working
- ✓ Execute command is working

**Exit code**: 0 if all pass, 1 if any fail

---

### Connectivity Tests

#### `test_connectivity.sh`
**Purpose**: Comprehensive connectivity testing

**What it tests**:
1. Application health check
2. Phoenix Query Server connectivity (port 8765)
3. Phoenix Query Server HTTP response
4. HBase REST API connectivity (port 8080)
5. HBase REST API HTTP response
6. Application API endpoints
7. Network ports (8099, 8100, 8765, 8080)
8. Docker containers status

**When to use**:
- Troubleshooting connection issues
- Verifying network configuration
- After network changes

**Example**:
```bash
./test_connectivity.sh
```

**Configuration**:
- `PHOENIX_SERVER` - Phoenix server host (default: localhost)
- `PHOENIX_PORT` - Phoenix server port (default: 8765)
- `HBASE_SERVER` - HBase server host (default: localhost)
- `HBASE_PORT` - HBase server port (default: 8080)

**Exit code**: 0 if all pass, 1 if any fail

---

#### `verify_phoenix_queryserver_ready.sh`
**Purpose**: Verify Phoenix Query Server readiness status

**What it checks**:
1. Container status (opdb-docker)
2. Port accessibility (8765)
3. HTTP endpoint response
4. JSON endpoint basic connectivity (openConnection test)
5. Error detection in responses
6. Phoenix Query Server process status
7. Recent logs analysis

**When to use**:
- Before running tests that require Phoenix Query Server
- Verifying Phoenix Query Server is fully initialized
- Troubleshooting Phoenix connection issues
- After starting or restarting Phoenix containers
- Checking if Phoenix is ready after configuration changes

**Example**:
```bash
./verify_phoenix_queryserver_ready.sh
```

**Configuration**:
- `PHOENIX_SERVER` - Phoenix server host (default: localhost)
- `PHOENIX_PORT` - Phoenix server port (default: 8765)

**Exit codes**:
- `0` - Phoenix Query Server is READY (all checks passed)
- `1` - Phoenix Query Server is NOT READY (issues found)
- `2` - Status is UNCLEAR (some checks passed but issues may exist)

**Expected output when ready**:
```
✓ Container is running
✓ Port 8765 is open and accessible
✓ HTTP endpoint responds
✓ JSON endpoint responds with HTTP 200
✓ OpenConnection request succeeded
✓ No error indicators in response
✓ Phoenix Query Server process is running
```

**Common causes of NOT READY status**:
- Container not started or crashed
- Port not accessible (firewall/network issue)
- Phoenix Query Server not fully initialized (wait 60-90 seconds)
- Configuration issue (JSON endpoint not enabled)
- Protocol mismatch (Protobuf vs JSON)

**Note**: Phoenix Query Server typically takes 60-90 seconds to fully initialize after container start. If checks fail immediately after starting, wait and retry.

---

### API Tests

#### `test_api_endpoints.sh`
**Purpose**: Comprehensive testing of all API endpoints

**What it tests**:
1. Health check endpoint
2. List tables endpoint
3. Get table columns endpoint
4. Execute query (valid query)
5. Execute query (invalid query - should fail gracefully)
6. Execute query (empty SQL - should return 400)
7. Execute non-query (create table)
8. Get columns for created table
9. Execute non-query (insert data)
10. Execute query (select from table)
11. Execute non-query (drop table)
12. HBase API - check table exists
13. HBase API - get table schema
14. HBase API - create sensor table
15. Error handling (invalid endpoint)
16. Error handling (missing body)

**When to use**:
- After API changes
- Validating API functionality
- Testing error handling
- Regression testing

**Example**:
```bash
./test_api_endpoints.sh
```

**Configuration**:
- `API_BASE_URL` - Base URL for API (default: http://localhost:8099)

**Exit code**: 0 if all pass, 1 if any fail

**Note**: Creates temporary test tables that are cleaned up automatically

---

#### `test_hbase_api.sh`
**Purpose**: Testing HBase REST API integration

**What it tests**:
1. Health check
2. Check if sensor table exists (before creation)
3. Create sensor table via HBase API
4. Check if sensor table exists (after creation)
5. Get table schema
6. Create sensor table with default values

**When to use**:
- Testing HBase REST API integration
- Verifying HBase table creation
- After HBase configuration changes

**Example**:
```bash
./test_hbase_api.sh
```

**Configuration**:
- `API_BASE_URL` - Base URL for API (default: http://localhost:8099)

**Exit code**: 0 if all pass, 1 if any fail

**Note**: Requires HBase REST API (Stargate) to be running on port 8080. Failures are expected if HBase REST API is not enabled.

---

### Database Tests

#### `test_database_operations.sh`
**Purpose**: Comprehensive database operations testing

**What it tests**:
1. Create table with multiple columns
2. Verify table creation
3. Get table columns
4. Insert data (UPSERT)
5. Select all records
6. Select with WHERE clause
7. Select with aggregation
8. Update data (UPSERT with same key)
9. Select with ORDER BY
10. Select with LIMIT
11. Data type validation
12. NULL handling
13. Delete data (via UPSERT with NULL)
14. Count records
15. Complex queries (CASE, GROUP BY)

**When to use**:
- Testing database functionality
- Validating data integrity
- Testing CRUD operations
- Regression testing after schema changes

**Example**:
```bash
./test_database_operations.sh
```

**Configuration**:
- `API_BASE_URL` - Base URL for API (default: http://localhost:8099)

**Exit code**: 0 if all pass, 1 if any fail

**Note**: 
- Creates temporary test tables that are automatically cleaned up
- Tests all CRUD operations
- Validates data types and NULL handling

---

### Debugging & Diagnostics

#### `diagnostic.sh`
**Purpose**: Gather comprehensive diagnostic information

**What it collects**:
1. System information (hostname, OS, uptime)
2. Environment variables (Phoenix, HBase, .NET, ASP.NET)
3. Docker information (version, containers, logs)
4. Network connectivity (ports, connections)
5. Application health
6. Phoenix connection status
7. HBase connection status
8. Configuration files (appsettings.json, etc.)
9. Disk space usage
10. Process information
11. Recent errors from logs
12. API endpoint test results

**When to use**:
- Before reporting bugs
- Gathering information for support
- System health check
- Troubleshooting complex issues
- After deployment verification

**Example**:
```bash
./diagnostic.sh
```

**Output**: Creates a timestamped diagnostic report file:
```
diagnostic_report_YYYYMMDD_HHMMSS.txt
```

**Configuration**:
- `API_BASE_URL` - Base URL for API (default: http://localhost:8099)
- `OUTPUT_FILE` - Output file name (default: diagnostic_report_*.txt)

**Exit code**: Always 0 (information gathering only)

---

#### `troubleshoot.sh`
**Purpose**: Automated troubleshooting for common issues

**What it checks**:
1. Application health check
2. Phoenix connectivity
3. Tables endpoint status
4. Configuration file existence and content
5. Port conflicts
6. Docker containers status
7. Recent errors in logs
8. Phoenix Query Server readiness

**When to use**:
- When experiencing issues
- Quick problem diagnosis
- Before deep debugging
- After deployment problems

**Example**:
```bash
./troubleshoot.sh
```

**Output**: 
- Lists issues found
- Provides solutions for each issue
- Summary of problems detected

**Exit code**: 0 if no issues, 1 if issues found

---

### Master Test Runner

#### `run_all_tests.sh`
**Purpose**: Run all test suites in sequence

**What it runs**:
1. Smoke test (quick verification)
2. Connectivity test
3. API endpoints test
4. Database operations test
5. HBase API test (if available)

**When to use**:
- Full test suite execution
- Before deployment
- Regression testing
- CI/CD pipelines

**Example**:
```bash
./run_all_tests.sh
```

**Output**: 
- Results from each test suite
- Summary of passed/failed test suites
- Recommendations for troubleshooting

**Exit code**: 0 if all pass, 1 if any fail

---

## Running Tests

### Basic Usage

All test scripts are executable and can be run directly:

```bash
cd tests
./script_name.sh
```

### Running Individual Tests

```bash
# Quick smoke test
./smoke_test.sh

# Connectivity test
./test_connectivity.sh

# Verify Phoenix Query Server readiness
./verify_phoenix_queryserver_ready.sh

# API endpoints test
./test_api_endpoints.sh

# Database operations test
./test_database_operations.sh

# HBase API test
./test_hbase_api.sh
```

### Running Diagnostic Tools

```bash
# Automated troubleshooting
./troubleshoot.sh

# Generate diagnostic report
./diagnostic.sh
```

### Running Full Test Suite

```bash
# Run all tests
./run_all_tests.sh
```

## Understanding Test Results

### Color Coding

- **Green (✓)**: Test passed
- **Red (✗)**: Test failed
- **Yellow (⚠)**: Warning or expected failure

### Exit Codes

- **0**: All tests passed
- **1**: One or more tests failed
- **2+**: Script error or unexpected issue

### Test Output Format

Each test script provides:
- Test name/description
- Status (pass/fail)
- HTTP status codes (for API tests)
- Response data (when relevant)
- Summary statistics

### Common Test Results

#### Success
```
✓ Application is responding
✓ Phoenix connection is working
✓ Query execution is working

Test Summary
Passed: 3
Failed: 0
```

#### Partial Failure
```
✓ Application is responding
✗ Phoenix connection failed (HTTP 500)
✓ Query execution is working

Test Summary
Passed: 2
Failed: 1
```

#### Expected Failures

Some failures are expected:
- **HBase REST API tests** - Fail if HBase REST API (Stargate) is not enabled
- **Invalid query tests** - Should fail gracefully (this is expected)

## Troubleshooting

### Common Issues

#### Issue: "Application is not responding"

**Solution**:
1. Check if application is running:
   ```bash
   curl http://localhost:8099/api/phoenix/health
   ```

2. Start the application:
   ```bash
   # If using Docker
   docker-compose up -d phoenix-app
   
   # If running locally
   dotnet run
   ```

#### Issue: "Phoenix connection failed"

**Solution**:
1. Verify Phoenix Query Server readiness:
   ```bash
   ./verify_phoenix_queryserver_ready.sh
   ```

2. Check if Phoenix is running:
   ```bash
   nc -zv localhost 8765
   ```

3. Start Phoenix:
   ```bash
   docker-compose up -d opdb-docker
   ```

4. Wait for initialization (60-90 seconds) and verify readiness:
   ```bash
   docker-compose logs -f opdb-docker
   # After waiting, verify readiness
   ./verify_phoenix_queryserver_ready.sh
   ```

#### Issue: "HBase REST API connection refused"

**Solution**:
- This is expected if HBase REST API (Stargate) is not enabled
- The application works with Phoenix; HBase REST API is optional
- If you need HBase REST API, enable Stargate in your HBase configuration

#### Issue: "Tests fail with JSON parsing errors"

**Solution**:
1. Install `jq` for better JSON handling:
   ```bash
   # macOS
   brew install jq
   
   # Linux
   sudo apt-get install jq
   ```

2. Or ensure SQL statements don't contain unescaped quotes

#### Issue: "Permission denied"

**Solution**:
```bash
chmod +x tests/*.sh
```

### Getting Help

1. **Run diagnostic script**:
   ```bash
   ./diagnostic.sh
   ```
   Review the generated report file

2. **Run troubleshooting script**:
   ```bash
   ./troubleshoot.sh
   ```
   Follow the suggested solutions

3. **Check application logs**:
   ```bash
   docker-compose logs phoenix-app
   ```

4. **Check Phoenix logs**:
   ```bash
   docker-compose logs opdb-docker
   ```

## Environment Variables

All test scripts support these environment variables:

### `API_BASE_URL`
Base URL for the API

**Default**: `http://localhost:8099`

**Example**:
```bash
API_BASE_URL=http://localhost:8099 ./smoke_test.sh
```

### `PHOENIX_SERVER`
Phoenix server hostname

**Default**: `localhost`

**Example**:
```bash
PHOENIX_SERVER=opdb-docker ./test_connectivity.sh
```

### `PHOENIX_PORT`
Phoenix server port

**Default**: `8765`

**Example**:
```bash
PHOENIX_PORT=8765 ./test_connectivity.sh
```

### `HBASE_SERVER`
HBase server hostname

**Default**: `localhost`

**Example**:
```bash
HBASE_SERVER=opdb-docker ./test_connectivity.sh
```

### `HBASE_PORT`
HBase server port

**Default**: `8080`

**Example**:
```bash
HBASE_PORT=8080 ./test_connectivity.sh
```

### `OUTPUT_FILE`
Output file for diagnostic script

**Default**: `diagnostic_report_YYYYMMDD_HHMMSS.txt`

**Example**:
```bash
OUTPUT_FILE=my_report.txt ./diagnostic.sh
```

## Test Workflow Recommendations

### Before Deployment

1. Verify Phoenix Query Server is ready:
   ```bash
   ./verify_phoenix_queryserver_ready.sh
   ```

2. Run full test suite:
   ```bash
   ./run_all_tests.sh
   ```

3. If any failures, run troubleshooting:
   ```bash
   ./troubleshoot.sh
   ```

4. Generate diagnostic report:
   ```bash
   ./diagnostic.sh
   ```

### After Deployment

1. Verify Phoenix Query Server is ready:
   ```bash
   ./verify_phoenix_queryserver_ready.sh
   ```

2. Quick smoke test:
   ```bash
   ./smoke_test.sh
   ```

3. If issues, run connectivity test:
   ```bash
   ./test_connectivity.sh
   ```

### During Development

1. Run relevant test after changes:
   ```bash
   # After API changes
   ./test_api_endpoints.sh
   
   # After database changes
   ./test_database_operations.sh
   ```

2. Run smoke test frequently:
   ```bash
   ./smoke_test.sh
   ```

### When Reporting Bugs

1. Generate diagnostic report:
   ```bash
   ./diagnostic.sh
   ```

2. Include the diagnostic report file in your bug report

3. Note which tests fail:
   ```bash
   ./run_all_tests.sh > test_results.txt
   ```

## Additional Resources

- **Main README**: `../README.md`
- **Tests README**: `README.md`
- **HBase API Test Guide**: `HBASE_API_TEST.md`
- **SQL Scripts**: See `README.md` for SQL test scripts

## Support

If you encounter issues not covered in this guide:

1. Check the diagnostic report
2. Review application logs
3. Run troubleshooting script
4. Check the main README for additional information

