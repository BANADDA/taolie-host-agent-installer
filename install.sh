#!/bin/bash

#############################################################################
# Taolie Host Agent - One-Line Installer
# 
# This script automates the installation of the Taolie Host Agent
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY --host-ssh-port PORT
#
# Options:
#   --api-key KEY          Your Taolie API key (required)
#   --host-ssh-port PORT   Host SSH port for SSH access verification (required)
#   --ssh-port PORT        SSH port for agent (default: 3030)
#   --rental-port-1 PORT   Rental port 1 (default: 3031)
#   --rental-port-2 PORT   Rental port 2 (default: 3032)
#   --rental-port-3 PORT   Rental port 3 (default: 3033)
#   --rental-port-N PORT   Additional rental ports (optional, e.g., --rental-port-4, --rental-port-5)
#   --location LOCATION    Your geographic location (auto-detected if not provided)
#   --public-ip IP         Your public IP address (auto-detected if not provided)
#   --db-password PASS     PostgreSQL password (default: db_pass)
#   Note: External/Internal ports default to 3036 (automatic, no user input required)
#   --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
#   --marketplace          Enable marketplace mode (for VM rentals, auto-setup VM requirements)
#   --label KEY=VALUE      Add Docker label to container (can be specified multiple times)
#   --help                 Show this help message
#
#############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Default values
API_KEY=""
PUBLIC_IP=""
SSH_PORT=""  # Will default to 3030 if not provided
HOST_SSH_PORT=""  # Host SSH port (different from agent SSH port) - required
RENTAL_PORTS=()  # Will default to 3031, 3032, 3033 if not provided
EXTERNAL_PORT="3036"  # Default external port
INTERNAL_PORT="3036"  # Default internal port (same as external)
DB_PASSWORD="db_pass"
CPU_ONLY=false
MARKETPLACE=false
USE_GPUS_FLAG=false
INSTALL_DIR="$HOME/taolie-host-agent"
LOCATION=""
DOCKER_LABELS=("com.centurylinklabs.watchtower.enable=true")  # Default labels (Watchtower enabled)
USER_PROVIDED_RENTAL_PORTS=false  # Track if user provided any rental ports

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
  --location LOCATION    Your geographic location (auto-detected from IP if not provided)
  --public-ip IP         Your public IP address (auto-detected if not provided)
  --host-ssh-port PORT   Host SSH port for SSH access verification (required)
  --ssh-port PORT        SSH port for agent (default: 3030)
  --rental-port-1 PORT   Rental port 1 (default: 3031)
  --rental-port-2 PORT   Rental port 2 (default: 3032)
  --rental-port-3 PORT   Rental port 3 (default: 3033)
  --rental-port-N PORT   Additional rental ports (optional, e.g., --rental-port-4, --rental-port-5)
  --db-password PASS     PostgreSQL password (default: db_pass)
  --cpu-only             Install in CPU-only mode (default: auto-detect GPU)
  --marketplace          Enable marketplace mode (for VM rentals, auto-setup VM requirements)
  --label KEY=VALUE      Add Docker label to container (can be specified multiple times)
  --help                 Show this help message

Examples:
  # Basic installation with default ports (location auto-detected)
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
    --api-key abc123 \
    --host-ssh-port 3030

  # With additional rental ports
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
    --api-key abc123 \
    --host-ssh-port 3030 \
    --rental-port-4 3034 \
    --rental-port-5 3035

  # Marketplace mode (for VM rentals)
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
    --api-key abc123 \
    --host-ssh-port 3030 \
    --marketplace

  # CPU-only mode
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
    --api-key abc123 \
    --host-ssh-port 3030 \
    --cpu-only

  # With Docker labels (e.g., for Watchtower)
  curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- \
    --api-key abc123 \
    --host-ssh-port 3030 \
    --label "com.centurylinklabs.watchtower.enable=true"

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
        --host-ssh-port)
            HOST_SSH_PORT="$2"
            shift 2
            ;;
        --rental-port-*)
            # Handle dynamic rental ports (--rental-port-1, --rental-port-2, etc.)
            PORT_NUM=$(echo "$1" | sed 's/--rental-port-//')
            if [ "$USER_PROVIDED_RENTAL_PORTS" = false ]; then
                # First rental port provided - clear defaults
                RENTAL_PORTS=()
                USER_PROVIDED_RENTAL_PORTS=true
            fi
            RENTAL_PORTS+=("$2")
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
        --label)
            DOCKER_LABELS+=("$2")
            shift 2
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

