#!/bin/bash

# Phoenix Query Examples
# This script demonstrates various ways to query Phoenix

API_URL="http://localhost:8099/api/phoenix"
TABLE_NAME="EMPLOYEE_DATA"

echo "=========================================="
echo "Phoenix Query Examples"
echo "=========================================="
echo ""

# Example 1: Query HBase Table Directly - Get All Rows
echo "Example 1: Query HBase Table Directly - Get All Rows"
echo ""
RESPONSE1=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name, \\\"info\\\".\\\"score\\\" as score, \\\"contact\\\".\\\"email\\\" as email, \\\"status\\\".\\\"status\\\" as status FROM \\\"$TABLE_NAME\\\" ORDER BY rowkey\"
  }")

echo "Response: $RESPONSE1"
echo ""

# Example 2: Query with WHERE Clause - Filter Active Status
echo "Example 2: Query with WHERE Clause - Filter Active Status"
echo ""
RESPONSE2=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name, \\\"info\\\".\\\"score\\\" as score FROM \\\"$TABLE_NAME\\\" WHERE \\\"status\\\".\\\"status\\\" = 'active' ORDER BY rowkey\"
  }")

echo "Response: $RESPONSE2"
echo ""

# Example 3: Query with LIMIT
echo "Example 3: Query with LIMIT"
echo ""
RESPONSE3=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name FROM \\\"$TABLE_NAME\\\" ORDER BY rowkey LIMIT 2\"
  }")

echo "Response: $RESPONSE3"
echo ""

# Example 4: Query with COUNT
echo "Example 4: Query with COUNT - Total Rows"
echo ""
RESPONSE4=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT COUNT(*) as total FROM \\\"$TABLE_NAME\\\"\"
  }")

echo "Response: $RESPONSE4"
echo ""

# Example 5: Query with GROUP BY
echo "Example 5: Query with GROUP BY - Count by Status"
echo ""
RESPONSE5=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT \\\"status\\\".\\\"status\\\" as status, COUNT(*) as count FROM \\\"$TABLE_NAME\\\" GROUP BY \\\"status\\\".\\\"status\\\"\"
  }")

echo "Response: $RESPONSE5"
echo ""

# Example 6: Query with Aggregation - AVG
echo "Example 6: Query with Aggregation - Average Score by Status"
echo ""
RESPONSE6=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT \\\"status\\\".\\\"status\\\" as status, COUNT(*) as count, AVG(\\\"info\\\".\\\"score\\\") as avg_score FROM \\\"$TABLE_NAME\\\" GROUP BY \\\"status\\\".\\\"status\\\"\"
  }")

echo "Response: $RESPONSE6"
echo ""

# Example 7: Query with WHERE and ORDER BY
echo "Example 7: Query with WHERE and ORDER BY - Active Employees Sorted by Score"
echo ""
RESPONSE7=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name, \\\"info\\\".\\\"score\\\" as score FROM \\\"$TABLE_NAME\\\" WHERE \\\"status\\\".\\\"status\\\" = 'active' ORDER BY \\\"info\\\".\\\"score\\\" DESC\"
  }")

echo "Response: $RESPONSE7"
echo ""

# Example 8: Query Phoenix View (if exists)
echo "Example 8: Query Phoenix View (if exists)"
echo ""
RESPONSE8=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM EMPLOYEE_DATA ORDER BY rowkey"
  }')

echo "Response: $RESPONSE8"
echo ""

# Example 9: Query with BETWEEN
echo "Example 9: Query with BETWEEN - Score Range"
echo ""
RESPONSE9=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name, \\\"info\\\".\\\"score\\\" as score FROM \\\"$TABLE_NAME\\\" WHERE \\\"info\\\".\\\"score\\\" BETWEEN 100 AND 200 ORDER BY rowkey\"
  }")

echo "Response: $RESPONSE9"
echo ""

# Example 10: Query with LIKE
echo "Example 10: Query with LIKE - Name Pattern"
echo ""
RESPONSE10=$(curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d "{
    \"sql\": \"SELECT rowkey, \\\"info\\\".\\\"name\\\" as name FROM \\\"$TABLE_NAME\\\" WHERE \\\"info\\\".\\\"name\\\" LIKE 'A%' ORDER BY rowkey\"
  }")

echo "Response: $RESPONSE10"
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ Example 1: Get all rows from HBase table"
echo "✅ Example 2: Filter with WHERE clause"
echo "✅ Example 3: Limit results"
echo "✅ Example 4: Count rows"
echo "✅ Example 5: Group by status"
echo "✅ Example 6: Aggregation (AVG)"
echo "✅ Example 7: WHERE + ORDER BY"
echo "✅ Example 8: Query Phoenix view"
echo "✅ Example 9: BETWEEN range"
echo "✅ Example 10: LIKE pattern matching"
echo ""
echo "All queries use the endpoint: POST /api/phoenix/query"
echo "GUI available at: http://localhost:8100"
echo ""

