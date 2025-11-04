#!/bin/bash

# Verification Script: Phoenix Query Server Readiness
# This script verifies whether Phoenix Query Server is ready or not ready

set -e

PHOENIX_SERVER="${PHOENIX_SERVER:-localhost}"
PHOENIX_PORT="${PHOENIX_PORT:-8765}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ISSUES=0
READY=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Phoenix Query Server Readiness Check${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Check 1: Container Status
echo -e "${BLUE}1. Container Status${NC}"
if docker ps --format "{{.Names}}" | grep -q "opdb-docker"; then
    CONTAINER_STATUS=$(docker ps --format "{{.Names}}: {{.Status}}" | grep "opdb-docker")
    echo -e "${GREEN}✓ Container is running: ${CONTAINER_STATUS}${NC}"
else
    echo -e "${RED}✗ Container 'opdb-docker' is not running${NC}"
    echo "  Phoenix Query Server is NOT ready (container not running)"
    ((ISSUES++))
    READY=1
fi

# Check 2: Port Accessibility
echo -e "\n${BLUE}2. Port Accessibility (${PHOENIX_SERVER}:${PHOENIX_PORT})${NC}"
if nc -z "$PHOENIX_SERVER" "$PHOENIX_PORT" 2>/dev/null; then
    echo -e "${GREEN}✓ Port ${PHOENIX_PORT} is open and accessible${NC}"
else
    echo -e "${RED}✗ Port ${PHOENIX_PORT} is not accessible${NC}"
    echo "  Phoenix Query Server is NOT ready (port not accessible)"
    ((ISSUES++))
    READY=1
fi

# Check 3: HTTP Endpoint Response
echo -e "\n${BLUE}3. HTTP Endpoint Response${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://${PHOENIX_SERVER}:${PHOENIX_PORT}/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" != "000" ]; then
    echo -e "${GREEN}✓ HTTP endpoint responds (HTTP ${HTTP_CODE})${NC}"
else
    echo -e "${YELLOW}⚠ HTTP endpoint does not respond to root path${NC}"
    echo "  (This may be normal - Phoenix Query Server uses specific endpoints)"
fi

# Check 4: JSON Endpoint - Basic Connectivity
echo -e "\n${BLUE}4. JSON Endpoint - Basic Connectivity${NC}"
JSON_RESPONSE=$(curl -s -X POST "http://${PHOENIX_SERVER}:${PHOENIX_PORT}/json" \
    -H "Content-Type: application/json" \
    -d '{"request":"openConnection","connectionId":"verify-test-connection","info":{}}' \
    -w "\nHTTP_CODE:%{http_code}" 2>&1)

HTTP_CODE=$(echo "$JSON_RESPONSE" | grep "HTTP_CODE" | cut -d: -f2)
if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ JSON endpoint responds with HTTP 200${NC}"
    if echo "$JSON_RESPONSE" | grep -q '"response":"openConnection"'; then
        echo -e "${GREEN}✓ OpenConnection request succeeded${NC}"
    else
        echo -e "${YELLOW}⚠ Response received but format may be unexpected${NC}"
        echo "  Response preview: $(echo "$JSON_RESPONSE" | grep -v "HTTP_CODE" | head -c 100)"
    fi
else
    echo -e "${RED}✗ JSON endpoint failed (HTTP ${HTTP_CODE})${NC}"
    echo "  Phoenix Query Server is NOT ready (cannot connect via JSON endpoint)"
    echo "  Error response: $(echo "$JSON_RESPONSE" | grep -v "HTTP_CODE" | head -c 200)"
    ((ISSUES++))
    READY=1
fi

# Check 5: Check for Error Responses
echo -e "\n${BLUE}5. Error Detection${NC}"
if echo "$JSON_RESPONSE" | grep -qi "error\|exception\|fail"; then
    echo -e "${YELLOW}⚠ Response contains error indicators${NC}"
    ERROR_MSG=$(echo "$JSON_RESPONSE" | grep -i "error\|exception" | head -1 | head -c 150)
    echo "  Error: ${ERROR_MSG}"
    if echo "$JSON_RESPONSE" | grep -qi "InvalidProtocolBufferException\|InvalidWireTypeException"; then
        echo -e "${YELLOW}⚠ Protocol mismatch detected (Protobuf vs JSON)${NC}"
        echo "  This may indicate Phoenix Query Server is not properly configured for JSON"
    fi
else
    echo -e "${GREEN}✓ No error indicators in response${NC}"
fi

# Check 6: Process Status (if container is accessible)
echo -e "\n${BLUE}6. Phoenix Query Server Process${NC}"
if docker ps --format "{{.Names}}" | grep -q "opdb-docker"; then
    if docker exec opdb-docker ps aux 2>/dev/null | grep -q "QueryServer"; then
        echo -e "${GREEN}✓ Phoenix Query Server process is running${NC}"
    else
        echo -e "${RED}✗ Phoenix Query Server process not found in container${NC}"
        echo "  Phoenix Query Server is NOT ready (process not running)"
        ((ISSUES++))
        READY=1
    fi
else
    echo -e "${YELLOW}⚠ Cannot check process (container not accessible)${NC}"
fi

# Check 7: Recent Logs Check
echo -e "\n${BLUE}7. Recent Logs Check${NC}"
if docker ps --format "{{.Names}}" | grep -q "opdb-docker"; then
    RECENT_LOGS=$(docker logs opdb-docker 2>&1 | tail -20 | grep -i "phoenix\|query\|server\|ready\|started\|error" || echo "")
    if [ -n "$RECENT_LOGS" ]; then
        echo "  Recent relevant log entries:"
        echo "$RECENT_LOGS" | head -5 | sed 's/^/    /'
    else
        echo -e "${YELLOW}⚠ No recent Phoenix-related log entries found${NC}"
    fi
fi

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

if [ $READY -eq 0 ] && [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Phoenix Query Server appears to be READY${NC}"
    echo ""
    echo "All checks passed:"
    echo "  - Container is running"
    echo "  - Port is accessible"
    echo "  - JSON endpoint responds correctly"
    echo "  - No error indicators detected"
    exit 0
elif [ $READY -eq 1 ]; then
    echo -e "${RED}✗ Phoenix Query Server is NOT READY${NC}"
    echo ""
    echo "Found $ISSUES issue(s) that prevent readiness:"
    echo "  - Review the checks above for details"
    echo ""
    echo "Common causes:"
    echo "  - Container not started or crashed"
    echo "  - Port not accessible (firewall/network issue)"
    echo "  - Phoenix Query Server not fully initialized (wait 60-90 seconds)"
    echo "  - Configuration issue (JSON endpoint not enabled)"
    echo ""
    echo "To troubleshoot:"
    echo "  docker-compose logs opdb-docker"
    echo "  docker-compose ps opdb-docker"
    exit 1
else
    echo -e "${YELLOW}⚠ Phoenix Query Server status is UNCLEAR${NC}"
    echo ""
    echo "Some checks passed but there may be issues:"
    echo "  - Review the detailed output above"
    echo "  - Check logs: docker-compose logs opdb-docker"
    exit 2
fi

