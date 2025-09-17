#!/bin/bash

###########################################
# n8n Enterprise Installer v2.0
# Interactive Multi-Client Deployment System
# Features: SSL, Backup, Update, Uninstall
###########################################

set -e

# Configuration
VERSION="2.0.0"
INSTALL_LOG="/tmp/n8n-install-$(date +%Y%m%d-%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$INSTALL_LOG"
    echo -e "$2$1${NC}"
}

# Error handling
trap 'error_exit "Installation failed at line $LINENO"' ERR

error_exit() {
    log "ERROR: $1" "$RED"
    echo -e "${RED}Installation log: $INSTALL_LOG${NC}"
    exit 1
}

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════╗
║                                              ║
║     n8n Enterprise Deployment System         ║
║         Multi-Client Installation            ║
║                 v2.0.0                       ║
║                                              ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# System validation
validate_system() {
    log "Validating system requirements..." "$YELLOW"

    # Check OS
    if [ ! -f /etc/os-release ]; then
        error_exit "Unsupported OS. Ubuntu/Debian required."
    fi

    # Check memory
    MEM=$(free -m | awk 'NR==2{print $2}')
    if [ "$MEM" -lt 900 ]; then
        error_exit "Insufficient memory. At least 1GB required (found: ${MEM}MB)"
    fi

    # Check disk space
    DISK=$(df / | awk 'NR==2{print $4}')
    if [ "$DISK" -lt 5000000 ]; then
        error_exit "Insufficient disk space. At least 5GB required."
    fi

    # Check CPU
    CPU=$(nproc)

    # Check ports
    for port in 80 443 5678; do
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            log "WARNING: Port $port is already in use" "$YELLOW"
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    done

    log "✓ System validation passed (${CPU} CPU, ${MEM}MB RAM)" "$GREEN"
}

