#!/bin/bash

# Create sample table and data for GUI testing
# This script creates a simple table and inserts data so it appears in the GUI

API_URL="http://localhost:8099/api/phoenix"

echo "=========================================="
echo "Creating Sample Table and Data"
echo "=========================================="
echo ""

# Step 1: Create table
echo "Step 1: Creating demo_table..."
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "CREATE TABLE IF NOT EXISTS demo_table (id VARCHAR PRIMARY KEY, name VARCHAR, score INTEGER)"
  }' | jq .
echo ""

# Wait for table creation
sleep 2

# Step 2: Insert 3 rows
echo "Step 2: Inserting 3 rows..."
echo ""

echo "Inserting row 1: id='1', name='Alice', score=100"
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO demo_table VALUES ('"'"'1'"'"', '"'"'Alice'"'"', 100)"
  }' | jq .
echo ""

echo "Inserting row 2: id='2', name='Bob', score=200"
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO demo_table VALUES ('"'"'2'"'"', '"'"'Bob'"'"', 200)"
  }' | jq .
echo ""

echo "Inserting row 3: id='3', name='Charlie', score=150"
curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO demo_table VALUES ('"'"'3'"'"', '"'"'Charlie'"'"', 150)"
  }' | jq .
echo ""

# Wait for data to be committed
echo "Waiting 5 seconds for data to be committed..."
sleep 5
echo ""

# Step 3: Verify data
echo "Step 3: Verifying data..."
echo ""

TABLE_DATA=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM DEMO_TABLE ORDER BY id"
  }')

echo "Table data: $TABLE_DATA"
echo ""

# Step 4: List tables
echo "Step 4: Listing tables..."
echo ""

TABLES=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT TABLE_NAME FROM SYSTEM.CATALOG WHERE TABLE_TYPE = '"'"'u'"'"' ORDER BY TABLE_NAME"
  }')

echo "Tables: $TABLES"
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "You can now:"
echo "1. Open the GUI at http://localhost:8100"
echo "2. Click 'List Tables' to see the table"
echo "3. Run: SELECT * FROM DEMO_TABLE ORDER BY id"
echo ""

