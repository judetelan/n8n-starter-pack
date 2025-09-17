#!/bin/bash

###########################################
# n8n Starter Pack - Ultra-Lite Installer
# Optimized for 1vCPU/1GB RAM VPS
# One-command installation
###########################################

set -e

# Configuration
INSTALL_DIR="$HOME/n8n"
GITHUB_REPO="https://raw.githubusercontent.com/yourusername/n8n-starter-pack/main"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ASCII Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║      n8n Starter Pack Installer       ║"
    echo "║         Ultra-Lite Edition             ║"
    echo "║          Version $VERSION              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# System check
check_system() {
    log_info "Checking system requirements..."

    # Check OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        log_error "Cannot detect OS. Ubuntu/Debian required."
    fi

    # Check memory (in MB)
    TOTAL_MEM=$(free -m | awk 'NR==2{print $2}')
    if [ "$TOTAL_MEM" -lt 900 ]; then
        log_error "Insufficient memory. At least 1GB required (found: ${TOTAL_MEM}MB)"
    fi

    # Check CPU
    CPU_CORES=$(nproc)
    log_info "Detected $CPU_CORES CPU core(s) and ${TOTAL_MEM}MB RAM"

    # Auto-select minimal mode for 1vCPU
    if [ "$CPU_CORES" -eq 1 ]; then
        log_warning "1vCPU detected - Ultra-lite mode activated"
        MINIMAL_MODE=true
    else
        MINIMAL_MODE=false
    fi
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker already installed"
    else
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com | sudo sh
        sudo usermod -aG docker $USER
        log_success "Docker installed"
    fi

    # Install Docker Compose
    if command -v docker-compose &> /dev/null; then
        log_info "Docker Compose already installed"
    else
        log_info "Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        log_success "Docker Compose installed"
    fi
}

# Interactive setup
setup_wizard() {
    echo
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}          Configuration Wizard${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo

    # Installation type
    echo -e "${YELLOW}Select installation type:${NC}"
    echo "1) Quick Setup (localhost, no SSL)"
    echo "2) Production (domain with SSL)"
    read -p "Choice [1]: " INSTALL_TYPE
    INSTALL_TYPE=${INSTALL_TYPE:-1}

    if [ "$INSTALL_TYPE" == "2" ]; then
        read -p "Enter your domain (e.g., n8n.example.com): " DOMAIN
        read -p "Enter email for SSL certificates: " EMAIL
        PRODUCTION=true
    else
        DOMAIN="localhost"
        EMAIL="admin@localhost"
        PRODUCTION=false
    fi

    # Workers (only for non-minimal systems)
    if [ "$MINIMAL_MODE" = false ]; then
        echo
        echo -e "${YELLOW}Worker configuration:${NC}"
        echo "0) Embedded mode (no workers)"
        echo "1) 1 worker (recommended for 2+ CPU)"
        echo "2) 2 workers (for 4+ CPU)"
        read -p "Choice [0]: " WORKERS
        WORKERS=${WORKERS:-0}
    else
        WORKERS=0
        log_info "Workers disabled for 1vCPU system"
    fi

    # Optional components
    echo
    echo -e "${YELLOW}Optional components:${NC}"
    read -p "Install Watchtower (auto-updates)? [y/N]: " INSTALL_WATCHTOWER
    INSTALL_WATCHTOWER=${INSTALL_WATCHTOWER:-n}

    # Generate passwords
    DB_PASSWORD=$(openssl rand -base64 32)
    ENCRYPTION_KEY=$(openssl rand -base64 32)

    if [ "$WORKERS" -gt 0 ]; then
        REDIS_PASSWORD=$(openssl rand -base64 32)
    fi
}

# Create directory structure
create_structure() {
    log_info "Creating directory structure..."

    mkdir -p "$INSTALL_DIR"/{data,backups,logs}
    cd "$INSTALL_DIR"
}

