#!/bin/bash

###########################################
# n8n Quick Installer - Direct Production
# No prompts version - edit variables below
###########################################

# EDIT THESE VALUES
DOMAIN="n8n.clearskiesmediagroup.com"
EMAIL="admin@clearskiesmediagroup.com"
CLIENT_NAME="clearskies"

# Auto-detect system
INSTALL_DIR="$HOME/n8n-$CLIENT_NAME"
cpu_cores=$(nproc)
total_mem=$(free -m | awk '/^Mem:/{print $2}')

# Auto-configure workers
if [ "$cpu_cores" -eq 1 ] || [ "$total_mem" -lt 1536 ]; then
    WORKERS=0
    EXECUTIONS_MODE="regular"
    echo "Single core/Low RAM: No workers"
else
    WORKERS=1
    EXECUTIONS_MODE="queue"
    echo "Multi-core: 1 worker"
fi

# Generate passwords
POSTGRES_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
REDIS_PASSWORD=$(openssl rand -base64 24 | tr -d "=+/" | cut -c1-20)
N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
N8N_BASIC_USER="admin"
N8N_BASIC_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)

# Memory limit
if [ "$total_mem" -lt 1536 ]; then
    NODE_OPTIONS="--max-old-space-size=512"
else
    NODE_OPTIONS="--max-old-space-size=1024"
fi

# Create directories
echo "Creating directories..."
mkdir -p $INSTALL_DIR/{data,postgres-data,redis-data,backups}
cd $INSTALL_DIR

# Create .env
echo "Creating configuration..."
cat > .env << EOF
# Domain
DOMAIN=$DOMAIN
EMAIL=$EMAIL

# Database
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=n8n

# n8n
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY
N8N_HOST=$DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://$DOMAIN/
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=$N8N_BASIC_USER
N8N_BASIC_AUTH_PASSWORD=$N8N_BASIC_PASSWORD

# Execution
EXECUTIONS_MODE=$EXECUTIONS_MODE
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168

# Redis (if workers)
REDIS_PASSWORD=$REDIS_PASSWORD
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379

# Performance
NODE_OPTIONS=$NODE_OPTIONS

# Timezone
TZ=UTC
GENERIC_TIMEZONE=UTC
EOF

chmod 600 .env

# Create docker-compose.yml
echo "Creating Docker configuration..."
cat > docker-compose.yml << 'EOFDOCKER'
version: '3.8'

services:
  # Caddy Reverse Proxy
  caddy:
    image: caddy:2-alpine
    container_name: ${CLIENT_NAME:-n8n}-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy-data:/data
    depends_on:
      - n8n

  # PostgreSQL Database
  postgres:
    image: postgres:13-alpine
    container_name: ${CLIENT_NAME:-n8n}-postgres
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
EOFDOCKER

# Add Redis if workers
if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOFDOCKER'

  # Redis for Queue Mode
  redis:
    image: redis:6-alpine
    container_name: ${CLIENT_NAME:-n8n}-redis
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - ./redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
EOFDOCKER
fi

# Add n8n main
cat >> docker-compose.yml << 'EOFDOCKER'

  # n8n Main Instance
  n8n:
    image: n8nio/n8n:latest
    container_name: ${CLIENT_NAME:-n8n}-main
    restart: unless-stopped
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - N8N_HOST=${N8N_HOST}
      - N8N_PORT=${N8N_PORT}
      - N8N_PROTOCOL=${N8N_PROTOCOL}
      - WEBHOOK_URL=${WEBHOOK_URL}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=${EXECUTIONS_MODE}
      - NODE_OPTIONS=${NODE_OPTIONS}
      - TZ=${TZ}
      - GENERIC_TIMEZONE=${GENERIC_TIMEZONE}
      - N8N_BASIC_AUTH_ACTIVE=${N8N_BASIC_AUTH_ACTIVE}
      - N8N_BASIC_AUTH_USER=${N8N_BASIC_AUTH_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_BASIC_AUTH_PASSWORD}
      - EXECUTIONS_DATA_SAVE_ON_ERROR=${EXECUTIONS_DATA_SAVE_ON_ERROR}
      - EXECUTIONS_DATA_SAVE_ON_SUCCESS=${EXECUTIONS_DATA_SAVE_ON_SUCCESS}
      - EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=${EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS}
      - EXECUTIONS_DATA_PRUNE=${EXECUTIONS_DATA_PRUNE}
      - EXECUTIONS_DATA_MAX_AGE=${EXECUTIONS_DATA_MAX_AGE}
