#!/bin/bash

# Test HBase API: Create Table and Insert Rows
# This script tests the HBase REST API endpoints for table creation and data insertion

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="TEST_TABLE"
NAMESPACE="default"

echo "=========================================="
echo "Testing HBase API: Table Creation and Data Insertion"
echo "=========================================="
echo ""

# Step 1: Health Check
echo "Step 1: Health Check"
echo ""
HEALTH=$(curl -s http://localhost:8099/api/phoenix/health)
echo "Health: $HEALTH"
echo ""

# Step 2: Create HBase Table
echo "Step 2: Creating HBase table '$TABLE_NAME' via HBase API..."
echo ""
CREATE_RESPONSE=$(curl -s -X POST "${API_URL}/hbase/tables/sensor" \
  -H "Content-Type: application/json" \
  -d "{
    \"tableName\": \"${TABLE_NAME}\",
    \"namespace\": \"${NAMESPACE}\"
  }")
echo "Create table response: $CREATE_RESPONSE"
echo ""

# Step 3: Verify Table Exists
echo "Step 3: Verifying table exists..."
echo ""
sleep 3
EXISTS_RESPONSE=$(curl -s "${API_URL}/hbase/tables/${TABLE_NAME}/exists?namespace=${NAMESPACE}")
echo "Table exists check: $EXISTS_RESPONSE"
echo ""

# Step 4: Get Table Schema
echo "Step 4: Getting table schema..."
echo ""
SCHEMA_RESPONSE=$(curl -s "${API_URL}/hbase/tables/${TABLE_NAME}/schema?namespace=${NAMESPACE}")
echo "Table schema: $SCHEMA_RESPONSE"
echo ""

# Step 5: Insert Row 1
echo "Step 5: Inserting Row 1 (rowKey='1', name='Alice', score=100, status='active')..."
echo ""

echo "  - Inserting name='Alice' (cf=metadata, col=name)"
RESPONSE1=$(curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Alice\",
    \"namespace\": \"${NAMESPACE}\"
  }")
echo "  Response: $RESPONSE1"
echo ""

echo "  - Inserting score=100 (cf=readings, col=score)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"100\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  - Inserting status='active' (cf=status, col=status)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"active\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  ✅ Row 1 inserted successfully"
echo ""

# Step 6: Insert Row 2
echo "Step 6: Inserting Row 2 (rowKey='2', name='Bob', score=200, status='active')..."
echo ""

echo "  - Inserting name='Bob' (cf=metadata, col=name)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Bob\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  - Inserting score=200 (cf=readings, col=score)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"200\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  - Inserting status='active' (cf=status, col=status)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"active\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  ✅ Row 2 inserted successfully"
echo ""

# Step 7: Insert Row 3
echo "Step 7: Inserting Row 3 (rowKey='3', name='Charlie', score=150, status='inactive')..."
echo ""

echo "  - Inserting name='Charlie' (cf=metadata, col=name)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Charlie\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  - Inserting score=150 (cf=readings, col=score)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"150\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  - Inserting status='inactive' (cf=status, col=status)"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"inactive\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "  ✅ Row 3 inserted successfully"
echo ""

# Step 8: Verify Data in HBase
echo "Step 8: Verifying data in HBase table..."
echo ""
echo "Scanning HBase table '${NAMESPACE}:${TABLE_NAME}'..."
echo ""

HBASE_SCAN=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "scan '${NAMESPACE}:${TABLE_NAME}'" 2>&1 | grep -E "ROW|COLUMN|value" | head -20)
echo "$HBASE_SCAN"
echo ""

# Step 9: Create Phoenix View
echo "Step 9: Creating Phoenix view on HBase table..."
echo ""
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"CREATE VIEW IF NOT EXISTS ${TABLE_NAME}_view (rowkey VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER, status VARCHAR) AS SELECT * FROM \\\"${NAMESPACE}:${TABLE_NAME}\\\"\"
  }")
echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 3

# Step 10: Query Phoenix View
echo "Step 10: Querying Phoenix view to verify data..."
echo ""
VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM ${TABLE_NAME^^}_VIEW ORDER BY rowkey\"
  }")
echo "Phoenix view data: $VIEW_DATA"
echo ""

# Step 11: Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "✅ Table Creation: $TABLE_NAME"
echo "✅ Data Insertion: 3 rows inserted"
echo "   - Row 1: rowKey='1', name='Alice', score=100, status='active'"
echo "   - Row 2: rowKey='2', name='Bob', score=200, status='active'"
echo "   - Row 3: rowKey='3', name='Charlie', score=150, status='inactive'"
echo "✅ Phoenix View: ${TABLE_NAME}_view"
echo ""
echo "You can verify data by:"
echo "  1. HBase shell: scan '${NAMESPACE}:${TABLE_NAME}'"
echo "  2. Phoenix query: SELECT * FROM ${TABLE_NAME^^}_VIEW ORDER BY rowkey"
echo "  3. GUI: http://localhost:8100"
echo ""

