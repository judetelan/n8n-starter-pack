#!/bin/bash

###########################################
# n8n Production Installer
# Interactive VPS Deployment
# GitHub: judetelan/n8n-starter-pack
###########################################

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored messages
print_color() {
    echo -e "${2}${1}${NC}"
}

# Print banner
clear
echo -e "${CYAN}"
echo "╔═══════════════════════════════════════╗"
echo "║     n8n Production VPS Installer      ║"
echo "║     Optimized for Minimal Resources   ║"
echo "╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_color "This script must be run as root (use sudo)" "$RED"
   exit 1
fi

# System check
print_color "🔍 Checking System Requirements..." "$CYAN"
echo

# Get system info
CPU_CORES=$(nproc)
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
AVAILABLE_DISK=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
SERVER_IP=$(curl -s https://api.ipify.org)

echo "CPU Cores: $CPU_CORES"
echo "Total RAM: ${TOTAL_MEM}MB"
echo "Available Disk: ${AVAILABLE_DISK}GB"
echo "Server IP: $SERVER_IP"
echo

# Check minimum requirements
if [ "$TOTAL_MEM" -lt 900 ]; then
    print_color "⚠️  Warning: Less than 1GB RAM detected" "$YELLOW"
    print_color "Installation will continue with minimal configuration" "$YELLOW"
    echo
fi

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    print_color "📦 Installing Docker..." "$CYAN"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
else
    print_color "✅ Docker is already installed" "$GREEN"
fi

# Install Docker Compose if needed
if ! docker compose version &> /dev/null 2>&1; then
    if ! command -v docker-compose &> /dev/null; then
        print_color "📦 Installing Docker Compose..." "$CYAN"
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
fi

echo
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
print_color "             CONFIGURATION" "$CYAN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$CYAN"
echo

# Get client/project name
while true; do
    echo -e "${YELLOW}Enter a name for this installation (e.g., client1, production):${NC}"
    read -r CLIENT_NAME
    if [[ "$CLIENT_NAME" =~ ^[a-z][a-z0-9-]{0,20}$ ]]; then
        break
    else
        print_color "Invalid name. Use lowercase letters, numbers, and hyphens only." "$RED"
    fi
done

# Get domain
while true; do
    echo -e "${YELLOW}Enter your domain (e.g., n8n.company.com):${NC}"
    read -r DOMAIN
    if [[ "$DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]?\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        print_color "Invalid domain format!" "$RED"
    fi
done

# Get email
while true; do
    echo -e "${YELLOW}Enter email for SSL certificates:${NC}"
    read -r EMAIL
    if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        break
    else
        print_color "Invalid email format!" "$RED"
    fi
done

# Configure workers based on CPU
if [ "$CPU_CORES" -eq 1 ] || [ "$TOTAL_MEM" -lt 1500 ]; then
    WORKERS=0
    print_color "📊 Single core/Low RAM detected - Running without workers" "$YELLOW"
else
    echo -e "${YELLOW}Number of workers (0-$CPU_CORES) [Recommended: 1]:${NC}"
    read -r WORKERS
    WORKERS=${WORKERS:-1}
    if ! [[ "$WORKERS" =~ ^[0-9]+$ ]] || [ "$WORKERS" -gt "$CPU_CORES" ]; then
        WORKERS=1
        print_color "Using default: 1 worker" "$YELLOW"
    fi
fi

# Set timezone
echo -e "${YELLOW}Timezone (e.g., America/New_York) [UTC]:${NC}"
read -r TIMEZONE
TIMEZONE=${TIMEZONE:-UTC}

# Daily backup option
echo -e "${YELLOW}Enable daily backups at 2 AM? (y/n) [y]:${NC}"
read -r ENABLE_BACKUP
ENABLE_BACKUP=${ENABLE_BACKUP:-y}

# Generate secure passwords
print_color "🔐 Generating secure credentials..." "$CYAN"
POSTGRES_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-20)
REDIS_PASSWORD=$(openssl rand -base64 20 | tr -d "=+/" | cut -c1-20)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
ADMIN_PASSWORD=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)

# Set installation directory
INSTALL_DIR="/root/n8n-$CLIENT_NAME"

# Summary
echo
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
print_color "           INSTALLATION SUMMARY" "$GREEN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo "Client Name: $CLIENT_NAME"
echo "Domain: $DOMAIN"
echo "Email: $EMAIL"
echo "Workers: $WORKERS"
echo "Timezone: $TIMEZONE"
echo "Backups: $ENABLE_BACKUP"
echo "Install Path: $INSTALL_DIR"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo

echo -e "${YELLOW}Proceed with installation? (y/n) [y]:${NC}"
read -r CONFIRM
CONFIRM=${CONFIRM:-y}
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    print_color "Installation cancelled" "$RED"
    exit 1
fi

# Create directory structure
print_color "📁 Creating directory structure..." "$CYAN"
mkdir -p $INSTALL_DIR/{data,postgres-data,backups}
if [ "$WORKERS" -gt 0 ]; then
    mkdir -p $INSTALL_DIR/redis-data
fi
cd $INSTALL_DIR

# Create .env file
print_color "📝 Creating configuration files..." "$CYAN"
cat > .env << EOF
# Client Configuration
CLIENT_NAME=$CLIENT_NAME
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Database
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=n8n

# n8n Core
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://$DOMAIN/

# Basic Auth
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=$ADMIN_PASSWORD

# Execution Mode
EXECUTIONS_MODE=$([ "$WORKERS" -gt 0 ] && echo "queue" || echo "regular")

# Redis (if workers)
REDIS_PASSWORD=$REDIS_PASSWORD
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379

# Performance
NODE_OPTIONS=$([ "$TOTAL_MEM" -lt 1500 ] && echo "--max-old-space-size=512" || echo "--max-old-space-size=1024")

# Data Management
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# Timezone
TZ=$TIMEZONE
GENERIC_TIMEZONE=$TIMEZONE
EOF

chmod 600 .env

# Create docker-compose.yml
print_color "🐳 Creating Docker configuration..." "$CYAN"
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: ${CLIENT_NAME}-postgres
    restart: unless-stopped
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - n8n-network
EOF

# Add Redis if using workers
if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOF'

  # Redis for Queue Mode
  redis:
    image: redis:7-alpine
    container_name: ${CLIENT_NAME}-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - ./redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - n8n-network
EOF
fi

# Add n8n main instance
cat >> docker-compose.yml << 'EOF'

  # n8n Main Instance
  n8n:
    image: n8nio/n8n:latest
    container_name: ${CLIENT_NAME}-n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
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
EOF

# Add Redis config if workers
if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOF'
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
      - QUEUE_HEALTH_CHECK_ACTIVE=true
EOF
fi

# Complete n8n configuration
cat >> docker-compose.yml << 'EOF'
      - NODE_OPTIONS=${NODE_OPTIONS}
      - EXECUTIONS_DATA_SAVE_ON_ERROR=${EXECUTIONS_DATA_SAVE_ON_ERROR}
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=${EXECUTIONS_DATA_SAVE_ON_SUCCESS}
      - EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=${EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS}
      - EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE}
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
      - TZ=${TZ}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
    volumes:
      - ./data:/home/node/.n8n
      - ./files:/files
    depends_on:
      postgres:
        condition: service_healthy
