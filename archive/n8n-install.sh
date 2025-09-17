#!/bin/bash

###########################################
# n8n Installer - Single File Solution
# Optimized for minimal VPS (1vCPU/1GB RAM)
# Supports 0-10 workers with Redis queue
###########################################

set -e

# Configuration
VERSION="1.0.0"
INSTALL_DIR="$HOME/n8n"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Banner
show_banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
     _ __   ___  _ __
    | '_ \ / _ \| '_ \
    | | | | (_) | | | |
    |_| |_|\___/|_| |_|

    Lightweight Installer v1.0
EOF
    echo -e "${NC}"
}

# Check system
check_system() {
    log_info "Checking system..."

    # Check memory
    MEM=$(free -m | awk 'NR==2{print $2}')
    if [ "$MEM" -lt 900 ]; then
        log_error "At least 1GB RAM required (found: ${MEM}MB)"
    fi

    # Check CPU
    CPU=$(nproc)
    log_success "Detected $CPU CPU core(s) and ${MEM}MB RAM"

    # Auto-detect mode
    if [ "$CPU" -eq 1 ]; then
        log_warning "1vCPU detected - minimal mode enabled"
        MAX_WORKERS=0
    else
        MAX_WORKERS=$((CPU - 1))
    fi
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker already installed"
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
        log_success "Docker installed (re-login required for permissions)"
    fi

    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose already installed"
    else
        log_info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed"
    fi
}

# Setup wizard
setup_wizard() {
    echo
    echo -e "${CYAN}=== Configuration ===${NC}"
    echo

    # Domain setup
    echo -e "${YELLOW}Setup type:${NC}"
    echo "1) Development (localhost)"
    echo "2) Production (domain + SSL)"
    read -p "Choice [1]: " SETUP_TYPE
    SETUP_TYPE=${SETUP_TYPE:-1}

    if [ "$SETUP_TYPE" == "2" ]; then
        read -p "Domain (e.g., n8n.example.com): " DOMAIN
        read -p "Email for SSL: " EMAIL
        PRODUCTION=true
    else
        DOMAIN="localhost"
        EMAIL=""
        PRODUCTION=false
    fi

    # Workers
    echo
    if [ "$MAX_WORKERS" -gt 0 ]; then
        echo -e "${YELLOW}Workers (0-$MAX_WORKERS):${NC}"
        echo "0 = No workers (embedded mode)"
        echo "1+ = Queue mode with Redis"
        read -p "Number of workers [0]: " WORKERS
        WORKERS=${WORKERS:-0}

        if [ "$WORKERS" -gt "$MAX_WORKERS" ]; then
            WORKERS=$MAX_WORKERS
            log_warning "Adjusted to $WORKERS workers for your system"
        fi
    else
        WORKERS=0
    fi

    # Watchtower
    echo
    read -p "Enable auto-updates with Watchtower? [y/N]: " WATCHTOWER
    WATCHTOWER=${WATCHTOWER:-n}

    # Generate secrets
    DB_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
    ENCRYPTION_KEY=$(openssl rand -base64 32)
    if [ "$WORKERS" -gt 0 ]; then
        REDIS_PASS=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-16)
    fi
}

