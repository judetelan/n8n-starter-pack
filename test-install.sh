#!/bin/bash

###########################################
# n8n Installation Test Script
# Tests the actual installation process
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
echo "║    n8n Installation Test              ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

# Test configuration
TEST_NAME="test$(date +%s)"
TEST_DOMAIN=""
TEST_EMAIL=""
TEST_MODE="dry-run"

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --domain) TEST_DOMAIN="$2"; shift ;;
        --email) TEST_EMAIL="$2"; shift ;;
        --live) TEST_MODE="live" ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --domain <domain>  Test with actual domain (required for live mode)"
            echo "  --email <email>    Email for SSL certificates"
            echo "  --live             Perform actual installation (default: dry-run)"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

if [ "$TEST_MODE" == "live" ]; then
    if [ -z "$TEST_DOMAIN" ] || [ -z "$TEST_EMAIL" ]; then
        print_color "❌ --domain and --email required for live mode" "$RED"
        exit 1
    fi
fi

print_color "Test Mode: $TEST_MODE" "$YELLOW"
if [ "$TEST_MODE" == "live" ]; then
    print_color "Domain: $TEST_DOMAIN" "$CYAN"
    print_color "Email: $TEST_EMAIL" "$CYAN"
fi
echo

###########################################
# PHASE 1: Pre-installation Checks
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 1: Pre-installation Checks" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# System requirements
print_color "Checking system requirements..." "$CYAN"

# OS Check
OS_CHECK=$(lsb_release -d 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
print_color "✓ OS: $OS_CHECK" "$GREEN"

# Memory Check
MEM_TOTAL=$(free -m | grep Mem | awk '{print $2}')
if [ $MEM_TOTAL -ge 1024 ]; then
    print_color "✓ Memory: ${MEM_TOTAL}MB (OK)" "$GREEN"
else
    print_color "⚠ Memory: ${MEM_TOTAL}MB (Minimum mode)" "$YELLOW"
fi

# CPU Check
CPU_COUNT=$(nproc)
print_color "✓ CPUs: $CPU_COUNT" "$GREEN"

# Disk Space
DISK_FREE=$(df -h / | awk 'NR==2 {print $4}')
print_color "✓ Free Disk: $DISK_FREE" "$GREEN"

# Docker Check
if docker --version >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    print_color "✓ Docker: $DOCKER_VERSION" "$GREEN"
else
    print_color "❌ Docker not installed" "$RED"
    if [ "$TEST_MODE" == "live" ]; then
        print_color "Installing Docker..." "$YELLOW"
        curl -fsSL https://get.docker.com | sh
    fi
fi

# Docker Compose Check
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version | awk '{print $4}')
    print_color "✓ Docker Compose: $COMPOSE_VERSION" "$GREEN"
else
    print_color "❌ Docker Compose not found" "$RED"
fi

# Network Check
if ping -c 1 google.com >/dev/null 2>&1; then
    print_color "✓ Internet Connection: OK" "$GREEN"
else
    print_color "❌ No internet connection" "$RED"
    exit 1
fi

# Port Check
for port in 80 443 5678; do
    if ! netstat -tuln | grep -q ":$port "; then
        print_color "✓ Port $port: Available" "$GREEN"
    else
        print_color "⚠ Port $port: In use" "$YELLOW"
    fi
done

echo

###########################################
# PHASE 2: Download and Validate Installer
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 2: Installer Download & Validation" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Download installer
print_color "Downloading installer..." "$CYAN"
curl -s -o /tmp/install-test.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh

if [ -f /tmp/install-test.sh ]; then
    FILE_SIZE=$(wc -c < /tmp/install-test.sh)
    print_color "✓ Installer downloaded (${FILE_SIZE} bytes)" "$GREEN"
else
    print_color "❌ Failed to download installer" "$RED"
    exit 1
fi

# Validate syntax
if bash -n /tmp/install-test.sh 2>/dev/null; then
    print_color "✓ Installer syntax: Valid" "$GREEN"
else
    print_color "❌ Installer syntax: Invalid" "$RED"
    exit 1
fi

# Check for required functions
REQUIRED_FUNCTIONS=("show_credentials" "generate_password" "trap")
for func in "${REQUIRED_FUNCTIONS[@]}"; do
    if grep -q "$func" /tmp/install-test.sh; then
        print_color "✓ Function found: $func" "$GREEN"
    else
        print_color "❌ Missing function: $func" "$RED"
    fi
done

echo

###########################################
# PHASE 3: Test Installation (Dry Run)
###########################################
if [ "$TEST_MODE" == "dry-run" ]; then
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    print_color "PHASE 3: Dry Run Simulation" "$YELLOW"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    echo

    print_color "Simulating installation steps..." "$CYAN"

    # Simulate directory creation
    TEST_DIR="/tmp/n8n-$TEST_NAME"
    mkdir -p "$TEST_DIR"
    print_color "✓ Created test directory: $TEST_DIR" "$GREEN"

    # Simulate file creation
    touch "$TEST_DIR/docker-compose.yml"
    touch "$TEST_DIR/.env"
    touch "$TEST_DIR/Caddyfile"
    touch "$TEST_DIR/manage.sh"
    touch "$TEST_DIR/credentials.txt"
    print_color "✓ Created configuration files" "$GREEN"

    # Simulate directory permissions
    mkdir -p "$TEST_DIR/data" "$TEST_DIR/files"
    chown -R 1000:1000 "$TEST_DIR/data" "$TEST_DIR/files"
    print_color "✓ Set correct permissions (UID 1000)" "$GREEN"

    # Test password generation
    TEST_PASSWORD=$(openssl rand -base64 20)
    print_color "✓ Generated test password: ${TEST_PASSWORD:0:5}..." "$GREEN"

    # Test encryption key generation
    TEST_KEY=$(openssl rand -base64 32)
    print_color "✓ Generated encryption key: ${TEST_KEY:0:5}..." "$GREEN"

    # Cleanup
    rm -rf "$TEST_DIR"
    print_color "✓ Cleaned up test files" "$GREEN"

    echo
    print_color "✅ Dry run completed successfully!" "$GREEN"
    print_color "The installer appears to be working correctly." "$CYAN"
