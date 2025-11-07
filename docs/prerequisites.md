# Prerequisites for Taolie Host Agent

This guide covers all the prerequisites needed before installing the Taolie Host Agent.

## System Requirements

### Operating System

**Required:** Ubuntu 20.04 or later

The installer is specifically designed and tested for Ubuntu. While it may work on other Debian-based distributions, Ubuntu is the officially supported platform.

**Check your Ubuntu version:**
```bash
lsb_release -a
```

**Minimum recommended version:** Ubuntu 20.04 LTS

### Hardware Requirements

#### For GPU Mode

- **GPU:** NVIDIA GPU with CUDA support
  - Recommended: RTX 3060 or higher, A100, H100
  - Minimum: GTX 1060 or equivalent
  
- **RAM:** 8GB minimum, 16GB+ recommended
- **Storage:** 50GB free space minimum
- **CPU:** 4 cores minimum, 8+ cores recommended

#### For CPU Mode

- **CPU:** 4 cores minimum, 8+ cores recommended
- **RAM:** 4GB minimum, 8GB+ recommended
- **Storage:** 20GB free space minimum

### Network Requirements

**Static Public IP Address** (Required)

You need a static public IP address that is accessible from the internet. This is essential for:
- Accepting compute rental requests
- Remote SSH access
- Application service ports

**How to check your public IP:**
```bash
curl ifconfig.me
```

**Port Requirements:**

The following ports must be accessible from the internet:

| Port | Purpose | Required |
|------|---------|----------|
| 2222 | SSH access for remote connections | Yes |
| 7777 | Rental port 3 (application services) | Yes |
| 8888 | Rental port 1 (application services) | Yes |
| 9999 | Rental port 2 (application services) | Yes |

## Software Prerequisites

### 1. Docker

**Required Version:** Docker 20.10 or later

Docker is the container platform used to run the Taolie Host Agent and PostgreSQL database.

#### Install Docker

**Quick installation:**
```bash
curl -fsSL https://get.docker.com | sh
```

**Add your user to the docker group:**
```bash
sudo usermod -aG docker $USER
```

**Important:** After adding your user to the docker group, you must log out and log back in for the changes to take effect.

#### Verify Docker Installation

```bash
docker --version
docker ps
```

Expected output:
```
Docker version 24.0.0 or higher
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

#### Test Docker Without Sudo

```bash
docker run hello-world
```

If you get a permission error, you need to log out and log back in.

### 2. NVIDIA Drivers (For GPU Mode Only)

**Required:** NVIDIA proprietary drivers (not nouveau)

#### Check if NVIDIA Drivers are Installed

```bash
nvidia-smi
```

Expected output should show your GPU information:
```
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 525.125.06   Driver Version: 525.125.06   CUDA Version: 12.0     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  NVIDIA GeForce ...  Off  | 00000000:01:00.0  On |                  N/A |
```

#### Install NVIDIA Drivers (if not installed)

**Ubuntu 20.04/22.04:**
```bash
# Add graphics drivers PPA
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

# Install recommended driver
sudo ubuntu-drivers autoinstall

# Or install specific version
sudo apt install nvidia-driver-525

# Reboot
sudo reboot
```

**After reboot, verify:**
```bash
nvidia-smi
```

### 3. NVIDIA Container Toolkit (For GPU Mode Only)

**Required:** NVIDIA Container Toolkit to enable GPU access in Docker containers

#### Install NVIDIA Container Toolkit

**Step 1: Add NVIDIA Docker repository**
```bash
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
```

**Step 2: Install the toolkit**
```bash
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

**Step 3: Restart Docker**
```bash
sudo systemctl restart docker
```

#### Verify NVIDIA Container Toolkit

