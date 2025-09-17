# Installation Guide

## Prerequisites

Before installing n8n Starter Pack, ensure you have:

1. **A VPS or Server** with:
   - Ubuntu 20.04+ / Debian 10+ / CentOS 8+
   - SSH access with sudo privileges
   - At least 1GB RAM (2GB recommended)
   - 5GB free disk space

2. **Domain Name** (optional, for production):
   - A registered domain or subdomain
   - Access to DNS management

## Installation Methods

### Method 1: One-Line Installation (Recommended)

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/n8n-starter-pack/main/install.sh | bash
```

### Method 2: Manual Installation

1. **Download the installer:**
```bash
wget https://raw.githubusercontent.com/yourusername/n8n-starter-pack/main/install.sh
chmod +x install.sh
```

2. **Run the installer:**
```bash
./install.sh
```

### Method 3: Clone Repository

```bash
git clone https://github.com/yourusername/n8n-starter-pack.git
cd n8n-starter-pack
chmod +x install.sh
./install.sh
```

## Installation Process

### Step 1: System Check

The installer will automatically check:
- Operating system compatibility
- Available RAM and CPU cores
- Disk space
- User permissions

### Step 2: Choose Setup Type

You'll be prompted to choose between:

#### Quick Setup (Development)
- Uses `localhost` as domain
- No SSL certificates
- Access via `http://localhost:5678`
- Best for testing and development

#### Production Setup
- Requires a domain name
- Automatic SSL with Let's Encrypt
- Caddy reverse proxy
- Production-ready configuration

### Step 3: Configuration Options

#### Workers (for scaling)
- **0 workers**: Embedded mode (default for 1vCPU)
- **1-2 workers**: For 2+ vCPU systems
- **3+ workers**: For high-load production

#### Optional Services
- **Portainer**: Docker management UI
- **Watchtower**: Automatic container updates

### Step 4: Installation

The installer will:
1. Install Docker and Docker Compose
2. Create directory structure
3. Generate secure passwords
4. Configure environment variables
5. Deploy containers
6. Start services

## Post-Installation

### Access n8n

After installation, access n8n at:

- **Quick Setup**: `http://localhost:5678`
- **Production**: `https://your-domain.com`

### First-Time Setup

1. **Create Admin Account:**
   - Email: Your admin email
   - Password: Strong password
   - Save credentials securely

2. **Configure SMTP (Optional):**
   - Settings → Email
   - Add SMTP credentials for notifications

3. **Set Timezone:**
   - Settings → Settings
   - Select your timezone

### Important Files

Your installation creates these files:

```
~/n8n/
├── docker-compose.yml  # Container configuration
├── .env               # Environment variables
├── credentials.txt    # Login information (KEEP SECURE!)
├── n8n.sh            # Management script
└── Caddyfile         # Web server config (production only)
```

## DNS Configuration (Production)

For production setup, configure DNS before or after installation:

1. **Get your server IP:**
```bash
curl ifconfig.me
```

2. **Add DNS A Record:**
- Type: `A`
- Name: `@` or subdomain (e.g., `n8n`)
- Value: Your server IP
- TTL: 300

3. **Verify DNS:**
```bash
nslookup your-domain.com
dig your-domain.com
```

## Troubleshooting Installation

### Docker Installation Failed

```bash
# Manual Docker installation
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Logout and login again
```

### Permission Issues

```bash
# Run with sudo
sudo ./install.sh

# Or fix permissions
sudo chown -R $USER:$USER ~/n8n
```

### Port Already in Use

```bash
# Check what's using port 5678
sudo lsof -i :5678

# Change port in .env
N8N_PORT=5679
```

### Low Memory Issues

Edit `~/n8n/.env`:
```bash
# Reduce memory usage
NODE_OPTIONS=--max-old-space-size=512
```

## Verification

After installation, verify everything is working:

```bash
# Check services
cd ~/n8n
docker-compose ps

# All services should show "Up" status

# Test n8n
curl http://localhost:5678/healthz
# Should return: {"status":"ok"}
```

## Security Considerations

1. **Firewall Configuration:**
```bash
# Allow only necessary ports
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw enable
```

2. **Secure Credentials:**
```bash
# Protect credentials file
chmod 600 ~/n8n/credentials.txt
```

3. **Regular Updates:**
```bash
# Update n8n regularly
cd ~/n8n
./n8n.sh update
```

## Next Steps

- [Configuration Guide](CONFIGURATION.md)
- [Management Commands](MANAGEMENT.md)
- [Backup & Restore](BACKUP.md)
- [Scaling Guide](SCALING.md)