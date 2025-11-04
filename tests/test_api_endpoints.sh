#!/bin/bash

# Comprehensive API Endpoints Test Script
# Tests all API endpoints with various scenarios

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"
TEST_TABLE="test_api_table_$(date +%s)"

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

test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo "Testing: $description"
    echo "  $method $endpoint"
    
    if [ "$method" = "GET" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}${endpoint}")
    elif [ "$method" = "POST" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${BASE_URL}${endpoint}")
    fi
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo -e "  ${GREEN}✓ Passed (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY" | head -c 200
        echo ""
        ((PASSED++))
        return 0
    elif [ "$HTTP_CODE" -ge 400 ] && [ "$HTTP_CODE" -lt 500 ]; then
        echo -e "  ${YELLOW}⚠ Client Error (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        ((FAILED++))
        return 1
    else
        echo -e "  ${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        ((FAILED++))
        return 1
    fi
}

print_header "API Endpoints Test Suite"

# Test 1: Health Check
print_header "1. Health Check Endpoint"
test_endpoint "GET" "/api/phoenix/health" "" "Health check"

# Test 2: List Tables
print_header "2. List Tables Endpoint"
test_endpoint "GET" "/api/phoenix/tables" "" "Get all tables"

# Test 3: Get Columns (may fail if no tables exist)
print_header "3. Get Table Columns Endpoint"
test_endpoint "GET" "/api/phoenix/tables/nonexistent/columns" "" "Get columns for non-existent table"

# Test 4: Execute Query - Valid Query
print_header "4. Execute Query - Valid Query"
QUERY_DATA='{"sql":"SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = '\''u'\'' LIMIT 5"}'
test_endpoint "POST" "/api/phoenix/query" "$QUERY_DATA" "Execute valid SELECT query"

# Test 5: Execute Query - Invalid Query
print_header "5. Execute Query - Invalid Query"
INVALID_QUERY_DATA='{"sql":"SELECT * FROM nonexistent_table"}'
test_endpoint "POST" "/api/phoenix/query" "$INVALID_QUERY_DATA" "Execute invalid query (should fail gracefully)"

# Test 6: Execute Query - Empty SQL
print_header "6. Execute Query - Empty SQL"
EMPTY_QUERY_DATA='{"sql":""}'
test_endpoint "POST" "/api/phoenix/query" "$EMPTY_QUERY_DATA" "Execute query with empty SQL (should return 400)"

# Test 7: Execute Non-Query - Create Table
print_header "7. Execute Non-Query - Create Table"
CREATE_TABLE_SQL="CREATE TABLE IF NOT EXISTS ${TEST_TABLE} (id INTEGER PRIMARY KEY, name VARCHAR(100))"
CREATE_DATA="{\"sql\":\"$CREATE_TABLE_SQL\"}"
test_endpoint "POST" "/api/phoenix/execute" "$CREATE_DATA" "Create test table"

# Test 8: Get Columns for Created Table
print_header "8. Get Columns for Created Table"
if [ $? -eq 0 ]; then
    test_endpoint "GET" "/api/phoenix/tables/${TEST_TABLE}/columns" "" "Get columns for created table"
fi

# Test 9: Execute Non-Query - Insert Data
print_header "9. Execute Non-Query - Insert Data"
INSERT_SQL="UPSERT INTO ${TEST_TABLE} (id, name) VALUES (1, 'Test User')"
INSERT_DATA="{\"sql\":\"$INSERT_SQL\"}"
test_endpoint "POST" "/api/phoenix/execute" "$INSERT_DATA" "Insert test data"

# Test 10: Execute Query - Select from Table
print_header "10. Execute Query - Select from Table"
SELECT_DATA="{\"sql\":\"SELECT * FROM ${TEST_TABLE}\"}"
test_endpoint "POST" "/api/phoenix/query" "$SELECT_DATA" "Query data from test table"

# Test 11: Execute Non-Query - Drop Table
print_header "11. Execute Non-Query - Drop Table"
DROP_SQL="DROP TABLE IF EXISTS ${TEST_TABLE}"
DROP_DATA="{\"sql\":\"$DROP_SQL\"}"
test_endpoint "POST" "/api/phoenix/execute" "$DROP_DATA" "Drop test table"

# Test 12: HBase API - Check Table Exists
print_header "12. HBase API - Check Table Exists"
test_endpoint "GET" "/api/phoenix/hbase/tables/SENSOR_INFO/exists?namespace=default" "" "Check if SENSOR_INFO table exists"

# Test 13: HBase API - Get Table Schema
print_header "13. HBase API - Get Table Schema"
test_endpoint "GET" "/api/phoenix/hbase/tables/SENSOR_INFO/schema?namespace=default" "" "Get SENSOR_INFO table schema"

# Test 14: HBase API - Create Sensor Table
print_header "14. HBase API - Create Sensor Table"
SENSOR_DATA='{"tableName":"SENSOR_INFO","namespace":"default"}'
test_endpoint "POST" "/api/phoenix/hbase/tables/sensor" "$SENSOR_DATA" "Create sensor table via HBase API"

# Test 15: Error Handling - Invalid Endpoint
print_header "15. Error Handling - Invalid Endpoint"
test_endpoint "GET" "/api/phoenix/invalid/endpoint" "" "Request invalid endpoint (should return 404)"

# Test 16: Error Handling - Missing Body
print_header "16. Error Handling - Missing Body"
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "${BASE_URL}/api/phoenix/query")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 400 ]; then
    echo -e "  ${GREEN}✓ Correctly returns 400 for missing body${NC}"
    ((PASSED++))
else
    echo -e "  ${RED}✗ Expected 400, got HTTP $HTTP_CODE${NC}"
    ((FAILED++))
fi

# Summary
print_header "Test Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All API endpoint tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some API endpoint tests failed. Review the output above.${NC}"
    exit 1
fi

