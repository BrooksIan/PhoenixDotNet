#!/bin/bash

# Create USERS Table Example
# This script demonstrates creating a Phoenix USERS table and inserting sample data

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="users"

echo "=========================================="
echo "Create USERS Table Example"
echo "=========================================="
echo ""

# Step 1: Check current tables (before creation)
echo "Step 1: Current tables (before creation)"
echo ""
BEFORE=$(curl -s "${API_URL}/tables")
echo "$BEFORE" | jq .
echo ""

# Step 2: Create the USERS table
echo "Step 2: Creating Phoenix table 'users'"
echo ""
CREATE_SQL="CREATE TABLE IF NOT EXISTS users (id INTEGER NOT NULL, username VARCHAR(50), email VARCHAR(100), created_date DATE, CONSTRAINT pk_users PRIMARY KEY (id))"

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

# Step 5: Insert sample data
echo "Step 4: Inserting sample data"
echo ""

INSERT1=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (1, '\''john_doe'\'', '\''john@example.com'\'', CURRENT_DATE())"
  }')
echo "Insert 1: $INSERT1" | jq .

INSERT2=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (2, '\''jane_smith'\'', '\''jane@example.com'\'', CURRENT_DATE())"
  }')
echo "Insert 2: $INSERT2" | jq .

INSERT3=$(curl -s -X POST "${API_URL}/execute" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "UPSERT INTO users (id, username, email, created_date) VALUES (3, '\''bob_johnson'\'', '\''bob@example.com'\'', CURRENT_DATE())"
  }')
echo "Insert 3: $INSERT3" | jq .
echo ""

# Step 6: Query the table
echo "Step 5: Querying the USERS table"
echo ""
QUERY_RESPONSE=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM users ORDER BY id"
  }')

echo "$QUERY_RESPONSE" | jq .
echo ""

echo "=========================================="
echo "Done! USERS table created and populated."
echo "=========================================="

