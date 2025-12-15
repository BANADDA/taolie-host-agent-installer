#!/bin/bash

#############################################################################
# Taolie Host Agent - One-Line Installer
# 
# This script automates the installation of the Taolie Host Agent
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY --location YOUR_LOCATION
#
# Options:
#   --api-key KEY          Your Taolie API key (required)
#   --location LOCATION    Your geographic location (required)
#   --public-ip IP         Your public IP address (auto-detected if not provided)
#   --ssh-port PORT        SSH port (default: 2222)
#   --rental-port-1 PORT   Rental port 1 (default: 8888)
#   --rental-port-2 PORT   Rental port 2 (default: 9999)
#   --rental-port-3 PORT   Rental port 3 (default: 7777)
#   --external-port PORT   External port for rental containers (optional)
#   --internal-port PORT   Internal port for rental containers (optional)
#   --db-password PASS     PostgreSQL password (default: db_pass)
#   --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
#   --marketplace          Enable marketplace mode (for VM rentals, auto-setup VM requirements)
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
EXTERNAL_PORT=""
INTERNAL_PORT=""
DB_PASSWORD="db_pass"
CPU_ONLY=false
MARKETPLACE=false
USE_GPUS_FLAG=false
INSTALL_DIR="$HOME/taolie-host-agent"
LOCATION=""

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
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY --location YOUR_LOCATION

Options:
  --api-key KEY          Your Taolie API key (required)
  --location LOCATION    Your geographic location (e.g., "US", "EU", "Asia") (required)
  --public-ip IP         Your public IP address (auto-detected if not provided)
  --ssh-port PORT        SSH port (default: 2222)
  --rental-port-1 PORT   Rental port 1 (default: 8888)
  --rental-port-2 PORT   Rental port 2 (default: 9999)
  --rental-port-3 PORT   Rental port 3 (default: 7777)
  --external-port PORT   External port for rental containers (optional)
  --internal-port PORT   Internal port for rental containers (optional, requires --external-port)
  --db-password PASS     PostgreSQL password (default: db_pass)
  --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
  --marketplace          Enable marketplace mode (for VM rentals, auto-setup VM requirements)
  --help                 Show this help message

Examples:
  # Basic installation with API key and location
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --location US

  # Marketplace mode (for VM rentals)
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --location US --marketplace

  # With custom external/internal port mapping
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --location US --external-port 3030 --internal-port 3030

  # Custom ports and IP
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --location US --public-ip 1.2.3.4 --ssh-port 2223

  # CPU-only mode
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key abc123 --location US --cpu-only

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
        --external-port)
            EXTERNAL_PORT="$2"
            shift 2
            ;;
        --internal-port)
            INTERNAL_PORT="$2"
            shift 2
            ;;
        --location)
            LOCATION="$2"
            shift 2
            ;;
        --cpu-only)
            CPU_ONLY=true
            shift
            ;;
        --marketplace)
            MARKETPLACE=true
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
    echo "Usage: curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY --location YOUR_LOCATION"
    exit 1
fi

# Prompt for location if not provided
if [ -z "$LOCATION" ]; then
    print_warning "Location is required for registration"
    echo ""
    echo "Please enter your geographic location (e.g., US, EU, Asia, Canada, etc.):"
    read -p "Location: " LOCATION < /dev/tty
    if [ -z "$LOCATION" ]; then
        print_error "Location cannot be empty!"
        exit 1
    fi
fi

# Validate port consistency
if [ -n "$EXTERNAL_PORT" ] && [ -z "$INTERNAL_PORT" ]; then
    print_error "--external-port requires --internal-port to be specified"
    exit 1
fi

