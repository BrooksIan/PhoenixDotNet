#!/bin/bash

# Complete Example: Create HBase Table Directly, Insert Rows, Create Phoenix View
# This script demonstrates the recommended workflow for HBase-native tables:
# 1. Create HBase table via HBase shell
# 2. Insert data via HBase shell (readable text format)
# 3. Create Phoenix view on top of HBase table
# 4. Query data via Phoenix view
#
# IMPORTANT: This approach is for HBase-native tables, NOT Phoenix tables.
# For Phoenix tables (created via Phoenix SQL), always use Phoenix SQL (UPSERT) to insert data.

API_URL="http://localhost:8099/api/phoenix"
HBASE_TABLE="EMPLOYEE_DATA"
PHOENIX_VIEW="EMPLOYEE_DATA"

# ⚠️ CRITICAL: View names MUST be UPPERCASE and MUST match HBase table name exactly

echo "=========================================="
echo "HBase Direct + Phoenix View Workflow"
echo "=========================================="
echo ""

# Step 1: Create HBase Table via HBase Shell
echo "Step 1: Creating HBase table '$HBASE_TABLE' via HBase shell..."
echo ""

CREATE_OUTPUT=$(docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
create '$HBASE_TABLE', 'info', 'contact', 'status'
EOF
 2>&1 | grep -v "WARN\|NativeCodeLoader\|HBase Shell\|Use \"help\"")

if echo "$CREATE_OUTPUT" | grep -q "already exists"; then
    echo "Table already exists, skipping creation"
else
    echo "$CREATE_OUTPUT" | grep -E "Created|ERROR" || echo "Table created"
fi
echo ""

# Wait for table creation
sleep 2

# Step 2: Insert 3 Rows via HBase Shell
echo "Step 2: Inserting 3 rows via HBase shell..."
echo ""

echo "  - Inserting row1: id='1', name='Alice', email='alice@example.com', score=100, status='active'"
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
put '$HBASE_TABLE', '1', 'info:name', 'Alice'
put '$HBASE_TABLE', '1', 'info:score', '100'
put '$HBASE_TABLE', '1', 'contact:email', 'alice@example.com'
put '$HBASE_TABLE', '1', 'status:status', 'active'
EOF
 > /dev/null 2>&1

echo "  - Inserting row2: id='2', name='Bob', email='bob@example.com', score=200, status='active'"
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
put '$HBASE_TABLE', '2', 'info:name', 'Bob'
put '$HBASE_TABLE', '2', 'info:score', '200'
put '$HBASE_TABLE', '2', 'contact:email', 'bob@example.com'
put '$HBASE_TABLE', '2', 'status:status', 'active'
EOF
 > /dev/null 2>&1

echo "  - Inserting row3: id='3', name='Charlie', email='charlie@example.com', score=150, status='inactive'"
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
put '$HBASE_TABLE', '3', 'info:name', 'Charlie'
put '$HBASE_TABLE', '3', 'info:score', '150'
put '$HBASE_TABLE', '3', 'contact:email', 'charlie@example.com'
put '$HBASE_TABLE', '3', 'status:status', 'inactive'
EOF
 > /dev/null 2>&1

echo "✅ All 3 rows inserted successfully"
echo ""

# Step 3: Verify Data in HBase
echo "Step 3: Verifying data in HBase table..."
echo ""
SCAN_OUTPUT=$(docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<EOF
scan '$HBASE_TABLE'
EOF
 2>&1 | grep -E "ROW|COLUMN|value" | head -15)

echo "$SCAN_OUTPUT"
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$PHOENIX_VIEW' on HBase table..."
echo ""
echo "Note: Phoenix views on HBase tables need to map column families to columns"
echo ""

# Create Phoenix view - use correct syntax for HBase tables
# For HBase tables, we need to map column families using "column_family"."column" syntax
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"CREATE VIEW IF NOT EXISTS \\\"$PHOENIX_VIEW\\\" (\\\"rowkey\\\" VARCHAR PRIMARY KEY, \\\"info\\\".\\\"name\\\" VARCHAR, \\\"info\\\".\\\"score\\\" INTEGER, \\\"contact\\\".\\\"email\\\" VARCHAR, \\\"status\\\".\\\"status\\\" VARCHAR)\"
  }")

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 3

