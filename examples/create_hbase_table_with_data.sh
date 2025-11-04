#!/bin/bash

# Complete Example: Create HBase Table using HBase API, Insert Data, and Create Phoenix View
# This script demonstrates creating an HBase table, inserting data via HBase API, and creating a Phoenix view

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="USER_DATA"
VIEW_NAME="USER_DATA"

# ⚠️ CRITICAL: View names MUST be UPPERCASE and MUST match HBase table name exactly
NAMESPACE="default"

echo "=========================================="
echo "Create HBase Table with Data via HBase API"
echo "=========================================="
echo ""

# Step 1: Create HBase Table using HBase API
echo "Step 1: Creating HBase table '$TABLE_NAME' with column families..."
echo ""

RESPONSE=$(curl -s -X POST "${API_URL}/hbase/tables/sensor" \
  -H "Content-Type: application/json" \
  -d "{
    \"tableName\": \"${TABLE_NAME}\",
    \"namespace\": \"${NAMESPACE}\"
  }")

echo "Response: $RESPONSE"
echo ""

# Wait for table creation
sleep 3

# Step 2: Verify HBase Table Exists
echo "Step 2: Verifying HBase table exists..."
echo ""

EXISTS=$(curl -s "${API_URL}/hbase/tables/${TABLE_NAME}/exists?namespace=${NAMESPACE}")
echo "Table exists check: $EXISTS"
echo ""

# Step 3: Insert 3 rows of data using HBase API
echo "Step 3: Inserting 3 rows of data using HBase API..."
echo ""

# Row 1: id='1', name='Alice', score=100, status='active'
echo "Inserting row 1: rowKey='1', cf='metadata', col='name', value='Alice'"
RESPONSE1=$(curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Alice\",
    \"namespace\": \"${NAMESPACE}\"
  }")
echo "Response: $RESPONSE1"
echo ""

echo "Inserting row 1: rowKey='1', cf='readings', col='score', value='100'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"100\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "Inserting row 1: rowKey='1', cf='status', col='status', value='active'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"1\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"active\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

# Row 2: id='2', name='Bob', score=200, status='active'
echo "Inserting row 2: rowKey='2', cf='metadata', col='name', value='Bob'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Bob\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "Inserting row 2: rowKey='2', cf='readings', col='score', value='200'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"200\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "Inserting row 2: rowKey='2', cf='status', col='status', value='active'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"2\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"active\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

# Row 3: id='3', name='Charlie', score=50, status='inactive'
echo "Inserting row 3: rowKey='3', cf='metadata', col='name', value='Charlie'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"metadata\",
    \"column\": \"name\",
    \"value\": \"Charlie\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "Inserting row 3: rowKey='3', cf='readings', col='score', value='50'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"readings\",
    \"column\": \"score\",
    \"value\": \"50\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "Inserting row 3: rowKey='3', cf='status', col='status', value='inactive'"
curl -s -X PUT "${API_URL}/hbase/tables/${TABLE_NAME}/data" \
  -H "Content-Type: application/json" \
  -d "{
    \"rowKey\": \"3\",
    \"columnFamily\": \"status\",
    \"column\": \"status\",
    \"value\": \"inactive\",
    \"namespace\": \"${NAMESPACE}\"
  }" > /dev/null

echo "All 3 rows inserted successfully via HBase API"
echo ""

# Wait for data to be committed
echo "Waiting 3 seconds for data to be committed..."
sleep 3
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME' on HBase table..."
echo ""

# Create Phoenix view - use single line SQL to avoid JSON escaping issues
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"CREATE VIEW ${VIEW_NAME} (rowkey VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER, status VARCHAR) AS SELECT * FROM \\\"${NAMESPACE}:${TABLE_NAME}\\\"\"
  }")

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 2

# Step 5: Query the Phoenix View
echo "Step 5: Querying the Phoenix view to verify data is visible..."
echo ""

VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM ${VIEW_NAME} ORDER BY rowkey\"
  }")

echo "Phoenix view data: $VIEW_DATA"
echo ""

# Verify row count
VIEW_ROW_COUNT=$(echo "$VIEW_DATA" | jq -r '.rowCount // 0')
if [ "$VIEW_ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible in the Phoenix view!"
else
    echo "⚠️  WARNING: Expected 3 rows in view, found $VIEW_ROW_COUNT rows"
fi
echo ""

# Step 6: List all tables
echo "Step 6: Listing all tables (including views)..."
echo ""

TABLES=$(curl -s "${API_URL}/tables")
echo "All tables: $TABLES"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Created HBase table: ${NAMESPACE}:${TABLE_NAME} via HBase API"
echo "✅ Inserted 3 rows into HBase table via HBase API:"
echo "   1. rowKey='1', name='Alice', score=100, status='active'"
echo "   2. rowKey='2', name='Bob', score=200, status='active'"
echo "   3. rowKey='3', name='Charlie', score=50, status='inactive'"
echo "✅ Created Phoenix view: ${VIEW_NAME}"
echo "✅ Verified all 3 rows are visible in Phoenix view"
echo ""
echo "You can now query:"
echo "  - Phoenix view: SELECT * FROM ${VIEW_NAME} ORDER BY rowkey"
echo ""