# Interactive configuration
configure_installation() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}         CLIENT CONFIGURATION${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # Client name
    while true; do
        read -p "$(echo -e ${YELLOW}Client/Project name:${NC} ) " CLIENT_NAME
        if [[ "$CLIENT_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            break
        else
            log "Invalid name. Use only letters, numbers, dash, underscore" "$RED"
        fi
    done

    # Installation directory
    DEFAULT_DIR="$HOME/n8n-$CLIENT_NAME"
    read -p "$(echo -e ${YELLOW}Installation directory [$DEFAULT_DIR]:${NC} ) " INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-$DEFAULT_DIR}

    # Deployment type
    echo
    echo -e "${CYAN}Deployment type:${NC}"
    echo "  1) Development (HTTP only)"
    echo "  2) Production (HTTPS with Let's Encrypt)"
    echo "  3) Production (HTTPS with custom certificate)"
    read -p "$(echo -e ${YELLOW}Choice [1]:${NC} ) " DEPLOY_TYPE
    DEPLOY_TYPE=${DEPLOY_TYPE:-1}

    # Domain configuration
    if [ "$DEPLOY_TYPE" != "1" ]; then
        read -p "$(echo -e ${YELLOW}Domain name (e.g., n8n.client.com):${NC} ) " DOMAIN

        # Validate domain
        if [ -z "$DOMAIN" ]; then
            error_exit "Domain required for production deployment"
        fi

        # Email for SSL
        if [ "$DEPLOY_TYPE" == "2" ]; then
            read -p "$(echo -e ${YELLOW}Email for SSL certificates:${NC} ) " SSL_EMAIL
            if ! [[ "$SSL_EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                error_exit "Invalid email address"
            fi
        fi
    else
        DOMAIN="localhost"
    fi

    # Workers configuration
    echo
    echo -e "${CYAN}Worker configuration:${NC}"
    echo "  Detected: $CPU CPU cores"
    echo "  Recommended: $([ $CPU -eq 1 ] && echo "0 workers" || echo "$((CPU-1)) workers")"
    read -p "$(echo -e ${YELLOW}Number of workers [$([ $CPU -eq 1 ] && echo "0" || echo "1")]:${NC} ) " WORKERS
    WORKERS=${WORKERS:-$([ $CPU -eq 1 ] && echo "0" || echo "1")}

    # Timezone
    echo
    CURRENT_TZ=$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")
    read -p "$(echo -e ${YELLOW}Timezone [$CURRENT_TZ]:${NC} ) " TIMEZONE
    TIMEZONE=${TIMEZONE:-$CURRENT_TZ}

    # Advanced options
    echo
    echo -e "${CYAN}Advanced options:${NC}"
    read -p "$(echo -e ${YELLOW}Enable automatic backups? [Y/n]:${NC} ) " -n 1 -r
    echo
    AUTO_BACKUP=${REPLY:-Y}

    read -p "$(echo -e ${YELLOW}Enable automatic updates? [y/N]:${NC} ) " -n 1 -r
    echo
    AUTO_UPDATE=${REPLY:-N}

    read -p "$(echo -e ${YELLOW}Set memory limit (MB) [$([ $CPU -eq 1 ] && echo "512" || echo "1024")]:${NC} ) " MEM_LIMIT
    MEM_LIMIT=${MEM_LIMIT:-$([ $CPU -eq 1 ] && echo "512" || echo "1024")}

    # Summary
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}         CONFIGURATION SUMMARY${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Client:     ${GREEN}$CLIENT_NAME${NC}"
    echo -e "  Directory:  ${GREEN}$INSTALL_DIR${NC}"
    echo -e "  Domain:     ${GREEN}$DOMAIN${NC}"
    echo -e "  Workers:    ${GREEN}$WORKERS${NC}"
    echo -e "  Timezone:   ${GREEN}$TIMEZONE${NC}"
    echo -e "  Auto-backup:${GREEN}$([[ $AUTO_BACKUP =~ ^[Yy]$ ]] && echo " Yes" || echo " No")${NC}"
    echo -e "  Auto-update:${GREEN}$([[ $AUTO_UPDATE =~ ^[Yy]$ ]] && echo " Yes" || echo " No")${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    read -p "$(echo -e ${YELLOW}Proceed with installation? [Y/n]:${NC} ) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [ ! -z "$REPLY" ]; then
        log "Installation cancelled by user" "$YELLOW"
        exit 0
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..." "$YELLOW"

    # Update system
    sudo apt-get update -qq

    # Install required packages
    PACKAGES="curl openssl lsof"
    for pkg in $PACKAGES; do
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            sudo apt-get install -y $pkg -qq
        fi
    done

    # Install Docker
    if ! command -v docker &> /dev/null; then
        log "Installing Docker..." "$YELLOW"
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
        log "✓ Docker installed" "$GREEN"
    else
        log "✓ Docker already installed" "$GREEN"
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log "Installing Docker Compose..." "$YELLOW"
        sudo curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log "✓ Docker Compose installed" "$GREEN"
    else
        log "✓ Docker Compose already installed" "$GREEN"
    fi
}

# Generate credentials
generate_credentials() {
    log "Generating secure credentials..." "$YELLOW"

    # Generate passwords
    DB_USER="${CLIENT_NAME}_db"
    DB_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    DB_NAME="${CLIENT_NAME}_n8n"
    REDIS_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-20)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    N8N_USER="admin"
    N8N_PASS=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-12)

    log "✓ Credentials generated" "$GREEN"
}

# Create configuration
create_configuration() {
    log "Creating configuration..." "$YELLOW"

    mkdir -p "$INSTALL_DIR"/{data,backups,ssl,scripts}
    cd "$INSTALL_DIR"

    # Create .env file
    cat > .env << EOF
# n8n Configuration for $CLIENT_NAME
# Generated: $(date)
# Version: $VERSION

# Client
CLIENT_NAME=$CLIENT_NAME
INSTALL_DIR=$INSTALL_DIR

# Database
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=$DB_NAME

# Redis
REDIS_PASSWORD=$REDIS_PASS

# n8n Core
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=$([[ "$DEPLOY_TYPE" != "1" ]] && echo "https" || echo "http")
WEBHOOK_URL=$([[ "$DEPLOY_TYPE" != "1" ]] && echo "https://$DOMAIN/" || echo "http://$DOMAIN:5678/")

# Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASS

# Queue Mode
EXECUTIONS_MODE=$([ "$WORKERS" -gt 0 ] && echo "queue" || echo "regular")
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379

# Performance
NODE_OPTIONS=--max-old-space-size=$MEM_LIMIT
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336
N8N_CONCURRENCY_PRODUCTION_LIMIT=10

# Timezone
TZ=$TIMEZONE
GENERIC_TIMEZONE=$TIMEZONE

# Logging
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=console
EOF

    # Create docker-compose.yml
    create_docker_compose

    # Create management scripts
    create_management_scripts

    # Setup SSL if production
    if [ "$DEPLOY_TYPE" != "1" ]; then
        setup_ssl
    fi

    log "✓ Configuration created" "$GREEN"
}

# Create Docker Compose
create_docker_compose() {
    cat > docker-compose.yml << 'YAML'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: ${CLIENT_NAME}-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backups:/backups
    healthcheck:
      test: pg_isready -U ${POSTGRES_USER}
      interval: 10s
      retries: 5
    networks:
      - n8n-network

  redis:
    image: redis:7-alpine
    container_name: ${CLIENT_NAME}-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      retries: 5
    networks:
      - n8n-network

  n8n:
    image: n8nio/n8n:latest
    container_name: ${CLIENT_NAME}-n8n
    restart: unless-stopped
YAML

    # Add ports based on deployment type
    if [ "$DEPLOY_TYPE" == "1" ]; then
        cat >> docker-compose.yml << 'YAML'
    ports:
      - "5678:5678"
YAML
    else
        cat >> docker-compose.yml << 'YAML'
    expose:
      - "5678"
YAML
    fi

    # Continue with n8n configuration
    cat >> docker-compose.yml << 'YAML'
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - NODE_ENV=production
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=${EXECUTIONS_MODE}
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
      - NODE_OPTIONS=${NODE_OPTIONS}
      - EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE}
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
      - N8N_LOG_LEVEL=${N8N_LOG_LEVEL}
      - TZ=${TZ}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./data/shared:/data/shared
      - ./data/files:/files
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - n8n-network
YAML

    # Add workers if configured
    if [ "$WORKERS" -gt 0 ]; then
        for i in $(seq 1 $WORKERS); do
            cat >> docker-compose.yml << YAML

  worker-$i:
    image: n8nio/n8n:latest
    container_name: \${CLIENT_NAME}-worker-$i
    restart: unless-stopped
    command: worker
    environment:
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=\${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=\${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=\${REDIS_PASSWORD}
      - NODE_OPTIONS=\${NODE_OPTIONS}
      - TZ=\${TZ}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./data/shared:/data/shared
      - ./data/files:/files
    depends_on:
      - postgres
      - redis
      - n8n
    networks:
      - n8n-network
YAML
        done
    fi

    # Add Caddy for SSL if production
    if [ "$DEPLOY_TYPE" != "1" ]; then
        cat >> docker-compose.yml << 'YAML'

  caddy:
    image: caddy:alpine
    container_name: ${CLIENT_NAME}-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
      - ./ssl:/ssl
    depends_on:
      - n8n
    networks:
      - n8n-network
YAML
    fi

    # Add networks and volumes
    cat >> docker-compose.yml << 'YAML'

networks:
  n8n-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  n8n_data:
YAML

    if [ "$DEPLOY_TYPE" != "1" ]; then
        cat >> docker-compose.yml << 'YAML'
  caddy_data:
  caddy_config:
YAML
    fi
}

# Setup SSL
setup_ssl() {
    if [ "$DEPLOY_TYPE" == "2" ]; then
        # Let's Encrypt
        cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678
    encode gzip

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy no-referrer-when-downgrade
    }

    log {
        output file /data/access.log
        format console
    }

    tls $SSL_EMAIL
}
EOF
    elif [ "$DEPLOY_TYPE" == "3" ]; then
        # Custom certificate
        cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678
    encode gzip

    tls /ssl/cert.pem /ssl/key.pem

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy no-referrer-when-downgrade
    }
}
EOF
        log "Place your SSL certificate files in:" "$YELLOW"
        log "  Certificate: $INSTALL_DIR/ssl/cert.pem" "$YELLOW"
        log "  Private Key: $INSTALL_DIR/ssl/key.pem" "$YELLOW"
    fi
}

