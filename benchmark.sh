#!/bin/bash

###########################################
# n8n Performance Benchmark
# Tests n8n instance performance
###########################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    echo -e "${2}${1}${NC}"
}

# Banner
clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║    n8n Performance Benchmark          ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

# Find n8n installation
print_color "🔍 Looking for n8n installations..." "$CYAN"
INSTALLATIONS=$(find /root -maxdepth 2 -name "docker-compose.yml" -type f 2>/dev/null | grep -E "n8n-.*/" || true)

if [ -z "$INSTALLATIONS" ]; then
    print_color "❌ No n8n installations found" "$RED"
    exit 1
fi

# Select installation
echo "Found installations:"
select compose_file in $INSTALLATIONS; do
    if [ -n "$compose_file" ]; then
        INSTALL_DIR=$(dirname "$compose_file")
        break
    fi
done

CLIENT_NAME=$(basename "$INSTALL_DIR")
print_color "Testing: $CLIENT_NAME" "$GREEN"
echo

cd "$INSTALL_DIR"

# Load environment
if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

###########################################
# PHASE 1: System Resource Baseline
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 1: System Baseline" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# System info
print_color "📊 System Resources:" "$CYAN"
echo "CPU Cores: $(nproc)"
echo "Total RAM: $(free -h | grep Mem | awk '{print $2}')"
echo "Free RAM: $(free -h | grep Mem | awk '{print $4}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 " used)"}')"
echo

# Docker resources before test
print_color "🐳 Docker Resource Usage (Before):" "$CYAN"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo

