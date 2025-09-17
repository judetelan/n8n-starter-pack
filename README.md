# n8n Production Installer 🚀

Professional n8n deployment system for VPS with automatic SSL, workers, and Redis queue support.

## ✅ Features

- **Domain Required** - Professional deployment with HTTPS
- **Automatic SSL** - Let's Encrypt certificates via Caddy
- **Optimized for 1GB VPS** - Runs on minimal resources
- **Dynamic Workers** - Auto-configures based on CPU/RAM
- **Built-in Management** - Update, backup, uninstall scripts
- **Multi-Client Ready** - Deploy multiple instances
- **Daily Backups** - Optional automated backups
- **Secure by Default** - Auto-generated credentials + basic auth

## 📋 Requirements

- Ubuntu/Debian VPS
- **1GB RAM minimum** (2GB recommended)
- 5GB disk space
- Domain name with DNS configured
- Root access

## 🚀 Installation

### One Command Install

```bash
curl -o install.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh && sudo bash install.sh
```

### Alternative Methods

**Using wget:**
```bash
wget -O install.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh && sudo bash install.sh
```

**Using git clone:**
```bash
git clone https://github.com/judetelan/n8n-starter-pack && cd n8n-starter-pack && sudo bash install.sh
```

## 📝 Installation Process

The installer will prompt for:

1. **Client/Project Name** - Identifier for this installation (e.g., `production`, `client1`)
2. **Domain** - Your domain/subdomain (e.g., `n8n.company.com`)
3. **Email** - For SSL certificates
4. **Workers** - Auto-calculated based on CPU (can override)
5. **Timezone** - For scheduling (default: UTC)
6. **Backups** - Enable daily backups at 2 AM (recommended)

## 🏗️ What Gets Installed

```
/root/n8n-[client]/
├── docker-compose.yml   # Complete Docker configuration
├── .env                 # Environment variables
├── Caddyfile           # SSL/reverse proxy config
├── manage.sh           # Management script
├── backup.sh           # Backup script (if enabled)
├── credentials.txt     # Login credentials (secured)
├── data/               # n8n data
├── postgres-data/      # Database files
├── redis-data/         # Queue data (if workers)
└── backups/            # Database backups
```

## 🔧 Services

- **n8n** - Workflow automation platform
- **PostgreSQL** - Database (Alpine version for minimal size)
- **Redis** - Queue management (if workers enabled)
- **Caddy** - Reverse proxy with automatic SSL
- **Workers** - Parallel execution (auto-configured)

## 🎮 Management Commands

```bash
cd /root/n8n-[client]

./manage.sh start      # Start all services
./manage.sh stop       # Stop all services
./manage.sh restart    # Restart services
./manage.sh status     # Check status
./manage.sh logs       # View logs (all services)
./manage.sh logs n8n   # View specific service logs
./manage.sh backup     # Create manual backup
./manage.sh update     # Update n8n to latest
./manage.sh uninstall  # Remove installation (backs up first)
```

## 🌐 DNS Configuration

### Before Installation

Configure your DNS A record:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `n8n` | Your-VPS-IP | 300 |

### Wildcard Setup (Multiple Instances)

For multiple clients, use wildcard DNS:

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `*` | Your-VPS-IP | 300 |

Then deploy:
- `client1.yourdomain.com`
- `client2.yourdomain.com`
- `staging.yourdomain.com`

## 🔐 Access n8n

After installation:

- **URL**: `https://your-domain.com`
- **Username**: `admin`
- **Password**: Auto-generated (shown after install)

Credentials are saved in `/root/n8n-[client]/credentials.txt`

## 💾 Backup & Restore

### Automatic Backups
If enabled, runs daily at 2 AM, keeping last 7 backups.

### Manual Backup
```bash
./manage.sh backup
```

### Restore
```bash
cd /root/n8n-[client]
gunzip backups/backup_*.sql.gz
docker exec [client]-postgres psql -U n8n n8n < backups/backup_*.sql
```

## 🔄 Updates

### Update n8n Application

```bash
./manage.sh update
```

This will:
1. Create backup
2. Pull latest n8n images
3. Restart services

### Update Installer Script

To get the latest installer improvements:

```bash
curl -o update-installer.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/update-installer.sh && sudo bash update-installer.sh
```

Or if you have the repository cloned:
```bash
cd n8n-starter-pack
git pull
```

## ⚙️ Resource Configuration

### 1GB VPS (1 CPU)
- Workers: 0 (embedded mode)
- Memory: 512MB Node.js limit
- Redis: Not installed
- ~600MB total usage

### 2GB VPS (2 CPU)
- Workers: 1
- Memory: 1024MB Node.js limit
- Redis: 256MB limited
- ~1.2GB total usage

### 4GB+ VPS (4+ CPU)
- Workers: 2+
- Memory: 2048MB Node.js limit
- Redis: 512MB
- Scales with resources

## 🛠️ Troubleshooting

### Check Services
```bash
./manage.sh status
docker compose ps
```

### View Logs
```bash
./manage.sh logs        # All logs
./manage.sh logs n8n    # n8n logs
./manage.sh logs postgres # Database logs
./manage.sh logs caddy  # SSL/proxy logs
```

### SSL Issues
- Ensure DNS is configured correctly
- Check ports 80 and 443 are open
- View Caddy logs: `./manage.sh logs caddy`

### Connection Issues
```bash
# Check firewall
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443

# Test locally
curl http://localhost:5678/healthz

# Check DNS
nslookup your-domain.com
```

### Low Memory
```bash
# Add swap if needed
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 🔒 Security

- ✅ Auto-generated strong passwords
- ✅ Basic authentication enabled
- ✅ SSL enforced (HTTPS only)
- ✅ Unique encryption keys per installation
- ✅ Database passwords (20 chars)
- ✅ Credentials file secured (600 permissions)

## 📚 Documentation

- **n8n Docs**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **Issues**: [Create issue](https://github.com/judetelan/n8n-starter-pack/issues)

## 📄 License

MIT

---

**Built for production n8n deployments on VPS** 🚀

Optimized for minimal resources while maintaining reliability and security.