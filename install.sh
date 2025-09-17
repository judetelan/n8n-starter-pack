#!/bin/bash

###########################################
# n8n Starter Pack - Lightweight Installer
# Optimized for 1vCPU VPS deployment
# GitHub: yourusername/n8n-starter-pack
###########################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
INSTALL_DIR="$HOME/n8n"
DOMAIN=""
EMAIL=""
WORKERS=1
INSTALL_PORTAINER="n"
INSTALL_WATCHTOWER="n"
MIN_MODE="y"  # Minimal mode for low-resource VPS

# Print functions
print_message() {
    echo -e "${2}${1}${NC}"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════╗"
    echo "║   n8n Starter Pack Installer   ║"
    echo "║   Lightweight VPS Deployment   ║"
    echo "╚════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Check system
check_system() {
    print_message "🔍 Checking system requirements..." "$CYAN"

    # Check if running as regular user
    if [ "$EUID" -eq 0 ]; then
        print_message "⚠️  Running as root. Creating dedicated user recommended." "$YELLOW"
    fi

    # Check minimal requirements
    cpu_cores=$(nproc)
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    available_space=$(df ~ | awk 'NR==2 {print int($4/1024/1024)}')

    echo "CPU Cores: $cpu_cores"
    echo "RAM: ${total_mem}MB"
    echo "Disk: ${available_space}GB available"

    # Minimal requirements check
    if [ "$total_mem" -lt 1024 ]; then
        print_message "⚠️  Less than 1GB RAM detected. Minimal mode enabled." "$YELLOW"
        MIN_MODE="y"
    elif [ "$total_mem" -lt 2048 ]; then
        print_message "⚠️  Less than 2GB RAM. Running in lightweight mode." "$YELLOW"
        MIN_MODE="y"
    else
        MIN_MODE="n"
    fi

    if [ "$available_space" -lt 5 ]; then
        print_message "❌ Insufficient disk space. Need at least 5GB." "$RED"
        exit 1
    fi
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        print_message "✅ Docker already installed" "$GREEN"
    else
        print_message "🐳 Installing Docker..." "$CYAN"
        curl -fsSL https://get.docker.com -o get-docker.sh

        if [ "$EUID" -eq 0 ]; then
            sh get-docker.sh
        else
            sudo sh get-docker.sh
            sudo usermod -aG docker $USER
            print_message "⚠️  Please logout and login for docker group changes" "$YELLOW"
        fi

        rm get-docker.sh
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_message "📦 Installing Docker Compose..." "$CYAN"
        if [ "$EUID" -eq 0 ]; then
            curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
        else
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
    fi
}

# Quick setup mode
quick_setup() {
    print_message "\n⚡ Quick Setup Mode" "$CYAN"
    echo "For testing or development environments"
    echo

    # Use localhost
    DOMAIN="localhost"
    EMAIL="admin@localhost"

    print_message "✅ Using localhost configuration" "$GREEN"
}

# Production setup
production_setup() {
    print_message "\n🔧 Production Setup" "$CYAN"

    # Get domain
    read -p "Enter domain/subdomain (e.g., n8n.company.com): " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        print_message "Domain required for production!" "$RED"
        read -p "Enter domain: " DOMAIN
    done

    # Get email
    read -p "Email for SSL certificates: " EMAIL
    while [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; do
        print_message "Invalid email!" "$RED"
        read -p "Enter email: " EMAIL
    done

    # Get server IP for DNS info
    SERVER_IP=$(curl -s https://api.ipify.org)

    print_message "\n📝 DNS Configuration Required:" "$YELLOW"
    echo "Add this DNS A record:"
    echo "  Type: A"
    echo "  Name: ${DOMAIN%%.*}"
    echo "  Value: $SERVER_IP"
    echo "  TTL: 300"
    echo
    read -p "Press Enter when DNS is configured..."
}

# Configure installation
configure_installation() {
    print_message "\n⚙️  Configuration" "$CYAN"

    # Setup type
    echo "1) Quick Setup (localhost/testing)"
    echo "2) Production Setup (with domain)"
    read -p "Choose setup type [1]: " setup_type
    setup_type=${setup_type:-1}

    if [ "$setup_type" = "2" ]; then
        production_setup
    else
        quick_setup
    fi

    # Workers configuration
    if [ "$MIN_MODE" = "y" ]; then
        WORKERS=0  # No separate workers in minimal mode
        print_message "📉 Minimal mode: Running without separate workers" "$YELLOW"
    else
        cpu_cores=$(nproc)
        if [ "$cpu_cores" -eq 1 ]; then
            WORKERS=0
            print_message "📉 Single core detected: Running without separate workers" "$YELLOW"
        else
            read -p "Number of workers (0 for embedded mode) [0]: " WORKERS
            WORKERS=${WORKERS:-0}
        fi
    fi

    # Optional components
    if [ "$MIN_MODE" != "y" ]; then
        read -p "Install Portainer for Docker management? (y/n) [n]: " INSTALL_PORTAINER
        INSTALL_PORTAINER=${INSTALL_PORTAINER:-n}

        read -p "Install Watchtower for auto-updates? (y/n) [n]: " INSTALL_WATCHTOWER
        INSTALL_WATCHTOWER=${INSTALL_WATCHTOWER:-n}
    fi

    # Generate passwords
    POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)

    # Summary
    echo
    print_message "📋 Configuration Summary:" "$GREEN"
    echo "================================"
    echo "Domain: $DOMAIN"
    echo "Email: $EMAIL"
    echo "Workers: $WORKERS"
    echo "Portainer: $INSTALL_PORTAINER"
    echo "Watchtower: $INSTALL_WATCHTOWER"
    echo "Install Path: $INSTALL_DIR"
    echo "================================"

    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# Create directories
create_structure() {
    print_message "\n📁 Creating directory structure..." "$CYAN"

    mkdir -p $INSTALL_DIR/{data,postgres-data,caddy-data,backups}

    if [ "$WORKERS" -gt 0 ]; then
        mkdir -p $INSTALL_DIR/{redis-data}
        for i in $(seq 1 $WORKERS); do
            mkdir -p $INSTALL_DIR/data/worker-$i
        done
    fi

    if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
        mkdir -p $INSTALL_DIR/portainer-data
    fi

    cd $INSTALL_DIR
}

# Create environment file
create_env() {
    print_message "📝 Creating configuration..." "$CYAN"

    cat > $INSTALL_DIR/.env << EOF
# n8n Configuration
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Database
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=n8n
POSTGRES_USER=n8n

# n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://$DOMAIN/

# Workers
WORKERS=$WORKERS

# Timezone
TZ=UTC
GENERIC_TIMEZONE=UTC

# Performance (adjusted for low resources)
NODE_OPTIONS="--max-old-space-size=1024"
EOF

    if [ "$WORKERS" -gt 0 ]; then
        REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
        cat >> $INSTALL_DIR/.env << EOF

# Redis (for workers)
REDIS_PASSWORD=$REDIS_PASSWORD
EXECUTIONS_MODE=queue
EOF
    else
        cat >> $INSTALL_DIR/.env << EOF

# Execution mode
EXECUTIONS_MODE=regular
EOF
    fi

    chmod 600 $INSTALL_DIR/.env
}

# Create Docker Compose
create_docker_compose() {
    print_message "🐳 Creating Docker configuration..." "$CYAN"

    # Start docker-compose.yml
    cat > $INSTALL_DIR/docker-compose.yml << 'EOF'
version: '3.8'

services:
EOF

    # Add Caddy only for production
    if [ "$DOMAIN" != "localhost" ]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
  caddy:
    image: caddy:2-alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
      - ./caddy-data:/config

EOF
    fi

    # Add PostgreSQL (lightweight config)
    cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
  postgres:
    image: postgres:13-alpine
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

EOF

    # Add Redis if using workers
    if [ "$WORKERS" -gt 0 ]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
  redis:
    image: redis:6-alpine
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - ./redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--raw", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

EOF
    fi

    # Add n8n main instance
    cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
  n8n:
    image: n8nio/n8n:latest
    restart: unless-stopped
EOF

    # Add ports based on setup type
    if [ "$DOMAIN" = "localhost" ]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
    ports:
      - "5678:5678"
EOF
    fi

    # Add n8n configuration
    cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - EXECUTIONS_MODE=${EXECUTIONS_MODE}
      - NODE_OPTIONS=${NODE_OPTIONS}
      - TZ=${TZ}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
EOF

    # Add Redis config if using workers
    if [ "$WORKERS" -gt 0 ]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
EOF
    fi

    # Complete n8n service
    cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
    volumes:
      - ./data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
EOF

    if [ "$WORKERS" -gt 0 ]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'
      redis:
        condition: service_healthy
EOF
    fi

    # Add workers if configured
    if [ "$WORKERS" -gt 0 ]; then
        for i in $(seq 1 $WORKERS); do
            cat >> $INSTALL_DIR/docker-compose.yml << EOF

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
      - QUEUE_BULL_REDIS_HOST=redis
      - QUEUE_BULL_REDIS_PORT=6379
      - QUEUE_BULL_REDIS_PASSWORD=\${REDIS_PASSWORD}
      - NODE_OPTIONS=\${NODE_OPTIONS}
    volumes:
      - ./data/worker-$i:/home/node/.n8n
    depends_on:
      - postgres
      - redis
      - n8n
EOF
        done
    fi

    # Add Portainer if selected
    if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'

  portainer:
    image: portainer/portainer-ce:alpine
    restart: unless-stopped
    ports:
      - "9000:9000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer-data:/data
EOF
    fi

    # Add Watchtower if selected
    if [[ "$INSTALL_WATCHTOWER" =~ ^[Yy]$ ]]; then
        cat >> $INSTALL_DIR/docker-compose.yml << 'EOF'

  watchtower:
    image: containrrr/watchtower:latest
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
      - WATCHTOWER_INCLUDE_STOPPED=false
EOF
    fi
}

# Create Caddyfile for production
create_caddyfile() {
    if [ "$DOMAIN" != "localhost" ]; then
        print_message "📄 Creating Caddy configuration..." "$CYAN"

        cat > $INSTALL_DIR/Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678 {
        flush_interval -1
    }
}
EOF

        if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
            cat >> $INSTALL_DIR/Caddyfile << EOF

portainer.$DOMAIN {
    reverse_proxy portainer:9000
}
EOF
        fi
    fi
}

# Create management script
create_management() {
    print_message "🛠️ Creating management script..." "$CYAN"

    cat > $INSTALL_DIR/n8n.sh << 'EOF'
#!/bin/bash

cd ~/n8n
source .env

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

case "$1" in
    start)
        docker-compose up -d
        echo -e "${GREEN}n8n started${NC}"
        ;;
    stop)
        docker-compose down
        echo -e "${YELLOW}n8n stopped${NC}"
        ;;
    restart)
        docker-compose restart
        echo -e "${GREEN}n8n restarted${NC}"
        ;;
    status)
        docker-compose ps
        ;;
    logs)
        docker-compose logs -f ${2:-n8n}
        ;;
    backup)
        timestamp=$(date +%Y%m%d_%H%M%S)
        docker exec n8n-postgres-1 pg_dump -U n8n n8n > backups/backup_$timestamp.sql
        gzip backups/backup_$timestamp.sql
        echo -e "${GREEN}Backup created: backups/backup_$timestamp.sql.gz${NC}"
        ;;
    update)
        docker-compose pull
        docker-compose up -d
        echo -e "${GREEN}n8n updated${NC}"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backup|update}"
        echo ""
        echo "Commands:"
        echo "  start    - Start n8n"
        echo "  stop     - Stop n8n"
        echo "  restart  - Restart n8n"
        echo "  status   - Show status"
        echo "  logs     - View logs (optional: service name)"
        echo "  backup   - Backup database"
        echo "  update   - Update n8n"
        exit 1
        ;;