# Create files
create_files() {
    log_info "Creating configuration..."

    mkdir -p "$INSTALL_DIR"/{data,shared,backups}
    cd "$INSTALL_DIR"

    # Environment file
    cat > .env << EOF
# n8n Configuration
N8N_VERSION=latest
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=$([ "$PRODUCTION" = true ] && echo "https" || echo "http")
WEBHOOK_URL=$([ "$PRODUCTION" = true ] && echo "https://$DOMAIN/" || echo "http://localhost:5678/")

# Database
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=n8n

# Queue Mode
EXECUTIONS_MODE=$([ "$WORKERS" -gt 0 ] && echo "queue" || echo "regular")
$([ "$WORKERS" -gt 0 ] && echo "QUEUE_BULL_REDIS_HOST=redis" || echo "")
$([ "$WORKERS" -gt 0 ] && echo "QUEUE_BULL_REDIS_PORT=6379" || echo "")
$([ "$WORKERS" -gt 0 ] && echo "QUEUE_BULL_REDIS_PASSWORD=$REDIS_PASS" || echo "")

# Performance
NODE_OPTIONS=--max-old-space-size=$([ "$CPU" -eq 1 ] && echo "512" || echo "1024")

# Data pruning
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336

# Timezone
TZ=UTC
EOF

    # Docker Compose
    cat > docker-compose.yml << 'COMPOSE'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: pg_isready -U ${POSTGRES_USER}
      interval: 5s
      timeout: 5s
      retries: 5

COMPOSE

    # Add Redis if workers enabled
    if [ "$WORKERS" -gt 0 ]; then
        cat >> docker-compose.yml << 'COMPOSE'
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${QUEUE_BULL_REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${QUEUE_BULL_REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

COMPOSE
    fi

    # n8n main service
    cat >> docker-compose.yml << 'COMPOSE'
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=5678
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - NODE_ENV=production
      - WEBHOOK_URL=${WEBHOOK_URL}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=${EXECUTIONS_MODE}
      - EXECUTIONS_DATA_SAVE_ON_ERROR=${EXECUTIONS_DATA_SAVE_ON_ERROR}
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=${EXECUTIONS_DATA_SAVE_ON_SUCCESS}
      - EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE}
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
      - NODE_OPTIONS=${NODE_OPTIONS}
COMPOSE

    # Add queue config if workers
    if [ "$WORKERS" -gt 0 ]; then
        cat >> docker-compose.yml << 'COMPOSE'
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${QUEUE_BULL_REDIS_PASSWORD}
      - QUEUE_HEALTH_CHECK_ACTIVE=true
COMPOSE
    fi

    # n8n volumes and depends
    cat >> docker-compose.yml << 'COMPOSE'
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      postgres:
        condition: service_healthy
COMPOSE

    if [ "$WORKERS" -gt 0 ]; then
        cat >> docker-compose.yml << 'COMPOSE'
      redis:
        condition: service_healthy
COMPOSE
    fi

    # Add workers
    if [ "$WORKERS" -gt 0 ]; then
        for i in $(seq 1 $WORKERS); do
            cat >> docker-compose.yml << COMPOSE

  n8n-worker-$i:
    image: n8nio/n8n:latest
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
      - QUEUE_BULL_REDIS_PASSWORD=\${QUEUE_BULL_REDIS_PASSWORD}
      - NODE_OPTIONS=\${NODE_OPTIONS}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      - postgres
      - redis
      - n8n
COMPOSE
        done
    fi

    # Add Watchtower
    if [ "$WATCHTOWER" = "y" ]; then
        cat >> docker-compose.yml << 'COMPOSE'

  watchtower:
    image: containrrr/watchtower:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
COMPOSE
    fi

    # Add Caddy for production
    if [ "$PRODUCTION" = true ]; then
        cat >> docker-compose.yml << 'COMPOSE'

  caddy:
    image: caddy:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - n8n
COMPOSE
    fi

    # Volumes
    cat >> docker-compose.yml << 'COMPOSE'

volumes:
  postgres_data:
  n8n_data:
COMPOSE

    if [ "$WORKERS" -gt 0 ]; then
        echo "  redis_data:" >> docker-compose.yml
    fi

    if [ "$PRODUCTION" = true ]; then
        echo "  caddy_data:" >> docker-compose.yml
        echo "  caddy_config:" >> docker-compose.yml
    fi

    # Caddyfile for production
    if [ "$PRODUCTION" = true ]; then
        cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678
    encode gzip
}
EOF
        # Remove port exposure from n8n in production
        sed -i '/ports:/,+1d' docker-compose.yml
    fi

    # Management script
    cat > n8n.sh << 'SCRIPT'
#!/bin/bash

case "$1" in
    start)
        docker-compose up -d
        echo "✓ Started"
        ;;
    stop)
        docker-compose down
        echo "✓ Stopped"
        ;;
    restart)
        docker-compose restart
        echo "✓ Restarted"
        ;;
    update)
        docker-compose pull
        docker-compose down
        docker-compose up -d
        echo "✓ Updated"
        ;;
    backup)
        mkdir -p backups
        DATE=$(date +%Y%m%d_%H%M%S)
        docker exec $(docker-compose ps -q postgres) pg_dump -U n8n n8n | gzip > backups/backup_$DATE.sql.gz
        echo "✓ Backup saved: backups/backup_$DATE.sql.gz"
        ;;
    logs)
        docker-compose logs -f ${2:-n8n}
        ;;
    status)
        docker-compose ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|update|backup|logs|status}"
        exit 1
        ;;
esac
SCRIPT
    chmod +x n8n.sh

    log_success "Configuration created"
}

# Start services
start_services() {
    log_info "Starting services..."
    docker-compose up -d

    log_info "Waiting for initialization..."
    sleep 10

    if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        log_success "n8n is running!"
    else
        log_warning "n8n starting... please wait"
    fi
}

# Save credentials
save_credentials() {
    cat > credentials.txt << EOF
=================================
n8n Installation Complete
=================================
Date: $(date)

Access URL:
$([ "$PRODUCTION" = true ] && echo "https://$DOMAIN" || echo "http://localhost:5678")

Database Password: $DB_PASS
Encryption Key: $ENCRYPTION_KEY
$([ "$WORKERS" -gt 0 ] && echo "Redis Password: $REDIS_PASS" || echo "")

Workers: $WORKERS
Mode: $([ "$WORKERS" -gt 0 ] && echo "Queue" || echo "Embedded")

Commands:
./n8n.sh start|stop|restart|update|backup|logs|status

IMPORTANT: Keep this file secure!
EOF
    chmod 600 credentials.txt
}

# Main
main() {
    show_banner

    if [ "$EUID" -eq 0 ]; then
        log_error "Don't run as root. Use regular user."
    fi

    check_system
    setup_wizard
    install_docker
    create_files
    start_services
    save_credentials

    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}        Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "Access: ${YELLOW}$([ "$PRODUCTION" = true ] && echo "https://$DOMAIN" || echo "http://localhost:5678")${NC}"
    echo -e "Workers: ${YELLOW}$WORKERS$([ "$WORKERS" -gt 0 ] && echo " (Queue mode with Redis)" || echo " (Embedded mode)")${NC}"
    echo
    echo -e "Directory: ${CYAN}$INSTALL_DIR${NC}"
    echo -e "Credentials: ${CYAN}$INSTALL_DIR/credentials.txt${NC}"
    echo

    if [ "$PRODUCTION" = true ]; then
        echo -e "${YELLOW}Configure DNS:${NC}"
        echo "Point $DOMAIN to $(curl -s ifconfig.me)"
        echo
    fi
}

main "$@"