# Set defaults if not provided
if [ -z "$SSH_PORT" ]; then
    SSH_PORT="3030"
fi

if [ ${#RENTAL_PORTS[@]} -lt 3 ]; then
    # User didn't provide enough rental ports, use defaults
    RENTAL_PORTS=("3031" "3032" "3033")
fi

# Validate required parameters
if [ -z "$API_KEY" ]; then
    print_error "API key is required!"
    echo ""
    echo "Get your API key from: https://taolie-ai.vercel.app/my-gpu"
    echo ""
    echo "Usage: curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/install.sh | bash -s -- --api-key YOUR_API_KEY --host-ssh-port PORT"
    exit 1
fi

# Validate required ports
if [ -z "$HOST_SSH_PORT" ]; then
    print_error "Host SSH port is required!"
    echo ""
    echo "Please specify host SSH port with --host-ssh-port option"
    echo "Example: --host-ssh-port 3030"
    exit 1
fi

# Auto-detect location from IP if not provided (will be done after IP detection)

# Validate port consistency (if user overrides external/internal ports, ensure both are set)
if [ -n "$EXTERNAL_PORT" ] && [ -z "$INTERNAL_PORT" ]; then
    # If external is set but internal is not, use external for internal too
    INTERNAL_PORT="$EXTERNAL_PORT"
fi

if [ -z "$EXTERNAL_PORT" ] && [ -n "$INTERNAL_PORT" ]; then
    # If internal is set but external is not, use internal for external too
    EXTERNAL_PORT="$INTERNAL_PORT"
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
    PUBLIC_IP=$(curl -4 -s ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        print_error "Failed to auto-detect public IP"
        echo "Please specify your public IP with --public-ip option"
        exit 1
    fi
    print_success "Detected public IP: $PUBLIC_IP"
else
    print_info "Using provided public IP: $PUBLIC_IP"
fi

# Auto-detect location from IP if not provided
if [ -z "$LOCATION" ]; then
    print_info "Auto-detecting location from IP address..."
    # Try multiple geolocation APIs
    LOCATION=$(curl -s "https://ipapi.co/${PUBLIC_IP}/country_code/" 2>/dev/null)
    if [ -z "$LOCATION" ] || [ "$LOCATION" = "null" ]; then
        LOCATION=$(curl -s "http://ip-api.com/json/${PUBLIC_IP}" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
    fi
    if [ -z "$LOCATION" ] || [ "$LOCATION" = "null" ]; then
        # Fallback: try to get country name and map to common codes
        COUNTRY=$(curl -s "http://ip-api.com/json/${PUBLIC_IP}" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 2>/dev/null)
        case "$COUNTRY" in
            *"United States"*) LOCATION="US" ;;
            *"United Kingdom"*) LOCATION="UK" ;;
            *"Germany"*|*"France"*|*"Italy"*|*"Spain"*|*"Netherlands"*|*"Belgium"*|*"Austria"*|*"Switzerland"*|*"Sweden"*|*"Norway"*|*"Denmark"*|*"Finland"*|*"Poland"*|*"Portugal"*) LOCATION="EU" ;;
            *"China"*|*"Japan"*|*"South Korea"*|*"Singapore"*|*"India"*|*"Thailand"*|*"Malaysia"*|*"Indonesia"*|*"Philippines"*|*"Vietnam"*) LOCATION="Asia" ;;
            *"Canada"*) LOCATION="CA" ;;
            *"Australia"*|*"New Zealand"*) LOCATION="AU" ;;
            *) LOCATION="Unknown" ;;
        esac
    fi
    if [ -z "$LOCATION" ] || [ "$LOCATION" = "null" ] || [ "$LOCATION" = "Unknown" ]; then
        print_warning "Could not auto-detect location, using 'Unknown'"
        LOCATION="Unknown"
    else
        print_success "Auto-detected location: $LOCATION"
    fi
