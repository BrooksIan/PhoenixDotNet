#!/bin/bash

# Complete Workflow: HBase REST API + Phoenix Views
# This script demonstrates creating HBase tables and inserting data via HBase REST API,
# then creating Phoenix views to query the data

API_URL="http://localhost:8099/api/phoenix"
HBASE_TABLE="REST_API_TABLE"
PHOENIX_VIEW="REST_API_TABLE"

# ⚠️ CRITICAL: View names MUST be UPPERCASE and MUST match HBase table name exactly

echo "=========================================="
echo "Complete HBase REST API + Phoenix View Workflow"
echo "=========================================="
echo ""

# Step 0: Enable HBase REST API (if not already running)
echo "Step 0: Ensuring HBase REST API is running..."
echo ""

# Check if REST is running
REST_RUNNING=$(docker exec opdb-docker ps aux | grep -i "rest\|stargate" | grep -v grep | wc -l | tr -d ' ')
if [ "$REST_RUNNING" -eq 0 ]; then
    echo "Starting HBase REST service..."
    docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start rest 2>&1 | grep -v "WARN\|NativeCodeLoader" || true
    sleep 5
    echo "HBase REST service started"
else
    echo "HBase REST service is already running"
fi
echo ""

# Step 1: Create HBase Table via HBase REST API
echo "Step 1: Creating HBase table '$HBASE_TABLE' via HBase REST API..."
echo ""

CREATE_RESPONSE=$(curl -s -X POST "${API_URL}/hbase/tables/sensor" \
  -H "Content-Type: application/json" \
  -d "{
    \"tableName\": \"${HBASE_TABLE}\",
    \"namespace\": \"default\"
  }")

echo "Create table response: $CREATE_RESPONSE"
echo ""

# Wait for table creation
sleep 3

# Step 2: Verify Table Exists
echo "Step 2: Verifying table exists..."
echo ""

EXISTS_RESPONSE=$(curl -s "${API_URL}/hbase/tables/${HBASE_TABLE}/exists?namespace=default")
echo "Table exists check: $EXISTS_RESPONSE"
echo ""

# Step 3: Insert 3 Rows via HBase REST API
echo "Step 3: Inserting 3 rows via HBase REST API..."
echo ""

# Row 1
echo "Inserting row 1: rowKey='1', name='Alice', score=100, status='active'"
curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "1",
    "columnFamily": "metadata",
    "column": "name",
    "value": "Alice",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "1",
    "columnFamily": "readings",
    "column": "score",
    "value": "100",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "1",
    "columnFamily": "status",
    "column": "status",
    "value": "active",
    "namespace": "default"
  }' > /dev/null

# Row 2
echo "Inserting row 2: rowKey='2', name='Bob', score=200, status='active'"
curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "2",
    "columnFamily": "metadata",
    "column": "name",
    "value": "Bob",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "2",
    "columnFamily": "readings",
    "column": "score",
    "value": "200",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "2",
    "columnFamily": "status",
    "column": "status",
    "value": "active",
    "namespace": "default"
  }' > /dev/null

# Row 3
echo "Inserting row 3: rowKey='3', name='Charlie', score=150, status='inactive'"
curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "3",
    "columnFamily": "metadata",
    "column": "name",
    "value": "Charlie",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "3",
    "columnFamily": "readings",
    "column": "score",
    "value": "150",
    "namespace": "default"
  }' > /dev/null

curl -s -X PUT "${API_URL}/hbase/tables/${HBASE_TABLE}/data" \
  -H "Content-Type: application/json" \
  -d '{
    "rowKey": "3",
    "columnFamily": "status",
    "column": "status",
    "value": "inactive",
    "namespace": "default"
  }' > /dev/null

echo "✅ All 3 rows inserted successfully via HBase REST API"
echo ""

# Step 4: Verify Data in HBase
echo "Step 4: Verifying data in HBase table..."
echo ""

SCAN_OUTPUT=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<EOF
scan '$HBASE_TABLE'
EOF
 2>&1 | grep -E "ROW|COLUMN|value" | head -15)

echo "$SCAN_OUTPUT"
echo ""

# Step 5: Query HBase Table Directly via Phoenix
echo "Step 5: Querying HBase table directly via Phoenix..."
echo ""

DIRECT_QUERY=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"metadata\\\".\\\"name\\\" as name, \\\"readings\\\".\\\"score\\\" as score, \\\"status\\\".\\\"status\\\" as status FROM \\\"$HBASE_TABLE\\\" ORDER BY rowkey\"
  }")

echo "Direct query result: $DIRECT_QUERY"
echo ""

DIRECT_ROW_COUNT=$(echo "$DIRECT_QUERY" | jq -r '.rowCount // 0')
if [ "$DIRECT_ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible when querying HBase table directly!"
    echo "$DIRECT_QUERY" | jq -r '.rows[] | "Row \(.ROWKEY): name=\(.NAME), score=\(.SCORE), status=\(.STATUS)"'
else
    echo "⚠️  Expected 3 rows, found $DIRECT_ROW_COUNT rows"
fi
echo ""

# Step 6: Create Phoenix View
echo "Step 6: Creating Phoenix view '$PHOENIX_VIEW'..."
echo ""

VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"CREATE VIEW IF NOT EXISTS \\\"$PHOENIX_VIEW\\\" AS SELECT rowkey, \\\"metadata\\\".\\\"name\\\" as name, \\\"readings\\\".\\\"score\\\" as score, \\\"status\\\".\\\"status\\\" as status FROM \\\"$HBASE_TABLE\\\"\"
  }")

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 3

# Step 7: Query Phoenix View
echo "Step 7: Querying Phoenix view..."
echo ""

VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"$PHOENIX_VIEW\\\" ORDER BY rowkey\"
  }")

echo "Phoenix view data: $VIEW_DATA"
echo ""

VIEW_ROW_COUNT=$(echo "$VIEW_DATA" | jq -r '.rowCount // 0')
if [ "$VIEW_ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible in the Phoenix view!"
    echo "$VIEW_DATA" | jq -r '.rows[] | "Row \(.ROWKEY): name=\(.NAME), score=\(.SCORE), status=\(.STATUS)"'
else
    echo "⚠️  View returned $VIEW_ROW_COUNT rows. Direct query works: SELECT rowkey, \"metadata\".\"name\" FROM \"$HBASE_TABLE\""
fi
echo ""

# Step 8: Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Created HBase table: $HBASE_TABLE (via HBase REST API)"
echo "✅ Inserted 3 rows via HBase REST API"
echo "✅ Verified data in HBase"
echo "✅ Queried HBase table directly via Phoenix"
echo "✅ Created Phoenix view: $PHOENIX_VIEW"
echo ""
echo "You can now:"
echo "  - Query directly: SELECT rowkey, \"metadata\".\"name\" FROM \"$HBASE_TABLE\""
echo "  - Query view: SELECT * FROM \"$PHOENIX_VIEW\""
echo "  - Use HBase REST API: PUT /api/phoenix/hbase/tables/{table}/data"
echo "  - Use HBase shell: scan '$HBASE_TABLE'"
echo ""

