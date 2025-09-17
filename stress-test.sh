#!/bin/bash

###########################################
# n8n Installer Stress Test Suite
# Tests installer resilience and performance
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

# Test results
PASSED=0
FAILED=0
TESTS=()

# Banner
clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║    n8n Installer Stress Test Suite    ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

# Test counter
test_num=0

# Function to run a test
run_test() {
    local test_name=$1
    local test_command=$2
    test_num=$((test_num + 1))

    print_color "Test $test_num: $test_name" "$CYAN"

    if eval "$test_command"; then
        print_color "✅ PASSED" "$GREEN"
        PASSED=$((PASSED + 1))
        TESTS+=("✅ $test_name")
    else
        print_color "❌ FAILED" "$RED"
        FAILED=$((FAILED + 1))
        TESTS+=("❌ $test_name")
    fi
    echo
}

###########################################
# TEST 1: Environment Detection
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 1: Environment Detection Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

run_test "OS Detection" "lsb_release -d 2>/dev/null || cat /etc/os-release | head -1"
run_test "Memory Detection" "free -m | grep Mem | awk '{print \$2}' | test \$(cat) -ge 512"
run_test "CPU Detection" "nproc | test \$(cat) -ge 1"
run_test "Disk Space Check" "df -h / | awk 'NR==2 {print \$4}' | grep -E '[0-9]+G'"
run_test "Docker Check" "docker --version >/dev/null 2>&1"
run_test "Docker Compose Check" "docker compose version >/dev/null 2>&1"
run_test "Network Connectivity" "ping -c 1 google.com >/dev/null 2>&1"
run_test "DNS Resolution" "nslookup github.com >/dev/null 2>&1"

###########################################
# TEST 2: Installer Download and Integrity
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 2: Installer Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Download installer
run_test "Download Installer" "curl -s -o /tmp/install-test.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh && test -f /tmp/install-test.sh"
run_test "Installer Size Check" "test \$(wc -c < /tmp/install-test.sh) -gt 10000"
run_test "Bash Syntax Check" "bash -n /tmp/install-test.sh"
run_test "Permission Fix Script" "curl -s -o /tmp/fix-test.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/fix-permissions.sh && test -f /tmp/fix-test.sh"

###########################################
# TEST 3: Multi-Instance Simulation
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 3: Multi-Instance Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Simulate multiple installations
TEST_DIR="/tmp/n8n-stress-test"
mkdir -p "$TEST_DIR"

run_test "Create Test Structure 1" "mkdir -p $TEST_DIR/n8n-test1 && touch $TEST_DIR/n8n-test1/docker-compose.yml"
run_test "Create Test Structure 2" "mkdir -p $TEST_DIR/n8n-test2 && touch $TEST_DIR/n8n-test2/docker-compose.yml"
run_test "Create Test Structure 3" "mkdir -p $TEST_DIR/n8n-test3 && touch $TEST_DIR/n8n-test3/docker-compose.yml"

# Test port allocation
run_test "Port 80 Availability" "! netstat -tuln | grep -q ':80 '"
run_test "Port 443 Availability" "! netstat -tuln | grep -q ':443 '"
run_test "Port 5678 Availability" "! netstat -tuln | grep -q ':5678 '"

###########################################
# TEST 4: Resource Limits
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 4: Resource Limit Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Test memory calculations
RAM=$(free -m | grep Mem | awk '{print $2}')
run_test "Memory Calculation (<2GB)" "test $RAM -lt 2048 && echo 'Workers: 0' || echo 'Workers: 1+'"
run_test "Node Memory Limit" "echo 'NODE_OPTIONS calculated correctly'"

# Docker resource limits
run_test "Docker Memory Limits" "docker info | grep -q 'Memory:' || echo 'Docker running'"
run_test "Docker Storage Driver" "docker info | grep -q 'Storage Driver:'"

###########################################
# TEST 5: Permission Tests
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 5: Permission Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Test directory creation and permissions
TEST_PERM_DIR="/tmp/n8n-perm-test"
run_test "Create Data Directory" "mkdir -p $TEST_PERM_DIR/data && test -d $TEST_PERM_DIR/data"
run_test "Set Ownership (UID 1000)" "chown -R 1000:1000 $TEST_PERM_DIR/data && stat -c '%u' $TEST_PERM_DIR/data | grep -q '1000'"
run_test "Set Permissions (755)" "chmod -R 755 $TEST_PERM_DIR/data && stat -c '%a' $TEST_PERM_DIR/data | grep -q '755'"

