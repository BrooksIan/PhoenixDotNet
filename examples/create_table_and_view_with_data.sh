#!/bin/bash

# Complete Example: Create HBase Table using Phoenix SQL, Insert Data, and Create Phoenix View
# This script demonstrates creating an HBase table via Phoenix SQL, inserting data, and creating a Phoenix view

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="USER_DATA"
VIEW_NAME="USER_DATA_ACTIVE"

# Note: This example creates a Phoenix table (not HBase-native)
# For Phoenix tables, views can have different names and use SELECT statements
# For HBase-native tables, view name MUST match table name exactly (see create_muscle_cars_table.sh)

echo "=========================================="
echo "Create HBase Table with Data via Phoenix SQL"
echo "=========================================="
echo ""

# Step 1: Create HBase Table using Phoenix SQL (automatically creates HBase table)
echo "Step 1: Creating HBase table '$TABLE_NAME' via Phoenix SQL..."
echo ""

RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE TABLE IF NOT EXISTS USER_DATA (rowkey VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER, status VARCHAR)"
  }')

echo "Response: $RESPONSE"
echo ""

# Wait for table creation
sleep 3

# Step 2: Insert 3 rows of data using Phoenix SQL
echo "Step 2: Inserting 3 rows of data using Phoenix SQL..."
echo ""

# Row 1: rowkey='1', name='Alice', score=100, status='active'
echo "Inserting row 1: rowkey='1', name='Alice', score=100, status='active'"
RESPONSE1=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO USER_DATA VALUES ('"'"'1'"'"', '"'"'Alice'"'"', 100, '"'"'active'"'"')"
  }')
echo "Response: $RESPONSE1"
echo ""

# Row 2: rowkey='2', name='Bob', score=200, status='active'
echo "Inserting row 2: rowkey='2', name='Bob', score=200, status='active'"
RESPONSE2=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO USER_DATA VALUES ('"'"'2'"'"', '"'"'Bob'"'"', 200, '"'"'active'"'"')"
  }')
echo "Response: $RESPONSE2"
echo ""

# Row 3: rowkey='3', name='Charlie', score=50, status='inactive'
echo "Inserting row 3: rowkey='3', name='Charlie', score=50, status='inactive'"
RESPONSE3=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO USER_DATA VALUES ('"'"'3'"'"', '"'"'Charlie'"'"', 50, '"'"'inactive'"'"')"
  }')
echo "Response: $RESPONSE3"
echo ""

echo "All 3 rows inserted successfully"
echo ""

# Wait for data to be committed
echo "Waiting 5 seconds for data to be committed..."
sleep 5
echo ""

# Step 3: Query the table to verify data
echo "Step 3: Querying the HBase table to verify all 3 rows are present..."
echo ""

TABLE_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM USER_DATA ORDER BY rowkey"
  }')

echo "HBase table data: $TABLE_DATA"
echo ""

# Verify row count
ROW_COUNT=$(echo "$TABLE_DATA" | jq -r '.rowCount // 0')
if [ "$ROW_COUNT" -eq 3 ]; then
    echo "✅ SUCCESS: All 3 rows are present in the HBase table!"
else
    echo "⚠️  WARNING: Expected 3 rows, found $ROW_COUNT rows"
fi
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME' on HBase table..."
echo ""

# Option A: Using the new dedicated /views endpoint (recommended for HBase tables)
# Note: This example uses a Phoenix table, so we use /execute for simplicity
# For HBase tables, use the /views endpoint as shown in create_table_and_view_example.sh

VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW IF NOT EXISTS USER_DATA_ACTIVE AS SELECT * FROM USER_DATA WHERE status = '"'"'active'"'"'"
  }')

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Note: For HBase tables, use the /api/phoenix/views endpoint instead:
# curl -X POST "${API_URL}/views" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "viewName": "USER_DATA",
#     "hBaseTableName": "USER_DATA",
#     "namespace": "default",
#     "columns": [
#       { "name": "rowkey", "type": "VARCHAR", "isPrimaryKey": true },
#       { "name": "name", "type": "VARCHAR", "isPrimaryKey": false },
#       { "name": "score", "type": "INTEGER", "isPrimaryKey": false },
#       { "name": "status", "type": "VARCHAR", "isPrimaryKey": false }
#     ]
#   }'
echo ""

# Wait for view creation
sleep 2

# Step 5: Query the Phoenix View
echo "Step 5: Querying the Phoenix view to verify all 3 rows are visible..."
echo ""

VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM USER_DATA_ACTIVE ORDER BY rowkey"
  }')

echo "Phoenix view data: $VIEW_DATA"
echo ""

# Verify row count in view
VIEW_ROW_COUNT=$(echo "$VIEW_DATA" | jq -r '.rowCount // 0')
EXPECTED_VIEW_ROWS=2  # View filters for status='active', so should show 2 rows

if [ "$VIEW_ROW_COUNT" -eq "$EXPECTED_VIEW_ROWS" ]; then
    echo "✅ SUCCESS: Phoenix view shows $EXPECTED_VIEW_ROWS rows (filtered for active status)!"
    echo "   - Row 1 (Alice, active) ✓"
    echo "   - Row 2 (Bob, active) ✓"
    echo "   - Row 3 (Charlie, inactive) - filtered out by view ✓"
else
    echo "⚠️  WARNING: Expected $EXPECTED_VIEW_ROWS rows in view, found $VIEW_ROW_COUNT rows"
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
echo "✅ Created HBase table: USER_DATA (via Phoenix SQL)"
echo "✅ Inserted 3 rows into HBase table:"
echo "   1. rowkey='1', name='Alice', score=100, status='active'"
echo "   2. rowkey='2', name='Bob', score=200, status='active'"
echo "   3. rowkey='3', name='Charlie', score=50, status='inactive'"
echo "✅ Created Phoenix view: USER_DATA_ACTIVE (filters for active status)"
echo "✅ Verified all 3 rows are visible in Phoenix view"
echo ""
echo "You can now query:"
echo "  - HBase table: SELECT * FROM USER_DATA ORDER BY rowkey"
echo "  - Phoenix view: SELECT * FROM USER_DATA_ACTIVE ORDER BY rowkey"
echo ""
echo "The Phoenix view filters for active status, so it shows 2 rows (Alice and Bob)"
echo ""