else
    print_info "Using provided location: $LOCATION"
fi

# Configure firewall
print_info "Configuring firewall rules..."
if command -v ufw &> /dev/null; then
    print_info "Opening required ports in UFW..."
    sudo ufw allow $SSH_PORT/tcp &> /dev/null || true
    sudo ufw allow $HOST_SSH_PORT/tcp &> /dev/null || true
    for port in "${RENTAL_PORTS[@]}"; do
        sudo ufw allow $port/tcp &> /dev/null || true
    done
    if [ -n "$EXTERNAL_PORT" ]; then
        sudo ufw allow $EXTERNAL_PORT/tcp &> /dev/null || true
    fi
    print_success "Firewall rules configured"
else
    PORTS_LIST="$SSH_PORT"
    for port in "${RENTAL_PORTS[@]}"; do
        PORTS_LIST="$PORTS_LIST, $port"
    done
    if [ -n "$EXTERNAL_PORT" ]; then
        PORTS_LIST="$PORTS_LIST, $EXTERNAL_PORT"
    fi
    print_warning "UFW not found. Please manually configure your firewall to allow ports: $PORTS_LIST"
fi

print_info "Port configuration:"
echo "  SSH Port:       $SSH_PORT"
echo "  Host SSH Port: $HOST_SSH_PORT"
for i in "${!RENTAL_PORTS[@]}"; do
    echo "  Rental Port $((i+1)):  ${RENTAL_PORTS[$i]}"
done
if [ -n "$EXTERNAL_PORT" ]; then
    echo "  External Port:  $EXTERNAL_PORT -> Internal Port: $INTERNAL_PORT"
fi

# Port checking function
check_port_open() {
    local port=$1
    local port_name=$2
    local port_type=$3  # "required" or "optional"
    local nc_pid=""
    
    # Display port check with nice formatting
    printf "  ${BLUE}→${NC} Checking ${CYAN}%s${NC} (port ${YELLOW}%s${NC})" "$port_name" "$port"
    if [ "$port_type" = "optional" ]; then
        printf " ${GRAY}[Optional]${NC}"
    fi
    printf " ... "
    
    # Netcat should already be installed at this point (checked before port checks)
    # But verify it's available just in case
    if ! command -v nc &> /dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
        print_error "    netcat (nc) not found - port check cannot proceed"
        return 1
    fi
    
    # Start netcat listener in background
    # This will listen on the port and send "hello port is open" when a connection is made
    echo "hello port is open" | nc -l -p $port >/dev/null 2>&1 &
    nc_pid=$!
    
    # Wait a moment for netcat to start listening
    sleep 2
    
    # Verify netcat is still running (if it died immediately, port might be in use)
    if ! kill -0 $nc_pid 2>/dev/null; then
        # Netcat died - port might be in use, but continue with portchecker anyway
        nc_pid=""
    fi
    
    # Use "me" as host to auto-detect requester IP
    local response=$(curl -s --max-time 10 "https://portchecker.io/api/me/$port" 2>/dev/null)
    
    # Clean up netcat process if we started it
    if [ -n "$nc_pid" ] && kill -0 $nc_pid 2>/dev/null; then
        kill $nc_pid 2>/dev/null || true
        wait $nc_pid 2>/dev/null || true
    fi
    
    # Also try to kill any remaining netcat processes on this port (safety cleanup)
    pkill -f "nc -l -p $port" 2>/dev/null || true
    
    # Evaluate response
    if [ "$response" = "True" ]; then
        echo -e "${GREEN}✓ OPEN${NC}"
        return 0
    elif [ "$response" = "False" ]; then
        echo -e "${RED}✗ CLOSED${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ UNKNOWN${NC}"
        print_warning "    Could not verify port status (API response: ${response:-timeout})"
        print_warning "    Proceeding anyway, but please ensure the port is open"
        return 0  # Don't block on API errors, just warn
    fi
}