# Generate environment file
generate_env() {
    log_info "Generating configuration..."

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
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=n8n

# Performance (Ultra-lite for 1vCPU)
NODE_OPTIONS=--max-old-space-size=$([ "$MINIMAL_MODE" = true ] && echo "512" || echo "768")
EXECUTIONS_PROCESS=main
EXECUTIONS_MODE=$([ "$WORKERS" -gt 0 ] && echo "queue" || echo "regular")

# Workers
$([ "$WORKERS" -gt 0 ] && echo "QUEUE_BULL_REDIS_HOST=redis" || echo "# No workers")
$([ "$WORKERS" -gt 0 ] && echo "QUEUE_BULL_REDIS_PORT=6379" || echo "")
$([ "$WORKERS" -gt 0 ] && echo "REDIS_PASSWORD=$REDIS_PASSWORD" || echo "")

# Timezone
TZ=UTC
GENERIC_TIMEZONE=UTC

# Security
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=changeme

# Execution limits
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# Email (optional - configure later)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=
N8N_SMTP_PORT=
N8N_SMTP_USER=
N8N_SMTP_PASS=
EOF

    log_success "Configuration generated"
}

# Generate Docker Compose
generate_compose() {
    log_info "Creating Docker Compose configuration..."

    if [ "$MINIMAL_MODE" = true ]; then
        # Ultra-minimal compose for 1vCPU
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          memory: 256M
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
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
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      postgres:
        condition: service_healthy
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  postgres_data:
  n8n_data:
EOF
    else
        # Standard compose with optional workers
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: n8n-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5
EOF

        # Add Redis if workers enabled
        if [ "$WORKERS" -gt 0 ]; then
            cat >> docker-compose.yml << 'EOF'

  redis:
    image: redis:7-alpine
    container_name: n8n-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
EOF
        fi

        # Main n8n service
        cat >> docker-compose.yml << 'EOF'

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
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
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
EOF

        # Add Redis config if workers enabled
        if [ "$WORKERS" -gt 0 ]; then
            cat >> docker-compose.yml << 'EOF'
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
EOF
        fi

        # Continue n8n service
        cat >> docker-compose.yml << 'EOF'
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      postgres:
        condition: service_healthy
EOF

        # Add Redis dependency if needed
        if [ "$WORKERS" -gt 0 ]; then
            cat >> docker-compose.yml << 'EOF'
      redis:
        condition: service_healthy
EOF
        fi

        # Add workers if configured
        if [ "$WORKERS" -gt 0 ]; then
            for i in $(seq 1 $WORKERS); do
                cat >> docker-compose.yml << EOF

  n8n-worker-$i:
    image: n8nio/n8n:latest
    container_name: n8n-worker-$i
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
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      - postgres
      - redis
      - n8n
EOF
            done
        fi

        # Add Watchtower if selected
        if [ "$INSTALL_WATCHTOWER" = "y" ]; then
            cat >> docker-compose.yml << 'EOF'

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
      - WATCHTOWER_NOTIFICATIONS=email
      - WATCHTOWER_NOTIFICATION_EMAIL_FROM=${EMAIL:-admin@localhost}
      - WATCHTOWER_NOTIFICATION_EMAIL_TO=${EMAIL:-admin@localhost}
    deploy:
      resources:
        limits:
          memory: 64M
EOF
        fi

        # Volumes section
        cat >> docker-compose.yml << 'EOF'

volumes:
  postgres_data:
  n8n_data:
EOF

        if [ "$WORKERS" -gt 0 ]; then
            echo "  redis_data:" >> docker-compose.yml
        fi

        if [ "$INSTALL_PORTAINER" = "y" ]; then
            echo "  portainer_data:" >> docker-compose.yml
        fi
    fi

    log_success "Docker Compose configuration created"
}

# Generate Caddy config if production
generate_caddy() {
    if [ "$PRODUCTION" = true ]; then
        log_info "Generating Caddy configuration..."

        cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  caddy:
    image: caddy:alpine
    container_name: n8n-caddy
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

  n8n:
    ports: []
    expose:
      - "5678"

volumes:
  caddy_data:
  caddy_config:
EOF

        cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678 {
        header_up Host {host}
        header_up X-Real-IP {remote}
        header_up X-Forwarded-For {remote}
        header_up X-Forwarded-Proto {scheme}
    }

    encode gzip

    header {
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        -Server
    }

    log {
        output file /data/access.log
        format console
    }
}
EOF

        log_success "Caddy configuration created"
    fi
}