# Create management scripts
create_management_scripts() {
    # Main management script
    cat > n8n-manage.sh << 'SCRIPT'
#!/bin/bash

source .env

case "$1" in
    start)
        docker-compose up -d
        echo "✓ n8n started"
        ;;
    stop)
        docker-compose down
        echo "✓ n8n stopped"
        ;;
    restart)
        docker-compose restart
        echo "✓ n8n restarted"
        ;;
    status)
        echo "Services status:"
        docker-compose ps
        echo
        echo "Health check:"
        curl -s http://localhost:5678/healthz && echo " - n8n: OK" || echo " - n8n: Not responding"
        ;;
    logs)
        docker-compose logs -f ${2:-n8n}
        ;;
    backup)
        bash scripts/backup.sh
        ;;
    update)
        bash scripts/update.sh
        ;;
    uninstall)
        bash scripts/uninstall.sh
        ;;
    *)
        echo "n8n Management Tool"
        echo "Usage: $0 {start|stop|restart|status|logs|backup|update|uninstall} [service]"
        echo
        echo "Commands:"
        echo "  start      Start all services"
        echo "  stop       Stop all services"
        echo "  restart    Restart all services"
        echo "  status     Show service status and health"
        echo "  logs       Follow logs (optionally specify service)"
        echo "  backup     Create database backup"
        echo "  update     Update n8n to latest version"
        echo "  uninstall  Remove n8n installation"
        ;;