# SSH verification function
check_ssh_access() {
    local ip=$1
    local port=$2
    local username=$3
    local port_name=$4
    
    # Display SSH check with nice formatting
    printf "  ${BLUE}→${NC} Checking ${CYAN}%s${NC} (SSH on port ${YELLOW}%s${NC})" "$port_name" "$port"
    printf " ... "
    
    # Check if Python 3 is available
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}✗ FAILED${NC}"
        print_error "    Python 3 not found - SSH check cannot proceed"
        return 1
    fi
    
    # Check if paramiko is installed, install if not
    if ! python3 -c "import paramiko" 2>/dev/null; then
        print_info "    Installing paramiko (required for SSH verification)..."
        if command -v pip3 &> /dev/null; then
            pip3 install --quiet paramiko 2>/dev/null || {
                echo -e "${RED}✗ FAILED${NC}"
                print_error "    Failed to install paramiko"
                return 1
            }
        else
            # Try installing pip3 first
            if command -v sudo &> /dev/null; then
                sudo apt-get update -qq >/dev/null 2>&1
                sudo apt-get install -y python3-pip >/dev/null 2>&1
                sudo pip3 install --quiet paramiko 2>/dev/null || {
                    echo -e "${RED}✗ FAILED${NC}"
                    print_error "    Failed to install paramiko"
                    return 1
                }
            else
                apt-get update -qq >/dev/null 2>&1
                apt-get install -y python3-pip >/dev/null 2>&1
                pip3 install --quiet paramiko 2>/dev/null || {
                    echo -e "${RED}✗ FAILED${NC}"
                    print_error "    Failed to install paramiko"
                    return 1
                }
            fi
        fi
    fi
    
    # Create temporary Python script for SSH verification
    local ssh_check_script=$(mktemp)
    cat > "$ssh_check_script" << 'PYTHON_EOF'
import paramiko
import socket
import sys

def test_ssh_access(ip, port, username):
    client = paramiko.SSHClient()
    # This auto-accepts the server's host key (needed for first-time connections)
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    
    try:
        # We don't provide a password; we are testing if the service responds
        client.connect(ip, port=port, username=username, password="wrong_password_on_purpose", timeout=10)
        
    except paramiko.AuthenticationException:
        # Authentication failed means SSH is active and responding
        print("SUCCESS")
        return 0
    
    except socket.timeout:
        print("FAILURE: Connection timed out. The port is likely closed or firewalled.")
        return 1
    
    except paramiko.SSHException as e:
        # SSH is responding, but encountered a protocol error
        print("SUCCESS")
        return 0
    
    except Exception as e:
        print(f"FAILURE: Could not connect: {e}")
        return 1
    
    finally:
        client.close()

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("FAILURE: Usage: python3 script.py <ip> <port> <username>")
        sys.exit(1)
    
    ip = sys.argv[1]
    port = int(sys.argv[2])
    username = sys.argv[3]
    
    result = test_ssh_access(ip, port, username)
    sys.exit(result)
PYTHON_EOF
    
    # Run the SSH check script
    local result=$(python3 "$ssh_check_script" "$ip" "$port" "$username" 2>&1)
    local exit_code=$?
    
    # Clean up temporary script
    rm -f "$ssh_check_script"
    
    # Evaluate result
    if [ $exit_code -eq 0 ] && echo "$result" | grep -q "SUCCESS"; then
        echo -e "${GREEN}✓ SSH ACTIVE${NC}"
        return 0
    else
        echo -e "${RED}✗ SSH FAILED${NC}"
        if [ -n "$result" ]; then
            print_error "    $result"
        fi
        return 1
    fi
}

# Check all ports before proceeding
print_header "Step 2.5: Port Availability Check"

echo ""
print_info "Verifying port accessibility from external network..."

