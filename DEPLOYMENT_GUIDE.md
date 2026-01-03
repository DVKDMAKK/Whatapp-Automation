# n8n Deployment Guide - Oracle Cloud Free Tier

This guide walks you through deploying your n8n workflow on Oracle Cloud Infrastructure (OCI) Free Tier.

---

## Prerequisites

- Oracle Cloud account (free tier): https://www.oracle.com/cloud/free/
- ngrok account (free tier): https://ngrok.com/
- SSH client (PuTTY for Windows or terminal for Mac/Linux)

---

## Part 1: Oracle Cloud Setup

### Step 1: Create Oracle Cloud Account

1. Go to https://www.oracle.com/cloud/free/
2. Click "Start for free"
3. Complete registration (credit card required for verification, but won't be charged)
4. Wait for account activation (usually 5-10 minutes)

### Step 2: Create Compute Instance

1. Log into Oracle Cloud Console: https://cloud.oracle.com/
2. Navigate to **Compute** → **Instances** → **Create Instance**

3. Configure the instance:
   ```
   Name: n8n-server
   Image: Ubuntu 22.04 (Canonical Ubuntu)
   Shape: VM.Standard.A1.Flex (ARM - Free Tier)
   OCPUs: 2 (or up to 4)
   Memory: 12 GB (or up to 24 GB)
   ```

4. **Networking:**
   - Create new VCN or use existing
   - Assign public IPv4 address: Yes
   - Select "Create new public subnet"

5. **Add SSH Keys:**
   - Generate new key pair OR upload your public key
   - **IMPORTANT:** Download the private key and save it securely

6. Click **Create** and wait for instance to be "Running"

### Step 3: Configure Security Rules (Firewall)

1. Go to **Networking** → **Virtual Cloud Networks**
2. Click on your VCN → **Security Lists** → **Default Security List**
3. Click **Add Ingress Rules** and add:

   | Source CIDR | Protocol | Port | Description |
   |-------------|----------|------|-------------|
   | 0.0.0.0/0 | TCP | 22 | SSH |
   | 0.0.0.0/0 | TCP | 5678 | n8n (optional, if not using ngrok) |
   | 0.0.0.0/0 | TCP | 4040 | ngrok dashboard |

---

## Part 2: Server Setup

### Step 4: Connect to Your Server

**Windows (PuTTY):**
1. Convert .key to .ppk using PuTTYgen
2. Connect using PuTTY with your instance's public IP

**Mac/Linux:**
```bash
chmod 400 your-private-key.key
ssh -i your-private-key.key ubuntu@YOUR_PUBLIC_IP
```

### Step 5: Install Docker

Run these commands on your Oracle Cloud server:

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group (avoids needing sudo)
sudo usermod -aG docker $USER

# Install Docker Compose
sudo apt install docker-compose-plugin -y

# Log out and back in for group changes to take effect
exit
```

Reconnect via SSH, then verify:
```bash
docker --version
docker compose version
```

### Step 6: Configure Ubuntu Firewall

```bash
# Open required ports
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 5678 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 4040 -j ACCEPT

# Save firewall rules
sudo netfilter-persistent save
```

---

## Part 3: ngrok Setup

### Step 7: Get ngrok Credentials

1. Create account at https://ngrok.com/ (free)
2. Go to https://dashboard.ngrok.com/get-started/your-authtoken
3. Copy your **Authtoken**
4. Go to https://dashboard.ngrok.com/cloud-edge/domains
5. Click **Create Domain** to get a free static domain (e.g., `your-name.ngrok-free.app`)

---

## Part 4: Deploy n8n

### Step 8: Upload Project Files

**Option A: Using Git (Recommended)**
```bash
# On Oracle server
cd ~
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git n8n
cd n8n
```

**Option B: Using SCP (Manual Upload)**
```bash
# From your local machine
scp -i your-private-key.key -r ./n8n ubuntu@YOUR_PUBLIC_IP:~/
```

### Step 9: Configure Environment Variables

```bash
cd ~/n8n

# Create .env file from example
cp .env.example .env

# Edit with your values
nano .env
```

Update these values in `.env`:
```
NGROK_AUTHTOKEN=your_actual_ngrok_authtoken
NGROK_DOMAIN=your-domain.ngrok-free.app
N8N_USER=admin
N8N_PASSWORD=your_secure_password
```

Save: `Ctrl+X`, then `Y`, then `Enter`

### Step 10: Start n8n

```bash
# Start the services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

### Step 11: Verify Deployment

1. **ngrok Dashboard:** http://YOUR_PUBLIC_IP:4040
2. **n8n Interface:** https://your-domain.ngrok-free.app

Login with your configured credentials.

---

## Part 5: Post-Deployment

### Update WhatsApp Webhook URL

Update your WhatsApp Business API webhook to:
```
https://your-domain.ngrok-free.app/webhook/whatsapp
```

### Import Your Workflows

1. Open n8n at your ngrok URL
2. Go to **Workflows** → **Import from File**
3. Upload your workflow JSON files

### Useful Commands

```bash
# View logs
docker compose logs -f n8n
docker compose logs -f ngrok

# Restart services
docker compose restart

# Stop services
docker compose down

# Update and restart
docker compose pull
docker compose up -d

# Check disk usage
df -h
```

---

## Troubleshooting

### ngrok not connecting
```bash
# Check ngrok logs
docker compose logs ngrok

# Verify authtoken in .env
cat .env | grep NGROK
```

### n8n not accessible
```bash
# Check if containers are running
docker compose ps

# Check n8n logs
docker compose logs n8n

# Restart everything
docker compose down && docker compose up -d
```

### Firewall issues
```bash
# Check iptables rules
sudo iptables -L -n

# Re-add rules if missing
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 5678 -j ACCEPT
sudo iptables -I INPUT 6 -m state --state NEW -p tcp --dport 4040 -j ACCEPT
```

### Data backup
```bash
# Backup n8n data
tar -czvf n8n_backup_$(date +%Y%m%d).tar.gz n8n_data/

# Copy to local machine
scp -i your-key.key ubuntu@YOUR_IP:~/n8n/n8n_backup_*.tar.gz ./
```

---

## Security Recommendations

1. **Change default credentials** - Use strong passwords for N8N_USER and N8N_PASSWORD
2. **Keep backups** - Regularly backup the `n8n_data` folder
3. **Monitor usage** - Check Oracle Cloud dashboard for resource usage
4. **Update regularly** - Pull latest images periodically

---

## Cost Summary

| Service | Cost |
|---------|------|
| Oracle Cloud (ARM instance) | Free |
| ngrok (free tier with static domain) | Free |
| **Total** | **$0/month** |

---

## Support

- n8n Documentation: https://docs.n8n.io/
- ngrok Documentation: https://ngrok.com/docs
- Oracle Cloud Docs: https://docs.oracle.com/en-us/iaas/Content/home.htm
