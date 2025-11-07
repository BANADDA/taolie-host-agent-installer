# Troubleshooting Guide

This guide covers common issues you may encounter when installing or running the Taolie Host Agent, along with their solutions.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Container Issues](#container-issues)
- [GPU Issues](#gpu-issues)
- [Network Issues](#network-issues)
- [Database Issues](#database-issues)
- [Performance Issues](#performance-issues)
- [Uninstallation Issues](#uninstallation-issues)

## Installation Issues

### Issue: "API key is required!"

**Symptom:**
```
✗ API key is required!
```

**Cause:** You didn't provide the `--api-key` parameter.

**Solution:**
```bash
curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_ACTUAL_API_KEY
```

Get your API key from: https://taolie-ai.vercel.app/my-gpu

---

### Issue: "Docker is not installed!"

**Symptom:**
```
✗ Docker is not installed!
```

**Cause:** Docker is not installed on your system.

**Solution:**
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in
exit
```

After logging back in, run the installer again.

---

### Issue: "Docker requires sudo"

**Symptom:**
```
✗ Docker requires sudo (add user to docker group)
You need to log out and log back in for group changes to take effect
```

**Cause:** Your user is not in the docker group.

**Solution:**
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Log out and log back in
exit
```

**Verify after logging back in:**
```bash
docker ps
```

---

### Issue: "NVIDIA Container Toolkit is not properly configured!"

**Symptom:**
```
✗ NVIDIA Container Toolkit is not properly configured!
```

**Cause:** NVIDIA Container Toolkit is not installed or not working.

**Solution:**
```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

# Restart Docker
sudo systemctl restart docker

# Test
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

---

### Issue: "Failed to auto-detect public IP"

**Symptom:**
```
✗ Failed to auto-detect public IP
```

**Cause:** Network connectivity issue or firewall blocking outbound connections.

**Solution:**
```bash
# Manually check your public IP
curl ifconfig.me

# Then provide it manually
curl -fsSL [...]/install.sh | bash -s -- \
  --api-key YOUR_KEY \
  --public-ip YOUR_IP_HERE
```

---

## Container Issues

### Issue: Container Won't Start

**Symptom:**
```
✗ Container failed to start!
```

**Diagnosis:**
```bash
# Check container status
docker ps -a | grep taolie

# View logs
docker logs taolie-host-agent
```

**Common Causes:**

#### 1. Port Already in Use

**Check logs for:**
```
Error starting userland proxy: listen tcp4 0.0.0.0:2222: bind: address already in use
```

**Solution:**
```bash
# Find what's using the port
sudo netstat -tulpn | grep 2222

# Either stop that service or use different ports
curl -fsSL [...]/install.sh | bash -s -- \
  --api-key YOUR_KEY \
  --ssh-port 2223
```

#### 2. Configuration File Error

**Check logs for:**
```
Error reading config file
```

**Solution:**
```bash
# Check config file
cat ~/taolie-host-agent/config.yaml

# Recreate with correct format
cd ~/taolie-host-agent
nano config.yaml
# Fix any YAML syntax errors

# Restart container
docker restart taolie-host-agent
```

#### 3. Docker Network Issue

**Solution:**
```bash
# Recreate network
docker network rm taolie-network
docker network create taolie-network

# Restart containers
docker restart taolie-postgres taolie-host-agent
```

---

### Issue: Container Keeps Restarting

**Symptom:**
```bash
docker ps
# Shows container constantly restarting
```

**Diagnosis:**
```bash
# View logs
docker logs --tail 100 taolie-host-agent

# Check restart count
docker inspect taolie-host-agent | grep -A 5 RestartCount
```

**Solution:**

Check logs for specific error and address it. Common issues:
- Database connection failure
- Invalid API key
- Network connectivity issues

**Temporary fix to stop restart loop:**
```bash
docker update --restart=no taolie-host-agent
docker stop taolie-host-agent
# Fix the issue
docker start taolie-host-agent
docker update --restart=unless-stopped taolie-host-agent
```

---

### Issue: Cannot Access Container Logs

**Symptom:**
```
Error: No such container: taolie-host-agent
```

**Solution:**
```bash
# List all containers
docker ps -a

# If container doesn't exist, reinstall
curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
```

---

## GPU Issues

### Issue: GPU Not Detected

**Symptom:**
```
⚠ No NVIDIA GPU detected. Switching to CPU-only mode.
```

**Diagnosis:**
```bash
# Check if GPU is visible to host
nvidia-smi
```

**Solutions:**

#### If nvidia-smi fails:

**Install NVIDIA drivers:**
```bash
sudo ubuntu-drivers autoinstall
sudo reboot
```

#### If nvidia-smi works but installer doesn't detect GPU:

**Check NVIDIA Container Toolkit:**
```bash
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

If this fails, reinstall NVIDIA Container Toolkit (see above).

---

### Issue: GPU Not Accessible in Container

**Symptom:**
Container is running but GPU is not accessible inside.

**Diagnosis:**
```bash
# Try to access GPU from container
docker exec taolie-host-agent nvidia-smi
```

**If it fails:**

```
Error: Could not find nvidia-smi
```

**Solution:**
```bash
# Stop and remove container
docker stop taolie-host-agent
docker rm taolie-host-agent

# Reinstall in GPU mode (ensure NVIDIA Container Toolkit is working)
curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
```

---

### Issue: GPU Temperature Too High

**Symptom:**
GPU overheating during compute tasks.

**Diagnosis:**
```bash
# Monitor GPU temperature
watch -n 1 nvidia-smi
```

**Solution:**
```bash
# Adjust max temperature in config
cd ~/taolie-host-agent
nano config.yaml

# Change:
gpu:
  max_temperature: 75  # Lower from default 85
  max_power: 350       # Lower from default 400

# Restart agent
docker restart taolie-host-agent
```

---

## Network Issues

### Issue: Ports Not Accessible from Internet

**Symptom:**
Agent is running but not receiving rental requests.

**Diagnosis:**
```bash
# Check if ports are listening
sudo netstat -tulpn | grep -E '(2222|7777|8888|9999)'

# Test from external machine
nc -zv YOUR_PUBLIC_IP 2222
```

**Solutions:**

#### 1. Firewall Blocking Ports

```bash
# Check UFW status
sudo ufw status

# Allow ports
sudo ufw allow 2222/tcp
sudo ufw allow 7777/tcp
sudo ufw allow 8888/tcp
sudo ufw allow 9999/tcp
```

#### 2. Router Not Forwarding Ports

**Configure port forwarding in your router:**
1. Access router admin panel (usually 192.168.1.1)
2. Find "Port Forwarding" settings
3. Forward ports 2222, 7777, 8888, 9999 to your machine's local IP

**Find your local IP:**
```bash
hostname -I | awk '{print $1}'
```

#### 3. Cloud Security Groups

**AWS:**
- Go to EC2 → Security Groups
- Add inbound rules for ports 2222, 7777, 8888, 9999

**GCP:**
- Go to VPC Network → Firewall
- Create firewall rule allowing tcp:2222,7777,8888,9999

**Azure:**
- Go to Network Security Groups
- Add inbound rules for the ports

---

### Issue: Wrong Public IP Detected

**Symptom:**
Installer detected wrong public IP.

**Solution:**
```bash
# Manually specify correct IP
curl -fsSL [...]/install.sh | bash -s -- \
  --api-key YOUR_KEY \
  --public-ip YOUR_CORRECT_IP
```

---

### Issue: Connection Timeout

**Symptom:**
Agent cannot connect to Taolie server.

**Diagnosis:**
```bash
# Check logs
docker logs taolie-host-agent | grep -i "connection\|timeout"

# Test connectivity
curl -v https://api.taolie-server.work
```

**Solution:**
```bash
# Check internet connectivity
ping -c 4 8.8.8.8

# Check DNS
nslookup api.taolie-server.work

# If behind proxy, configure Docker proxy settings
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo nano /etc/systemd/system/docker.service.d/http-proxy.conf

# Add:
[Service]
Environment="HTTP_PROXY=http://proxy.example.com:8080"
Environment="HTTPS_PROXY=http://proxy.example.com:8080"

# Restart Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## Database Issues

### Issue: Database Connection Failed

**Symptom:**
```
Error: could not connect to database
```

**Diagnosis:**
```bash
# Check if PostgreSQL is running
docker ps | grep postgres

# Check PostgreSQL logs
docker logs taolie-postgres
```

**Solutions:**

#### PostgreSQL Container Not Running

```bash
# Start PostgreSQL
docker start taolie-postgres

# If it won't start, check logs
docker logs taolie-postgres

# Recreate if necessary
docker stop taolie-postgres
docker rm taolie-postgres

# Reinstall
curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
```

#### Wrong Database Password

```bash
# Check config file
cat ~/taolie-host-agent/config.yaml | grep password

# Ensure it matches PostgreSQL container password
docker inspect taolie-postgres | grep POSTGRES_PASSWORD
```

---

### Issue: Database Disk Full

**Symptom:**
```
Error: no space left on device
```

**Diagnosis:**
```bash
# Check disk usage
df -h

# Check Docker volumes
docker system df
```

**Solution:**
```bash
# Clean up Docker
docker system prune -a

# If still full, increase disk space or move Docker data directory
```

---

## Performance Issues

### Issue: High CPU Usage

**Diagnosis:**
```bash
# Check container resource usage
docker stats taolie-host-agent
```

**Solution:**
```bash
# Limit CPU usage
docker update --cpus="4" taolie-host-agent

# Or in docker run (requires recreation)
docker stop taolie-host-agent
docker rm taolie-host-agent
# Add --cpus="4" to docker run command in install script
```

---

### Issue: High Memory Usage

**Diagnosis:**
```bash
docker stats taolie-host-agent
```

**Solution:**
```bash
# Limit memory
docker update --memory="8g" taolie-host-agent
```

---

### Issue: Slow Performance

**Possible Causes:**
1. Insufficient resources
2. Network latency
3. Disk I/O bottleneck

**Diagnosis:**
```bash
# Check system resources
htop

# Check disk I/O
iostat -x 1

# Check network
iftop
```

**Solutions:**
- Upgrade hardware
- Use SSD instead of HDD
- Improve network connection
- Reduce concurrent tasks

---

## Uninstallation Issues

### Issue: Cannot Remove Container

**Symptom:**
```
Error: cannot remove container: container is running
```

**Solution:**
```bash
# Force stop and remove
docker stop taolie-host-agent
docker rm -f taolie-host-agent
```

---

### Issue: Volume in Use

**Symptom:**
```
Error: volume is in use
```

**Solution:**
```bash
# Find what's using the volume
docker ps -a --filter volume=taolie_postgres_data

# Stop and remove those containers first
docker stop <container_id>
docker rm <container_id>

# Then remove volume
docker volume rm taolie_postgres_data
```

---

### Issue: Network in Use

**Symptom:**
```
Error: network taolie-network has active endpoints
```

**Solution:**
```bash
# Disconnect all containers
docker network disconnect taolie-network taolie-host-agent
docker network disconnect taolie-network taolie-postgres

# Then remove network
docker network rm taolie-network
```

---

## Advanced Debugging

### Enable Debug Logging

```bash
# Edit config file
cd ~/taolie-host-agent
nano config.yaml

# Change logging level
logging:
  level: "DEBUG"  # Changed from INFO

# Restart agent
docker restart taolie-host-agent

# View debug logs
docker logs -f taolie-host-agent
```

---

### Access Container Shell

```bash
# Access running container
docker exec -it taolie-host-agent bash

# Inside container, you can:
# - Check files
# - Test network connectivity
# - View logs
# - Run diagnostic commands
```

---

### Check Container Health

```bash
# Inspect container
docker inspect taolie-host-agent

# Check specific fields
docker inspect taolie-host-agent | grep -A 10 State
docker inspect taolie-host-agent | grep -A 10 NetworkSettings
```

---

### Export Logs for Support

```bash
# Export all logs
docker logs taolie-host-agent > ~/taolie-agent-logs.txt
docker logs taolie-postgres > ~/taolie-postgres-logs.txt

# Include system info
uname -a >> ~/taolie-debug-info.txt
docker version >> ~/taolie-debug-info.txt
nvidia-smi >> ~/taolie-debug-info.txt 2>&1 || echo "No GPU" >> ~/taolie-debug-info.txt

# Share these files with support
```

---

## Getting Help

If you've tried the solutions above and still have issues:

1. **Check Documentation**: https://taolie-ai.vercel.app/my-gpu
2. **GitHub Issues**: Report bugs or ask questions
3. **Community Support**: Join the Taolie community
4. **Collect Debug Info**:
   ```bash
   # Run this and share output
   docker logs taolie-host-agent > debug.log
   docker inspect taolie-host-agent >> debug.log
   cat ~/taolie-host-agent/config.yaml >> debug.log
   ```

---

## Quick Reference Commands

### View Logs
```bash
docker logs -f taolie-host-agent
docker logs -f taolie-postgres
```

### Restart Services
```bash
docker restart taolie-host-agent
docker restart taolie-postgres
```

### Check Status
```bash
docker ps
docker stats
```

### Stop/Start
```bash
docker stop taolie-host-agent
docker start taolie-host-agent
```

### Complete Reinstall
```bash
# Uninstall
curl -fsSL [...]/uninstall.sh | bash -s -- --yes

# Reinstall
curl -fsSL [...]/install.sh | bash -s -- --api-key YOUR_KEY
```
