# Taolie Host Agent - One-Line Installer

Automated installation script for the Taolie Host Agent. Earn rewards by providing GPU or CPU compute power to the Taolie network.

## Quick Start

### One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY
```

Replace `YOUR_API_KEY` with your actual API key from [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu).

## Prerequisites

Before running the installer, ensure you have:

1. **Operating System**: Ubuntu 20.04 or later
2. **Docker**: Installed and running
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker $USER
   ```
   *Note: Log out and log back in after adding user to docker group*

3. **NVIDIA Container Toolkit** (for GPU mode):
   ```bash
   distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
   curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
   curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
   sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
   sudo systemctl restart docker
   ```

4. **Static Public IP Address**: Required for accepting compute rental requests

5. **API Key**: Get yours from [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu)

## Installation Options

### Basic Installation

Uses auto-detected settings with default ports:

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY
```

### Custom IP Address

Specify your public IP manually:

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
  --api-key YOUR_API_KEY \
  --public-ip 1.2.3.4
```

### Custom Ports

Change default ports if needed:

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
  --api-key YOUR_API_KEY \
  --ssh-port 2223 \
  --rental-port-1 8889 \
  --rental-port-2 9998 \
  --rental-port-3 7778
```

### CPU-Only Mode

Force CPU-only mode (no GPU):

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
  --api-key YOUR_API_KEY \
  --cpu-only
```

### Custom Database Password

Set a custom PostgreSQL password:

```bash
curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
  --api-key YOUR_API_KEY \
  --db-password my_secure_password
```

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--api-key KEY` | Your Taolie API key (required) | - |
| `--public-ip IP` | Your public IP address | Auto-detected |
| `--ssh-port PORT` | SSH access port | 2222 |
| `--rental-port-1 PORT` | Application service port 1 | 8888 |
| `--rental-port-2 PORT` | Application service port 2 | 9999 |
| `--rental-port-3 PORT` | Application service port 3 | 7777 |
| `--db-password PASS` | PostgreSQL password | db_pass |
| `--cpu-only` | Install in CPU-only mode | Auto-detect GPU |
| `--help` | Show help message | - |

## What the Installer Does

The installation script automatically:

1. ✅ Checks system prerequisites (OS, Docker, GPU)
2. ✅ Auto-detects your public IP address
3. ✅ Configures firewall rules (UFW)
4. ✅ Creates installation directory (`~/taolie-host-agent`)
5. ✅ Generates `config.yaml` with your settings
6. ✅ Creates Docker network
7. ✅ Deploys PostgreSQL database container
8. ✅ Deploys Taolie Host Agent container
9. ✅ Verifies installation and GPU access
10. ✅ Provides status report and next steps

## Network Configuration

### Required Ports

The following ports must be accessible from the internet:

| Port | Purpose | Protocol |
|------|---------|----------|
| 2222 | SSH access for remote connections | TCP |
| 7777 | Rental port 3 (application services) | TCP |
| 8888 | Rental port 1 (application services) | TCP |
| 9999 | Rental port 2 (application services) | TCP |

### Router/Firewall Setup

**If behind a router:**
- Configure port forwarding for ports 2222, 7777, 8888, and 9999 to your machine's local IP

**If using cloud provider (AWS, GCP, Azure):**
- Update security groups/firewall rules to allow inbound traffic on these ports

**Verify ports are open:**
```bash
sudo netstat -tulpn | grep -E '(2222|7777|8888|9999)'
```

## Post-Installation

### Verify Installation

Check container status:
```bash
docker ps
```

View agent logs:
```bash
docker logs -f taolie-host-agent
```

Verify GPU access (GPU mode only):
```bash
docker exec taolie-host-agent nvidia-smi
```

### Check Your Resources

Visit the [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu) to see your connected resources. Your GPU/CPU will appear in the Resources tab once the agent successfully connects.

### Useful Commands

| Command | Description |
|---------|-------------|
| `docker logs -f taolie-host-agent` | View real-time logs |
| `docker ps` | Check container status |
| `docker restart taolie-host-agent` | Restart the agent |
| `docker stop taolie-host-agent` | Stop the agent |
| `docker start taolie-host-agent` | Start the agent |
| `docker exec -it taolie-host-agent bash` | Access container shell |

### Configuration File

The configuration file is located at:
```
~/taolie-host-agent/config.yaml
```

To modify settings:
1. Edit the config file
2. Restart the agent: `docker restart taolie-host-agent`

## Uninstallation

To completely remove the Taolie Host Agent:

```bash
# Stop and remove containers
docker stop taolie-host-agent taolie-postgres
docker rm taolie-host-agent taolie-postgres

