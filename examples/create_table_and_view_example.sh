#!/bin/bash

# Example: Create HBase Table and Phoenix View
# This script demonstrates how to create an HBase table and a Phoenix view on top of it

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="USER_ACTIVITY"
VIEW_NAME="USER_ACTIVITY"
NAMESPACE="default"

# ⚠️ CRITICAL: View names MUST be UPPERCASE and MUST match HBase table name exactly

echo "=========================================="
echo "Creating HBase Table and Phoenix View"
echo "=========================================="
echo ""

# Step 1: Create HBase Table
echo "Step 1: Creating HBase table '$TABLE_NAME'..."
echo ""

RESPONSE=$(curl -s -X POST "${API_URL}/hbase/tables/sensor" \
  -H "Content-Type: application/json" \
  -d "{
    \"tableName\": \"${TABLE_NAME}\",
    \"namespace\": \"${NAMESPACE}\"
  }")

echo "Response: $RESPONSE"
echo ""

# Wait a moment for table to be created
sleep 2

# Step 2: Verify HBase Table Exists
echo "Step 2: Verifying HBase table exists..."
echo ""

EXISTS=$(curl -s "${API_URL}/hbase/tables/${TABLE_NAME}/exists?namespace=${NAMESPACE}")
echo "Table exists check: $EXISTS"
echo ""

# Step 3: Get HBase Table Schema
echo "Step 3: Getting HBase table schema..."
echo ""

SCHEMA=$(curl -s "${API_URL}/hbase/tables/${TABLE_NAME}/schema?namespace=${NAMESPACE}")
echo "Schema: $SCHEMA"
echo ""

# Step 4: Create Phoenix View
echo "Step 4: Creating Phoenix view '$VIEW_NAME'..."
echo "⚠️ IMPORTANT: View name must be UPPERCASE and match HBase table name exactly"
echo ""

# Option A: Using the new dedicated /views endpoint (recommended)
echo "Using the new /api/phoenix/views endpoint..."
VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/views" \
  -H "Content-Type: application/json" \
  -d "{
    \"viewName\": \"${VIEW_NAME}\",
    \"hBaseTableName\": \"${TABLE_NAME}\",
    \"namespace\": \"${NAMESPACE}\",
    \"columns\": [
      { \"name\": \"rowkey\", \"type\": \"VARCHAR\", \"isPrimaryKey\": true },
      { \"name\": \"sensor_type\", \"type\": \"VARCHAR\", \"isPrimaryKey\": false },
      { \"name\": \"timestamp\", \"type\": \"BIGINT\", \"isPrimaryKey\": false },
      { \"name\": \"temperature\", \"type\": \"DOUBLE\", \"isPrimaryKey\": false },
      { \"name\": \"humidity\", \"type\": \"DOUBLE\", \"isPrimaryKey\": false },
      { \"name\": \"status\", \"type\": \"VARCHAR\", \"isPrimaryKey\": false }
    ]
  }")

echo "View creation response: $VIEW_RESPONSE"
echo ""

# Alternative Option B: Using the /execute endpoint with raw SQL
# Uncomment below to use the old method:
# VIEW_SQL="CREATE VIEW IF NOT EXISTS ${VIEW_NAME} (
#     rowkey VARCHAR PRIMARY KEY,
#     sensor_type VARCHAR,
#     timestamp BIGINT,
#     temperature DOUBLE,
#     humidity DOUBLE,
#     status VARCHAR
# ) AS SELECT * FROM \"${NAMESPACE}:${TABLE_NAME}\""
# 
# VIEW_RESPONSE=$(curl -s -X POST "${API_URL}/execute" \
#   -H "Content-Type: application/json" \
#   -d "{
#     \"sql\": \"${VIEW_SQL}\"
#   }")
# 
# echo "View creation response: $VIEW_RESPONSE"
# echo ""

# Step 5: Verify View Creation
echo "Step 5: Verifying Phoenix view exists..."
echo ""

TABLES=$(curl -s "${API_URL}/tables")
echo "All tables (including views): $TABLES"
echo ""

# Step 6: Get View Columns
echo "Step 6: Getting view columns..."
echo ""

COLUMNS=$(curl -s "${API_URL}/tables/${VIEW_NAME}/columns")
echo "View columns: $COLUMNS"
echo ""

echo "=========================================="
echo "Done!"
echo "=========================================="
echo ""
echo "You can now query the view using:"
echo "  curl -X POST ${API_URL}/query -H 'Content-Type: application/json' -d '{\"sql\": \"SELECT * FROM ${VIEW_NAME} LIMIT 10\"}'"
echo ""
echo "Note: The new /api/phoenix/views endpoint automatically:"
echo "  - Validates that the HBase table exists"
echo "  - Generates the CREATE VIEW SQL statement"
echo "  - Maps Phoenix columns to HBase table structure"
echo ""