# Ensure netcat is installed before checking ports
if ! command -v nc &> /dev/null; then
    echo ""
    print_info "Installing netcat (required for port checking)..."
    if command -v sudo &> /dev/null; then
        sudo apt-get update -qq >/dev/null 2>&1
        sudo apt-get install -y netcat-openbsd >/dev/null 2>&1
    else
        # Try without sudo (in case we're already root)
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y netcat-openbsd >/dev/null 2>&1
    fi
    
    # Verify installation
    if ! command -v nc &> /dev/null; then
        print_error "Failed to install netcat. Port checking cannot proceed."
        exit 1
    fi
    print_success "netcat installed successfully"
fi

echo ""

PORT_CHECK_FAILED=false
CLOSED_PORTS=()
MACHINE_USERNAME=$(whoami)

# Check all ports in range 3030-3039 one at a time
print_info "Checking all ports in range 3030-3039..."
for port in {3030..3039}; do
    # Determine port type and name
    # Check host SSH port first (prioritize SSH verification)
    if [ "$port" = "$HOST_SSH_PORT" ]; then
        # Check host SSH port with SSH verification
        if ! check_ssh_access "$PUBLIC_IP" "$port" "$MACHINE_USERNAME" "Host SSH Port"; then
            PORT_CHECK_FAILED=true
            CLOSED_PORTS+=("Host SSH Port: $port (SSH verification failed)")
        fi
    elif [ "$port" = "$SSH_PORT" ]; then
        # Check SSH port
        if ! check_port_open "$port" "SSH Port" "required"; then
            PORT_CHECK_FAILED=true
            CLOSED_PORTS+=("SSH Port: $port")
        fi
    elif [[ " ${RENTAL_PORTS[@]} " =~ " ${port} " ]]; then
        # Check rental port
        # Find which rental port number this is
        rental_num=1
        for i in "${!RENTAL_PORTS[@]}"; do
            if [ "${RENTAL_PORTS[$i]}" = "$port" ]; then
                rental_num=$((i+1))
                break
            fi
        done
        if ! check_port_open "$port" "Rental Port $rental_num" "required"; then
            PORT_CHECK_FAILED=true
            CLOSED_PORTS+=("Rental Port $rental_num: $port")
        fi
    elif [ -n "$EXTERNAL_PORT" ] && [ "$port" = "$EXTERNAL_PORT" ]; then
        # Check external port (optional)
        if ! check_port_open "$port" "External Port" "optional"; then
            PORT_CHECK_FAILED=true
            CLOSED_PORTS+=("External Port: $port")
        fi
    else
        # Check any other port in the range (check but don't fail)
        check_port_open "$port" "Port $port" "optional" || true
    fi
done

# If host-ssh-port is outside the 3030-3039 range, check it separately
if [ -n "$HOST_SSH_PORT" ] && ([ "$HOST_SSH_PORT" -lt 3030 ] || [ "$HOST_SSH_PORT" -gt 3039 ]); then
    if ! check_ssh_access "$PUBLIC_IP" "$HOST_SSH_PORT" "$MACHINE_USERNAME" "Host SSH Port"; then
        PORT_CHECK_FAILED=true
        CLOSED_PORTS+=("Host SSH Port: $HOST_SSH_PORT (SSH verification failed)")
    fi
fi

echo ""

