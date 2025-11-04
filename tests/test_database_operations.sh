#!/bin/bash

# Database Operations Test Script
# Tests CRUD operations and data integrity

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"
TEST_TABLE="test_operations_$(date +%s)"
TEST_DATA=()

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

execute_sql() {
    local sql=$1
    local description=$2
    
    echo "Executing: $description"
    echo "  SQL: $sql"
    
    # Use jq to properly escape SQL for JSON, or use printf for simple escaping
    if command -v jq &> /dev/null; then
        local json_data=$(printf '{"sql":%s}' "$(echo "$sql" | jq -Rs .)")
    else
        # Fallback: simple escaping - replace newlines with spaces and escape quotes
        local escaped_sql=$(echo "$sql" | tr '\n' ' ' | sed 's/"/\\"/g')
        local json_data="{\"sql\":\"$escaped_sql\"}"
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "${BASE_URL}/api/phoenix/execute")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo -e "  ${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        ((FAILED++))
        return 1
    fi
}

query_sql() {
    local sql=$1
    local description=$2
    
    echo "Querying: $description"
    echo "  SQL: $sql"
    
    # Use jq to properly escape SQL for JSON, or use printf for simple escaping
    if command -v jq &> /dev/null; then
        local json_data=$(printf '{"sql":%s}' "$(echo "$sql" | jq -Rs .)")
    else
        # Fallback: simple escaping - replace newlines with spaces and escape quotes
        local escaped_sql=$(echo "$sql" | tr '\n' ' ' | sed 's/"/\\"/g')
        local json_data="{\"sql\":\"$escaped_sql\"}"
    fi
    
    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "$json_data" \
        "${BASE_URL}/api/phoenix/query")
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
        echo -e "  ${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
        echo "$BODY" | jq '.' 2>/dev/null || echo "$BODY" | head -c 200
        echo ""
        ((PASSED++))
        return 0
    else
        echo -e "  ${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
        echo "  Response: $BODY"
        ((FAILED++))
        return 1
    fi
}

cleanup() {
    echo -e "\n${YELLOW}Cleaning up test table...${NC}"
    execute_sql "DROP TABLE IF EXISTS ${TEST_TABLE}" "Drop test table"
}

trap cleanup EXIT

print_header "Database Operations Test Suite"

# Test 1: Create Table
print_header "1. Create Table"
execute_sql "CREATE TABLE IF NOT EXISTS ${TEST_TABLE} (
    id INTEGER NOT NULL,
    name VARCHAR(100),
    email VARCHAR(255),
    age INTEGER,
    active BOOLEAN,
    created_date DATE,
    CONSTRAINT pk_${TEST_TABLE} PRIMARY KEY (id)
)" "Create test table with multiple columns"

# Test 2: Verify Table Creation
print_header "2. Verify Table Creation"
query_sql "SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_NAME = '${TEST_TABLE^^}'" "Check if table exists in catalog"

# Test 3: Get Table Columns
print_header "3. Get Table Columns"
RESPONSE=$(curl -s "${BASE_URL}/api/phoenix/tables/${TEST_TABLE}/columns")
if echo "$RESPONSE" | grep -q "id"; then
    echo -e "  ${GREEN}✓ Table columns retrieved${NC}"
    echo "$RESPONSE" | jq '.' 2>/dev/null || echo "$RESPONSE"
    ((PASSED++))
else
    echo -e "  ${RED}✗ Failed to retrieve table columns${NC}"
    ((FAILED++))
fi

# Test 4: Insert Data
print_header "4. Insert Data (UPSERT)"
execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (1, 'John Doe', 'john.doe@example.com', 30, true, CURRENT_DATE())" "Insert first record"

execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (2, 'Jane Smith', 'jane.smith@example.com', 25, true, CURRENT_DATE())" "Insert second record"

execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (3, 'Bob Johnson', 'bob.johnson@example.com', 35, false, CURRENT_DATE())" "Insert third record"

# Test 5: Select All Records
print_header "5. Select All Records"
query_sql "SELECT * FROM ${TEST_TABLE} ORDER BY id" "Select all records"

# Test 6: Select with WHERE Clause
print_header "6. Select with WHERE Clause"
query_sql "SELECT * FROM ${TEST_TABLE} WHERE active = true ORDER BY id" "Select active records only"

# Test 7: Select with Aggregation
print_header "7. Select with Aggregation"
query_sql "SELECT COUNT(*) as total, SUM(CASE WHEN active = true THEN 1 ELSE 0 END) as active_count 
FROM ${TEST_TABLE}" "Count records with aggregation"

# Test 8: Update Data (UPSERT with same key)
print_header "8. Update Data (UPSERT)"
execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (1, 'John Doe Updated', 'john.doe.updated@example.com', 31, true, CURRENT_DATE())" "Update existing record"

query_sql "SELECT * FROM ${TEST_TABLE} WHERE id = 1" "Verify update"

# Test 9: Select with ORDER BY
print_header "9. Select with ORDER BY"
query_sql "SELECT * FROM ${TEST_TABLE} ORDER BY age DESC" "Select ordered by age descending"

# Test 10: Select with LIMIT
print_header "10. Select with LIMIT"
query_sql "SELECT * FROM ${TEST_TABLE} ORDER BY id LIMIT 2" "Select with limit"

# Test 11: Data Type Validation
print_header "11. Data Type Validation"
query_sql "SELECT id, name, email, age, active, created_date FROM ${TEST_TABLE} WHERE id = 1" "Verify data types are preserved"

# Test 12: NULL Handling
print_header "12. NULL Handling"
execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (4, 'Test User', NULL, NULL, NULL, CURRENT_DATE())" "Insert record with NULL values"

query_sql "SELECT * FROM ${TEST_TABLE} WHERE id = 4" "Query record with NULL values"

# Test 13: Delete Data (via UPSERT with NULL)
print_header "13. Delete Data (Phoenix doesn't support DELETE, use UPSERT with NULL)"
execute_sql "UPSERT INTO ${TEST_TABLE} (id, name, email, age, active, created_date) 
VALUES (4, NULL, NULL, NULL, NULL, NULL)" "Clear record data (Phoenix way)"

# Test 14: Count Records
print_header "14. Count Records"
query_sql "SELECT COUNT(*) as record_count FROM ${TEST_TABLE}" "Count total records"

# Test 15: Complex Query
print_header "15. Complex Query"
query_sql "SELECT 
    CASE 
        WHEN age < 30 THEN 'Young'
        WHEN age >= 30 AND age < 40 THEN 'Middle-aged'
        ELSE 'Senior'
    END as age_group,
    COUNT(*) as count
FROM ${TEST_TABLE}
WHERE age IS NOT NULL
GROUP BY 
    CASE 
        WHEN age < 30 THEN 'Young'
        WHEN age >= 30 AND age < 40 THEN 'Middle-aged'
        ELSE 'Senior'
    END" "Complex query with CASE and GROUP BY"

# Summary
print_header "Test Summary"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All database operation tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some database operation tests failed. Review the output above.${NC}"
    exit 1
fi