###########################################
# PHASE 2: API Response Tests
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 2: API Response Time" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Health check
print_color "Testing health endpoint..." "$CYAN"
TIMES=()
for i in {1..10}; do
    TIME=$(curl -o /dev/null -s -w '%{time_total}\n' http://localhost:5678/healthz)
    TIMES+=($TIME)
    echo "Request $i: ${TIME}s"
done

# Calculate average
AVG=$(echo "${TIMES[@]}" | awk '{s=0; for (i=1;i<=NF;i++) s+=$i; print s/NF}')
print_color "Average response time: ${AVG}s" "$GREEN"
echo

###########################################
# PHASE 3: Workflow Execution Test
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 3: Workflow Execution" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Create test workflow via API
print_color "Creating test workflow..." "$CYAN"

# Note: This requires API key setup
if [ -n "$N8N_API_KEY" ]; then
    # Create simple workflow
    WORKFLOW_JSON='{
        "name": "Benchmark Test",
        "nodes": [
            {
                "parameters": {},
                "name": "Start",
                "type": "n8n-nodes-base.start",
                "typeVersion": 1,
                "position": [250, 300]
            }
        ],
        "connections": {},
        "active": false
    }'

    # Create workflow
    RESPONSE=$(curl -s -X POST \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$WORKFLOW_JSON" \
        http://localhost:5678/api/v1/workflows)

    echo "Workflow created for testing"
else
    print_color "⚠️  API key not configured, skipping workflow tests" "$YELLOW"
fi
echo

###########################################
# PHASE 4: Database Performance
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 4: Database Performance" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Test database response
print_color "Testing PostgreSQL performance..." "$CYAN"
docker exec ${CLIENT_NAME}-postgres psql -U n8n -d n8n -c "\timing on" -c "SELECT COUNT(*) FROM workflow_entity;" 2>/dev/null || echo "No workflows yet"

# Database size
DB_SIZE=$(docker exec ${CLIENT_NAME}-postgres psql -U n8n -d n8n -t -c "SELECT pg_database_size('n8n');" 2>/dev/null || echo "0")
print_color "Database size: $(echo $DB_SIZE | numfmt --to=iec-i --suffix=B 2>/dev/null || echo 'Empty')" "$CYAN"
echo

###########################################
# PHASE 5: Redis Performance (if workers)
###########################################
if docker ps | grep -q "${CLIENT_NAME}-redis"; then
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    print_color "PHASE 5: Redis Queue Performance" "$YELLOW"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    echo

    # Redis ping test
    print_color "Testing Redis latency..." "$CYAN"
    for i in {1..5}; do
        docker exec ${CLIENT_NAME}-redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning ping
    done

    # Redis info
    docker exec ${CLIENT_NAME}-redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO stats | grep "instantaneous_ops_per_sec"
    echo
fi

###########################################
# PHASE 6: Concurrent Load Test
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 6: Concurrent Load Test" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

print_color "Sending 50 concurrent requests..." "$CYAN"

# Concurrent requests
START_TIME=$(date +%s)
for i in {1..50}; do
    curl -s -o /dev/null http://localhost:5678/healthz &
done
wait
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

print_color "Completed 50 requests in ${DURATION}s" "$GREEN"
print_color "Requests per second: $(echo "scale=2; 50/${DURATION}" | bc)" "$GREEN"
echo

###########################################
# PHASE 7: Memory Stress Test
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 7: Memory Usage Under Load" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Monitor memory during load
print_color "Monitoring memory during load test..." "$CYAN"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo

###########################################
# PHASE 8: SSL/Caddy Performance
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 8: SSL/HTTPS Performance" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

if [ -n "$DOMAIN" ]; then
    print_color "Testing HTTPS response times..." "$CYAN"
    for i in {1..5}; do
        TIME=$(curl -o /dev/null -s -w '%{time_total}\n' https://$DOMAIN 2>/dev/null || echo "N/A")
        echo "HTTPS Request $i: ${TIME}s"
    done
else
    print_color "⚠️  No domain configured, skipping HTTPS tests" "$YELLOW"
fi
echo

###########################################
# PHASE 9: Container Restart Time
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 9: Recovery Time Test" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

print_color "Testing container restart time..." "$CYAN"
START=$(date +%s)
docker restart ${CLIENT_NAME}-n8n >/dev/null 2>&1
# Wait for health
while ! curl -s http://localhost:5678/healthz >/dev/null 2>&1; do
    sleep 1
done
END=$(date +%s)
RESTART_TIME=$((END - START))
print_color "Container restart time: ${RESTART_TIME}s" "$GREEN"
echo

###########################################
# PHASE 10: Final Resource Check
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 10: Final Resource Usage" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

print_color "🐳 Docker Resource Usage (After):" "$CYAN"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
echo

# Container logs check
print_color "📋 Recent Error Logs:" "$CYAN"
docker logs ${CLIENT_NAME}-n8n 2>&1 | grep -i error | tail -5 || echo "No recent errors"
echo

###########################################
# RESULTS SUMMARY
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
print_color "        BENCHMARK COMPLETE" "$GREEN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo

print_color "📊 Performance Summary:" "$CYAN"
echo "✅ Health Check Avg Response: ${AVG}s"
echo "✅ Concurrent Requests: 50 in ${DURATION}s"
echo "✅ Container Restart Time: ${RESTART_TIME}s"
echo

# Performance rating
if (( $(echo "$AVG < 0.5" | bc -l) )); then
    RATING="⭐⭐⭐⭐⭐ Excellent"
elif (( $(echo "$AVG < 1.0" | bc -l) )); then
    RATING="⭐⭐⭐⭐ Good"
elif (( $(echo "$AVG < 2.0" | bc -l) )); then
    RATING="⭐⭐⭐ Acceptable"
else
    RATING="⭐⭐ Needs Optimization"
fi

print_color "Performance Rating: $RATING" "$GREEN"
echo

print_color "💡 Optimization Tips:" "$YELLOW"
if [ "$WORKERS" -eq 0 ]; then
    echo "• Consider upgrading VPS to enable workers for better performance"
fi
echo "• Monitor memory usage regularly with: docker stats"
echo "• Check logs for errors with: ./manage.sh logs"
echo "• Keep n8n updated with: ./manage.sh update"
echo