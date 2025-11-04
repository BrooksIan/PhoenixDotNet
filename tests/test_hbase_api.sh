#!/bin/bash

# Test script for HBase API endpoints
# This script tests the HBase REST API integration

BASE_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="SENSOR_INFO"
NAMESPACE="default"

echo "=========================================="
echo "Testing HBase API Endpoints"
echo "=========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health check
echo "1. Testing Health Endpoint..."
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Health check failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    echo ""
    echo "Make sure the application is running:"
    echo "  docker-compose up -d"
    echo "  or"
    echo "  dotnet run"
    exit 1
fi
echo ""

# Test 2: Check if table exists (before creation)
echo "2. Checking if table '${TABLE_NAME}' exists (before creation)..."
EXISTS_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/hbase/tables/${TABLE_NAME}/exists?namespace=${NAMESPACE}")
HTTP_CODE=$(echo "$EXISTS_RESPONSE" | tail -n1)
BODY=$(echo "$EXISTS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Table exists check passed${NC}"
    echo "Response: $BODY"
    EXISTS=$(echo "$BODY" | grep -o '"exists":[^,}]*' | cut -d: -f2 | tr -d ' ')
    if [ "$EXISTS" = "true" ]; then
        echo -e "${YELLOW}Table already exists${NC}"
    else
        echo -e "${YELLOW}Table does not exist yet${NC}"
    fi
else
    echo -e "${RED}✗ Table exists check failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
fi
echo ""

# Test 3: Create sensor table
echo "3. Creating sensor table '${TABLE_NAME}'..."
CREATE_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "{\"tableName\": \"${TABLE_NAME}\", \"namespace\": \"${NAMESPACE}\"}" \
    "${BASE_URL}/hbase/tables/sensor")
HTTP_CODE=$(echo "$CREATE_RESPONSE" | tail -n1)
BODY=$(echo "$CREATE_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Table created successfully${NC}"
    echo "Response: $BODY"
elif [ "$HTTP_CODE" = "409" ]; then
    echo -e "${YELLOW}⚠ Table already exists (HTTP 409)${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Table creation failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
    echo ""
    echo "This might be expected if HBase REST API is not available on port 8080"
    echo "Check your HBase configuration and ensure HBase REST API (Stargate) is running"
fi
echo ""

# Test 4: Check if table exists (after creation)
echo "4. Checking if table '${TABLE_NAME}' exists (after creation)..."
EXISTS_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/hbase/tables/${TABLE_NAME}/exists?namespace=${NAMESPACE}")
HTTP_CODE=$(echo "$EXISTS_RESPONSE" | tail -n1)
BODY=$(echo "$EXISTS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Table exists check passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Table exists check failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
fi
echo ""

# Test 5: Get table schema
echo "5. Getting table schema for '${TABLE_NAME}'..."
SCHEMA_RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/hbase/tables/${TABLE_NAME}/schema?namespace=${NAMESPACE}")
HTTP_CODE=$(echo "$SCHEMA_RESPONSE" | tail -n1)
BODY=$(echo "$SCHEMA_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ Schema retrieval passed${NC}"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Schema retrieval failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
fi
echo ""

# Test 6: Create table with default values (no body)
echo "6. Creating sensor table with default values (no request body)..."
CREATE_DEFAULT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    "${BASE_URL}/hbase/tables/sensor")
HTTP_CODE=$(echo "$CREATE_DEFAULT_RESPONSE" | tail -n1)
BODY=$(echo "$CREATE_DEFAULT_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "409" ]; then
    echo -e "${GREEN}✓ Default table creation passed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
else
    echo -e "${RED}✗ Default table creation failed${NC} (HTTP $HTTP_CODE)"
    echo "Response: $BODY"
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "If all tests passed, the HBase API integration is working correctly."
echo ""
echo "Note: If you see errors related to HBase REST API, make sure:"
echo "  1. HBase is running and accessible"
echo "  2. HBase REST API (Stargate) is enabled on port 8080"
echo "  3. The HBase:Server and HBase:Port in appsettings.json are correct"
echo ""
echo "To test manually:"
echo "  curl -X POST ${BASE_URL}/hbase/tables/sensor"
echo "  curl ${BASE_URL}/hbase/tables/${TABLE_NAME}/exists"
echo "  curl ${BASE_URL}/hbase/tables/${TABLE_NAME}/schema"