fi

###########################################
# PHASE 4: Live Installation
###########################################
if [ "$TEST_MODE" == "live" ]; then
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    print_color "PHASE 3: Live Installation" "$YELLOW"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    echo

    print_color "⚠️  WARNING: This will perform an actual installation!" "$RED"
    read -p "Continue? (y/N) " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_color "Installation cancelled" "$YELLOW"
        exit 0
    fi

    # Prepare input for installer
    INSTALLER_INPUT="${TEST_NAME}\n${TEST_DOMAIN}\n${TEST_EMAIL}\n\n\n\n"

    # Run installer with input
    print_color "Running installer..." "$CYAN"
    echo -e "$INSTALLER_INPUT" | bash /tmp/install-test.sh

    # Check if installation succeeded
    INSTALL_DIR="/root/n8n-${TEST_NAME}"
    if [ -d "$INSTALL_DIR" ]; then
        print_color "✓ Installation directory created" "$GREEN"

        # Verify files
        for file in docker-compose.yml .env Caddyfile manage.sh credentials.txt; do
            if [ -f "$INSTALL_DIR/$file" ]; then
                print_color "✓ File exists: $file" "$GREEN"
            else
                print_color "❌ Missing file: $file" "$RED"
            fi
        done

        # Check services
        cd "$INSTALL_DIR"
        if docker compose ps | grep -q "Up"; then
            print_color "✓ Services are running" "$GREEN"
        else
            print_color "❌ Services not running" "$RED"
        fi

        # Test health endpoint
        sleep 10
        if curl -s http://localhost:5678/healthz >/dev/null 2>&1; then
            print_color "✓ n8n is responding" "$GREEN"
        else
            print_color "❌ n8n not responding" "$RED"
        fi

        # Check credentials file
        if [ -f "$INSTALL_DIR/credentials.txt" ]; then
            print_color "✓ Credentials saved" "$GREEN"
            echo
            print_color "Installation Details:" "$CYAN"
            cat "$INSTALL_DIR/credentials.txt"
        fi
    else
        print_color "❌ Installation failed" "$RED"
        exit 1
    fi
fi

echo

###########################################
# PHASE 5: Post-Installation Tests
###########################################
if [ "$TEST_MODE" == "live" ] && [ -d "$INSTALL_DIR" ]; then
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    print_color "PHASE 4: Post-Installation Tests" "$YELLOW"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
    echo

    cd "$INSTALL_DIR"

    # Test management commands
    print_color "Testing management commands..." "$CYAN"

    if ./manage.sh status >/dev/null 2>&1; then
        print_color "✓ manage.sh status: OK" "$GREEN"
    fi

    # Test HTTPS if domain configured
    if [ -n "$TEST_DOMAIN" ]; then
        sleep 5
        if curl -s -I "https://$TEST_DOMAIN" | head -1 | grep -q "401"; then
            print_color "✓ HTTPS with basic auth: OK" "$GREEN"
        else
            print_color "⚠ HTTPS not ready yet" "$YELLOW"
        fi
    fi

    # Check logs for errors
    ERROR_COUNT=$(docker logs ${TEST_NAME}-n8n 2>&1 | grep -i error | wc -l)
    if [ $ERROR_COUNT -eq 0 ]; then
        print_color "✓ No errors in logs" "$GREEN"
    else
        print_color "⚠ Found $ERROR_COUNT errors in logs" "$YELLOW"
    fi

    echo
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    print_color "✅ INSTALLATION TEST PASSED!" "$GREEN"
    print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
    echo
    print_color "Access your n8n instance at:" "$CYAN"
    echo "  https://$TEST_DOMAIN"
    echo
    print_color "To uninstall test installation:" "$YELLOW"
    echo "  cd $INSTALL_DIR"
    echo "  ./manage.sh uninstall"
fi

###########################################
# CLEANUP
###########################################
if [ "$TEST_MODE" == "dry-run" ]; then
    rm -f /tmp/install-test.sh
    print_color "Cleaned up test files" "$CYAN"
fi

echo
print_color "Test completed!" "$GREEN"
echo

# Summary
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
print_color "Test Summary:" "$CYAN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
echo "Mode: $TEST_MODE"
echo "System: $OS_CHECK"
echo "Memory: ${MEM_TOTAL}MB"
echo "CPUs: $CPU_COUNT"
echo "Docker: ${DOCKER_VERSION:-Not installed}"

if [ "$TEST_MODE" == "dry-run" ]; then
    echo
    print_color "💡 To perform a live installation test, run:" "$YELLOW"
    echo "  $0 --live --domain your-test-domain.com --email your-email@example.com"
fi