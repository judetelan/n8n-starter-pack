# Configuration Guide

## Environment Variables

The `.env` file controls all n8n configuration. Located at `~/n8n/.env`.

## Essential Configuration

### Database Settings

```bash
# PostgreSQL Configuration
POSTGRES_USER=n8n
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=n8n
```

### n8n Core Settings

```bash
# Encryption key (DO NOT CHANGE after first run!)
N8N_ENCRYPTION_KEY=your_encryption_key_here

# Host configuration
N8N_HOST=your-domain.com
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://your-domain.com/
```

## Performance Tuning

### Memory Configuration

Adjust based on your VPS resources:

```bash
# 1GB RAM VPS
NODE_OPTIONS=--max-old-space-size=768

# 2GB RAM VPS
NODE_OPTIONS=--max-old-space-size=1536

# 4GB+ RAM VPS
NODE_OPTIONS=--max-old-space-size=2048
```

### Execution Settings

```bash
# Concurrent executions limit
N8N_CONCURRENCY_PRODUCTION_LIMIT=5  # Increase for more parallel workflows

# Payload size (MB)
N8N_PAYLOAD_SIZE_MAX=16  # Increase for large files

# Execution timeout (ms)
N8N_DEFAULT_EXECUTION_TIMEOUT=3600000  # 1 hour
```

## Worker Configuration

### Enable Queue Mode

For multi-worker setup:

```bash
# Change execution mode
EXECUTIONS_MODE=queue

# Set number of workers
WORKERS=2

# Redis configuration
REDIS_PASSWORD=your_redis_password
REDIS_MAX_MEMORY=512mb
```

### Worker Scaling

```bash
# Basic worker config
QUEUE_BULL_REDIS_HOST=redis
QUEUE_BULL_REDIS_PORT=6379
QUEUE_HEALTH_CHECK_ACTIVE=true
```

## Email Configuration

### SMTP Settings

```bash
# Enable email
N8N_EMAIL_MODE=smtp

# SMTP configuration
N8N_SMTP_HOST=smtp.gmail.com
N8N_SMTP_PORT=587
N8N_SMTP_USER=your-email@gmail.com
N8N_SMTP_PASS=your-app-password
N8N_SMTP_SENDER=your-email@gmail.com
N8N_SMTP_SSL=false
```

### Gmail Setup

1. Enable 2-factor authentication
2. Generate app-specific password
3. Use app password in `N8N_SMTP_PASS`

## Security Configuration

### Basic Authentication

```bash
# Enable basic auth
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=secure_password
```

### JWT Configuration

```bash
# JWT settings
N8N_JWT_AUTH_ACTIVE=true
N8N_JWT_AUTH_HEADER=Authorization
N8N_JWT_AUTH_HEADER_VALUE_PREFIX=Bearer
```

### Webhook Security

```bash
# Webhook authentication
N8N_WEBHOOK_TUNNEL_JWT_SECRET=your_webhook_secret
WEBHOOK_TUNNEL_URL=https://your-domain.com/
```

## Logging Configuration

### Log Levels

```bash
# Options: error, warn, info, verbose, debug
N8N_LOG_LEVEL=info

# Output: console, file
N8N_LOG_OUTPUT=console

# File logging
N8N_LOG_FILE_LOCATION=/home/node/.n8n/logs/n8n.log
N8N_LOG_FILE_MAX_SIZE=100m
N8N_LOG_FILE_MAX_FILES=30
```

### Execution Data

```bash
# Save execution data
EXECUTIONS_DATA_SAVE_ON_ERROR=all
EXECUTIONS_DATA_SAVE_ON_SUCCESS=all
EXECUTIONS_DATA_SAVE_MANUAL_EXECUTIONS=true

# Prune old executions
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=336  # Hours (14 days)
```

## Database Optimization

### PostgreSQL Tuning

Add to `docker-compose.yml`:

```yaml
postgres:
  command:
    - postgres
    - -c
    - shared_buffers=256MB
    - -c
    - max_connections=200
    - -c
    - effective_cache_size=1GB
    - -c
    - maintenance_work_mem=64MB
```

### Connection Pooling

```bash
# Database pool settings
DB_POSTGRESDB_CONNECTION_LIMIT=20
DB_POSTGRESDB_POOL_MIN=2
DB_POSTGRESDB_POOL_MAX=10
```

## Redis Configuration

### Memory Management

```bash
# Redis memory settings
REDIS_MAX_MEMORY=512mb
REDIS_MAX_MEMORY_POLICY=allkeys-lru

# Persistence
REDIS_APPENDONLY=yes
REDIS_APPENDFSYNC=everysec
```

### Queue Settings

```bash
# Bull queue configuration
QUEUE_BULL_REDIS_CONCURRENCY=5
QUEUE_RECOVERY_INTERVAL=60000
QUEUE_WORKER_LOCK_DURATION=30000
QUEUE_WORKER_STALLED_INTERVAL=30000
```

## Custom Nodes

### Install Custom Nodes

```bash
# Custom nodes directory
CUSTOM_EXTENSION_ENV=~/n8n/custom

# External hooks
EXTERNAL_HOOK_FILES=/home/node/.n8n/hooks.js
```

### Community Nodes

```bash
# Enable community nodes
N8N_COMMUNITY_PACKAGES_ENABLED=true
```

## Timezone Configuration

```bash
# Set timezone
TZ=America/New_York
GENERIC_TIMEZONE=America/New_York
```

## Metrics & Monitoring

### Enable Metrics

```bash
# Metrics endpoint
N8N_METRICS=true
N8N_METRICS_PREFIX=n8n_
N8N_METRICS_INCLUDE_DEFAULT_METRICS=true
N8N_METRICS_INCLUDE_API_ENDPOINTS=true
```

### Prometheus Integration

```bash
# Prometheus scraping
N8N_METRICS_INCLUDE_API_PATH_LABEL=true
N8N_METRICS_INCLUDE_API_METHOD_LABEL=true
N8N_METRICS_INCLUDE_API_STATUS_CODE_LABEL=true
```

## Advanced Settings

### Workflow Settings

```bash
# Default workflow settings
EXECUTIONS_TIMEOUT=3600
EXECUTIONS_TIMEOUT_MAX=7200

# Workflow sharing
N8N_WORKFLOW_SHARING_ENABLED=true
```

### API Configuration

```bash
# Public API
N8N_PUBLIC_API_DISABLED=false
N8N_PUBLIC_API_ENDPOINT_PREFIX=api/v1

# Payload limits
N8N_PAYLOAD_SIZE_MAX=16
N8N_REQUEST_SIZE_MAX=16mb
```

## Apply Configuration Changes

After modifying `.env`:

```bash
# Restart services
cd ~/n8n
docker-compose restart

# Or restart specific service
docker-compose restart n8n
```

## Configuration Best Practices

1. **Always backup** before making changes
2. **Test changes** in development first
3. **Document custom settings**
4. **Use strong passwords**
5. **Keep encryption key secure**
6. **Monitor after changes**

## Troubleshooting Configuration

### Check Current Configuration

```bash
# View environment variables
docker exec n8n-n8n-1 env | grep N8N

# Test configuration
docker-compose config
```

### Common Issues

**Changes not taking effect:**
```bash
# Full restart
docker-compose down
docker-compose up -d
```

**Invalid configuration:**
```bash
# Validate docker-compose
docker-compose config --quiet

# Check logs
docker-compose logs n8n
```