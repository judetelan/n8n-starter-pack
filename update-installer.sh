#!/bin/bash

###########################################
# n8n Starter Pack - Installer Updater
# Updates the installer to latest version
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
echo "║    n8n Installer Update Utility       ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

print_color "🔄 Checking for installer updates..." "$CYAN"

# Download latest installer
TEMP_FILE="/tmp/install-new.sh"
CURRENT_FILE="./install.sh"
REPO_URL="https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh"

# Download latest version
print_color "📥 Downloading latest installer..." "$YELLOW"
if command -v wget &> /dev/null; then
    wget -q -O "$TEMP_FILE" "$REPO_URL"
elif command -v curl &> /dev/null; then
    curl -s -o "$TEMP_FILE" "$REPO_URL"
else
    print_color "❌ Neither wget nor curl found. Cannot download." "$RED"
    exit 1
fi

# Check if download was successful
if [ ! -f "$TEMP_FILE" ]; then
    print_color "❌ Failed to download latest installer" "$RED"
    exit 1
fi

# Compare versions if current exists
if [ -f "$CURRENT_FILE" ]; then
    if cmp -s "$CURRENT_FILE" "$TEMP_FILE"; then
        print_color "✅ Installer is already up to date!" "$GREEN"
        rm "$TEMP_FILE"
        exit 0
    else
        print_color "🆕 New version available!" "$YELLOW"

        # Backup current installer
        BACKUP_FILE="install.sh.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$CURRENT_FILE" "$BACKUP_FILE"
        print_color "📦 Current installer backed up to: $BACKUP_FILE" "$CYAN"
    fi
fi

# Update installer
mv "$TEMP_FILE" "$CURRENT_FILE"
chmod +x "$CURRENT_FILE"

print_color "✅ Installer updated successfully!" "$GREEN"
echo
print_color "You can now run the updated installer with:" "$CYAN"
echo "  sudo bash install.sh"
echo

# Show what's new (if available)
print_color "📝 Latest updates from repository:" "$YELLOW"
echo "- Fixed interactive prompts"
echo "- Improved resource detection"
echo "- Better error handling"
echo "- Updated dependencies"
echo

print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"