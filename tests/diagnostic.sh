#!/bin/bash

# Diagnostic Script
# Gathers comprehensive diagnostic information about the system

set -e

BASE_URL="${API_BASE_URL:-http://localhost:8099}"
OUTPUT_FILE="${OUTPUT_FILE:-diagnostic_report_$(date +%Y%m%d_%H%M%S).txt}"

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

save_to_file() {
    echo "$1" >> "$OUTPUT_FILE"
}

print_header "System Diagnostic Report"
echo "Generating diagnostic report: $OUTPUT_FILE"
echo ""

# Initialize report file
echo "=== PhoenixDotNet Diagnostic Report ===" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# 1. System Information
print_header "1. System Information"
echo "Collecting system information..."
{
    echo "=== System Information ==="
    echo "Hostname: $(hostname)"
    echo "OS: $(uname -a)"
    echo "Uptime: $(uptime)"
    echo ""
    echo "=== Environment Variables ==="
    env | grep -E "(PHOENIX|HBASE|DOTNET|ASPNET)" | sort
    echo ""
} | tee -a "$OUTPUT_FILE"

# 2. Docker Information
print_header "2. Docker Information"
if command -v docker &> /dev/null; then
    {
        echo "=== Docker Version ==="
        docker --version
        echo ""
        echo "=== Docker Compose Version ==="
        docker-compose --version 2>/dev/null || echo "docker-compose not found"
        echo ""
        echo "=== Running Containers ==="
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo "=== Phoenix Container Logs (last 50 lines) ==="
        docker logs --tail 50 opdb-docker 2>&1 || echo "Container not found"
        echo ""
        echo "=== Application Container Logs (last 50 lines) ==="
        docker logs --tail 50 phoenix-app 2>&1 || docker logs --tail 50 phoenix-dotnet-app 2>&1 || echo "Container not found"
        echo ""
    } | tee -a "$OUTPUT_FILE"
else
    echo "Docker not available" | tee -a "$OUTPUT_FILE"
fi

# 3. Network Connectivity
print_header "3. Network Connectivity"
{
    echo "=== Network Ports ==="
    for port in 8099 8100 8765 8080; do
        if nc -z localhost "$port" 2>/dev/null; then
            echo "Port $port: LISTENING"
        else
            echo "Port $port: NOT LISTENING"
        fi
    done
    echo ""
    echo "=== Network Connections ==="
    netstat -an | grep -E "(8099|8100|8765|8080)" || echo "No connections found"
    echo ""
} | tee -a "$OUTPUT_FILE"

# 4. Application Health
print_header "4. Application Health"
{
    echo "=== Health Check ==="
    curl -s "${BASE_URL}/api/phoenix/health" | jq '.' 2>/dev/null || curl -s "${BASE_URL}/api/phoenix/health"
    echo ""
    echo ""
} | tee -a "$OUTPUT_FILE"

# 5. Phoenix Connection Status
print_header "5. Phoenix Connection Status"
{
    echo "=== Phoenix Server Check ==="
    PHOENIX_SERVER=$(grep -A 2 '"Phoenix"' appsettings.json 2>/dev/null | grep '"Server"' | cut -d'"' -f4 || echo "localhost")
    PHOENIX_PORT=$(grep -A 2 '"Phoenix"' appsettings.json 2>/dev/null | grep '"Port"' | cut -d'"' -f4 || echo "8765")
    echo "Phoenix Server: $PHOENIX_SERVER:$PHOENIX_PORT"
    
    if nc -z "$PHOENIX_SERVER" "$PHOENIX_PORT" 2>/dev/null; then
        echo "Status: CONNECTED"
    else
        echo "Status: NOT CONNECTED"
    fi
    echo ""
    echo "=== Phoenix Tables ==="
    curl -s "${BASE_URL}/api/phoenix/tables" | jq '.' 2>/dev/null || curl -s "${BASE_URL}/api/phoenix/tables"
    echo ""
    echo ""
} | tee -a "$OUTPUT_FILE"

# 6. HBase Connection Status
print_header "6. HBase Connection Status"
{
    echo "=== HBase Server Check ==="
    HBASE_SERVER=$(grep -A 2 '"HBase"' appsettings.json 2>/dev/null | grep '"Server"' | cut -d'"' -f4 || echo "localhost")
    HBASE_PORT=$(grep -A 2 '"HBase"' appsettings.json 2>/dev/null | grep '"Port"' | cut -d'"' -f4 || echo "8080")
    echo "HBase Server: $HBASE_SERVER:$HBASE_PORT"
    
    if nc -z "$HBASE_SERVER" "$HBASE_PORT" 2>/dev/null; then
        echo "Status: CONNECTED"
    else
        echo "Status: NOT CONNECTED (may be normal if REST API not enabled)"
    fi
    echo ""
} | tee -a "$OUTPUT_FILE"

# 7. Configuration Files
print_header "7. Configuration Files"
{
    echo "=== appsettings.json ==="
    cat appsettings.json 2>/dev/null || echo "File not found"
    echo ""
    echo "=== appsettings.Development.json ==="
    cat appsettings.Development.json 2>/dev/null || echo "File not found"
    echo ""
    echo "=== appsettings.Production.json ==="
    cat appsettings.Production.json 2>/dev/null || echo "File not found"
    echo ""
} | tee -a "$OUTPUT_FILE"

# 8. Disk Space
print_header "8. Disk Space"
{
    echo "=== Disk Usage ==="
    df -h . | tail -1
    echo ""
    echo "=== Current Directory Size ==="
    du -sh . 2>/dev/null || echo "Unable to calculate"
    echo ""
} | tee -a "$OUTPUT_FILE"

# 9. Process Information
print_header "9. Process Information"
{
    echo "=== .NET Processes ==="
    ps aux | grep -E "(dotnet|PhoenixDotNet)" | grep -v grep || echo "No .NET processes found"
    echo ""
} | tee -a "$OUTPUT_FILE"

# 10. Recent Errors
print_header "10. Recent Errors"
{
    echo "=== Application Logs (if available) ==="
    if [ -f "logs/application.log" ]; then
        tail -50 logs/application.log | grep -i error || echo "No recent errors found"
    else
        echo "Log file not found"
    fi
    echo ""
} | tee -a "$OUTPUT_FILE"

# 11. API Endpoint Test
print_header "11. API Endpoint Test"
{
    echo "=== Testing API Endpoints ==="
    echo "Health:"
    curl -s "${BASE_URL}/api/phoenix/health" | jq '.' 2>/dev/null || echo "Failed"
    echo ""
    echo "Tables:"
    curl -s "${BASE_URL}/api/phoenix/tables" | jq '.rowCount' 2>/dev/null || echo "Failed"
    echo ""
} | tee -a "$OUTPUT_FILE"

# Summary
print_header "Diagnostic Complete"
echo -e "${GREEN}Diagnostic report saved to: $OUTPUT_FILE${NC}"
echo ""
echo "To share this report:"
echo "  cat $OUTPUT_FILE"
echo ""

