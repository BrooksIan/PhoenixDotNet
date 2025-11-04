#!/bin/bash

# Enable HBase Thrift and REST Services
# This script starts HBase Thrift and REST services to enable HBase REST API access

echo "=========================================="
echo "Enabling HBase Thrift and REST Services"
echo "=========================================="
echo ""

# Step 1: Start HBase Thrift
echo "Step 1: Starting HBase Thrift service..."
THRIFT_OUTPUT=$(docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start thrift 2>&1)
echo "$THRIFT_OUTPUT"
echo ""

# Step 2: Start HBase REST (Stargate)
echo "Step 2: Starting HBase REST service..."
REST_OUTPUT=$(docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh start rest 2>&1)
echo "$REST_OUTPUT"
echo ""

# Wait for services to start
echo "Waiting 5 seconds for services to initialize..."
sleep 5
echo ""

# Step 3: Verify services are running
echo "Step 3: Verifying services are running..."
echo ""

THRIFT_PROCESS=$(docker exec opdb-docker ps aux | grep -i thrift | grep -v grep | head -1)
if [ -n "$THRIFT_PROCESS" ]; then
    echo "✅ HBase Thrift is running"
    echo "   $THRIFT_PROCESS"
else
    echo "⚠️  HBase Thrift process not found"
fi
echo ""

REST_PROCESS=$(docker exec opdb-docker ps aux | grep -i "rest\|stargate" | grep -v grep | head -1)
if [ -n "$REST_PROCESS" ]; then
    echo "✅ HBase REST is running"
    echo "   $REST_PROCESS"
else
    echo "⚠️  HBase REST process not found"
fi
echo ""

# Step 4: Test HBase REST API
echo "Step 4: Testing HBase REST API..."
echo ""

REST_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" http://localhost:8099/api/phoenix/hbase/tables/TEST_TABLE/exists?namespace=default 2>&1)
HTTP_CODE=$(echo "$REST_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
RESPONSE=$(echo "$REST_RESPONSE" | grep -v "HTTP_CODE")

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ HBase REST API is accessible (HTTP $HTTP_CODE)"
    echo "   Response: $RESPONSE"
else
    echo "⚠️  HBase REST API returned HTTP $HTTP_CODE"
    echo "   Response: $RESPONSE"
fi
echo ""

# Step 5: Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "Services started:"
echo "  - HBase Thrift: $(docker exec opdb-docker ps aux | grep -i thrift | grep -v grep | wc -l | tr -d ' ') process(es)"
echo "  - HBase REST: $(docker exec opdb-docker ps aux | grep -i "rest\|stargate" | grep -v grep | wc -l | tr -d ' ') process(es)"
echo ""
echo "You can now:"
echo "  1. Create HBase tables via HBase REST API"
echo "  2. Insert data via HBase REST API"
echo "  3. Use both HBase shell and REST API"
echo ""
echo "To check service status:"
echo "  docker exec opdb-docker ps aux | grep -E 'thrift|rest'"
echo ""
echo "To stop services:"
echo "  docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh stop thrift"
echo "  docker exec opdb-docker /opt/hbase/bin/hbase-daemon.sh stop rest"
echo ""

