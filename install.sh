#!/bin/bash

#############################################################################
# Taolie Host Agent - One-Line Installer
# 
# This script automates the installation of the Taolie Host Agent
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY
#
# Options:
#   --api-key KEY          Your Taolie API key (required)
#   --public-ip IP         Your public IP address (auto-detected if not provided)
#   --ssh-port PORT        SSH port (default: 2222)
#   --rental-port-1 PORT   Rental port 1 (default: 8888)
#   --rental-port-2 PORT   Rental port 2 (default: 9999)
#   --rental-port-3 PORT   Rental port 3 (default: 7777)
#   --db-password PASS     PostgreSQL password (default: db_pass)
#   --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
#   --help                 Show this help message
#
#############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
API_KEY=""
PUBLIC_IP=""
SSH_PORT=2222
RENTAL_PORT_1=8888
RENTAL_PORT_2=9999
RENTAL_PORT_3=7777
DB_PASSWORD="db_pass"
CPU_ONLY=false
USE_GPUS_FLAG=false
INSTALL_DIR="$HOME/taolie-host-agent"

# Helper functions
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}\n"
}

show_help() {
    cat << EOF
Taolie Host Agent - One-Line Installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY

Options:
  --api-key KEY          Your Taolie API key (required)
  --public-ip IP         Your public IP address (auto-detected if not provided)
  --ssh-port PORT        SSH port (default: 2222)
  --rental-port-1 PORT   Rental port 1 (default: 8888)
  --rental-port-2 PORT   Rental port 2 (default: 9999)
  --rental-port-3 PORT   Rental port 3 (default: 7777)
  --db-password PASS     PostgreSQL password (default: db_pass)
  --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
  --help                 Show this help message

Examples:
  # Basic installation with API key
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123

  # Custom ports and IP
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --public-ip 1.2.3.4 --ssh-port 2223

  # CPU-only mode
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --cpu-only

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --public-ip)
            PUBLIC_IP="$2"
            shift 2
            ;;
        --ssh-port)
            SSH_PORT="$2"
            shift 2
            ;;
        --rental-port-1)
            RENTAL_PORT_1="$2"
            shift 2
            ;;
        --rental-port-2)
            RENTAL_PORT_2="$2"
            shift 2
            ;;
        --rental-port-3)
            RENTAL_PORT_3="$2"
            shift 2
            ;;
        --db-password)
            DB_PASSWORD="$2"
            shift 2
            ;;
        --cpu-only)
            CPU_ONLY=true
            shift
            ;;
        --help)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Banner
clear
cat << "EOF"
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║        TAOLIE HOST AGENT - AUTOMATED INSTALLER             ║
║                                                            ║
║     Earn rewards by providing GPU/CPU compute power        ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

EOF

# Validate required parameters
if [ -z "$API_KEY" ]; then
    print_error "API key is required!"
    echo ""
    echo "Get your API key from: https://taolie-ai.vercel.app/my-gpu"
    echo ""
    echo "Usage: curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY"
    exit 1
fi

print_header "Step 1: System Prerequisites Check"

# Check OS
print_info "Checking operating system..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" ]]; then
        print_success "Ubuntu detected: $VERSION"
    else
        print_warning "This script is designed for Ubuntu. Your OS: $ID"
        read -p "Continue anyway? (y/n) " -n 1 -r < /dev/tty
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
else
    print_error "Cannot detect OS. This script requires Ubuntu 20.04+"
    exit 1
fi

# Check Docker
print_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed!"
    echo ""
    echo "Please install Docker first:"
    echo "  curl -fsSL https://get.docker.com | sh"
    echo "  sudo usermod -aG docker \$USER"
    echo ""
    echo "Then log out and log back in, and run this script again."
    exit 1
fi
print_success "Docker is installed: $(docker --version)"

# Check if user is in docker group
if ! groups | grep -q docker; then
    print_warning "Current user is not in the docker group"
    print_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_warning "You need to log out and log back in for group changes to take effect"
    print_warning "After logging back in, run this script again"
    exit 1
fi