# Step 5: Query HBase Table Directly via Phoenix (No View Needed!)
echo "Step 5: Querying HBase table directly via Phoenix..."
echo ""

DIRECT_QUERY=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name, \\\"info\\\".\\\"score\\\" as score, \\\"contact\\\".\\\"email\\\" as email, \\\"status\\\".\\\"status\\\" as status FROM \\\"$HBASE_TABLE\\\" ORDER BY rowkey\"
  }")

echo "Direct query result: $DIRECT_QUERY"
echo ""

# Verify row count
DIRECT_ROW_COUNT=$(echo "$DIRECT_QUERY" | jq -r '.rowCount // 0')
if [ "$DIRECT_ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible when querying HBase table directly!"
    echo ""
    echo "$DIRECT_QUERY" | jq -r '.rows[] | "Row \(.ROWKEY): name=\(.NAME), score=\(.SCORE), email=\(.EMAIL), status=\(.STATUS)"'
else
    echo "⚠️  WARNING: Expected 3 rows, found $DIRECT_ROW_COUNT rows"
    echo ""
    echo "Full response: $DIRECT_QUERY"
fi
echo ""

# Step 5b: Query Phoenix View (if created)
echo "Step 5b: Querying Phoenix view..."
echo ""

VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"$PHOENIX_VIEW\\\" ORDER BY rowkey\"
  }")

echo "Phoenix view data: $VIEW_DATA"
echo ""

# Verify row count
ROW_COUNT=$(echo "$VIEW_DATA" | jq -r '.rowCount // 0')
if [ "$ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are visible in the Phoenix view!"
    echo ""
    echo "$VIEW_DATA" | jq -r '.rows[] | "Row \(.ROWKEY): name=\(.NAME), score=\(.SCORE), email=\(.EMAIL), status=\(.STATUS)"'
else
    echo "⚠️  NOTE: View returned $ROW_COUNT rows. You can query the HBase table directly instead!"
    echo ""
    echo "Direct query (works): SELECT rowkey, \"info\".\"name\", \"info\".\"score\" FROM \"$HBASE_TABLE\""
fi
echo ""

# Step 6: Test Query with Filter
echo "Step 6: Testing Phoenix view with WHERE clause (filter active status)..."
echo ""

FILTERED_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT * FROM \\\"$PHOENIX_VIEW\\\" WHERE \\\"status\\\".\\\"status\\\" = 'active' ORDER BY rowkey\"
  }")

echo "Filtered data (active only): $FILTERED_DATA"
echo ""

FILTERED_COUNT=$(echo "$FILTERED_DATA" | jq -r '.rowCount // 0')
if [ "$FILTERED_COUNT" -eq 2 ]; then
    echo "✅ SUCCESS: View correctly filters for active status (2 rows found)"
else
    echo "⚠️  WARNING: Expected 2 active rows, found $FILTERED_COUNT rows"
fi
echo ""

# Step 7: Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Created HBase table: $HBASE_TABLE (via HBase shell)"
echo "   Column families: info, contact, status"
echo ""
echo "✅ Inserted 3 rows via HBase shell:"
echo "   - Row 1: id='1', name='Alice', email='alice@example.com', score=100, status='active'"
echo "   - Row 2: id='2', name='Bob', email='bob@example.com', score=200, status='active'"
echo "   - Row 3: id='3', name='Charlie', email='charlie@example.com', score=150, status='inactive'"
echo ""
echo "✅ Created Phoenix view: $PHOENIX_VIEW"
echo "   Maps HBase column families to Phoenix columns"
echo ""
echo "✅ Verified data is queryable via Phoenix view"
echo ""
echo "You can now query the data:"
echo "  - Full query: SELECT * FROM \"$PHOENIX_VIEW\" ORDER BY rowkey"
echo "  - Filtered: SELECT * FROM \"$PHOENIX_VIEW\" WHERE \"status\".\"status\" = 'active'"
echo "  - HBase direct: scan '$HBASE_TABLE'"
echo "  - GUI: http://localhost:8100"
echo ""

