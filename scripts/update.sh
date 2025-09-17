#!/bin/bash

###########################################
# n8n Update Script
# Updates n8n to the latest version
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
print_message() {
    echo -e "${2}${1}${NC}"
}

# Change to n8n directory
if [ ! -d "$N8N_DIR" ]; then
    print_message "Error: n8n directory not found at $N8N_DIR" "$RED"
    exit 1
fi

cd "$N8N_DIR"

# Check current version
print_message "Checking current version..." "$CYAN"
CURRENT_VERSION=$(docker exec n8n-n8n-1 n8n --version 2>/dev/null || echo "Unknown")
print_message "Current version: $CURRENT_VERSION" "$YELLOW"

# Create backup before update
print_message "\nCreating backup before update..." "$CYAN"
if [ -f "scripts/backup.sh" ]; then
    bash scripts/backup.sh
else
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    docker exec n8n-postgres-1 pg_dump -U n8n n8n > "backups/pre_update_${TIMESTAMP}.sql"
    gzip "backups/pre_update_${TIMESTAMP}.sql"
    print_message "✅ Backup created: backups/pre_update_${TIMESTAMP}.sql.gz" "$GREEN"
fi

# Pull latest images
print_message "\nPulling latest images..." "$CYAN"
docker-compose pull

# Stop services
print_message "Stopping services..." "$YELLOW"
docker-compose down

# Start services with new images
print_message "Starting services with new images..." "$CYAN"
docker-compose up -d

# Wait for services to be ready
print_message "Waiting for services to be ready..." "$YELLOW"
sleep 10

# Check new version
NEW_VERSION=$(docker exec n8n-n8n-1 n8n --version 2>/dev/null || echo "Unknown")
print_message "\n✅ Update complete!" "$GREEN"
print_message "New version: $NEW_VERSION" "$GREEN"

# Check service status
print_message "\nService status:" "$CYAN"
docker-compose ps

# Clean up old images
print_message "\nCleaning up old images..." "$YELLOW"
docker image prune -f

print_message "\n✅ n8n has been updated successfully!" "$GREEN"