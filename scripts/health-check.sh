#!/bin/bash

###########################################
# n8n Health Check Script
# Monitors service status and health
###########################################

set -e

# Configuration
N8N_DIR="${N8N_DIR:-$HOME/n8n}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Functions
print_status() {
    if [ "$2" = "OK" ]; then
        echo -e "${GREEN}✅ $1: OK${NC}"
    elif [ "$2" = "WARNING" ]; then
        echo -e "${YELLOW}⚠️  $1: WARNING${NC}"
    else
        echo -e "${RED}❌ $1: FAILED${NC}"
    fi
}

print_message() {
    echo -e "${2}${1}${NC}"
}

# Change to n8n directory
cd "$N8N_DIR" 2>/dev/null || {
    print_message "Error: n8n not installed at $N8N_DIR" "$RED"
    exit 1
}

print_message "n8n Health Check Report" "$CYAN"
echo "================================"

# Check Docker
if command -v docker &> /dev/null; then
    print_status "Docker" "OK"
else
    print_status "Docker" "FAILED"
    exit 1
fi

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    print_status "Docker Compose" "OK"
else
    print_status "Docker Compose" "FAILED"
    exit 1
fi

# Check PostgreSQL
if docker exec n8n-postgres-1 pg_isready -U n8n &> /dev/null; then
    print_status "PostgreSQL" "OK"

    # Get database size
    DB_SIZE=$(docker exec n8n-postgres-1 psql -U n8n -d n8n -t -c "SELECT pg_size_pretty(pg_database_size('n8n'));" 2>/dev/null | tr -d ' ')
    echo "  Database size: $DB_SIZE"
else
    print_status "PostgreSQL" "FAILED"
fi

# Check Redis (if exists)
if docker ps | grep -q redis; then
    if docker exec n8n-redis-1 redis-cli ping &> /dev/null; then
        print_status "Redis" "OK"

        # Get Redis info
        REDIS_MEM=$(docker exec n8n-redis-1 redis-cli INFO memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        echo "  Memory usage: $REDIS_MEM"
    else
        print_status "Redis" "FAILED"
    fi
fi

# Check n8n
if curl -s http://localhost:5678/healthz &> /dev/null; then
    print_status "n8n" "OK"

    # Get n8n version
    N8N_VERSION=$(docker exec n8n-n8n-1 n8n --version 2>/dev/null || echo "Unknown")
    echo "  Version: $N8N_VERSION"
else
    print_status "n8n" "FAILED"
fi

# Check Caddy (if exists)
if docker ps | grep -q caddy; then
    if docker exec n8n-caddy-1 caddy version &> /dev/null; then
        print_status "Caddy" "OK"
    else
        print_status "Caddy" "WARNING"
    fi
fi

# Check Portainer (if exists)
if docker ps | grep -q portainer; then
    if curl -s http://localhost:9000 &> /dev/null; then
        print_status "Portainer" "OK"
    else
        print_status "Portainer" "WARNING"
    fi
fi

# System Resources
print_message "\nSystem Resources:" "$CYAN"
echo "================================"

# Memory
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m | awk '/^Mem:/{print $3}')
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))

echo "Memory: ${MEM_USED}MB / ${MEM_TOTAL}MB (${MEM_PERCENT}%)"
if [ $MEM_PERCENT -gt 90 ]; then
    print_message "  ⚠️  High memory usage!" "$YELLOW"
fi

# Disk
DISK_USAGE=$(df -h ~ | awk 'NR==2 {print $5}' | tr -d '%')
DISK_INFO=$(df -h ~ | awk 'NR==2 {print $3" / "$2}')

echo "Disk: $DISK_INFO (${DISK_USAGE}% used)"
if [ $DISK_USAGE -gt 90 ]; then
    print_message "  ⚠️  High disk usage!" "$YELLOW"
fi

# Docker Containers
print_message "\nDocker Containers:" "$CYAN"
echo "================================"
docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

# Recent Logs Check
print_message "\nRecent Errors (last 10 lines):" "$CYAN"
echo "================================"

ERROR_COUNT=$(docker-compose logs --tail=100 2>&1 | grep -iE "error|failed|exception" | wc -l)
if [ $ERROR_COUNT -gt 0 ]; then
    print_message "Found $ERROR_COUNT error messages in recent logs" "$YELLOW"
    echo "Run 'docker-compose logs' to view full logs"
else
    print_message "No recent errors found" "$GREEN"
fi

# Summary
echo
print_message "Health Check Complete" "$CYAN"
echo "================================"