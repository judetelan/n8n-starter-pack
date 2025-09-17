# n8n Production Installer 🚀

Professional n8n deployment system with automatic SSL, workers, and Redis queue support. Optimized for VPS deployment with multi-client configurations.

## Features

- ✅ **Domain Required** - Professional deployment with HTTPS
- ✅ **Automatic SSL** - Let's Encrypt or custom certificates
- ✅ **Single Docker Compose** - Clean, unified configuration
- ✅ **Dynamic Workers** - 0 to N workers based on CPU
- ✅ **Built-in Management** - Update, backup, uninstall scripts
- ✅ **Multi-Client Ready** - Deploy for different clients easily
- ✅ **Auto Backups** - Optional daily backups
- ✅ **Resource Optimized** - Runs on 1GB RAM VPS

## Requirements

- Ubuntu/Debian VPS
- 1GB RAM minimum (2GB recommended)
- 5GB disk space
- Domain name pointed to VPS

## Quick Install

```bash
curl -sSL https://raw.githubusercontent.com/judetelan/n8n-starter-pack/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/judetelan/n8n-starter-pack.git
cd n8n-starter-pack
chmod +x install.sh
./install.sh
```

## Installation Process

The installer will ask for:

1. **Client/Project name** - Identifies this installation
2. **Domain name** - Required (e.g., n8n.company.com)
3. **SSL type** - Let's Encrypt (automatic) or custom
4. **Email** - For Let's Encrypt certificates
5. **Workers** - Number based on CPU cores
6. **Timezone** - For scheduling
7. **Auto-backup** - Daily backups at 2 AM

## What Gets Installed

```
n8n-[client]/
├── docker-compose.yml   # Single, complete configuration
├── .env                # Environment variables
├── Caddyfile          # SSL/reverse proxy config
├── manage.sh          # Management script
├── credentials.txt    # Login credentials (secured)
├── scripts/
│   ├── backup.sh      # Backup script
│   ├── update.sh      # Update script
│   └── uninstall.sh   # Uninstall script
├── data/              # n8n data
└── backups/           # Database backups
```

## Services Included

- **n8n** - Workflow automation platform
- **PostgreSQL** - Database (Alpine version)
- **Redis** - Queue management for workers
- **Caddy** - Reverse proxy with automatic SSL
- **Workers** - Parallel execution (if configured)

## Management Commands

After installation, manage n8n with:

```bash
cd ~/n8n-[client]

./manage.sh start      # Start all services
./manage.sh stop       # Stop all services
./manage.sh restart    # Restart services
./manage.sh status     # Check status & health
./manage.sh logs       # View logs
./manage.sh logs redis # View specific service logs
./manage.sh backup     # Create backup
./manage.sh update     # Update n8n
./manage.sh uninstall  # Remove installation
```

## DNS Configuration

After installation, configure your DNS:

1. Get your VPS IP from the installer output
2. Add DNS A record:
   - Type: `A`
   - Name: Your subdomain
   - Value: VPS IP address
   - TTL: 300

Wait 5-10 minutes for DNS propagation.

## Access n8n

Once DNS is configured:

- URL: `https://your-domain.com`
- Username: `admin` (shown after installation)
- Password: Auto-generated (shown after installation)

Credentials are saved in `credentials.txt` (permission 600).

## Worker Configuration

Workers process workflows in parallel:

- **1 CPU**: 0 workers (embedded mode)
- **2 CPU**: 1 worker recommended
- **4 CPU**: 2-3 workers recommended
- **8 CPU**: 4-7 workers recommended

## Resource Usage

### Minimal (1 CPU, no workers)
- n8n: ~400MB
- PostgreSQL: ~150MB
- Redis: ~50MB
- Caddy: ~20MB
- **Total**: ~620MB

### Standard (2+ CPU with workers)
- Above plus ~200MB per worker
- **Total**: ~1GB-1.5GB

## Backup & Restore

### Automatic Backups
If enabled during installation, daily backups run at 2 AM.

### Manual Backup
```bash
./manage.sh backup
```

### Restore Backup
```bash
cd ~/n8n-[client]
gunzip backups/backup_[CLIENT]_[TIMESTAMP].sql.gz
docker exec [CLIENT]-postgres psql -U [DB_USER] [DB_NAME] < backups/backup_[CLIENT]_[TIMESTAMP].sql
```

## Update n8n

```bash
./manage.sh update
```

This will:
1. Create a backup
2. Pull latest images
3. Restart services

## Uninstall

```bash
./manage.sh uninstall
```

This will:
1. Create final backup
2. Stop and remove containers
3. Remove volumes
4. Keep backups in `backups/` folder

## Troubleshooting

### Check Service Status
```bash
./manage.sh status
docker-compose ps
```

### View Logs
```bash
./manage.sh logs        # All logs
./manage.sh logs n8n     # n8n logs
./manage.sh logs postgres # Database logs
./manage.sh logs redis   # Redis logs
./manage.sh logs caddy   # SSL/proxy logs
```

### SSL Certificate Issues
- Ensure DNS is properly configured
- Check Caddy logs: `./manage.sh logs caddy`
- Verify ports 80 and 443 are open

### Connection Issues
- Check firewall: ports 80, 443 must be open
- Verify DNS propagation: `nslookup your-domain.com`
- Test locally: `curl http://localhost:5678/healthz`

## Security Notes

- Credentials are auto-generated and unique
- Basic auth is enabled by default
- SSL is enforced (HTTPS only)
- Database passwords are random 20-char strings
- Encryption key is unique per installation
- Regular backups recommended

## Support

- n8n Docs: https://docs.n8n.io
- n8n Community: https://community.n8n.io
- Issues: Create issue in this repo

## License

MIT

---

Built for production n8n deployments on VPS 🚀