EOF

if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOF'
      redis:
        condition: service_healthy
EOF
fi

cat >> docker-compose.yml << 'EOF'
    networks:
      - n8n-network
EOF

# Add workers if configured
for ((i=1; i<=$WORKERS; i++)); do
cat >> docker-compose.yml << EOF

  # n8n Worker $i
  n8n-worker-$i:
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
      - ./data:/home/node/.n8n
      - ./files:/files
    depends_on:
      - postgres
      - redis
      - n8n
    networks:
      - n8n-network
EOF
done

# Add Caddy
cat >> docker-compose.yml << 'EOF'

  # Caddy Reverse Proxy
  caddy:
    image: caddy:2-alpine
    container_name: ${CLIENT_NAME}-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
      - ./caddy-config:/config
    depends_on:
      - n8n
    networks:
      - n8n-network

networks:
  n8n-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
  n8n_data:
  caddy_data:
  caddy_config:
EOF

# Create Caddyfile
cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678 {
        flush_interval -1
    }
}
EOF

# Create management script
print_color "🛠️  Creating management scripts..." "$CYAN"
cat > manage.sh << 'EOF'
#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd $(dirname $0)

case "$1" in
    start)
        docker compose up -d
        echo -e "${GREEN}✅ n8n started${NC}"
        ;;
    stop)
        docker compose down
        echo -e "${YELLOW}⏹️  n8n stopped${NC}"
        ;;
    restart)
        docker compose restart
        echo -e "${GREEN}🔄 n8n restarted${NC}"
        ;;
    status)
        docker compose ps
        ;;
    logs)
        docker compose logs -f ${2:-n8n}
        ;;
    backup)
        timestamp=$(date +%Y%m%d_%H%M%S)
        source .env
        docker exec ${CLIENT_NAME}-postgres pg_dump -U n8n n8n > backups/backup_${CLIENT_NAME}_$timestamp.sql
        gzip backups/backup_${CLIENT_NAME}_$timestamp.sql
        echo -e "${GREEN}✅ Backup created: backups/backup_${CLIENT_NAME}_$timestamp.sql.gz${NC}"
        ;;
    update)
        echo "Creating backup before update..."
        $0 backup
        docker compose pull
        docker compose up -d
        echo -e "${GREEN}✅ n8n updated${NC}"
        ;;
    uninstall)
        echo -e "${RED}⚠️  This will delete all data! Are you sure? (yes/no)${NC}"
        read -r confirm
        if [ "$confirm" = "yes" ]; then
            $0 backup
            docker compose down -v
            echo -e "${RED}n8n uninstalled. Backups saved in backups/ folder${NC}"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|backup|update|uninstall}"
        echo
        echo "Commands:"
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  status    - Show service status"
        echo "  logs      - View logs (optional: service name)"
        echo "  backup    - Create database backup"
        echo "  update    - Update n8n to latest version"
        echo "  uninstall - Remove n8n (creates backup first)"
        ;;