esac
SCRIPT
    chmod +x n8n-manage.sh

    # Update script
    cat > scripts/update.sh << 'SCRIPT'
#!/bin/bash

source ../.env

echo "n8n Update Script"
echo "=================="
echo

# Backup before update
echo "Creating backup before update..."
bash backup.sh

# Pull latest images
echo "Pulling latest images..."
docker-compose pull

# Stop services
echo "Stopping services..."
docker-compose down

# Start services
echo "Starting updated services..."
docker-compose up -d

# Wait for services
sleep 10

# Check version
echo
echo "Update complete!"
docker exec ${CLIENT_NAME}-n8n n8n --version

echo
echo "✓ n8n has been updated successfully"
SCRIPT
    chmod +x scripts/update.sh

    # Backup script
    cat > scripts/backup.sh << 'SCRIPT'
#!/bin/bash

source ../.env

BACKUP_DIR="../backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/backup_${CLIENT_NAME}_${TIMESTAMP}.sql.gz"

echo "Creating backup..."
mkdir -p $BACKUP_DIR

# Backup database
docker exec ${CLIENT_NAME}-postgres pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > $BACKUP_FILE

# Backup configuration
cp ../.env "$BACKUP_DIR/env_${TIMESTAMP}.backup"

# Keep only last 30 backups
ls -t $BACKUP_DIR/backup_*.sql.gz | tail -n +31 | xargs -r rm

echo "✓ Backup created: $BACKUP_FILE"
echo "✓ Configuration backed up"
SCRIPT
    chmod +x scripts/backup.sh

    # Uninstall script
    cat > scripts/uninstall.sh << 'SCRIPT'
#!/bin/bash

source ../.env

echo "================================"
echo "    n8n Uninstaller"
echo "================================"
echo
echo "This will remove:"
echo "  - All Docker containers"
echo "  - All Docker volumes (data will be lost!)"
echo "  - Installation directory"
echo
echo "Client: $CLIENT_NAME"
echo "Directory: $INSTALL_DIR"
echo
read -p "Are you sure? Type 'yes' to confirm: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstallation cancelled"
    exit 0
fi

# Create final backup
echo "Creating final backup..."
bash backup.sh

# Stop and remove containers
echo "Removing containers..."
docker-compose down -v

# Remove network
docker network rm ${CLIENT_NAME}_n8n-network 2>/dev/null || true

# Save backup location
BACKUP_LOCATION="$HOME/n8n-uninstalled-$CLIENT_NAME-$(date +%Y%m%d)"
mv ../backups $BACKUP_LOCATION

echo
echo "✓ n8n has been uninstalled"
echo "✓ Backups saved to: $BACKUP_LOCATION"
echo
echo "To completely remove installation directory, run:"
echo "  rm -rf $INSTALL_DIR"
SCRIPT
    chmod +x scripts/uninstall.sh
}

# Start services
start_services() {
    log "Starting services..." "$YELLOW"

    docker-compose up -d

    # Wait for services to be ready
    log "Waiting for services to initialize..." "$YELLOW"

    # Wait up to 60 seconds for n8n to be ready
    for i in {1..60}; do
        if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
            log "✓ n8n is running!" "$GREEN"
            break
        fi
        sleep 1
    done
}

# Setup automatic backups
setup_auto_backup() {
    if [[ $AUTO_BACKUP =~ ^[Yy]$ ]]; then
        log "Setting up automatic backups..." "$YELLOW"

        # Add cron job for daily backup at 2 AM
        (crontab -l 2>/dev/null || true; echo "0 2 * * * cd $INSTALL_DIR && bash scripts/backup.sh >> $INSTALL_DIR/backup.log 2>&1") | crontab -

        log "✓ Automatic daily backups configured (2:00 AM)" "$GREEN"
    fi
}