# Detect GPU
print_info "Detecting GPU..."
if [ "$CPU_ONLY" = false ]; then
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        if [ -n "$GPU_INFO" ]; then
            print_success "NVIDIA GPU detected: $GPU_INFO"
            
            # Check NVIDIA Container Toolkit
            print_info "Checking NVIDIA Container Toolkit..."
            
            # Pre-pull the test image to avoid timeout issues
            print_info "Pulling test image (this may take a moment on first run)..."
            # Use valid CUDA base image tags
            docker pull nvidia/cuda:12.6.0-base-ubuntu22.04 &> /dev/null || docker pull nvidia/cuda:11.8.0-base-ubuntu22.04 &> /dev/null
            
            # Determine which CUDA image is available
            if docker images nvidia/cuda:12.6.0-base-ubuntu22.04 --format "{{.Repository}}" | grep -q cuda; then
                TEST_IMAGE="nvidia/cuda:12.6.0-base-ubuntu22.04"
            else
                TEST_IMAGE="nvidia/cuda:11.8.0-base-ubuntu22.04"
            fi
            
            # Try --gpus all first (recommended method)
            print_info "Testing GPU access with --gpus all..."
            if timeout 10 docker run --rm --gpus all $TEST_IMAGE nvidia-smi &> /dev/null; then
                print_success "NVIDIA Container Toolkit is properly configured (--gpus all)"
                USE_GPUS_FLAG=true
            # Then try --runtime=nvidia as fallback
            elif timeout 10 docker run --rm --runtime=nvidia $TEST_IMAGE nvidia-smi &> /dev/null; then
                print_success "NVIDIA Container Toolkit is properly configured (--runtime=nvidia)"
                USE_GPUS_FLAG=false
            else
                print_warning "NVIDIA Container Toolkit test failed, attempting to fix..."
                
                # Check if toolkit is installed
                if command -v nvidia-ctk &> /dev/null || dpkg -l | grep -q nvidia-container-toolkit; then
                    print_info "NVIDIA Container Toolkit is installed, configuring Docker..."
                    
                    # Configure Docker to use NVIDIA runtime
                    sudo nvidia-ctk runtime configure --runtime=docker &> /dev/null || true
                    
                    # Restart Docker daemon
                    print_info "Restarting Docker daemon..."
                    sudo systemctl restart docker
                    sleep 3
                    
                    # Test again
                    print_info "Testing NVIDIA Container Toolkit again..."
                    if timeout 10 docker run --rm --gpus all $TEST_IMAGE nvidia-smi &> /dev/null; then
                        print_success "NVIDIA Container Toolkit is now working! (--gpus all)"
                        USE_GPUS_FLAG=true
                    elif timeout 10 docker run --rm --runtime=nvidia $TEST_IMAGE nvidia-smi &> /dev/null; then
                        print_success "NVIDIA Container Toolkit is now working! (--runtime=nvidia)"
                        USE_GPUS_FLAG=false
                    else
                        print_error "NVIDIA Container Toolkit is still not working after configuration"
                        echo ""
                        echo "Please try manually:"
                        echo "  sudo nvidia-ctk runtime configure --runtime=docker"
                        echo "  sudo systemctl restart docker"
                        echo "  docker run --rm --gpus all nvidia/cuda:12.6.0-base-ubuntu22.04 nvidia-smi"
                        echo ""
                        read -p "Continue with CPU-only mode instead? (y/n) " -n 1 -r < /dev/tty
                        echo
                        if [[ $REPLY =~ ^[Yy]$ ]]; then
                            print_warning "Switching to CPU-only mode"
                            CPU_ONLY=true
                        else
                            exit 1
                        fi
                    fi
                else
                    print_error "NVIDIA Container Toolkit is not installed!"
                    echo ""
                    echo "Please install NVIDIA Container Toolkit:"
                    echo "  distribution=\$(. /etc/os-release;echo \$ID\$VERSION_ID)"
                    echo "  curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -"
                    echo "  curl -s -L https://nvidia.github.io/nvidia-docker/\$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list"
                    echo "  sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit"
                    echo "  sudo systemctl restart docker"
                    echo ""
                    read -p "Continue with CPU-only mode instead? (y/n) " -n 1 -r < /dev/tty
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        print_warning "Switching to CPU-only mode"
                        CPU_ONLY=true
                    else
                        exit 1
                    fi
                fi
            fi
        else
            print_warning "No NVIDIA GPU detected. Switching to CPU-only mode."
            CPU_ONLY=true
        fi
    else
        print_warning "nvidia-smi not found. Switching to CPU-only mode."
        CPU_ONLY=true
    fi
else
    print_info "Running in CPU-only mode (--cpu-only flag set)"
