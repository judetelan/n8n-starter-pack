#!/bin/bash

###########################################
# n8n Restore Script
# Restores database from backup
###########################################

set -e

# Configuration
BACKUP_DIR="${BACKUP_DIR:-$HOME/n8n/backups}"
CONTAINER_NAME="n8n-postgres-1"
DB_NAME="n8n"
DB_USER="n8n"

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

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    print_message "Error: Backup directory not found!" "$RED"
    exit 1
fi

# List available backups
print_message "Available backups:" "$CYAN"
echo "=================="

BACKUPS=($(ls -1r "$BACKUP_DIR"/n8n_backup_*.sql.gz 2>/dev/null))

if [ ${#BACKUPS[@]} -eq 0 ]; then
    print_message "No backups found!" "$RED"
    exit 1
fi

for i in "${!BACKUPS[@]}"; do
    BACKUP_NAME=$(basename "${BACKUPS[$i]}")
    BACKUP_SIZE=$(du -h "${BACKUPS[$i]}" | cut -f1)
    BACKUP_DATE=$(stat -c %y "${BACKUPS[$i]}" | cut -d' ' -f1)
    echo "$((i+1)). $BACKUP_NAME ($BACKUP_SIZE, $BACKUP_DATE)"
done

# Select backup
echo
read -p "Select backup number (or enter filename): " SELECTION

if [[ "$SELECTION" =~ ^[0-9]+$ ]]; then
    # Numeric selection
    if [ "$SELECTION" -lt 1 ] || [ "$SELECTION" -gt ${#BACKUPS[@]} ]; then
        print_message "Invalid selection!" "$RED"
        exit 1
    fi
    BACKUP_FILE="${BACKUPS[$((SELECTION-1))]}"
else
    # Filename provided
    BACKUP_FILE="$BACKUP_DIR/$SELECTION"
    if [ ! -f "$BACKUP_FILE" ]; then
        print_message "Backup file not found!" "$RED"
        exit 1
    fi
fi

# Confirm restoration
print_message "\n⚠️  WARNING: This will replace all current n8n data!" "$YELLOW"
echo "Backup to restore: $(basename "$BACKUP_FILE")"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_message "Restoration cancelled." "$RED"
    exit 0
fi

# Stop n8n services
print_message "\nStopping n8n services..." "$YELLOW"
cd ~/n8n
docker-compose stop n8n n8n-worker || true

# Perform restoration
print_message "Restoring database..." "$YELLOW"

# Check if backup is compressed
if [[ "$BACKUP_FILE" == *.gz ]]; then
    # Decompress and restore
    gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME"
else
    # Restore directly
    docker exec -i "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" < "$BACKUP_FILE"
fi

if [ $? -eq 0 ]; then
    print_message "✅ Database restored successfully!" "$GREEN"

    # Restart services
    print_message "Restarting n8n services..." "$YELLOW"
    docker-compose start n8n n8n-worker || true

    print_message "\n✅ Restoration complete!" "$GREEN"
    print_message "n8n should now be running with the restored data." "$CYAN"
else
    print_message "❌ Restoration failed!" "$RED"
    exit 1
fi