# Create management script
create_management_script() {
    log_info "Creating management script..."

    cat > n8n.sh << 'EOF'
#!/bin/bash

# n8n Management Script

case "$1" in
    start)
        docker-compose up -d
        echo "n8n started"
        ;;
    stop)
        docker-compose down
        echo "n8n stopped"
        ;;
    restart)
        docker-compose restart
        echo "n8n restarted"
        ;;
    logs)
        docker-compose logs -f ${2:-n8n}
        ;;
    backup)
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        docker exec n8n-postgres pg_dump -U n8n n8n | gzip > backups/n8n_backup_$TIMESTAMP.sql.gz
        echo "Backup created: backups/n8n_backup_$TIMESTAMP.sql.gz"
        ;;
    update)
        docker-compose pull
        docker-compose down
        docker-compose up -d
        echo "n8n updated"
        ;;
    status)
        docker-compose ps
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|backup|update|status}"
        exit 1
        ;;
esac
EOF

    chmod +x n8n.sh
    log_success "Management script created"
}

# Start services
start_services() {
    log_info "Starting services..."

    docker-compose up -d

    # Wait for services
    log_info "Waiting for services to initialize..."
    sleep 10

    # Check status
    if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
        log_success "n8n is running!"
    else
        log_warning "n8n may still be starting. Please wait a moment."
    fi
}

# Save credentials
save_credentials() {
    cat > credentials.txt << EOF
n8n Starter Pack - Installation Details
========================================
Date: $(date)
Version: $VERSION

Access URL: $([ "$PRODUCTION" = true ] && echo "https://$DOMAIN" || echo "http://localhost:5678")

Default Credentials:
Username: admin
Password: changeme
(Change these immediately!)

Database Password: $DB_PASSWORD
Encryption Key: $ENCRYPTION_KEY
$([ "$WORKERS" -gt 0 ] && echo "Redis Password: $REDIS_PASSWORD" || echo "")

Management Commands:
./n8n.sh start    - Start services
./n8n.sh stop     - Stop services
./n8n.sh restart  - Restart services
./n8n.sh logs     - View logs
./n8n.sh backup   - Create backup
./n8n.sh update   - Update n8n
./n8n.sh status   - Check status

Important:
- Keep this file secure
- Change default password immediately
- Regular backups recommended
EOF

    chmod 600 credentials.txt
    log_success "Credentials saved to credentials.txt"
}

# Main installation flow
main() {
    clear
    show_banner

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        log_error "Please run as regular user, not root"
    fi

    check_system
    setup_wizard

    log_info "Starting installation..."

    install_docker
    create_structure
    generate_env
    generate_compose
    generate_caddy
    create_management_script

    # Create shared folder for file operations
    mkdir -p shared
    log_info "Created shared folder at $INSTALL_DIR/shared"

    start_services
    save_credentials

    # Final message
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}     Installation Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${CYAN}Access n8n at:${NC}"
    if [ "$PRODUCTION" = true ]; then
        echo -e "${YELLOW}https://$DOMAIN${NC}"
    else
        echo -e "${YELLOW}http://localhost:5678${NC}"
    fi
    echo
    echo -e "${CYAN}Default login:${NC}"
    echo "Username: admin"
    echo "Password: changeme"
    echo
    echo -e "${RED}⚠️  Change the default password immediately!${NC}"
    echo
    echo -e "${CYAN}Management:${NC}"
    echo "cd $INSTALL_DIR"
    echo "./n8n.sh [start|stop|restart|logs|backup|update|status]"
    echo
    echo -e "${GREEN}Credentials saved in: $INSTALL_DIR/credentials.txt${NC}"
    echo

    if [ "$MINIMAL_MODE" = true ]; then
        echo -e "${YELLOW}Ultra-lite mode active - optimized for 1vCPU${NC}"
    fi

    if [ "$PRODUCTION" = true ]; then
        echo
        echo -e "${YELLOW}DNS Configuration Required:${NC}"
        echo "Add an A record pointing $DOMAIN to $(curl -s ifconfig.me)"
    fi
}

# Run installation
main "$@"