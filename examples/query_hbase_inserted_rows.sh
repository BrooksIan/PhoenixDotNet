#!/bin/bash

# Query HBase-Inserted Rows from Phoenix Tables
# This script demonstrates how to query rows that were inserted directly via HBase shell
# into a Phoenix table (which uses different encoding than Phoenix SQL inserts)

API_URL="http://localhost:8099/api/phoenix"

echo "=========================================="
echo "Querying HBase-Inserted Rows"
echo "=========================================="
echo ""
echo "NOTE: Rows inserted via HBase shell into Phoenix tables use readable text format"
echo "and are NOT visible in Phoenix SQL queries. Use HBase shell to query them."
echo ""

# Query via HBase shell (direct access)
echo "Querying rows 10 and 11 via HBase shell:"
echo ""
docker exec -i opdb-docker /opt/hbase/bin/hbase shell <<'EOF'
echo "Row 10:"
scan 'USERS', {ROWPREFIXFILTER => '10'}
echo ""
echo "Row 11:"
scan 'USERS', {ROWPREFIXFILTER => '11'}
EOF

echo ""
echo "=========================================="
echo "Alternative: Query via Phoenix SQL (won't see HBase-inserted rows)"
echo "=========================================="
echo ""
echo "Rows inserted via Phoenix SQL (binary-encoded):"
curl -s -X POST "${API_URL}/query" \
  -H "Content-Type: application/json" \
  -d '{
    "sql": "SELECT * FROM users ORDER BY id LIMIT 10"
  }' | jq '.rows[] | {id: .ID, username: .USERNAME, email: .EMAIL}'

echo ""
echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "✅ HBase shell inserts: Rows 10, 11 (visible in HBase shell, NOT in Phoenix SQL)"
echo "✅ Phoenix SQL inserts: Rows 1-9 (visible in Phoenix SQL, binary-encoded in HBase)"
echo ""
echo "⚠️  IMPORTANT: Phoenix views cannot be created on Phoenix tables."
echo "   Phoenix views are designed for HBase-native tables (created via HBase shell)."
echo ""
echo "📝 Recommendation:"
echo "   - For Phoenix tables: Always use Phoenix SQL (UPSERT) to insert data"
echo "   - For HBase-native tables: Use HBase shell to insert, then create Phoenix views"
echo ""