# If any port check failed, exit with error
if [ "$PORT_CHECK_FAILED" = true ]; then
    echo ""
    print_error "Port verification failed!"
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}⚠  The following ports are not accessible from the external network:${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    for closed_port in "${CLOSED_PORTS[@]}"; do
        echo -e "  ${RED}✗${NC} ${closed_port}"
    done
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📋 Required Ports Summary:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${CYAN}SSH Port:${NC}        ${YELLOW}$SSH_PORT${NC}"
    echo -e "  ${CYAN}Host SSH Port:${NC}   ${YELLOW}$HOST_SSH_PORT${NC}"
    for i in "${!RENTAL_PORTS[@]}"; do
        echo -e "  ${CYAN}Rental Port $((i+1)):${NC}   ${YELLOW}${RENTAL_PORTS[$i]}${NC}"
    done
    if [ -n "$EXTERNAL_PORT" ]; then
        echo -e "  ${CYAN}External Port:${NC}    ${YELLOW}$EXTERNAL_PORT${NC} ${GRAY}(Optional)${NC}"
    fi
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🔧 Troubleshooting Steps:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${GREEN}1.${NC} ${CYAN}Router Configuration:${NC}"
    echo -e "     • Log into your router admin panel"
    echo -e "     • Navigate to Port Forwarding / Virtual Server settings"
    echo -e "     • Forward the required ports to this machine's local IP"
    echo ""
    echo -e "  ${GREEN}2.${NC} ${CYAN}Cloud Provider (AWS/GCP/Azure):${NC}"
    echo -e "     • Update Security Groups / Firewall Rules"
    echo -e "     • Allow inbound traffic on the required ports"
    echo ""
    echo -e "  ${GREEN}3.${NC} ${CYAN}Local Firewall (UFW/iptables):${NC}"
    echo -e "     • Ensure UFW allows the ports: ${YELLOW}sudo ufw allow $SSH_PORT/tcp${NC}"
    echo -e "     • ${YELLOW}sudo ufw allow $HOST_SSH_PORT/tcp${NC}"
    for port in "${RENTAL_PORTS[@]}"; do
        echo -e "     • ${YELLOW}sudo ufw allow $port/tcp${NC}"
    done
    echo ""
    echo -e "  ${GREEN}4.${NC} ${CYAN}Verify Port Status:${NC}"
    echo -e "     • Check ports manually at: ${BLUE}https://portchecker.io${NC}"
    echo -e "     • Test from external network: ${BLUE}telnet $PUBLIC_IP $SSH_PORT${NC}"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_error "Installation cannot proceed until all required ports are accessible."
    echo ""
    exit 1
fi

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
print_success "All ports are verified and accessible from external network"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

print_header "Step 3: Installation Directory Setup"

# Create installation directory
print_info "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
print_success "Directory created"

# Get hostname and machine username
HOSTNAME=$(hostname)
MACHINE_USERNAME=$(whoami)

# Create config.yaml
print_info "Generating configuration file..."
cat > config.yaml << EOF
agent:
  id: ""
  api_key: "$API_KEY"
  hostname: "$HOSTNAME"
  machine_username: "$MACHINE_USERNAME"
  resource_type: "$([ "$CPU_ONLY" = true ] && echo "cpu" || echo "gpu")"
  location: "$LOCATION"$([ "$MARKETPLACE" = true ] && echo "
  marketplace: true" || echo "")

network:
  public_ip: "$PUBLIC_IP"
  ports:
    ssh: $SSH_PORT
    host_ssh_port: $HOST_SSH_PORT
$(for i in "${!RENTAL_PORTS[@]}"; do
  echo "    rental_port_$((i+1)): ${RENTAL_PORTS[$i]}"
done)$([ -n "$EXTERNAL_PORT" ] && echo "
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

print_header "Step 5: Deploying Taolie Host Agent"

# Run Taolie Host Agent
print_info "Starting Taolie Host Agent..."

# Build docker run command with labels
build_docker_cmd() {
    local cmd_args=(
        "docker" "run" "-d"
        "--name" "taolie-host-agent"
        "--restart" "unless-stopped"
    )
    
    # Add GPU-specific flags if not CPU-only
    if [ "$1" != "cpu" ]; then
        if [ "${USE_GPUS_FLAG:-false}" = true ]; then
            cmd_args+=("--gpus" "all")
        else
            cmd_args+=("--runtime" "nvidia")
        fi
        cmd_args+=(
            "-e" "NVIDIA_VISIBLE_DEVICES=all"
            "-e" "NVIDIA_DRIVER_CAPABILITIES=all"
        )
    fi
    
    # Add common flags
    cmd_args+=(
        "--privileged"
        "--network" "taolie-network"
    )
    
    # Add labels
    for label in "${DOCKER_LABELS[@]}"; do
        cmd_args+=("--label" "$label")
    done
    
    # Add volumes
    cmd_args+=(
        "-v" "/var/run/docker.sock:/var/run/docker.sock"
        "-v" "/usr/local/bin:/usr/local/bin"
        "-v" "$(pwd)/config.yaml:/etc/taolie-host-agent/config.yaml:ro"
        "-v" "taolie_agent_logs:/var/log/taolie-host-agent"
        "ghcr.io/banadda/host-agent:latest"
    )
    
    # Execute the command
    "${cmd_args[@]}"
}

if [ "$CPU_ONLY" = true ]; then
    print_info "Deploying in CPU-only mode..."
    build_docker_cmd "cpu"
else
    print_info "Deploying with GPU support..."
    build_docker_cmd "gpu"
fi

print_success "Taolie Host Agent container started"

print_header "Step 5.5: Setting up Watchtower"

# Stop and remove existing watchtower container if it exists
print_info "Checking for existing Watchtower container..."
if docker ps -a --format '{{.Names}}' | grep -q "^taolie-watchtower$"; then
    print_warning "Stopping and removing existing taolie-watchtower container..."
    docker stop taolie-watchtower &> /dev/null || true
    docker rm taolie-watchtower &> /dev/null || true
    print_success "Old Watchtower container removed"
fi

# Pull Watchtower image
print_info "Pulling Watchtower image..."
if docker pull ghcr.io/banadda/taolie-watchtower:latest &> /dev/null; then
    print_success "Watchtower image pulled successfully"
else
    print_warning "Failed to pull Watchtower image, but will try to run anyway"
fi

# Run Watchtower container
print_info "Starting Watchtower container..."
if docker run -d \
    --name taolie-watchtower \
    --restart unless-stopped \
    --network taolie-network \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -e WATCHTOWER_CLEANUP=true \
    -e WATCHTOWER_POLL_INTERVAL=180 \
    -e WATCHTOWER_INCLUDE_STOPPED=false \
    -e WATCHTOWER_REVIVE_STOPPED=false \
    -e WATCHTOWER_LABEL_ENABLE=true \
    ghcr.io/banadda/taolie-watchtower:latest &> /dev/null; then
    print_success "Watchtower container started"
else
    print_warning "Failed to start Watchtower container"
    print_info "Watchtower is optional - the agent will still work without it"
fi

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

# Check Watchtower container status
print_info "Checking Watchtower container status..."
if docker ps | grep -q taolie-watchtower; then
    print_success "Watchtower container is running"
else
    print_warning "Watchtower container is not running (optional component)"
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
  Hostname:              $HOSTNAME
  Machine Username:      $MACHINE_USERNAME
  Public IP:             $PUBLIC_IP
  Location:              $LOCATION (auto-detected)
  SSH Port:              $SSH_PORT
  Host SSH Port:         $HOST_SSH_PORT
  Rental Ports:          $(IFS=', '; echo "${RENTAL_PORTS[*]}")$([ -n "$EXTERNAL_PORT" ] && echo "
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
  View Watchtower:  docker logs -f taolie-watchtower
  Check status:     docker ps
  Restart agent:    docker restart taolie-host-agent
  Stop agent:       docker stop taolie-host-agent
  Remove agent:     docker stop taolie-host-agent && docker rm taolie-host-agent

${BLUE}Automatic Updates:${NC}
  • Watchtower is installed and will automatically update containers with the watchtower label
  • Poll interval: 3 minutes (180 seconds)
  • The host agent container has the watchtower label enabled

${YELLOW}⚠ Important Reminders:${NC}
  • Ensure ports $SSH_PORT, $HOST_SSH_PORT$(for port in "${RENTAL_PORTS[@]}"; do echo ", $port"; done)$([ -n "$EXTERNAL_PORT" ] && echo ", $EXTERNAL_PORT" || echo "") are forwarded in your router
  • If using cloud provider, update security groups to allow these ports
  • Keep your API key secure and never share it

${BLUE}Need Help?${NC}
  Documentation: https://taolie-ai.vercel.app/my-gpu
  Support: https://help.taolie-ai.vercel.app

EOF

print_success "Installation completed successfully!"
