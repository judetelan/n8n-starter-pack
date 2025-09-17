# n8n Production Installer 🚀

Professional n8n deployment system for VPS with automatic SSL, workers, and Redis queue support.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![n8n Version](https://img.shields.io/badge/n8n-latest-orange.svg)](https://github.com/n8n-io/n8n)
[![Docker](https://img.shields.io/badge/docker-required-blue.svg)](https://www.docker.com/)
[![Ubuntu](https://img.shields.io/badge/ubuntu-20.04%2B-orange.svg)](https://ubuntu.com/)

> **Production-ready n8n deployment in under 5 minutes** - Complete with SSL, PostgreSQL, Redis queues, and automated backups.

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-what-youll-be-asked)
- [Services & Architecture](#-services)
- [Management Commands](#-management-commands)
- [DNS Configuration](#-dns-configuration)
- [Access n8n](#-access-n8n)
- [Backup & Restore](#-backup--restore)
- [Updates](#-updates)
- [Resource Configuration](#️-resource-configuration)
- [Troubleshooting](#️-troubleshooting)
- [Security](#-security)
- [Advanced Configuration](#-advanced-configuration)
- [Performance Tuning](#-performance-tuning)
- [FAQ](#-frequently-asked-questions)
- [Documentation](#-documentation--resources)
- [Contributing](#-contributing)
- [License](#-license)

## 🚀 Quick Start

```bash
curl -o install.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/install.sh && sudo bash install.sh
```

That's it! Just follow the prompts. The installer will:
1. Check your system resources
2. Ask for your domain and email
3. Configure everything automatically
4. Give you the login credentials

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

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or Debian 11+
- **RAM**: 1GB minimum (2GB+ recommended for production)
- **CPU**: 1 vCPU minimum (2+ for workers)
- **Storage**: 10GB minimum
- **Domain**: Required with DNS A record configured
- **Ports**: 80, 443 (must be open)
- **Access**: Root or sudo access

### Supported Providers
Tested and optimized for:
- DigitalOcean
- Linode
- Vultr
- Hetzner
- AWS Lightsail
- Google Cloud
- Any KVM/Xen VPS provider

## 📝 What You'll Be Asked

1. **Installation name** - e.g., `production` or `client1`
2. **Domain** - e.g., `n8n.yourdomain.com`
3. **Email** - For SSL certificates
4. **Workers** - Auto-detected (just press Enter)
5. **Timezone** - Default UTC (just press Enter)
6. **Backups** - Default Yes (just press Enter)

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

### Common Issues & Solutions

#### 🔴 502 Bad Gateway Error
**Symptom**: Browser shows 502 error when accessing n8n

**Solution 1**: Fix permissions (most common)
```bash
curl -o fix-permissions.sh https://raw.githubusercontent.com/judetelan/n8n-starter-pack/master/fix-permissions.sh && sudo bash fix-permissions.sh
```

**Solution 2**: Check if services are running
```bash
cd /root/n8n-[client]
./manage.sh status
./manage.sh logs n8n
```

#### 🔴 Permission Denied Errors
**Symptom**: Logs show `EACCES: permission denied, open '/home/node/.n8n/config'`

**Solution**: Run the permission fix script
```bash
cd /root/n8n-[client]
docker compose down
chown -R 1000:1000 ./data ./files
docker compose up -d
```

#### 🔴 SSL Certificate Issues
**Symptom**: HTTPS not working or certificate errors

**Solutions**:
1. Verify DNS is configured:
```bash
nslookup your-domain.com
dig your-domain.com
```

2. Check Caddy logs:
```bash
./manage.sh logs caddy
```

3. Ensure ports are open:
```bash
sudo ufw status
sudo ufw allow 80
sudo ufw allow 443
```

#### 🔴 High Memory Usage
**Symptom**: Services crashing or VPS running out of memory

**Solutions**:
1. Add swap space:
```bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

2. Reduce Node.js memory limit in `.env`:
```bash
NODE_OPTIONS="--max-old-space-size=512"
```

#### 🔴 Container Keeps Restarting
**Symptom**: n8n container in restart loop

**Debug steps**:
```bash
# Check logs
./manage.sh logs n8n --tail=50

# Check disk space
df -h

# Check memory
free -m

# Restart fresh
docker compose down
docker compose up -d
```

### Quick Diagnostic Commands

```bash
# Check all services
cd /root/n8n-[client]
./manage.sh status

# View recent logs
./manage.sh logs --tail=50

# Test n8n health
curl http://localhost:5678/healthz

# Check disk usage
df -h

# Check memory
free -m

# Check Docker
docker ps -a
docker compose ps
```

### Log Locations

| Service | Log Command | Description |
|---------|-------------|-------------|
| n8n | `./manage.sh logs n8n` | Application logs |
| PostgreSQL | `./manage.sh logs postgres` | Database logs |
| Redis | `./manage.sh logs redis` | Queue logs |
| Caddy | `./manage.sh logs caddy` | SSL/proxy logs |
| Workers | `./manage.sh logs n8n-worker-1` | Worker process logs |

## 🔒 Security

### Security Features
- ✅ **Auto-generated strong passwords** - 20+ character passwords
- ✅ **Basic authentication enabled** - Additional layer before n8n login
- ✅ **SSL enforced** - HTTPS only, no plain HTTP
- ✅ **Unique encryption keys** - Per-installation encryption
- ✅ **Database isolation** - Separate PostgreSQL per instance
- ✅ **Credentials secured** - 600 permissions on sensitive files
- ✅ **Docker network isolation** - Services communicate internally
- ✅ **No root processes** - n8n runs as non-root user

### Security Best Practices
1. **Regular Updates**: Run `./manage.sh update` monthly
2. **Backup Credentials**: Save credentials.txt offline
3. **Firewall Rules**: Only allow ports 80, 443, and SSH
4. **SSH Keys**: Disable password authentication for SSH
5. **Monitoring**: Check logs regularly for suspicious activity

## 🎯 Advanced Configuration

### Environment Variables
All configuration is stored in `/root/n8n-[client]/.env`. Key variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `N8N_PORT` | n8n internal port | 5678 |
| `NODE_OPTIONS` | Node.js memory limit | --max-old-space-size=1024 |
| `EXECUTIONS_MODE` | Execution mode | queue (with workers) or regular |
| `EXECUTIONS_DATA_SAVE_ON_ERROR` | Save failed executions | all |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | Save successful executions | all |
| `EXECUTIONS_DATA_MAX_AGE` | Max age of execution data | 336 (hours) |
| `TZ` | Timezone | UTC |

### Multiple Instances
Deploy multiple n8n instances on the same VPS:

```bash
# First instance
sudo bash install.sh
# Enter: client1 as name, client1.domain.com as domain

# Second instance
sudo bash install.sh
# Enter: client2 as name, client2.domain.com as domain
```

Each instance is completely isolated with its own:
- Database
- Redis queue (if workers enabled)
- Data directory
- Credentials
- SSL certificate

### Custom Workflows Directory
To use a custom workflows location:

1. Edit `docker-compose.yml`
2. Add volume mapping:
```yaml
volumes:
  - ./data:/home/node/.n8n
  - ./files:/files
  - /path/to/workflows:/home/node/.n8n/workflows
```

## ❓ Frequently Asked Questions

### Q: Can I install this on a shared hosting?
**A**: No, this requires a VPS with root access and Docker support. Shared hosting won't work.

### Q: What's the minimum RAM requirement?
**A**: 1GB RAM minimum, but 2GB+ is recommended for production use with workers.

### Q: Can I use this without a domain?
**A**: No, a domain is required for SSL certificates. You cannot use just an IP address.

### Q: How do I access n8n after installation?
**A**: Visit `https://your-domain.com` and use the credentials shown after installation or saved in `/root/n8n-[client]/credentials.txt`

### Q: Can I install multiple instances on one VPS?
**A**: Yes! Just run the installer multiple times with different client names and domains.

### Q: How do I update n8n?
**A**: Run `./manage.sh update` in your installation directory.

### Q: Is my data backed up?
**A**: If you enabled backups during installation, daily backups run at 2 AM. You can also run manual backups with `./manage.sh backup`

### Q: What if I forget my password?
**A**: Check `/root/n8n-[client]/credentials.txt` or reset it in the `.env` file and restart services.

### Q: Can I migrate from another n8n installation?
**A**: Yes, export your workflows from the old instance and import them in the new one through the n8n UI.

### Q: How do I uninstall?
**A**: Run `./manage.sh uninstall` - this creates a backup first, then removes everything.

### Q: Does this work on ARM processors?
**A**: Currently optimized for x86_64. ARM support (Raspberry Pi, etc.) is not tested.

### Q: Can I customize the installation path?
**A**: The installer uses `/root/n8n-[client]` by default. Customizing requires modifying the install script.

## 🚦 Performance Tuning

### For High-Volume Workflows
1. **Increase Workers**: Edit `.env` and restart
```bash
WORKERS=4
```

2. **Optimize PostgreSQL**: Add to `docker-compose.yml`:
```yaml
postgres:
  command:
    - postgres
    - -c
    - max_connections=200
    - -c
    - shared_buffers=256MB
```

3. **Redis Memory**: Increase in `docker-compose.yml`:
```yaml
redis:
  command: redis-server --maxmemory 512mb
```

### Monitoring Performance
```bash
# CPU and Memory usage
docker stats

# Database connections
docker exec [client]-postgres psql -U n8n -c "SELECT count(*) FROM pg_stat_activity;"

# Redis memory
docker exec [client]-redis redis-cli -a $REDIS_PASSWORD INFO memory
```

## 📚 Documentation & Resources

### Official Documentation
- **n8n Docs**: https://docs.n8n.io
- **n8n Community**: https://community.n8n.io
- **n8n Forum**: https://community.n8n.io/c/questions/5
- **n8n Discord**: https://discord.gg/n8n

### This Installer
- **GitHub**: https://github.com/judetelan/n8n-starter-pack
- **Issues**: [Report bugs](https://github.com/judetelan/n8n-starter-pack/issues)
- **Updates**: Check [Releases](https://github.com/judetelan/n8n-starter-pack/releases)

### Useful Guides
- [n8n Workflow Examples](https://n8n.io/workflows)
- [n8n Nodes Documentation](https://docs.n8n.io/integrations/)
- [n8n API Reference](https://docs.n8n.io/api/)
- [Custom Nodes Development](https://docs.n8n.io/nodes/creating-nodes/)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### How to Contribute
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [n8n.io](https://n8n.io) for the amazing workflow automation platform
- [Caddy Server](https://caddyserver.com) for simple SSL management
- [Docker](https://docker.com) for containerization
- Community contributors and testers

---

**Built with ❤️ for production n8n deployments** 🚀

*Optimized for minimal resources while maintaining reliability and security.*

**Last Updated**: 2024 | **Version**: 1.0.2 | **Status**: Production Ready