EOFDOCKER

# Add Redis config if workers
if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOFDOCKER'
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
EOFDOCKER
fi

# Complete n8n service
cat >> docker-compose.yml << 'EOFDOCKER'
    volumes:
      - ./data:/home/node/.n8n
    depends_on:
      postgres:
        condition: service_healthy
EOFDOCKER

if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOFDOCKER'
      redis:
        condition: service_healthy
EOFDOCKER
fi

# Add worker if configured
if [ "$WORKERS" -gt 0 ]; then
cat >> docker-compose.yml << 'EOFDOCKER'

  # n8n Worker
  n8n-worker:
    image: n8nio/n8n:latest
    container_name: ${CLIENT_NAME:-n8n}-worker
    restart: unless-stopped
    command: worker
    environment:
      - N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=${POSTGRES_DB}
      - DB_POSTGRESDB_USER=${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=${POSTGRES_PASSWORD}
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=${QUEUE_BULL_REDIS_HOST}
      - QUEUE_BULL_REDIS_PORT=${QUEUE_BULL_REDIS_PORT}
      - QUEUE_BULL_REDIS_PASSWORD=${REDIS_PASSWORD}
      - NODE_OPTIONS=${NODE_OPTIONS}
    volumes:
      - ./data:/home/node/.n8n
    depends_on:
      - postgres
      - redis
      - n8n
EOFDOCKER
fi

# Add CLIENT_NAME to .env
echo "CLIENT_NAME=$CLIENT_NAME" >> .env

# Create Caddyfile
echo "Creating Caddy configuration..."
cat > Caddyfile << EOF
$DOMAIN {
    reverse_proxy n8n:5678 {
        flush_interval -1
    }

    tls $EMAIL
}
EOF

# Create management script
echo "Creating management script..."
cat > manage.sh << 'EOF'
#!/bin/bash

cd $(dirname $0)

case "$1" in
    start)
        docker compose up -d
        echo "n8n started"
        ;;
    stop)
        docker compose down
        echo "n8n stopped"
        ;;
    restart)
        docker compose restart
        echo "n8n restarted"
        ;;
    status)
        docker compose ps
        ;;
    logs)
        docker compose logs -f ${2:-n8n}
        ;;
    update)
        docker compose pull
        docker compose up -d
        echo "n8n updated"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|update}"
        exit 1
        ;;
esac
EOF

chmod +x manage.sh

# Save credentials
echo "Saving credentials..."
cat > credentials.txt << EOF
====================================
n8n Installation Complete
====================================

URL: https://$DOMAIN
Username: $N8N_BASIC_USER
Password: $N8N_BASIC_PASSWORD

Database Password: $POSTGRES_PASSWORD
Encryption Key: $N8N_ENCRYPTION_KEY

Management: ./manage.sh
====================================
EOF

chmod 600 credentials.txt

# Start services
echo "Starting services..."
docker compose up -d

# Summary
echo ""
echo "======================================"
echo "✅ Installation Complete!"
echo "======================================"
echo ""
echo "Access n8n at: https://$DOMAIN"
echo "Username: $N8N_BASIC_USER"
echo "Password: $N8N_BASIC_PASSWORD"
echo ""
echo "Credentials saved to: $INSTALL_DIR/credentials.txt"
echo ""
echo "Management commands:"
echo "  cd $INSTALL_DIR"
echo "  ./manage.sh status"
echo "  ./manage.sh logs"
echo "  ./manage.sh restart"
echo "======================================"