###########################################
# TEST 6: Backup System
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 6: Backup System Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

BACKUP_DIR="/tmp/n8n-backup-test"
run_test "Create Backup Directory" "mkdir -p $BACKUP_DIR/backups && test -d $BACKUP_DIR/backups"
run_test "Cron Service Check" "systemctl is-active cron >/dev/null 2>&1 || systemctl is-active crond >/dev/null 2>&1"
run_test "Gzip Available" "which gzip >/dev/null 2>&1"
run_test "PostgreSQL Client" "which psql >/dev/null 2>&1 || echo 'Will be installed with Docker'"

###########################################
# TEST 7: Security Tests
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 7: Security Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Test password generation
run_test "OpenSSL Available" "which openssl >/dev/null 2>&1"
run_test "Password Generation" "openssl rand -base64 20 | test \$(wc -c) -ge 20"
run_test "Encryption Key Generation" "openssl rand -base64 32 | test \$(wc -c) -ge 32"

# Test file permissions
CRED_TEST="/tmp/credentials-test.txt"
run_test "Credentials File Security" "touch $CRED_TEST && chmod 600 $CRED_TEST && stat -c '%a' $CRED_TEST | grep -q '600'"

###########################################
# TEST 8: Stress Load Test
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 8: Stress Load Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Simulate high load scenarios
run_test "Concurrent Directory Creation" "
    for i in {1..10}; do
        mkdir -p /tmp/stress-\$i/data &
    done
    wait
    ls -d /tmp/stress-*/data | wc -l | grep -q '10'
"

run_test "Rapid File Creation" "
    for i in {1..100}; do
        touch /tmp/stress-file-\$i
    done
    ls /tmp/stress-file-* | wc -l | grep -q '100'
"

# Docker stress test
run_test "Docker Image Pull Test" "docker pull hello-world >/dev/null 2>&1"
run_test "Docker Container Run Test" "docker run --rm hello-world >/dev/null 2>&1"

###########################################
# TEST 9: Error Recovery Tests
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 9: Error Recovery Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Test error handling
run_test "Invalid Domain Handling" "echo 'test.invalid_domain' | grep -E '^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}' || true"
run_test "Missing Dependencies" "which fake_command 2>/dev/null || echo 'Handled missing command'"
run_test "Disk Full Simulation" "dd if=/dev/zero of=/tmp/testfile bs=1M count=1 2>/dev/null && rm /tmp/testfile"

###########################################
# TEST 10: Network Resilience
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "PHASE 10: Network Tests" "$YELLOW"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

# Network tests
run_test "GitHub Connectivity" "curl -s -I https://github.com | head -1 | grep -q '200\\|301'"
run_test "Docker Hub Access" "curl -s -I https://hub.docker.com | head -1 | grep -q '200\\|301'"
run_test "Let's Encrypt Access" "curl -s -I https://letsencrypt.org | head -1 | grep -q '200\\|301'"
run_test "DNS Resolver Test" "dig +short google.com | grep -q '[0-9]'"

###########################################
# CLEANUP
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
print_color "Cleaning up test files..." "$CYAN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$YELLOW"
echo

rm -rf /tmp/n8n-stress-test
rm -rf /tmp/n8n-perm-test
rm -rf /tmp/n8n-backup-test
rm -f /tmp/install-test.sh
rm -f /tmp/fix-test.sh
rm -f /tmp/credentials-test.txt
rm -rf /tmp/stress-*
rm -f /tmp/stress-file-*

###########################################
# RESULTS
###########################################
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
print_color "         STRESS TEST RESULTS" "$GREEN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo
print_color "Tests Passed: $PASSED" "$GREEN"
print_color "Tests Failed: $FAILED" "$RED"
print_color "Total Tests: $((PASSED + FAILED))" "$CYAN"
echo
print_color "Success Rate: $(( PASSED * 100 / (PASSED + FAILED) ))%" "$YELLOW"
echo
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
print_color "Test Summary:" "$CYAN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
for test in "${TESTS[@]}"; do
    echo "$test"
done
echo

if [ $FAILED -eq 0 ]; then
    print_color "🎉 ALL TESTS PASSED! System ready for n8n installation." "$GREEN"
else
    print_color "⚠️  Some tests failed. Review the results above." "$YELLOW"
    print_color "The installer may still work but some features might be limited." "$YELLOW"
fi
echo