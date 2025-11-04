#!/bin/bash

# Troubleshooting Script
# Automated troubleshooting for common issues

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_issue() {
    echo -e "${YELLOW}Issue: $1${NC}"
}

print_solution() {
    echo -e "${GREEN}Solution: $1${NC}"
}

print_header "Automated Troubleshooting"

ISSUES_FOUND=0

# Check 1: Application not responding
print_header "1. Application Health Check"
if curl -s -f "${BASE_URL}/api/phoenix/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is responding${NC}"
else
    print_issue "Application is not responding at ${BASE_URL}"
    print_solution "Check if the application is running:"
    echo "  - docker-compose ps phoenix-app"
    echo "  - docker-compose logs phoenix-app"
    echo "  - Or check if running locally: ps aux | grep dotnet"
    ((ISSUES_FOUND++))
fi

# Check 2: Phoenix not accessible
print_header "2. Phoenix Connectivity"
PHOENIX_SERVER=$(grep -A 2 '"Phoenix"' appsettings.json 2>/dev/null | grep '"Server"' | cut -d'"' -f4 || echo "localhost")
PHOENIX_PORT=$(grep -A 2 '"Phoenix"' appsettings.json 2>/dev/null | grep '"Port"' | cut -d'"' -f4 || echo "8765")

if nc -z "$PHOENIX_SERVER" "$PHOENIX_PORT" 2>/dev/null; then
    echo -e "${GREEN}✓ Phoenix is accessible on $PHOENIX_SERVER:$PHOENIX_PORT${NC}"
else
    print_issue "Phoenix is not accessible on $PHOENIX_SERVER:$PHOENIX_PORT"
    print_solution "Start Phoenix:"
    echo "  - docker-compose up -d opdb-docker"
    echo "  - Wait 60-90 seconds for initialization"
    echo "  - Check logs: docker-compose logs opdb-docker"
    ((ISSUES_FOUND++))
fi

# Check 3: Tables endpoint failing
print_header "3. Tables Endpoint"
RESPONSE=$(curl -s -w "\n%{http_code}" "${BASE_URL}/api/phoenix/tables")
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Tables endpoint is working${NC}"
else
    print_issue "Tables endpoint returned HTTP $HTTP_CODE"
    print_solution "This may indicate Phoenix connection issues:"
    echo "  1. Verify Phoenix is running and ready"
    echo "  2. Check application logs for connection errors"
    echo "  3. Verify Phoenix configuration in appsettings.json"
    ((ISSUES_FOUND++))
fi

# Check 4: Configuration issues
print_header "4. Configuration Check"
if [ -f "appsettings.json" ]; then
    echo -e "${GREEN}✓ Configuration file exists${NC}"
    
    # Check Phoenix config
    if grep -q '"Phoenix"' appsettings.json; then
        echo -e "${GREEN}✓ Phoenix configuration found${NC}"
    else
        print_issue "Phoenix configuration missing in appsettings.json"
        print_solution "Add Phoenix configuration:"
        echo '  {'
        echo '    "Phoenix": {'
        echo '      "Server": "localhost",'
        echo '      "Port": "8765"'
        echo '    }'
        echo '  }'
        ((ISSUES_FOUND++))
    fi
else
    print_issue "appsettings.json not found"
    print_solution "Create configuration file with Phoenix settings"
    ((ISSUES_FOUND++))
fi

# Check 5: Port conflicts
print_header "5. Port Conflicts"
for port in 8099 8100 8765; do
    if lsof -i :$port > /dev/null 2>&1; then
        PROCESS=$(lsof -i :$port | tail -1 | awk '{print $1 " (PID: " $2 ")"}')
        echo -e "${GREEN}✓ Port $port is in use by: $PROCESS${NC}"
    else
        echo -e "${YELLOW}⚠ Port $port is not in use${NC}"
    fi
done

# Check 6: Docker containers
print_header "6. Docker Containers"
if command -v docker &> /dev/null && docker ps &> /dev/null; then
    if docker ps --format "{{.Names}}" | grep -q "phoenix\|opdb"; then
        echo -e "${GREEN}✓ Phoenix-related containers are running${NC}"
        docker ps --format "  - {{.Names}}: {{.Status}}" | grep -i phoenix
    else
        print_issue "No Phoenix-related containers found"
        print_solution "Start containers:"
        echo "  - docker-compose up -d"
        echo "  - Wait for initialization (60-90 seconds)"
        ((ISSUES_FOUND++))
    fi
else
    echo -e "${YELLOW}⚠ Docker not available or not running${NC}"
fi

# Check 7: Recent errors in logs
print_header "7. Recent Errors"
if docker ps --format "{{.Names}}" | grep -q "phoenix-app"; then
    ERRORS=$(docker logs phoenix-app 2>&1 | tail -100 | grep -i "error\|exception\|fail" | tail -5)
    if [ -z "$ERRORS" ]; then
        echo -e "${GREEN}✓ No recent errors in application logs${NC}"
    else
        print_issue "Recent errors found in application logs"
        echo "$ERRORS"
        print_solution "Review full logs: docker-compose logs phoenix-app"
        ((ISSUES_FOUND++))
    fi
fi

# Check 8: Phoenix Query Server readiness
print_header "8. Phoenix Query Server Readiness"
if nc -z "$PHOENIX_SERVER" "$PHOENIX_PORT" 2>/dev/null; then
    # Try to connect
    TEST_RESPONSE=$(curl -s -X POST "http://${PHOENIX_SERVER}:${PHOENIX_PORT}/json" \
        -H "Content-Type: application/json" \
        -d '{"request":"openConnection","connectionId":"test","info":{}}' 2>&1)
    
    if echo "$TEST_RESPONSE" | grep -q "error\|exception"; then
        print_issue "Phoenix Query Server may not be fully ready"
        print_solution "Wait a few more seconds and try again"
        ((ISSUES_FOUND++))
    else
        echo -e "${GREEN}✓ Phoenix Query Server appears ready${NC}"
    fi
fi

# Summary
print_header "Troubleshooting Summary"
if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}✓ No issues found!${NC}"
    echo "The system appears to be functioning correctly."
else
    echo -e "${YELLOW}Found $ISSUES_FOUND potential issue(s)${NC}"
    echo "Review the suggestions above to resolve them."
    echo ""
    echo "For more detailed diagnostics, run:"
    echo "  ./tests/diagnostic.sh"
fi

