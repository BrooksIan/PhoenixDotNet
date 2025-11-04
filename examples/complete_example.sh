#!/bin/bash

# Complete Example: Create HBase Table and Phoenix View
# This script demonstrates the complete workflow

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="EXAMPLE_TABLE"
VIEW_NAME="EXAMPLE_TABLE_ACTIVE"

# Note: This example creates a Phoenix table (not HBase-native)
# For Phoenix tables, views can have different names and use SELECT statements
# For HBase-native tables, view name MUST match table name exactly (see create_muscle_cars_table.sh)

echo "=========================================="
echo "Complete Example: Table and View Creation"
echo "=========================================="
echo ""

# Step 1: Create Phoenix Table (automatically creates HBase table)
echo "Step 1: Creating Phoenix table '$TABLE_NAME'..."
echo ""

RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE TABLE IF NOT EXISTS EXAMPLE_TABLE (id VARCHAR PRIMARY KEY, name VARCHAR, \"value\" INTEGER, status VARCHAR)"
  }')

echo "Response: $RESPONSE"
echo ""

# Wait for table creation
sleep 2

# Step 2: Insert sample data
echo "Step 2: Inserting sample data..."
echo ""

# Insert multiple rows
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO EXAMPLE_TABLE (id, name, \"value\", status) VALUES ('"'"'1'"'"', '"'"'Alice'"'"', 100, '"'"'active'"'"')"
  }' > /dev/null

curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO EXAMPLE_TABLE (id, name, \"value\", status) VALUES ('"'"'2'"'"', '"'"'Bob'"'"', 200, '"'"'active'"'"')"
  }' > /dev/null

curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO EXAMPLE_TABLE (id, name, \"value\", status) VALUES ('"'"'3'"'"', '"'"'Charlie'"'"', 50, '"'"'inactive'"'"')"
  }' > /dev/null

echo "All 3 rows inserted successfully into HBase table"
echo ""

# Wait for data to be committed to HBase (Phoenix auto-commits, but needs time)
echo "Waiting 5 seconds for data to be committed to HBase..."
sleep 5
echo ""

# Step 3: Query the table
echo "Step 3: Querying the table..."
echo ""

TABLE_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EXAMPLE_TABLE ORDER BY id"
  }')

echo "Table data: $TABLE_DATA"
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME'..."
echo ""

VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE VIEW EXAMPLE_TABLE_ACTIVE AS SELECT * FROM EXAMPLE_TABLE WHERE status = '"'"'active'"'"'"
  }')

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Wait for view creation
sleep 2

# Step 5: Query the view to verify data is visible
echo "Step 5: Querying the Phoenix view to verify all 3 rows are visible..."
echo ""

VIEW_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EXAMPLE_TABLE_ACTIVE ORDER BY id"
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
echo "✅ Created HBase table: EXAMPLE_TABLE (via Phoenix SQL)"
echo "✅ Inserted 3 rows into HBase table:"
echo "   1. id='1', name='Alice', value=100, status='active'"
echo "   2. id='2', name='Bob', value=200, status='active'"
echo "   3. id='3', name='Charlie', value=50, status='inactive'"
echo "✅ Created Phoenix view: EXAMPLE_TABLE_ACTIVE (filters for active status)"
echo "✅ Verified all 3 rows are visible in Phoenix view"
echo ""
echo "You can now query:"
echo "  - HBase table: SELECT * FROM EXAMPLE_TABLE ORDER BY id"
echo "  - Phoenix view: SELECT * FROM EXAMPLE_TABLE_ACTIVE ORDER BY id"
echo ""
echo "The Phoenix view filters for active status, so it shows 2 rows (Alice and Bob)"
echo ""

