#!/bin/bash

###########################################
# n8n Quick Installer with Auto Credentials
# Components: n8n + PostgreSQL + Redis + Workers
###########################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
clear
echo -e "${CYAN}"
cat << "EOF"
 _ __   ___  _ __
| '_ \ / _ \| '_ \
| | | | (_) | | | |
|_| |_|\___/|_| |_|

Quick Docker Installer
EOF
echo -e "${NC}"

# System check
MEM=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "1024")
CPU=$(nproc 2>/dev/null || echo "1")
echo -e "${YELLOW}System: ${CPU} CPU, ${MEM}MB RAM${NC}"

# Quick setup questions
echo
read -p "Number of workers (0-$CPU) [1]: " WORKERS
WORKERS=${WORKERS:-1}

read -p "Installation path [$HOME/n8n]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-$HOME/n8n}

# Install Docker if needed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    sudo curl -sL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Create directory
mkdir -p "$INSTALL_DIR" && cd "$INSTALL_DIR"

# Generate random credentials
echo
echo -e "${BLUE}Generating secure credentials...${NC}"

# Random password generator
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Generate all credentials
DB_USER="n8n_user"
DB_PASS=$(generate_password)
DB_NAME="n8n_db"
REDIS_PASS=$(generate_password)
ENCRYPTION_KEY=$(openssl rand -base64 32)
N8N_USER="admin"
N8N_PASS=$(generate_password)

# Create .env file
cat > .env << EOF
# Auto-generated credentials
# Created: $(date)

# Database
POSTGRES_USER=$DB_USER
POSTGRES_PASSWORD=$DB_PASS
POSTGRES_DB=$DB_NAME

# Redis
REDIS_PASSWORD=$REDIS_PASS

# n8n Core
N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY
N8N_HOST=localhost
N8N_PORT=5678
N8N_PROTOCOL=http
WEBHOOK_URL=http://localhost:5678/

# Basic Auth
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_PASS

# Queue Mode
EXECUTIONS_MODE=$([ "$WORKERS" -gt 0 ] && echo "queue" || echo "regular")
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379

# Performance
NODE_OPTIONS=--max-old-space-size=$([ "$CPU" -eq 1 ] && echo "512" || echo "1024")
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# Timezone
TZ=UTC
EOF

# Create docker-compose.yml
cat > docker-compose.yml << 'YAML'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: pg_isready -U ${POSTGRES_USER}
      interval: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: always
    command: redis-server --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "--no-auth-warning", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 5s
      retries: 5

  n8n:
    image: n8nio/n8n:latest
    restart: always
    ports:
      - "5678:5678"
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
      - TZ=${TZ}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./shared:/data/shared
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
YAML

# Add workers if specified
if [ "$WORKERS" -gt 0 ]; then
    for i in $(seq 1 $WORKERS); do
        cat >> docker-compose.yml << YAML

  worker-$i:
    image: n8nio/n8n:latest
    restart: always
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
YAML
    done
fi

# Add volumes
cat >> docker-compose.yml << 'YAML'

volumes:
  postgres_data:
  redis_data:
  n8n_data:
YAML

# Create management script
cat > manage.sh << 'SCRIPT'
#!/bin/bash

case "$1" in
    start) docker-compose up -d ;;
    stop) docker-compose down ;;
    restart) docker-compose restart ;;
    logs) docker-compose logs -f ${2:-n8n} ;;
    status) docker-compose ps ;;
    update)
        docker-compose pull
        docker-compose down
        docker-compose up -d
        ;;
    backup)
        mkdir -p backups
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        docker exec $(docker-compose ps -q postgres) pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > backups/$TIMESTAMP.sql.gz
        echo "Backup saved: backups/$TIMESTAMP.sql.gz"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|update|backup}"
        ;;
esac
SCRIPT
chmod +x manage.sh

# Create directories
mkdir -p shared backups

# Start services
echo
echo -e "${BLUE}Starting services...${NC}"
docker-compose up -d

# Wait for services
echo -e "${YELLOW}Waiting for initialization...${NC}"
sleep 10

# Check status
if curl -s http://localhost:5678/healthz > /dev/null 2>&1; then
    STATUS="${GREEN}✓ Running${NC}"
else
    STATUS="${YELLOW}⚠ Starting...${NC}"
fi

# Save credentials to file
cat > credentials.txt << EOF
n8n Installation Credentials
============================
Date: $(date)
Path: $INSTALL_DIR

Access URL: http://localhost:5678

Login Credentials:
  Username: $N8N_USER
  Password: $N8N_PASS

Database:
  User: $DB_USER
  Password: $DB_PASS
  Database: $DB_NAME

Redis:
  Password: $REDIS_PASS

Encryption Key: $ENCRYPTION_KEY

Workers: $WORKERS
Mode: $([ "$WORKERS" -gt 0 ] && echo "Queue" || echo "Regular")
============================
EOF
chmod 600 credentials.txt

# Display credentials (like kossakovsky)
clear
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║            🎉 Installation Complete! 🎉             ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                 ACCESS CREDENTIALS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}📍 URL:${NC}      http://localhost:5678"
echo -e "${BLUE}👤 Username:${NC} ${GREEN}$N8N_USER${NC}"
echo -e "${BLUE}🔑 Password:${NC} ${GREEN}$N8N_PASS${NC}"
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                 SYSTEM DETAILS${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${BLUE}📁 Location:${NC}   $INSTALL_DIR"
echo -e "${BLUE}⚙️  Workers:${NC}    $WORKERS"
echo -e "${BLUE}🔄 Status:${NC}     $STATUS"
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}                  MANAGEMENT${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo "  cd $INSTALL_DIR"
echo "  ./manage.sh status    # Check status"
echo "  ./manage.sh logs      # View logs"
echo "  ./manage.sh backup    # Create backup"
echo "  ./manage.sh update    # Update n8n"
echo
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "${RED}⚠️  IMPORTANT:${NC} Credentials saved in: ${YELLOW}credentials.txt${NC}"
echo -e "${RED}⚠️  IMPORTANT:${NC} Keep these credentials secure!"
echo
echo -e "${GREEN}Happy automating! 🚀${NC}"
echo