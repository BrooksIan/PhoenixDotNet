#!/bin/bash

# Master Test Runner
# Runs all test suites in sequence

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_header "PhoenixDotNet Test Suite Runner"
echo "Running all test suites..."
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0

# Test 1: Smoke Test (Quick verification)
print_header "1. Running Smoke Test"
if ./smoke_test.sh; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
    echo -e "${YELLOW}Smoke test failed. Continuing with other tests...${NC}"
fi

# Test 2: Connectivity Test
print_header "2. Running Connectivity Test"
if ./test_connectivity.sh; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
    echo -e "${YELLOW}Connectivity test failed. Some tests may fail.${NC}"
fi

# Test 3: API Endpoints Test
print_header "3. Running API Endpoints Test"
if ./test_api_endpoints.sh; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi

# Test 4: Database Operations Test
print_header "4. Running Database Operations Test"
if ./test_database_operations.sh; then
    ((TOTAL_PASSED++))
else
    ((TOTAL_FAILED++))
fi

# Test 5: HBase API Test (if exists)
if [ -f "test_hbase_api.sh" ]; then
    print_header "5. Running HBase API Test"
    if ./test_hbase_api.sh; then
        ((TOTAL_PASSED++))
    else
        ((TOTAL_FAILED++))
    fi
fi

# Summary
print_header "Test Suite Summary"
echo -e "${GREEN}Test Suites Passed: $TOTAL_PASSED${NC}"
echo -e "${RED}Test Suites Failed: $TOTAL_FAILED${NC}"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All test suites passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠ Some test suites failed${NC}"
    echo ""
    echo "For troubleshooting, run:"
    echo "  ./troubleshoot.sh"
    echo "  ./diagnostic.sh"
    exit 1
fi

