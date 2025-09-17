#!/bin/bash

###########################################
# n8n Backup Script
# Creates timestamped database backups
###########################################

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-$HOME/n8n/backups}"
CONTAINER_NAME="n8n-postgres-1"
DB_NAME="n8n"
DB_USER="n8n"
KEEP_DAYS=30

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Functions
print_message() {
    echo -e "${2}${1}${NC}"
}

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="n8n_backup_${TIMESTAMP}.sql"

# Create backup
print_message "Creating backup..." "$YELLOW"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    print_message "Error: PostgreSQL container is not running!" "$RED"
    exit 1
fi

# Perform backup
if docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/$BACKUP_FILE"; then
    # Compress backup
    gzip "$BACKUP_DIR/$BACKUP_FILE"

    # Get file size
    SIZE=$(du -h "$BACKUP_DIR/${BACKUP_FILE}.gz" | cut -f1)

    print_message "✅ Backup created successfully!" "$GREEN"
    print_message "File: $BACKUP_DIR/${BACKUP_FILE}.gz" "$GREEN"
    print_message "Size: $SIZE" "$GREEN"

    # Clean old backups
    print_message "Cleaning old backups (older than $KEEP_DAYS days)..." "$YELLOW"
    find "$BACKUP_DIR" -name "n8n_backup_*.sql.gz" -mtime +$KEEP_DAYS -delete

    # List remaining backups
    BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/n8n_backup_*.sql.gz 2>/dev/null | wc -l)
    print_message "Total backups: $BACKUP_COUNT" "$GREEN"
else
    print_message "❌ Backup failed!" "$RED"
    exit 1
fi