# Setup automatic updates
setup_auto_update() {
    if [[ $AUTO_UPDATE =~ ^[Yy]$ ]]; then
        log "Setting up automatic updates..." "$YELLOW"

        # Add cron job for weekly update on Sunday at 3 AM
        (crontab -l 2>/dev/null || true; echo "0 3 * * 0 cd $INSTALL_DIR && bash scripts/update.sh >> $INSTALL_DIR/update.log 2>&1") | crontab -

        log "✓ Automatic weekly updates configured (Sunday 3:00 AM)" "$GREEN"
    fi
}

# Save installation report
save_report() {
    cat > installation-report.txt << EOF
n8n Enterprise Installation Report
====================================
Date: $(date)
Version: $VERSION
Client: $CLIENT_NAME
Directory: $INSTALL_DIR

System Information
------------------
CPU Cores: $CPU
Memory: ${MEM}MB
Timezone: $TIMEZONE

Configuration
-------------
Domain: $DOMAIN
Workers: $WORKERS
Mode: $([ "$WORKERS" -gt 0 ] && echo "Queue (Redis)" || echo "Regular")
SSL: $([ "$DEPLOY_TYPE" != "1" ] && echo "Enabled" || echo "Disabled")
Auto-backup: $([[ $AUTO_BACKUP =~ ^[Yy]$ ]] && echo "Enabled (Daily 2 AM)" || echo "Disabled")
Auto-update: $([[ $AUTO_UPDATE =~ ^[Yy]$ ]] && echo "Enabled (Sunday 3 AM)" || echo "Disabled")

Access Credentials
------------------
URL: $([[ "$DEPLOY_TYPE" != "1" ]] && echo "https://$DOMAIN" || echo "http://$DOMAIN:5678")
Username: $N8N_USER
Password: $N8N_PASS

Database Credentials
--------------------
Database: $DB_NAME
User: $DB_USER
Password: $DB_PASS

Redis Password: $REDIS_PASS
Encryption Key: $ENCRYPTION_KEY

Management Commands
-------------------
Start:     ./n8n-manage.sh start
Stop:      ./n8n-manage.sh stop
Status:    ./n8n-manage.sh status
Logs:      ./n8n-manage.sh logs
Backup:    ./n8n-manage.sh backup
Update:    ./n8n-manage.sh update
Uninstall: ./n8n-manage.sh uninstall

Important Files
---------------
Configuration: $INSTALL_DIR/.env
Docker Compose: $INSTALL_DIR/docker-compose.yml
Backups: $INSTALL_DIR/backups/
Logs: $INSTALL_DIR/*.log

Support
-------
Installation log: $INSTALL_LOG
====================================
EOF
    chmod 600 installation-report.txt
}

# Display completion
display_completion() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║         🎉 Installation Complete! 🎉                ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}                 ACCESS DETAILS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${BLUE}Client:${NC}     ${GREEN}$CLIENT_NAME${NC}"
    echo -e "  ${BLUE}URL:${NC}        ${GREEN}$([[ "$DEPLOY_TYPE" != "1" ]] && echo "https://$DOMAIN" || echo "http://$DOMAIN:5678")${NC}"
    echo -e "  ${BLUE}Username:${NC}   ${GREEN}$N8N_USER${NC}"
    echo -e "  ${BLUE}Password:${NC}   ${GREEN}$N8N_PASS${NC}"
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}                 MANAGEMENT${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo "  cd $INSTALL_DIR"
    echo "  ./n8n-manage.sh status    # Check status"
    echo "  ./n8n-manage.sh logs      # View logs"
    echo "  ./n8n-manage.sh backup    # Create backup"
    echo "  ./n8n-manage.sh update    # Update n8n"
    echo

    if [ "$DEPLOY_TYPE" != "1" ] && [ "$DEPLOY_TYPE" == "2" ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}                 DNS SETUP${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo
        echo -e "  Add DNS A record:"
        echo -e "  ${YELLOW}$DOMAIN → $(curl -s ifconfig.me)${NC}"
        echo
    fi

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "  ${YELLOW}Full report saved:${NC} installation-report.txt"
    echo -e "  ${YELLOW}Installation log:${NC} $INSTALL_LOG"
    echo
    echo -e "${GREEN}Happy automating with n8n! 🚀${NC}"
}

# Main installation flow
main() {
    show_banner
    validate_system
    configure_installation
    install_dependencies
    generate_credentials
    create_configuration
    start_services
    setup_auto_backup
    setup_auto_update
    save_report
    display_completion
}

# Run installation
main "$@"