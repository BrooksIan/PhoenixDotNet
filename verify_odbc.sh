#!/bin/bash
# Script to verify ODBC driver installation in Docker container

echo "=========================================="
echo "Verifying ODBC Driver Installation"
echo "=========================================="
echo ""

# Check if container is running
if ! docker ps | grep -q phoenix-dotnet-app; then
    echo "❌ Container phoenix-dotnet-app is not running"
    echo "   Start it with: docker-compose up -d phoenix-app"
    exit 1
fi

echo "✅ Container is running"
echo ""

# Check if ODBC driver is installed
echo "Checking ODBC driver installation..."
echo ""
ODBC_DRIVERS=$(docker exec phoenix-dotnet-app odbcinst -q -d 2>&1)
if echo "$ODBC_DRIVERS" | grep -qi "phoenix"; then
    echo "✅ Phoenix ODBC Driver is installed:"
    echo "$ODBC_DRIVERS" | grep -i phoenix
else
    echo "⚠️  Phoenix ODBC Driver not found in odbcinst -q -d"
    echo "   Output: $ODBC_DRIVERS"
fi
echo ""

# Check if driver library file exists
echo "Checking for driver library file..."
echo ""
if docker exec phoenix-dotnet-app test -f /usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so; then
    echo "✅ Driver library file exists:"
    docker exec phoenix-dotnet-app ls -lh /usr/lib/x86_64-linux-gnu/odbc/libphoenixodbc.so
else
    echo "⚠️  Driver library file not found at expected location"
    echo "   Checking for any .so files in ODBC directory:"
    docker exec phoenix-dotnet-app ls -la /usr/lib/x86_64-linux-gnu/odbc/ 2>&1 || echo "   Directory not found or empty"
fi
echo ""

# Check odbcinst.ini configuration
echo "Checking odbcinst.ini configuration..."
echo ""
if docker exec phoenix-dotnet-app test -f /etc/odbcinst.ini; then
    echo "✅ odbcinst.ini exists:"
    docker exec phoenix-dotnet-app cat /etc/odbcinst.ini
else
    echo "❌ odbcinst.ini not found"
fi
echo ""

# Check application logs for ODBC connection
echo "Checking application logs for ODBC connection status..."
echo ""
ODBC_LOG=$(docker logs phoenix-dotnet-app 2>&1 | grep -i "odbc\|connection" | tail -5)
if [ -n "$ODBC_LOG" ]; then
    echo "Recent ODBC/connection log entries:"
    echo "$ODBC_LOG"
else
    echo "⚠️  No ODBC/connection entries found in logs"
fi
echo ""

# Test connection
echo "Testing ODBC connection..."
echo ""
TEST_RESULT=$(docker exec phoenix-dotnet-app curl -s http://localhost:8099/api/phoenix/health 2>&1)
if echo "$TEST_RESULT" | grep -qi "healthy\|ok"; then
    echo "✅ Application health check passed"
else
    echo "⚠️  Application health check: $TEST_RESULT"
fi
echo ""

echo "=========================================="
echo "Verification Complete"
echo "=========================================="
echo ""
echo "If ODBC driver is installed, the application should use ODBC."
echo "If not, it will automatically fall back to REST API."
echo ""
echo "To test a query:"
echo "  curl -X POST http://localhost:8099/api/phoenix/query \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\":\"SELECT TABLE_NAME FROM SYSTEM.CATALOG LIMIT 5\"}'"
echo ""

