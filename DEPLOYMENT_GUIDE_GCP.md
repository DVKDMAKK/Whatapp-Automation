# n8n Deployment Guide - Google Cloud Platform (GCP) Free Tier

Deploy your n8n workflow on GCP's **Always Free** tier with an e2-micro instance.

---

## Free Tier Specs

| Resource | Free Allocation |
|----------|-----------------|
| **Compute** | 1 e2-micro instance (2 vCPU, 1GB RAM) |
| **Storage** | 30 GB standard persistent disk |
| **Egress** | 1 GB/month to most regions |
| **Regions** | us-west1, us-central1, us-east1 only |

> **Note:** The 1GB RAM is tight for n8n. We'll configure swap space to handle peak loads.

---

## Prerequisites

- Google account
- ngrok account (free): https://ngrok.com/
- Credit/debit card (for verification only - won't be charged)

---

## Part 1: GCP Account Setup

### Step 1: Create GCP Account

1. Go to https://cloud.google.com/free
2. Click **Get started for free**
3. Sign in with your Google account
4. Complete billing setup (required but won't charge for free tier)
5. You'll also get **$300 free credits** for 90 days

### Step 2: Create New Project

1. Go to https://console.cloud.google.com/
2. Click the project dropdown (top-left) → **New Project**
3. Name: `n8n-project`
4. Click **Create**
5. Select the new project from the dropdown

---

## Part 2: Create VM Instance

### Step 3: Navigate to Compute Engine

1. Go to **Navigation Menu** (☰) → **Compute Engine** → **VM instances**
2. Click **Enable** if prompted (wait for API to enable)
3. Click **Create Instance**

### Step 4: Configure the Instance

**Basic Settings:**
```
Name: n8n-server
Region: us-central1 (Iowa) - FREE TIER ELIGIBLE
Zone: us-central1-a
```

**Machine Configuration:**
```
Series: E2
Machine type: e2-micro (2 vCPU, 1 GB memory) - FREE TIER
```

**Boot Disk:** Click **Change**
```
Operating system: Ubuntu
Version: Ubuntu 22.04 LTS
Boot disk type: Standard persistent disk
Size: 30 GB
```
Click **Select**

**Firewall:**
```
☑ Allow HTTP traffic
☑ Allow HTTPS traffic
```

**Advanced Options → Networking → Network interfaces:**
- Click on default network interface
- External IPv4 address: **Reserve static external IP address**
  - Name: `n8n-static-ip`
  - Click **Reserve**

Click **Create** and wait for the instance to start.

### Step 5: Note Your External IP

Once running, copy the **External IP** address (you'll need this).

---

## Part 3: Configure Firewall Rules

### Step 6: Open Required Ports

1. Go to **Navigation Menu** (☰) → **VPC Network** → **Firewall**
2. Click **Create Firewall Rule**

**Rule 1 - n8n Port:**
```
Name: allow-n8n
Direction: Ingress
Targets: All instances in the network
Source IP ranges: 0.0.0.0/0
Protocols and ports: TCP: 5678
```
Click **Create**

**Rule 2 - ngrok Dashboard:**
```
Name: allow-ngrok-dashboard
Direction: Ingress
Targets: All instances in the network
Source IP ranges: 0.0.0.0/0
Protocols and ports: TCP: 4040
```
Click **Create**

---

## Part 4: Server Setup

### Step 7: Connect to Your VM

**Option A: Browser SSH (Easiest)**
1. Go to **Compute Engine** → **VM instances**
2. Click **SSH** button next to your instance

**Option B: gcloud CLI**
```bash
gcloud compute ssh n8n-server --zone=us-central1-a
```

**Option C: External SSH Client**
```bash
ssh -i ~/.ssh/google_compute_engine YOUR_USERNAME@YOUR_EXTERNAL_IP
```

### Step 8: Install Docker

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install docker-compose-plugin -y

# Apply group changes (or logout/login)
newgrp docker

# Verify installation
docker --version
docker compose version
```

### Step 9: Configure Swap Space (Important for 1GB RAM)

```bash
# Create 2GB swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Verify swap is active
free -h
```

You should see ~2GB swap space.

---

## Part 5: ngrok Setup

### Step 10: Get ngrok Credentials

1. Sign up at https://ngrok.com/ (free)
2. Get your **Authtoken**: https://dashboard.ngrok.com/get-started/your-authtoken
3. Create a **free static domain**: https://dashboard.ngrok.com/cloud-edge/domains
   - Click **Create Domain**
   - Note your domain (e.g., `your-name.ngrok-free.app`)

---

## Part 6: Deploy n8n

### Step 11: Create Project Directory

```bash
mkdir ~/n8n && cd ~/n8n
```

### Step 12: Create docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
services:
  n8n:
    image: n8nio/n8n:1.123.7
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=localhost
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://${NGROK_DOMAIN}
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER:-admin}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD:-changeme}
      - GENERIC_TIMEZONE=Asia/Kolkata
      - TZ=Asia/Kolkata
    volumes:
      - ./n8n_data:/home/node/.n8n
    depends_on:
      - ngrok
    networks:
      - n8n-network

  ngrok:
    image: ngrok/ngrok:latest
    restart: unless-stopped
    command:
      - "http"
      - "n8n:5678"
      - "--domain=${NGROK_DOMAIN}"
    environment:
      - NGROK_AUTHTOKEN=${NGROK_AUTHTOKEN}
    ports:
      - "4040:4040"
    networks:
      - n8n-network

networks:
  n8n-network:
    driver: bridge
EOF
```

### Step 13: Create Environment File

```bash
cat > .env << 'EOF'
# ngrok Configuration
NGROK_AUTHTOKEN=your_ngrok_authtoken_here
NGROK_DOMAIN=your-domain.ngrok-free.app

# n8n Credentials
N8N_USER=admin
N8N_PASSWORD=your_secure_password_here
EOF
```

Edit with your actual values:
```bash
nano .env
```

Replace:
- `your_ngrok_authtoken_here` → Your actual ngrok authtoken
- `your-domain.ngrok-free.app` → Your ngrok static domain
- `your_secure_password_here` → A strong password

Save: `Ctrl+X`, then `Y`, then `Enter`

### Step 14: Start n8n

```bash
# Start services
docker compose up -d

# Check status
docker compose ps

# View logs (Ctrl+C to exit)
docker compose logs -f
```

### Step 15: Verify Deployment

1. **ngrok Dashboard:** `http://YOUR_GCP_IP:4040`
2. **n8n Interface:** `https://your-domain.ngrok-free.app`

Login with your configured username and password.

---

## Part 7: Upload Your Workflows

### Option A: Using SCP (From Local Machine)

```bash
# Upload n8n_data folder
scp -r ./n8n_data/* USERNAME@YOUR_GCP_IP:~/n8n/n8n_data/

# Or upload specific workflow files
scp ./workflows/*.json USERNAME@YOUR_GCP_IP:~/n8n/
```

### Option B: Using Git

```bash
# On GCP server
cd ~
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cp -r YOUR_REPO/n8n_data/* ~/n8n/n8n_data/
```

### Option C: Import via n8n UI

1. Open n8n at your ngrok URL
2. Go to **Workflows** → **Import from File**
3. Upload your workflow JSON files

After uploading data, restart n8n:
```bash
cd ~/n8n
docker compose restart n8n
```

---

## Part 8: Update WhatsApp Webhook

Update your WhatsApp Business API webhook URL to:
```
https://your-domain.ngrok-free.app/webhook/whatsapp
```

---

## Useful Commands

```bash
# View all logs
docker compose logs -f

# View n8n logs only
docker compose logs -f n8n

# Restart services
docker compose restart

# Stop services
docker compose down

# Start services
docker compose up -d

# Check resource usage
docker stats

# Check disk space
df -h

# Check memory/swap usage
free -h

# Update n8n (change version in docker-compose.yml first)
docker compose pull
docker compose up -d
```

---

## Troubleshooting

### Out of Memory Issues

```bash
# Check memory usage
free -h

# If swap isn't working, re-enable it
sudo swapon /swapfile

# Increase swap if needed (4GB)
sudo swapoff /swapfile
sudo fallocate -l 4G /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### n8n Not Starting

```bash
# Check logs
docker compose logs n8n

# Check if port is in use
sudo netstat -tlnp | grep 5678

# Restart fresh
docker compose down
docker compose up -d
```

### ngrok Connection Issues

```bash
# Check ngrok logs
docker compose logs ngrok

# Verify authtoken
cat .env | grep NGROK

# Test ngrok manually
docker run --rm -it ngrok/ngrok:latest authtoken YOUR_TOKEN
```

### Cannot Connect via SSH

1. Check if instance is running in GCP Console
2. Verify firewall rules allow port 22
3. Use browser-based SSH from GCP Console

### Disk Space Full

```bash
# Check disk usage
df -h

# Clean Docker resources
docker system prune -a

# Remove old logs
sudo journalctl --vacuum-time=3d
```

---

## Backup & Restore

### Create Backup

```bash
cd ~/n8n
tar -czvf n8n_backup_$(date +%Y%m%d).tar.gz n8n_data/
```

### Download Backup to Local

```bash
# From your local machine
gcloud compute scp n8n-server:~/n8n/n8n_backup_*.tar.gz ./ --zone=us-central1-a
```

### Restore from Backup

```bash
cd ~/n8n
docker compose down
rm -rf n8n_data/*
tar -xzvf n8n_backup_YYYYMMDD.tar.gz
docker compose up -d
```

---

## Auto-Start on Reboot

Docker with `restart: unless-stopped` handles this automatically. To verify:

```bash
# Reboot server
sudo reboot

# After reconnecting, check services
docker compose ps
```

---

## Security Tips

1. **Use strong passwords** for N8N_USER and N8N_PASSWORD
2. **Don't expose port 5678** directly if using ngrok (remove from firewall)
3. **Backup regularly** - GCP free tier has limited snapshot capabilities
4. **Monitor usage** - Stay within free tier limits

---

## Cost Summary

| Service | Cost |
|---------|------|
| GCP e2-micro (us-central1) | Free |
| 30GB Standard Disk | Free |
| ngrok (free tier) | Free |
| **Total** | **$0/month** |

> **Warning:** If you exceed free tier limits or use resources outside free regions, you may incur charges. Monitor your billing dashboard.

---

## Quick Reference

| Item | Value |
|------|-------|
| GCP Console | https://console.cloud.google.com |
| n8n URL | https://your-domain.ngrok-free.app |
| ngrok Dashboard | http://YOUR_GCP_IP:4040 |
| SSH Command | `gcloud compute ssh n8n-server --zone=us-central1-a` |
| Project Directory | `~/n8n` |

---

## Support Resources

- GCP Free Tier FAQ: https://cloud.google.com/free/docs/free-cloud-features
- n8n Documentation: https://docs.n8n.io/
- ngrok Documentation: https://ngrok.com/docs
- Docker Documentation: https://docs.docker.com/