# Remove Docker network
docker network rm taolie-network

# Remove volumes (this will delete database data)
docker volume rm taolie_postgres_data taolie_agent_logs

# Remove installation directory
rm -rf ~/taolie-host-agent
```

## Troubleshooting

### Container Won't Start

Check logs for errors:
```bash
docker logs taolie-host-agent
```

### GPU Not Detected

Verify NVIDIA drivers:
```bash
nvidia-smi
```

Test NVIDIA Container Toolkit:
```bash
docker run --rm --runtime=nvidia nvidia/cuda:11.0-base nvidia-smi
```

### Connection Issues

Verify your public IP:
```bash
curl ifconfig.me
```

Check firewall rules:
```bash
sudo ufw status
```

Verify ports are listening:
```bash
sudo netstat -tulpn | grep -E '(2222|7777|8888|9999)'
```

### Database Connection Errors

Check PostgreSQL container:
```bash
docker logs taolie-postgres
```

Restart PostgreSQL:
```bash
docker restart taolie-postgres
```

### Permission Denied Errors

Ensure user is in docker group:
```bash
groups
```

If not in docker group:
```bash
sudo usermod -aG docker $USER
```
Then log out and log back in.

## Security Considerations

1. **API Key**: Keep your API key secure. Never commit it to version control or share it publicly.

2. **Database Password**: Change the default database password using `--db-password` option.

3. **Firewall**: Only open the required ports. Consider using a firewall to restrict access.

4. **Updates**: Regularly update the Docker image:
   ```bash
   docker pull ghcr.io/banadda/host-agent:latest
   docker stop taolie-host-agent
   docker rm taolie-host-agent
   # Then re-run the installation script
   ```

5. **SSH Access**: Port 2222 allows SSH access. Ensure your system has strong SSH security configured.

## Architecture

The Taolie Host Agent consists of:

- **Host Agent Container**: Main application that manages compute resources
- **PostgreSQL Database**: Stores agent state and configuration
- **Docker Network**: Isolated network for container communication
- **Volumes**: Persistent storage for database and logs

```
┌─────────────────────────────────────────┐
│         Taolie Host Agent               │
│  ┌───────────────────────────────────┐  │
│  │   Host Agent Container            │  │
│  │   (ghcr.io/banadda/host-agent)    │  │
│  └───────────────┬───────────────────┘  │
│                  │                       │
│  ┌───────────────▼───────────────────┐  │
│  │   PostgreSQL Database             │  │
│  │   (postgres:16)                   │  │
│  └───────────────────────────────────┘  │
│                                          │
│         Docker Network: taolie-network   │
└─────────────────────────────────────────┘
```

## Support

- **Documentation**: [Taolie Dashboard](https://taolie-ai.vercel.app/my-gpu)
- **Issues**: [GitHub Issues](https://github.com/BANADDA/taolie-host-agent-installer/issues)
- **Community**: Join the Taolie community for support

## License

This installer script is provided as-is for use with the Taolie platform.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Changelog

### Version 1.0.0 (Initial Release)
- One-line installation command
- Auto-detection of public IP and GPU
- Configurable ports and settings
- Comprehensive error checking
- Post-installation verification
- Detailed logging and status reporting

---

**Made with ❤️ for the Taolie.ai community**
