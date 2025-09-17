#!/bin/bash

###########################################
# n8n Permission Fix Script
# Fixes permission issues on existing installations
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
echo "║    n8n Permission Fix Utility         ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

# Find n8n installations
print_color "🔍 Looking for n8n installations..." "$CYAN"
echo

INSTALLATIONS=$(find /root -maxdepth 2 -name "docker-compose.yml" -type f 2>/dev/null | grep -E "n8n-.*/" || true)

if [ -z "$INSTALLATIONS" ]; then
    print_color "❌ No n8n installations found in /root" "$RED"
    print_color "Please specify the installation directory:" "$YELLOW"
    read -r INSTALL_DIR
    if [ ! -f "$INSTALL_DIR/docker-compose.yml" ]; then
        print_color "❌ Invalid directory: docker-compose.yml not found" "$RED"
        exit 1
    fi
    INSTALLATIONS="$INSTALL_DIR/docker-compose.yml"
fi

# Process each installation
for compose_file in $INSTALLATIONS; do
    INSTALL_DIR=$(dirname "$compose_file")
    CLIENT_NAME=$(basename "$INSTALL_DIR")

    print_color "📁 Found installation: $INSTALL_DIR" "$GREEN"
    print_color "   Client: $CLIENT_NAME" "$CYAN"
    echo

    # Navigate to installation directory
    cd "$INSTALL_DIR"

    # Stop services
    print_color "⏹️  Stopping services..." "$YELLOW"
    docker compose down || true

    # Create directories if they don't exist
    print_color "📂 Creating directories..." "$CYAN"
    mkdir -p ./data ./files ./postgres-data
    if [ -d "./redis-data" ]; then
        print_color "   Redis data directory found" "$CYAN"
    fi

    # Fix permissions
    print_color "🔧 Fixing permissions..." "$YELLOW"
    chown -R 1000:1000 ./data ./files
    chmod -R 755 ./data ./files

    # Start services
    print_color "🚀 Starting services..." "$GREEN"
    docker compose up -d

    # Wait for services
    print_color "⏳ Waiting for services to initialize..." "$YELLOW"
    sleep 10

    # Check status
    print_color "✅ Checking service status..." "$CYAN"
    docker compose ps

    echo
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    print_color "✅ Fixed permissions for: $CLIENT_NAME" "$GREEN"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo
done

print_color "🎉 All installations have been fixed!" "$GREEN"
echo
print_color "You can now access your n8n instance(s)" "$CYAN"
echo
print_color "If you still see errors, check the logs with:" "$YELLOW"
echo "  cd /root/n8n-[client]"
echo "  ./manage.sh logs"
echo