esac
EOF

    chmod +x $INSTALL_DIR/n8n.sh
}

# Start services
start_services() {
    print_message "\n🚀 Starting services..." "$CYAN"

    cd $INSTALL_DIR
    docker-compose up -d

    # Wait for services
    print_message "⏳ Waiting for services..." "$YELLOW"
    sleep 10

    # Check status
    docker-compose ps
}

# Save credentials
save_info() {
    cat > $INSTALL_DIR/credentials.txt << EOF
====================================
n8n Starter Pack - Installation Info
====================================

ACCESS:
-------
EOF

    if [ "$DOMAIN" = "localhost" ]; then
        echo "n8n: http://localhost:5678" >> $INSTALL_DIR/credentials.txt
    else
        echo "n8n: https://$DOMAIN" >> $INSTALL_DIR/credentials.txt
    fi

    if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
        if [ "$DOMAIN" = "localhost" ]; then
            echo "Portainer: http://localhost:9000" >> $INSTALL_DIR/credentials.txt
        else
            echo "Portainer: https://portainer.$DOMAIN" >> $INSTALL_DIR/credentials.txt
        fi
    fi

    cat >> $INSTALL_DIR/credentials.txt << EOF

DATABASE:
---------
User: n8n
Password: $POSTGRES_PASSWORD
Database: n8n

ENCRYPTION:
----------
Key: $N8N_ENCRYPTION_KEY

MANAGEMENT:
----------
Command: ~/n8n/n8n.sh

====================================
KEEP THIS FILE SECURE!
====================================
EOF

    chmod 600 $INSTALL_DIR/credentials.txt
}