esac
EOF

chmod +x manage.sh

# Create backup script for cron
if [[ "$ENABLE_BACKUP" =~ ^[Yy]$ ]]; then
    print_color "⏰ Setting up daily backup..." "$CYAN"
    cat > backup.sh << 'EOF'
#!/bin/bash
cd $(dirname $0)
source .env
timestamp=$(date +%Y%m%d_%H%M%S)
docker exec ${CLIENT_NAME}-postgres pg_dump -U n8n n8n > backups/backup_${CLIENT_NAME}_$timestamp.sql
gzip backups/backup_${CLIENT_NAME}_$timestamp.sql
# Keep only last 7 backups
ls -t backups/backup_*.sql.gz | tail -n +8 | xargs -r rm
EOF
    chmod +x backup.sh

    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 2 * * * $INSTALL_DIR/backup.sh") | crontab -
fi

# Save credentials
cat > credentials.txt << EOF
=====================================
n8n Installation Credentials
=====================================
Installation: $CLIENT_NAME
Date: $(date)
=====================================

ACCESS URLS:
------------
n8n URL: https://$DOMAIN
Local: http://$SERVER_IP:5678

LOGIN CREDENTIALS:
------------------
Username: admin
Password: $ADMIN_PASSWORD

DATABASE:
---------
Database: n8n
User: n8n
Password: $POSTGRES_PASSWORD

ENCRYPTION:
-----------
Key: $N8N_ENCRYPTION_KEY

MANAGEMENT:
-----------
Directory: $INSTALL_DIR
Command: ./manage.sh

=====================================
IMPORTANT: SAVE THESE CREDENTIALS!
=====================================
EOF

chmod 600 credentials.txt

# Start services
print_color "🚀 Starting services..." "$CYAN"
docker compose up -d

# Wait for services
print_color "⏳ Waiting for services to start..." "$YELLOW"
sleep 15

# Check status
docker compose ps

# Final summary
echo
echo
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
print_color "    ✅ INSTALLATION COMPLETE!" "$GREEN"
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo
echo -e "${CYAN}n8n Access:${NC}"
echo "  URL: https://$DOMAIN"
echo "  Username: admin"
echo "  Password: $ADMIN_PASSWORD"
echo
echo -e "${YELLOW}DNS Configuration:${NC}"
echo "  Ensure your DNS A record points to:"
echo "  $DOMAIN → $SERVER_IP"
echo
echo -e "${CYAN}Management Commands:${NC}"
echo "  cd $INSTALL_DIR"
echo "  ./manage.sh status   # Check status"
echo "  ./manage.sh logs     # View logs"
echo "  ./manage.sh backup   # Create backup"
echo "  ./manage.sh update   # Update n8n"
echo
echo -e "${GREEN}Credentials saved to:${NC}"
echo "  $INSTALL_DIR/credentials.txt"
echo
print_color "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "$GREEN"
echo
print_color "🎉 n8n is ready to use!" "$GREEN"
echo