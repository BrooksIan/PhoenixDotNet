#!/bin/bash

# Smoke Test Script
# Quick test to verify basic functionality

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

print_header "Smoke Test Suite"
echo "Quick verification of basic functionality"
echo ""

# Test 1: Application Health
echo "1. Application Health Check..."
if curl -s -f "${BASE_URL}/api/phoenix/health" > /dev/null 2>&1; then
    test_result 0 "Application is responding"
else
    test_result 1 "Application is not responding"
    echo "   Run: docker-compose up -d"
    exit 1
fi

# Test 2: Phoenix Connection
echo "2. Phoenix Connection..."
RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/phoenix/tables")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ]; then
    test_result 0 "Phoenix connection is working"
else
    test_result 1 "Phoenix connection failed (HTTP $HTTP_CODE)"
fi

# Test 3: Query Execution
echo "3. Query Execution..."
QUERY_DATA='{"sql":"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = '\''u'\'' LIMIT 1"}'
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$QUERY_DATA" \
    "${BASE_URL}/api/phoenix/query")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ]; then
    test_result 0 "Query execution is working"
else
    test_result 1 "Query execution failed (HTTP $HTTP_CODE)"
fi

# Test 4: Execute Command
echo "4. Execute Command..."
CREATE_DATA='{"sql":"SELECT CURRENT_DATE() as test_date"}'
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$CREATE_DATA" \
    "${BASE_URL}/api/phoenix/execute")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ]; then
    test_result 0 "Execute command is working"
else
    test_result 1 "Execute command failed (HTTP $HTTP_CODE)"
fi

# Summary
print_header "Smoke Test Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All smoke tests passed!${NC}"
    echo "Basic functionality is working correctly."
    exit 0
else
    echo -e "${RED}✗ Some smoke tests failed${NC}"
    echo "Run diagnostic script for more details:"
    echo "  ./tests/diagnostic.sh"
    exit 1
fi