# Display summary
show_summary() {
    print_message "\n✅ Installation Complete!" "$GREEN"
    echo "======================================"

    if [ "$DOMAIN" = "localhost" ]; then
        print_message "\n📌 Access n8n at:" "$CYAN"
        echo "http://localhost:5678"
    else
        print_message "\n📌 Access n8n at:" "$CYAN"
        echo "https://$DOMAIN"

        SERVER_IP=$(curl -s https://api.ipify.org)
        print_message "\n⚠️ DNS Setup Required:" "$YELLOW"
        echo "Point $DOMAIN to $SERVER_IP"
    fi

    if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]]; then
        print_message "\n🐳 Portainer:" "$CYAN"
        if [ "$DOMAIN" = "localhost" ]; then
            echo "http://localhost:9000"
        else
            echo "https://portainer.$DOMAIN"
        fi
    fi

    print_message "\n🛠️ Management Commands:" "$CYAN"
    echo "cd ~/n8n"
    echo "./n8n.sh status    # Check status"
    echo "./n8n.sh logs      # View logs"
    echo "./n8n.sh restart   # Restart n8n"
    echo "./n8n.sh backup    # Backup data"

    print_message "\n📄 Credentials saved to:" "$YELLOW"
    echo "~/n8n/credentials.txt"

    print_message "\n📚 Documentation:" "$BLUE"
    echo "https://docs.n8n.io"
    echo "======================================"
}

# Main
main() {
    print_banner
    check_system
    install_docker
    configure_installation
    create_structure
    create_env
    create_docker_compose
    create_caddyfile
    create_management
    start_services
    save_info
    show_summary
}

# Run
main