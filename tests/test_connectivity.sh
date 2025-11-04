#!/bin/bash

# Connectivity Test Script
# Tests connectivity to Phoenix, HBase, and the application API

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"
PHOENIX_SERVER="${PHOENIX_SERVER:-localhost}"
PHOENIX_PORT="${PHOENIX_PORT:-8765}"
HBASE_SERVER="${HBASE_SERVER:-localhost}"
HBASE_PORT="${HBASE_PORT:-8080}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ $2${NC}"
        ((FAILED++))
    fi
}

print_header "Connectivity Test Suite"

echo "Configuration:"
echo "  API Base URL: $BASE_URL"
echo "  Phoenix Server: $PHOENIX_SERVER:$PHOENIX_PORT"
echo "  HBase Server: $HBASE_SERVER:$HBASE_PORT"
echo ""

# Test 1: Application Health Check
print_header "1. Application Health Check"
if curl -s -f "${BASE_URL}/api/phoenix/health" > /dev/null 2>&1; then
    RESPONSE=$(curl -s "${BASE_URL}/api/phoenix/health")
    test_result 0 "Application is responding"
    echo "  Response: $RESPONSE"
else
    test_result 1 "Application is not responding at ${BASE_URL}"
    echo "  Check if the application is running"
fi

# Test 2: Phoenix Query Server Connectivity
print_header "2. Phoenix Query Server Connectivity"
if nc -z "$PHOENIX_SERVER" "$PHOENIX_PORT" 2>/dev/null; then
    test_result 0 "Phoenix Query Server is accessible on $PHOENIX_SERVER:$PHOENIX_PORT"
else
    test_result 1 "Phoenix Query Server is not accessible on $PHOENIX_SERVER:$PHOENIX_PORT"
    echo "  Check if Phoenix is running: docker-compose ps opdb-docker"
fi

# Test 3: Phoenix Query Server HTTP Response
print_header "3. Phoenix Query Server HTTP Response"
if curl -s -f "http://${PHOENIX_SERVER}:${PHOENIX_PORT}" > /dev/null 2>&1; then
    test_result 0 "Phoenix Query Server HTTP endpoint is responding"
else
    # Phoenix might not respond to root, try /json endpoint
    if curl -s -f "http://${PHOENIX_SERVER}:${PHOENIX_PORT}/json" > /dev/null 2>&1; then
        test_result 0 "Phoenix Query Server JSON endpoint is responding"
    else
        test_result 1 "Phoenix Query Server HTTP endpoint is not responding"
        echo "  This might be normal - Phoenix may require specific endpoints"
    fi
fi

# Test 4: HBase REST API Connectivity
print_header "4. HBase REST API Connectivity"
if nc -z "$HBASE_SERVER" "$HBASE_PORT" 2>/dev/null; then
    test_result 0 "HBase REST API is accessible on $HBASE_SERVER:$HBASE_PORT"
else
    test_result 1 "HBase REST API is not accessible on $HBASE_SERVER:$HBASE_PORT"
    echo "  Check if HBase REST API (Stargate) is running"
    echo "  Note: HBase REST API may not be enabled by default"
fi

# Test 5: HBase REST API HTTP Response
print_header "5. HBase REST API HTTP Response"
if curl -s -f "http://${HBASE_SERVER}:${HBASE_PORT}" > /dev/null 2>&1; then
    test_result 0 "HBase REST API HTTP endpoint is responding"
else
    test_result 1 "HBase REST API HTTP endpoint is not responding"
    echo "  HBase REST API (Stargate) may not be enabled"
    echo "  This is optional - the application uses Phoenix primarily"
fi

# Test 6: Application API Endpoints
print_header "6. Application API Endpoints"

# Test tables endpoint
if curl -s -f "${BASE_URL}/api/phoenix/tables" > /dev/null 2>&1; then
    test_result 0 "Tables endpoint is accessible"
else
    test_result 1 "Tables endpoint is not accessible"
fi

# Test 7: Network Ports Check
print_header "7. Network Ports Check"
PORTS=("8099:API" "8100:GUI" "8765:Phoenix" "8080:HBase")
for port_info in "${PORTS[@]}"; do
    PORT=$(echo $port_info | cut -d: -f1)
    NAME=$(echo $port_info | cut -d: -f2)
    if nc -z localhost "$PORT" 2>/dev/null; then
        test_result 0 "Port $PORT ($NAME) is listening"
    else
        test_result 1 "Port $PORT ($NAME) is not listening"
    fi
done

# Test 8: Docker Containers (if using Docker)
print_header "8. Docker Containers Status"
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    if docker ps --format "{{.Names}}" | grep -q "phoenix"; then
        test_result 0 "Phoenix-related containers are running"
        echo "  Running containers:"
        docker ps --format "  - {{.Names}} ({{.Status}})" | grep -i phoenix
    else
        test_result 1 "No Phoenix-related containers found"
        echo "  Run: docker-compose ps"
    fi
else
    echo -e "${YELLOW}⚠ Docker not available or not running${NC}"
    echo "  Skipping container checks"
fi

# Summary
print_header "Test Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All connectivity tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some connectivity tests failed. Check the output above for details.${NC}"
    exit 1
fi