if [ -z "$EXTERNAL_PORT" ] && [ -n "$INTERNAL_PORT" ]; then
    print_error "--internal-port requires --external-port to be specified"
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
            # Try multiple CUDA versions for better compatibility
            if docker pull nvidia/cuda:12.2.0-base-ubuntu22.04 &> /dev/null; then
                TEST_IMAGE="nvidia/cuda:12.2.0-base-ubuntu22.04"
            elif docker pull nvidia/cuda:12.0.0-base-ubuntu22.04 &> /dev/null; then
                TEST_IMAGE="nvidia/cuda:12.0.0-base-ubuntu22.04"
            elif docker pull nvidia/cuda:11.8.0-base-ubuntu22.04 &> /dev/null; then
                TEST_IMAGE="nvidia/cuda:11.8.0-base-ubuntu22.04"
            else
                print_error "Failed to pull NVIDIA CUDA test image"
                TEST_IMAGE="nvidia/cuda:12.2.0-base-ubuntu22.04"
            fi
            print_info "Using test image: $TEST_IMAGE"
            
            # Try --gpus all first (recommended method)
            print_info "Testing GPU access with --gpus all..."
            if timeout 30 docker run --rm --gpus all $TEST_IMAGE nvidia-smi > /dev/null 2>&1; then
                print_success "NVIDIA Container Toolkit is properly configured (--gpus all)"
                USE_GPUS_FLAG=true
            # Then try --runtime=nvidia as fallback
            elif timeout 30 docker run --rm --runtime=nvidia $TEST_IMAGE nvidia-smi > /dev/null 2>&1; then
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
                    if timeout 30 docker run --rm --gpus all $TEST_IMAGE nvidia-smi > /dev/null 2>&1; then
                        print_success "NVIDIA Container Toolkit is now working! (--gpus all)"
                        USE_GPUS_FLAG=true
                    elif timeout 30 docker run --rm --runtime=nvidia $TEST_IMAGE nvidia-smi > /dev/null 2>&1; then
                        print_success "NVIDIA Container Toolkit is now working! (--runtime=nvidia)"
                        USE_GPUS_FLAG=false
                    else
                        print_error "NVIDIA Container Toolkit is still not working after configuration"
                        echo ""
                        echo "Please try manually:"
                        echo "  sudo nvidia-ctk runtime configure --runtime=docker"
                        echo "  sudo systemctl restart docker"
                        echo "  docker run --rm --gpus all $TEST_IMAGE nvidia-smi"
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
    if [ -n "$EXTERNAL_PORT" ]; then
        sudo ufw allow $EXTERNAL_PORT/tcp &> /dev/null || true
    fi
    print_success "Firewall rules configured"
else
    PORTS_LIST="$SSH_PORT, $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3"
    if [ -n "$EXTERNAL_PORT" ]; then
        PORTS_LIST="$PORTS_LIST, $EXTERNAL_PORT"
    fi
    print_warning "UFW not found. Please manually configure your firewall to allow ports: $PORTS_LIST"
fi

print_info "Port configuration:"
echo "  SSH Port:       $SSH_PORT"
echo "  Rental Port 1:  $RENTAL_PORT_1"
echo "  Rental Port 2:  $RENTAL_PORT_2"
echo "  Rental Port 3:  $RENTAL_PORT_3"
if [ -n "$EXTERNAL_PORT" ]; then
    echo "  External Port:  $EXTERNAL_PORT -> Internal Port: $INTERNAL_PORT"
