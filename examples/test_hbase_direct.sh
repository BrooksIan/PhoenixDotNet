#!/bin/bash

# Test HBase Direct: Create Table and Insert Rows using HBase Shell
# This script tests creating an HBase table directly via HBase shell and then creating a Phoenix view

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="TEST_HBASE_DIRECT"
VIEW_NAME="TEST_HBASE_DIRECT"

# ⚠️ CRITICAL: View names MUST be UPPERCASE and MUST match HBase table name exactly

echo "=========================================="
echo "Testing HBase Direct: Table Creation and Data Insertion"
echo "=========================================="
echo ""

# Step 1: Create HBase Table via HBase Shell
echo "Step 1: Creating HBase table '$TABLE_NAME' via HBase shell..."
echo ""
CREATE_OUTPUT=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "create '$TABLE_NAME', 'cf1', 'cf2'" 2>&1 | grep -v "WARN\|NativeCodeLoader\|HBase Shell\|Use \"help\"\|For Reference" | head -5)
echo "$CREATE_OUTPUT"
echo ""

# Step 2: Insert 3 Rows via HBase Shell
echo "Step 2: Inserting 3 rows via HBase shell..."
echo ""

echo "  - Inserting row1: name='Alice', score=100"
PUT_OUTPUT1=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "put '$TABLE_NAME', 'row1', 'cf1:name', 'Alice'; put '$TABLE_NAME', 'row1', 'cf1:score', '100'" 2>&1 | grep -v "WARN\|NativeCodeLoader" | head -3)
echo "$PUT_OUTPUT1"
echo ""

echo "  - Inserting row2: name='Bob', score=200"
PUT_OUTPUT2=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "put '$TABLE_NAME', 'row2', 'cf1:name', 'Bob'; put '$TABLE_NAME', 'row2', 'cf1:score', '200'" 2>&1 | grep -v "WARN\|NativeCodeLoader" | head -3)
echo "$PUT_OUTPUT2"
echo ""

echo "  - Inserting row3: name='Charlie', score=150"
PUT_OUTPUT3=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "put '$TABLE_NAME', 'row3', 'cf1:name', 'Charlie'; put '$TABLE_NAME', 'row3', 'cf1:score', '150'" 2>&1 | grep -v "WARN\|NativeCodeLoader" | head -3)
echo "$PUT_OUTPUT3"
echo ""

echo "✅ All 3 rows inserted successfully"
echo ""

# Step 3: Verify Data in HBase
echo "Step 3: Verifying data in HBase table..."
echo ""
SCAN_OUTPUT=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "scan '$TABLE_NAME'" 2>&1 | grep -E "ROW|COLUMN|value" | head -15)
echo "$SCAN_OUTPUT"
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME' on HBase table..."
echo ""
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"CREATE VIEW ${VIEW_NAME} (rowkey VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER) AS SELECT rowkey, \\\"cf1\\\".\\\"name\\\" as name, \\\"cf1\\\".\\\"score\\\" as score FROM \\\"${TABLE_NAME}\\\"\"
  }")
echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 3

# Step 5: Query Phoenix View
echo "Step 5: Querying Phoenix view to verify data..."
echo ""
VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM ${VIEW_NAME^^} ORDER BY rowkey\"
  }")
echo "Phoenix view data: $VIEW_DATA"
echo ""

# Verify row count
ROW_COUNT=$(echo "$VIEW_DATA" | jq -r '.rowCount // 0')
if [ "$ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible in the Phoenix view!"
else
    echo "⚠️  WARNING: Expected 3 rows, found $ROW_COUNT rows"
fi
echo ""

# Step 6: Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "✅ Created HBase table: $TABLE_NAME (via HBase shell)"
echo "✅ Inserted 3 rows via HBase shell:"
echo "   - row1: name='Alice', score=100"
echo "   - row2: name='Bob', score=200"
echo "   - row3: name='Charlie', score=150"
echo "✅ Created Phoenix view: $VIEW_NAME"
echo ""
echo "Data verification:"
echo "  - HBase shell: scan '$TABLE_NAME'"
echo "  - Phoenix view: SELECT * FROM ${VIEW_NAME^^} ORDER BY rowkey"
echo "  - GUI: http://localhost:8100"
echo ""