Test that Docker can access the GPU:
```bash
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

Expected output should show the same GPU information as the host `nvidia-smi` command.

If this fails, the Taolie installer will not be able to run in GPU mode.

### 4. Taolie API Key

**Required:** API key from your Taolie account

#### How to Get Your API Key

1. Visit [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu)
2. Sign in to your account
3. Navigate to "My GPU" section
4. Click "Get API Key" button
5. Copy your API key

**Important:** 
- Keep your API key secure
- Each unique machine requires its own public IP
- You can reuse the same key for the same machine

## Network Configuration

### Firewall Configuration

The installer will automatically configure UFW (Uncomplicated Firewall) if it's installed. However, you may need additional configuration depending on your setup.

#### Ubuntu UFW (Handled by Installer)

The installer automatically runs:
```bash
sudo ufw allow 2222/tcp
sudo ufw allow 7777/tcp
sudo ufw allow 8888/tcp
sudo ufw allow 9999/tcp
```

#### Router Port Forwarding (Manual)

If your machine is behind a router, you need to configure port forwarding:

**Steps:**
1. Access your router's admin panel (usually http://192.168.1.1 or http://192.168.0.1)
2. Find "Port Forwarding" or "Virtual Server" settings
3. Add port forwarding rules:
   - External Port 2222 → Internal IP:2222
   - External Port 7777 → Internal IP:7777
   - External Port 8888 → Internal IP:8888
   - External Port 9999 → Internal IP:9999

**Find your local IP:**
```bash
hostname -I | awk '{print $1}'
```

#### Cloud Provider Security Groups (Manual)

**AWS:**
1. Go to EC2 → Security Groups
2. Select your instance's security group
3. Add Inbound Rules:
   - Type: Custom TCP, Port: 2222, Source: 0.0.0.0/0
   - Type: Custom TCP, Port: 7777, Source: 0.0.0.0/0
   - Type: Custom TCP, Port: 8888, Source: 0.0.0.0/0
   - Type: Custom TCP, Port: 9999, Source: 0.0.0.0/0

**GCP:**
1. Go to VPC Network → Firewall
2. Create firewall rule:
   - Targets: All instances
   - Source IP ranges: 0.0.0.0/0
   - Protocols and ports: tcp:2222,7777,8888,9999

**Azure:**
1. Go to Network Security Groups
2. Add inbound security rules for ports 2222, 7777, 8888, 9999

### Verify Ports are Open

**Check if ports are listening:**
```bash
sudo netstat -tulpn | grep -E '(2222|7777|8888|9999)'
```

**Test from external network:**
```bash
# From a different machine
nc -zv YOUR_PUBLIC_IP 2222
nc -zv YOUR_PUBLIC_IP 7777
nc -zv YOUR_PUBLIC_IP 8888
nc -zv YOUR_PUBLIC_IP 9999
```

## Pre-Installation Checklist

Before running the installer, verify all prerequisites:

### Essential Requirements

- [ ] Ubuntu 20.04 or later installed
- [ ] Docker installed and working without sudo
- [ ] Static public IP address confirmed
- [ ] Taolie API key obtained
- [ ] Sufficient disk space (20GB+ free)

### For GPU Mode

- [ ] NVIDIA GPU present in system
- [ ] NVIDIA drivers installed (`nvidia-smi` works)
- [ ] NVIDIA Container Toolkit installed
- [ ] Docker can access GPU (`docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi` works)

### Network Configuration

- [ ] Firewall allows ports 2222, 7777, 8888, 9999
- [ ] Router port forwarding configured (if behind router)
- [ ] Cloud security groups configured (if on cloud)
- [ ] Ports are accessible from internet

## Quick Verification Script

Run this script to check most prerequisites:

```bash
#!/bin/bash

echo "=== Taolie Host Agent Prerequisites Check ==="
echo ""

# Check OS
echo "1. Checking OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   ✓ OS: $NAME $VERSION"
else
    echo "   ✗ Cannot detect OS"
fi

# Check Docker
echo "2. Checking Docker..."
if command -v docker &> /dev/null; then
    echo "   ✓ Docker: $(docker --version)"
    if docker ps &> /dev/null; then
        echo "   ✓ Docker running without sudo"
    else
        echo "   ✗ Docker requires sudo (add user to docker group)"
    fi
else
    echo "   ✗ Docker not installed"
fi

# Check GPU
echo "3. Checking GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    if [ -n "$GPU_NAME" ]; then
        echo "   ✓ GPU: $GPU_NAME"
    else
        echo "   ✗ nvidia-smi found but no GPU detected"
    fi
else
    echo "   ℹ No NVIDIA GPU (CPU-only mode will be used)"
fi

# Check NVIDIA Container Toolkit
echo "4. Checking NVIDIA Container Toolkit..."
if docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi &> /dev/null; then
    echo "   ✓ NVIDIA Container Toolkit working"
else
    echo "   ✗ NVIDIA Container Toolkit not working (required for GPU mode)"
fi

# Check public IP
echo "5. Checking public IP..."
PUBLIC_IP=$(curl -s ifconfig.me)
if [ -n "$PUBLIC_IP" ]; then
    echo "   ✓ Public IP: $PUBLIC_IP"
else
    echo "   ✗ Cannot detect public IP"
fi

# Check disk space
echo "6. Checking disk space..."
AVAILABLE=$(df -h $HOME | awk 'NR==2 {print $4}')
echo "   ℹ Available space: $AVAILABLE"

echo ""
echo "=== Prerequisites Check Complete ==="
```

Save this as `check_prerequisites.sh`, make it executable, and run it:

```bash
chmod +x check_prerequisites.sh
./check_prerequisites.sh
```

## Common Issues

### Docker Permission Denied

**Problem:** `permission denied while trying to connect to the Docker daemon socket`

**Solution:**
```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

### NVIDIA Driver Not Found

**Problem:** `nvidia-smi: command not found`

**Solution:**
```bash
sudo ubuntu-drivers autoinstall
sudo reboot
```

### NVIDIA Container Toolkit Test Fails

**Problem:** `docker: Error response from daemon: could not select device driver "" with capabilities: [[gpu]]`

**Solution:**
```bash
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

### Ports Not Accessible

**Problem:** Ports are not accessible from the internet

**Solution:**
1. Check firewall: `sudo ufw status`
2. Check router port forwarding
3. Check cloud security groups
4. Verify ports are listening: `sudo netstat -tulpn | grep -E '(2222|7777|8888|9999)'`

## Next Steps

Once all prerequisites are met, you can proceed with the installation:

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY
```

## Additional Resources

- [Docker Installation Guide](https://docs.docker.com/engine/install/ubuntu/)
- [NVIDIA Driver Installation](https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html)
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html)
- [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu)
