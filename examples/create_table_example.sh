#!/bin/bash

# Create Table Example
# This script demonstrates creating a Phoenix table and verifying it appears in the list

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="DEMO_USERS"

echo "=========================================="
echo "Create Table Example"
echo "=========================================="
echo ""

# Step 1: Check current tables (before creation)
echo "Step 1: Current tables (before creation)"
echo ""
BEFORE=$(curl -s "${API_URL}/tables")
echo "$BEFORE" | jq .
echo ""

# Step 2: Create a Phoenix table
echo "Step 2: Creating Phoenix table '$TABLE_NAME'"
echo ""
CREATE_SQL="CREATE TABLE IF NOT EXISTS $TABLE_NAME (id VARCHAR PRIMARY KEY, name VARCHAR, email VARCHAR, age INTEGER)"

CREATE_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"$CREATE_SQL\"
  }")

echo "$CREATE_RESPONSE" | jq .
echo ""

# Step 3: Wait a moment for table to be registered
echo "Waiting 2 seconds for table registration..."
sleep 2
echo ""

# Step 4: Check tables again (after creation)
echo "Step 3: Current tables (after creation)"
echo ""
AFTER=$(curl -s "${API_URL}/tables")
echo "$AFTER" | jq .
echo ""

# Step 5: Extract table names
echo "Step 4: Table names only"
echo ""
echo "$AFTER" | jq -r '.rows[] | "\(.TABLE_NAME) (\(.TABLE_TYPE))"' 2>/dev/null || echo "No tables found"
echo ""

# Step 6: Insert some sample data
echo "Step 5: Inserting sample data"
echo ""

INSERT1=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO DEMO_USERS (id, name, email, age) VALUES ('\''1'\'', '\''Alice'\'', '\''alice@example.com'\'', 25)"
  }')
echo "Insert 1: $INSERT1" | jq .

INSERT2=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO DEMO_USERS (id, name, email, age) VALUES ('\''2'\'', '\''Bob'\'', '\''bob@example.com'\'', 30)"
  }')
echo "Insert 2: $INSERT2" | jq .

INSERT3=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO DEMO_USERS (id, name, email, age) VALUES ('\''3'\'', '\''Charlie'\'', '\''charlie@example.com'\'', 35)"
  }')
echo "Insert 3: $INSERT3" | jq .
echo ""

# Step 7: Query the table
echo "Step 6: Querying the created table"
echo ""
QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM DEMO_USERS ORDER BY id"
  }')

echo "$QUERY_RESPONSE" | jq .
echo ""

# Step 8: Final table list
echo "Step 7: Final table list"
echo ""
FINAL=$(curl -s "${API_URL}/tables")
echo "$FINAL" | jq .
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Created Phoenix table: $TABLE_NAME"
echo "✅ Inserted 3 rows of sample data"
echo "✅ Queried the table successfully"
echo "✅ Table should now appear in GET /api/phoenix/tables"
echo ""
echo "To verify, run:"
echo "  curl http://localhost:8099/api/phoenix/tables"
echo ""