fi

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
  resource_type: "$([ "$CPU_ONLY" = true ] && echo "cpu" || echo "gpu")"
  location: "$LOCATION"$([ "$MARKETPLACE" = true ] && echo "
  marketplace: true" || echo "")

network:
  public_ip: "$PUBLIC_IP"
  ports:
    ssh: $SSH_PORT
    rental_port_1: $RENTAL_PORT_1
    rental_port_2: $RENTAL_PORT_2
    rental_port_3: $RENTAL_PORT_3$([ -n "$EXTERNAL_PORT" ] && echo "
    external_port: $EXTERNAL_PORT
    internal_port: $INTERNAL_PORT" || echo "")

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

print_header "Step 5: LXD Setup (Marketplace Mode)"

# Install and configure LXD if marketplace mode is enabled
if [ "$MARKETPLACE" = true ]; then
    print_info "Marketplace mode enabled - setting up LXD..."
    
    # Check if LXD is installed (check both snap and system package)
    LXD_INSTALLED=false
    if command -v lxd &> /dev/null; then
        LXD_INSTALLED=true
    elif snap list 2>/dev/null | grep -q "^lxd "; then
        LXD_INSTALLED=true
    fi
    
    if [ "$LXD_INSTALLED" = false ]; then
        print_info "Installing LXD via snap..."
        sudo snap install lxd
        if [ $? -ne 0 ]; then
            print_error "Failed to install LXD"
            echo "Please install LXD manually: sudo snap install lxd"
            exit 1
        fi
        print_success "LXD installed"
        sleep 2  # Give snap time to set up
    else
        print_info "LXD is already installed"
    fi
    
    # Check if LXD is initialized by checking for socket or config
    LXD_INITIALIZED=false
    if [ -S /var/snap/lxd/common/lxd/unix.socket ] 2>/dev/null; then
        LXD_INITIALIZED=true
    elif [ -d /var/snap/lxd/common/lxd ] 2>/dev/null; then
        # Try to check if LXD is ready
        if sudo lxd waitready --timeout=5 &> /dev/null; then
            LXD_INITIALIZED=true
        fi
    fi
    
    if [ "$LXD_INITIALIZED" = false ]; then
        print_info "Initializing LXD (non-interactive)..."
        sudo lxd init --auto
        if [ $? -ne 0 ]; then
            print_error "Failed to initialize LXD"
            echo "Please initialize LXD manually: sudo lxd init --auto"
            exit 1
        fi
        print_success "LXD initialized"
        sleep 2  # Give LXD time to create socket
    else
        print_info "LXD is already initialized"
    fi
    
    # Verify LXD socket exists and is accessible
    if [ ! -S /var/snap/lxd/common/lxd/unix.socket ]; then
        print_warning "LXD socket not found, waiting for LXD to be ready..."
        sudo lxd waitready --timeout=30
        if [ ! -S /var/snap/lxd/common/lxd/unix.socket ]; then
            print_error "LXD socket still not found at /var/snap/lxd/common/lxd/unix.socket"
            echo "Please check LXD installation: sudo lxd waitready"
            exit 1
        fi
    fi
    
    # Add current user to lxd group if not already a member
    if ! groups | grep -q lxd; then
        print_info "Adding current user to lxd group..."
        sudo usermod -aG lxd $USER
        print_warning "User added to lxd group. You may need to log out and log back in for this to take effect."
        print_info "For now, the container will use sudo for lxc commands"
    else
        print_info "User is already in lxd group"
    fi
    
    # Check and create storage pool if needed
    print_info "Checking LXD storage pools..."
    if ! sudo lxc storage list --format json 2>/dev/null | grep -q '"name"'; then
        print_info "No storage pools found, creating default storage pool..."
        sudo lxc storage create default dir 2>/dev/null || {
            # If creation fails, try to initialize
            print_info "Storage pool creation failed, ensuring LXD is properly initialized..."
            sudo lxd init --auto --storage-backend=dir --storage-pool=default 2>/dev/null || true
        }
        print_success "Storage pool configured"
    else
        print_info "Storage pools already exist"
    fi
    
    # Check and create default network if needed
    print_info "Checking LXD networks..."
    if ! sudo lxc network list --format json 2>/dev/null | grep -q '"name".*"lxdbr0"'; then
        print_info "Default network (lxdbr0) not found, creating..."
        sudo lxc network create lxdbr0 ipv4.address=auto ipv4.nat=true ipv6.address=none ipv6.nat=false 2>/dev/null || {
            print_warning "Network creation failed, but this may not be critical"
        }
        print_success "Default network configured"
    else
        print_info "Default network (lxdbr0) already exists"
    fi
    
    # Verify socket permissions (should be accessible)
    if [ ! -r /var/snap/lxd/common/lxd/unix.socket ]; then
        print_warning "LXD socket exists but may not be readable by current user"
        print_info "The container will use the mounted socket which should work"
    fi
    
    # Find lxc client binary location
    LXC_BINARY=""
    if command -v lxc &> /dev/null; then
        LXC_BINARY=$(command -v lxc)
    elif [ -f /snap/bin/lxc ]; then
        LXC_BINARY="/snap/bin/lxc"
    elif [ -f /usr/bin/lxc ]; then
        LXC_BINARY="/usr/bin/lxc"
    fi
    
    if [ -n "$LXC_BINARY" ]; then
        print_success "LXD socket is available at /var/snap/lxd/common/lxd/unix.socket"
        print_success "LXC client found at $LXC_BINARY"
        
        # Create a wrapper script for lxc in /usr/local/bin (which is mounted into container)
        # This allows the container to use the host's lxc command
        print_info "Creating LXC wrapper script for container access..."
        # Check for the actual lxc binary location
        LXC_BINARY_PATH=""
        if [ -f /snap/lxd/current/bin/lxc ]; then
            LXC_BINARY_PATH="/snap/lxd/current/bin/lxc"
        elif [ -f /snap/bin/lxc ]; then
            LXC_BINARY_PATH="/snap/bin/lxc"
        elif [ -f /usr/bin/lxc ]; then
            LXC_BINARY_PATH="/usr/bin/lxc"
        fi
        
        if [ -n "$LXC_BINARY_PATH" ]; then
            sudo tee /usr/local/bin/lxc > /dev/null << EOF
#!/bin/bash
# LXC wrapper to use host's lxc command via mounted /snap directory
# Sets LXD_SOCKET to point to the mounted socket location
export LXD_SOCKET=/var/snap/lxd/common/lxd/unix.socket
if [ -f $LXC_BINARY_PATH ]; then
    exec $LXC_BINARY_PATH "\$@"
else
    echo "Error: lxc not found at $LXC_BINARY_PATH" >&2
    exit 1
fi
EOF
            sudo chmod +x /usr/local/bin/lxc
            print_success "LXC wrapper script created at /usr/local/bin/lxc (using $LXC_BINARY_PATH)"
        else
            print_warning "Could not create LXC wrapper - lxc binary not found"
        fi
    else
        print_warning "LXC client not found - VM creation may not work"
        print_info "LXD socket is available, but lxc command is missing"
    fi
else
    print_info "Marketplace mode not enabled - skipping LXD setup"
    LXC_BINARY=""
fi

print_header "Step 6: Deploying Taolie Host Agent"

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
        -v /usr/local/bin:/usr/local/bin \
        -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
        -v taolie_agent_logs:/var/log/taolie-host-agent \
        $([ "$MARKETPLACE" = true ] && echo "-v /var/snap/lxd/common/lxd/unix.socket:/var/snap/lxd/common/lxd/unix.socket") \
        $([ "$MARKETPLACE" = true ] && [ -f /snap/bin/lxc ] && echo "-v /snap:/snap:ro") \
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
            -v /usr/local/bin:/usr/local/bin \
            -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
            -v taolie_agent_logs:/var/log/taolie-host-agent \
            $([ "$MARKETPLACE" = true ] && echo "-v /var/snap/lxd/common/lxd/unix.socket:/var/snap/lxd/common/lxd/unix.socket") \
            $([ "$MARKETPLACE" = true ] && [ -f /snap/bin/lxc ] && echo "-v /snap:/snap:ro") \
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
            -v /usr/local/bin:/usr/local/bin \
            -v "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro" \
            -v taolie_agent_logs:/var/log/taolie-host-agent \
            $([ "$MARKETPLACE" = true ] && echo "-v /var/snap/lxd/common/lxd/unix.socket:/var/snap/lxd/common/lxd/unix.socket") \
            $([ "$MARKETPLACE" = true ] && [ -f /snap/bin/lxc ] && echo "-v /snap:/snap:ro") \
            ghcr.io/banadda/host-agent:latest
    fi
fi

print_success "Taolie Host Agent container started"

print_header "Step 7: Verification"

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
  Location:              $LOCATION
  SSH Port:              $SSH_PORT
  Rental Ports:          $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3$([ -n "$EXTERNAL_PORT" ] && echo "
  External Port:         $EXTERNAL_PORT -> $INTERNAL_PORT" || echo "")
  Resource Type:         $([ "$CPU_ONLY" = true ] && echo "CPU" || echo "GPU")
  Mode:                  $([ "$CPU_ONLY" = true ] && echo "CPU-only" || echo "GPU-enabled")$([ "$MARKETPLACE" = true ] && echo "
  Marketplace Mode:     Enabled (VM rentals)")

${BLUE}Next Steps:${NC}
  1. Check your resources at: https://taolie-ai.vercel.app/my-gpu
  2. Your $([ "$CPU_ONLY" = true ] && echo "CPU" || echo "GPU") will appear in the Resources tab once connected
  3. You'll start earning rewards when your machine is rented or used for mining

${BLUE}Useful Commands:${NC}
  View logs:        docker logs -f taolie-host-agent
  Check status:     docker ps
  Restart agent:    docker restart taolie-host-agent
  Stop agent:       docker stop taolie-host-agent
  Remove agent:     docker stop taolie-host-agent && docker rm taolie-host-agent

${YELLOW}⚠ Important Reminders:${NC}
  • Ensure ports $SSH_PORT, $RENTAL_PORT_1, $RENTAL_PORT_2, $RENTAL_PORT_3$([ -n "$EXTERNAL_PORT" ] && echo ", $EXTERNAL_PORT" || echo "") are forwarded in your router
  • If using cloud provider, update security groups to allow these ports
  • Keep your API key secure and never share it

${BLUE}Need Help?${NC}
  Documentation: https://taolie-ai.vercel.app/my-gpu
  Support: https://help.manus.im

EOF

print_success "Installation completed successfully!"