fi

print_header "Step 2: Network Configuration"

# Auto-detect public IP if not provided
if [ -z "$PUBLIC_IP" ]; then
    print_info "Auto-detecting public IP address..."
    PUBLIC_IP=$(curl -s ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        print_error "Failed to auto-detect public IP"
        echo "Please specify your public IP with --public-ip option"
        exit 1
    fi
    print_success "Detected public IP: $PUBLIC_IP"
else
    print_info "Using provided public IP: $PUBLIC_IP"
fi

# Confirm IP with user
echo ""
print_warning "Please confirm your public IP address: $PUBLIC_IP"
read -p "Is this correct? (y/n) " -n 1 -r < /dev/tty
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    read -p "Enter your public IP address: " PUBLIC_IP < /dev/tty
fi

# Configure firewall
print_info "Configuring firewall rules..."
if command -v ufw &> /dev/null; then
    print_info "Opening required ports in UFW..."
    sudo ufw allow $SSH_PORT/tcp &> /dev/null || true
    sudo ufw allow $RENTAL_PORT_1/tcp &> /dev/null || true
    sudo ufw allow $RENTAL_PORT_2/tcp &> /dev/null || true
    sudo ufw allow $RENTAL_PORT_3/tcp &> /dev/null || true
    print_success "Firewall rules configured"
else
    print_warning "UFW not found. Please manually configure your firewall to allow ports: $SSH_PORT, $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3"
fi

print_info "Port configuration:"
echo "  SSH Port:       $SSH_PORT"
echo "  Rental Port 1:  $RENTAL_PORT_1"
echo "  Rental Port 2:  $RENTAL_PORT_2"
echo "  Rental Port 3:  $RENTAL_PORT_3"

print_header "Step 3: Installation Directory Setup"

# Create installation directory
print_info "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
print_success "Directory created"

# Create config.yaml
print_info "Generating configuration file..."
cat > config.yaml << EOF
agent:
  id: ""
  api_key: "$API_KEY"

network:
  public_ip: "$PUBLIC_IP"
  ports:
    ssh: $SSH_PORT
    rental_port_1: $RENTAL_PORT_1
    rental_port_2: $RENTAL_PORT_2
    rental_port_3: $RENTAL_PORT_3

server:
  url: "https://api.taolie-server.work"
  timeout: 30
  retry_attempts: 3

monitoring:
  heartbeat_interval: 30
  command_poll_interval: 10
  metrics_push_interval: 10
  health_push_interval: 60
  duration_check_interval: 30

database:
  host: "taolie-postgres"
  port: 5432
  name: "taolie_host_agent"
  user: "agent"
  password: "$DB_PASSWORD"

gpu:
  max_temperature: 85
  max_power: 400

logging:
  level: "INFO"
  file: "/var/log/taolie-host-agent/agent.log"
EOF
print_success "Configuration file created: $INSTALL_DIR/config.yaml"

print_header "Step 4: Docker Setup"

# Create Docker network
print_info "Creating Docker network..."
if docker network inspect taolie-network &> /dev/null; then
    print_warning "Docker network 'taolie-network' already exists"
else
    docker network create taolie-network
    print_success "Docker network created"
fi

# Stop and remove existing containers if they exist
print_info "Checking for existing containers..."
if docker ps -a --format '{{.Names}}' | grep -q "^taolie-host-agent$"; then
    print_warning "Stopping and removing existing taolie-host-agent container..."
    docker stop taolie-host-agent &> /dev/null || true
    docker rm taolie-host-agent &> /dev/null || true
    print_success "Old container removed"
fi

if docker ps -a --format '{{.Names}}' | grep -q "^taolie-postgres$"; then
    print_warning "Existing PostgreSQL container found"
    read -p "Remove and recreate PostgreSQL? This will delete existing data! (y/n) " -n 1 -r < /dev/tty
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker stop taolie-postgres &> /dev/null || true
        docker rm taolie-postgres &> /dev/null || true
        print_success "Old PostgreSQL container removed"
    else
        print_info "Keeping existing PostgreSQL container"
    fi
fi

# Run PostgreSQL
print_info "Starting PostgreSQL database..."
if ! docker ps --format '{{.Names}}' | grep -q "^taolie-postgres$"; then
    docker run -d \
        --name taolie-postgres \
        --restart unless-stopped \
        --network taolie-network \
        -e POSTGRES_DB=taolie_host_agent \
        -e POSTGRES_USER=agent \
        -e POSTGRES_PASSWORD="$DB_PASSWORD" \
        -v taolie_postgres_data:/var/lib/postgresql/data \
        postgres:16
    
    print_success "PostgreSQL container started"
    sleep 5  # Wait for PostgreSQL to initialize
else
    print_info "PostgreSQL container already running"
fi

print_header "Step 5: Deploying Taolie Host Agent"

# Run Taolie Host Agent
print_info "Starting Taolie Host Agent..."

if [ "$CPU_ONLY" = true ]; then
    print_info "Deploying in CPU-only mode..."
    docker run -d \
        --name taolie-host-agent \
        --restart unless-stopped \
        --privileged \
        --network taolie-network \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
        -v taolie_agent_logs:/var/log/taolie-host-agent \
        ghcr.io/banadda/host-agent:latest
else
    print_info "Deploying with GPU support..."
    # Use --gpus flag if USE_GPUS_FLAG is set, otherwise use --runtime nvidia
    if [ "${USE_GPUS_FLAG:-false}" = true ]; then
        docker run -d \
            --name taolie-host-agent \
            --restart unless-stopped \
            --gpus all \
            --privileged \
            --network taolie-network \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=all \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
            -v taolie_agent_logs:/var/log/taolie-host-agent \
            ghcr.io/banadda/host-agent:latest
    else
        docker run -d \
            --name taolie-host-agent \
            --restart unless-stopped \
            --runtime nvidia \
            --privileged \
            --network taolie-network \
            -e NVIDIA_VISIBLE_DEVICES=all \
            -e NVIDIA_DRIVER_CAPABILITIES=all \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
            -v taolie_agent_logs:/var/log/taolie-host-agent \
            ghcr.io/banadda/host-agent:latest
    fi
fi

print_success "Taolie Host Agent container started"

print_header "Step 6: Verification"

# Wait for container to start
print_info "Waiting for agent to initialize..."
sleep 10

# Check container status
print_info "Checking container status..."
if docker ps | grep -q taolie-host-agent; then
    print_success "Container is running"
else
    print_error "Container failed to start!"
    echo ""
    echo "Checking logs:"
    docker logs taolie-host-agent
    exit 1
fi

# Check logs
print_info "Checking agent logs..."
docker logs --tail 20 taolie-host-agent

# Verify GPU access (if not CPU-only)
if [ "$CPU_ONLY" = false ]; then
    print_info "Verifying GPU access..."
    sleep 5  # Give container time to fully start
    if docker exec taolie-host-agent nvidia-smi &> /dev/null; then
        print_success "GPU is accessible from container"
        # Show GPU info
        echo ""
        docker exec taolie-host-agent nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader | head -1
    else
        print_warning "GPU verification failed, but container is running"
        print_info "The agent may still work, check logs: docker logs taolie-host-agent"
    fi
fi

# Final summary
print_header "Installation Complete!"

cat << EOF
${GREEN}✓ Taolie Host Agent has been successfully installed!${NC}

${BLUE}Configuration Summary:${NC}
  Installation Directory: $INSTALL_DIR
  Public IP:             $PUBLIC_IP
  SSH Port:              $SSH_PORT
  Rental Ports:          $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3
  Mode:                  $([ "$CPU_ONLY" = true ] && echo "CPU-only" || echo "GPU-enabled")

${BLUE}Next Steps:${NC}
  1. Check your resources at: https://taolie-ai.vercel.app/my-gpu
  2. Your GPU will appear in the Resources tab once connected
  3. You'll start earning rewards when your machine is rented or used for mining

${BLUE}Useful Commands:${NC}
  View logs:        docker logs -f taolie-host-agent
  Check status:     docker ps
  Restart agent:    docker restart taolie-host-agent
  Stop agent:       docker stop taolie-host-agent
  Remove agent:     docker stop taolie-host-agent && docker rm taolie-host-agent

${YELLOW}⚠ Important Reminders:${NC}
  • Ensure ports $SSH_PORT, $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3 are forwarded in your router
  • If using cloud provider, update security groups to allow these ports
  • Keep your API key secure and never share it

${BLUE}Need Help?${NC}
  Documentation: https://taolie-ai.vercel.app/my-gpu
  Support: https://help.manus.im

EOF

print_success "Installation completed successfully!"
