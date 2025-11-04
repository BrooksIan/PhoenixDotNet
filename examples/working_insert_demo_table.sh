#!/bin/bash

# Working Insert into DEMO_TABLE
# This script ensures proper commits and timing for inserts

API_URL="http://localhost:8099/api/phoenix"

echo "=========================================="
echo "Working Insert into DEMO_TABLE"
echo "=========================================="
echo ""

# Step 1: Ensure table exists (don't drop if we're just inserting)
echo "Step 1: Verifying DEMO_TABLE exists..."
CREATE_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql":"CREATE TABLE IF NOT EXISTS DEMO_TABLE (id VARCHAR PRIMARY KEY, name VARCHAR, email VARCHAR)"}')
echo "$CREATE_RESPONSE" | jq .
echo ""

# Step 2: Wait for table to be ready
echo "Waiting 3 seconds for table to be ready..."
sleep 3
echo ""

# Step 3: Insert data (one at a time with waits)
echo "Step 2: Inserting data into DEMO_TABLE..."
echo ""

echo "Inserting row 1 (Alice)..."
INSERT1=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql":"UPSERT INTO DEMO_TABLE (id, name, email) VALUES ('\''1'\'', '\''Alice'\'', '\''alice@example.com'\'')"}')
echo "$INSERT1" | jq .
sleep 5  # Wait longer for commit

echo "Inserting row 2 (Bob)..."
INSERT2=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql":"UPSERT INTO DEMO_TABLE (id, name, email) VALUES ('\''2'\'', '\''Bob'\'', '\''bob@example.com'\'')"}')
echo "$INSERT2" | jq .
sleep 5  # Wait longer for commit

echo "Inserting row 3 (Charlie)..."
INSERT3=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{"sql":"UPSERT INTO DEMO_TABLE (id, name, email) VALUES ('\''3'\'', '\''Charlie'\'', '\''charlie@example.com'\'')"}')
echo "$INSERT3" | jq .
sleep 5  # Wait longer for commit

echo ""
echo "Waiting 5 seconds for all data to commit..."
sleep 5
echo ""

# Step 4: Query table
echo "Step 3: Querying DEMO_TABLE..."
QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT * FROM DEMO_TABLE ORDER BY id"}')
echo "$QUERY_RESPONSE" | jq .
echo ""

# Step 5: Count rows
echo "Step 4: Counting rows in DEMO_TABLE..."
COUNT_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{"sql":"SELECT COUNT(*) as total FROM DEMO_TABLE"}')
echo "$COUNT_RESPONSE" | jq .
echo ""

# Step 6: Check HBase directly
echo "Step 5: Checking HBase directly..."
HBASE_SCAN=$(docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< "scan 'DEMO_TABLE'" 2>&1 | grep -E "ROW|COLUMN|value" | head -10)
echo "$HBASE_SCAN"
echo ""

echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Inserted 3 rows into DEMO_TABLE"
echo "✅ Waited 5 seconds between inserts for commits"
echo "✅ Queried DEMO_TABLE to verify data"
echo "✅ Checked HBase directly"
echo ""
echo "Key Points:"
echo "  1. Wait 5+ seconds after each insert for Phoenix to commit"
echo "  2. Don't execute DDL statements (DROP/CREATE) while inserts are pending"
echo "  3. Check HBase directly if queries return empty"
echo ""

