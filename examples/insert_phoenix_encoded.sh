#!/bin/bash

# Insert data into Phoenix table using Phoenix SQL (UPSERT)
# This script demonstrates the recommended approach for inserting data into Phoenix tables

# IMPORTANT: Direct HBase insertion with Phoenix encoding is NOT practical
# - HBase shell treats escape sequences like \x80 as literal strings, not binary bytes
# - Phoenix's binary encoding requires complex byte manipulation
# - Requires access to Phoenix's internal encoding utilities
# - Not recommended for production use

# RECOMMENDED: Use Phoenix SQL (UPSERT) which:
# - Automatically handles binary encoding
# - Ensures data integrity
# - Provides type safety
# - Works seamlessly with Phoenix queries

echo "=========================================="
echo "Inserting Data into Phoenix Table (USERS)"
echo "=========================================="
echo ""
echo "Using Phoenix SQL (UPSERT) - Recommended Approach"
echo "Phoenix automatically handles binary encoding for row keys, column qualifiers, and values"
echo ""

# Insert using Phoenix SQL (recommended approach)
echo "Inserting rows 4, 5, 6 using Phoenix SQL:"
echo ""

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO users (id, username, email, created_date) VALUES (4, '\''david_wilson'\'', '\''david@example.com'\'', CURRENT_DATE())"}'

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO users (id, username, email, created_date) VALUES (5, '\''emma_brown'\'', '\''emma@example.com'\'', CURRENT_DATE())"}'

curl -X POST http://localhost:8099/api/phoenix/execute \
  -H "Content-Type: application/json" \
  -d '{"sql": "UPSERT INTO users (id, username, email, created_date) VALUES (6, '\''frank_miller'\'', '\''frank@example.com'\'', CURRENT_DATE())"}'

echo ""
echo "✅ Done! Data inserted using Phoenix SQL (which handles encoding automatically)."
echo ""
echo "The data is now binary-encoded and immediately visible in Phoenix queries."
echo ""
echo "To verify the data:"
echo "  curl -X POST http://localhost:8099/api/phoenix/query \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"sql\": \"SELECT * FROM users ORDER BY id\"}' | jq ."
echo ""
echo "To view the binary encoding in HBase:"
echo "  docker-compose exec -T opdb-docker /opt/hbase/bin/hbase shell <<< \"scan 'USERS'\""
echo ""
echo "Note: You'll see binary-encoded row keys (e.g., \\x80\\x00\\x00\\x04 for id=4)"
echo "      and binary-encoded column qualifiers (e.g., \\x80\\x0B for USERNAME)"
echo "      Phoenix queries automatically decode this data for you."

