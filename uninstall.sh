#!/bin/bash

#############################################################################
# Taolie Host Agent - Uninstaller
# 
# This script completely removes the Taolie Host Agent and all related
# components including containers, images, volumes, networks, and files.
# 
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/uninstall.sh | bash
#
# Or download and run locally:
#   wget https://raw.githubusercontent.com/BANADDA/taolie-host-agent-installer/main/uninstall.sh
#   chmod +x uninstall.sh
#   ./uninstall.sh
#
# Options:
#   --yes, -y              Skip confirmation prompts (auto-confirm)
#   --keep-data            Keep database volumes (preserve data)
#   --keep-config          Keep configuration directory
#   --help                 Show this help message
#
#############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default values
AUTO_CONFIRM=false
KEEP_DATA=false
KEEP_CONFIG=false
INSTALL_DIR="$HOME/taolie-host-agent"

# Component tracking
CONTAINERS_REMOVED=0
IMAGES_REMOVED=0
VOLUMES_REMOVED=0
NETWORKS_REMOVED=0
FILES_REMOVED=0

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
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════${NC}\n"
}

confirm() {
    if [ "$AUTO_CONFIRM" = true ]; then
        return 0
    fi
    
    local prompt="$1"
    read -p "$(echo -e ${YELLOW}${prompt}${NC}) (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

show_help() {
    cat << EOF
Taolie Host Agent - Uninstaller

This script removes all Taolie Host Agent components including:
  • Docker containers (taolie-host-agent, taolie-postgres)
  • Docker images (ghcr.io/banadda/host-agent, postgres)
  • Docker volumes (taolie_postgres_data, taolie_agent_logs)
  • Docker network (taolie-network)
  • Configuration files and directories

Usage:
  curl -fsSL https://[...]/uninstall.sh | bash

  Or download and run:
  wget https://[...]/uninstall.sh
  chmod +x uninstall.sh
  ./uninstall.sh

Options:
  --yes, -y              Skip confirmation prompts (auto-confirm all)
  --keep-data            Keep database volumes (preserve data)
  --keep-config          Keep configuration directory
  --help                 Show this help message

Examples:
  # Interactive uninstall (asks for confirmation)
  ./uninstall.sh

  # Auto-confirm all removals
  ./uninstall.sh --yes

  # Remove everything except data volumes
  ./uninstall.sh --keep-data

  # Keep configuration files
  ./uninstall.sh --keep-config

EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --yes|-y)
            AUTO_CONFIRM=true
            shift
            ;;
        --keep-data)
            KEEP_DATA=true
            shift
            ;;
        --keep-config)
            KEEP_CONFIG=true
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
║        TAOLIE HOST AGENT - UNINSTALLER                     ║
║                                                            ║
║     Complete removal of all agent components               ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

EOF

print_warning "This script will remove the Taolie Host Agent and all related components."
echo ""

# Show what will be removed
print_info "The following will be removed:"
echo "  • Docker containers: taolie-host-agent, taolie-postgres"
echo "  • Docker images: ghcr.io/banadda/host-agent, postgres:16"
if [ "$KEEP_DATA" = false ]; then
    echo "  • Docker volumes: taolie_postgres_data, taolie_agent_logs"
else
    print_warning "  • Docker volumes: WILL BE KEPT (--keep-data flag)"
fi
echo "  • Docker network: taolie-network"
if [ "$KEEP_CONFIG" = false ]; then
    echo "  • Configuration directory: $INSTALL_DIR"
else
    print_warning "  • Configuration directory: WILL BE KEPT (--keep-config flag)"
fi
echo ""

# Final confirmation
if ! confirm "⚠️  Are you sure you want to proceed with uninstallation?"; then
    print_info "Uninstallation cancelled."
    exit 0
fi

print_header "Step 1: Stopping Containers"

# Stop taolie-host-agent
if docker ps -q -f name=taolie-host-agent | grep -q .; then
    print_info "Stopping taolie-host-agent container..."
    if docker stop taolie-host-agent &> /dev/null; then
        print_success "Container stopped: taolie-host-agent"
    else
        print_warning "Failed to stop taolie-host-agent (may already be stopped)"
    fi
else
    print_info "Container taolie-host-agent is not running"
fi

# Stop taolie-postgres
if docker ps -q -f name=taolie-postgres | grep -q .; then
    print_info "Stopping taolie-postgres container..."
    if docker stop taolie-postgres &> /dev/null; then
        print_success "Container stopped: taolie-postgres"
    else
        print_warning "Failed to stop taolie-postgres (may already be stopped)"
    fi
else
    print_info "Container taolie-postgres is not running"
fi

print_header "Step 2: Removing Containers"

# Remove taolie-host-agent
if docker ps -a -q -f name=taolie-host-agent | grep -q .; then
    print_info "Removing taolie-host-agent container..."
    if docker rm taolie-host-agent &> /dev/null; then
        print_success "Container removed: taolie-host-agent"
        ((CONTAINERS_REMOVED++))
    else
        print_error "Failed to remove taolie-host-agent container"
    fi
else
    print_info "Container taolie-host-agent does not exist"
fi

# Remove taolie-postgres
if docker ps -a -q -f name=taolie-postgres | grep -q .; then
    print_info "Removing taolie-postgres container..."
    if docker rm taolie-postgres &> /dev/null; then
        print_success "Container removed: taolie-postgres"
        ((CONTAINERS_REMOVED++))
    else
        print_error "Failed to remove taolie-postgres container"
    fi
else
    print_info "Container taolie-postgres does not exist"
fi

print_header "Step 3: Removing Docker Images"

# Check if we should remove images
if confirm "Remove Docker images? (This will free up disk space)"; then
    # Remove host-agent image
    if docker images -q ghcr.io/banadda/host-agent | grep -q .; then
        print_info "Removing host-agent image..."
        if docker rmi ghcr.io/banadda/host-agent:latest &> /dev/null; then
            print_success "Image removed: ghcr.io/banadda/host-agent:latest"
            ((IMAGES_REMOVED++))
        else
            print_warning "Failed to remove host-agent image (may be in use)"
        fi
    else
        print_info "Image ghcr.io/banadda/host-agent does not exist"
    fi

    # Remove postgres image
    if docker images -q postgres:16 | grep -q .; then
        print_info "Removing postgres image..."
        if docker rmi postgres:16 &> /dev/null; then
            print_success "Image removed: postgres:16"
            ((IMAGES_REMOVED++))
        else
            print_warning "Failed to remove postgres image (may be in use by other containers)"
        fi
    else
        print_info "Image postgres:16 does not exist"
    fi
else
    print_info "Skipping image removal"
fi

print_header "Step 4: Removing Docker Volumes"

if [ "$KEEP_DATA" = false ]; then
    # Remove postgres data volume
    if docker volume ls -q -f name=taolie_postgres_data | grep -q .; then
        print_warning "Removing PostgreSQL data volume (all database data will be lost)..."
        if confirm "⚠️  This will permanently delete all database data. Continue?"; then
            if docker volume rm taolie_postgres_data &> /dev/null; then
                print_success "Volume removed: taolie_postgres_data"
                ((VOLUMES_REMOVED++))
            else
                print_error "Failed to remove taolie_postgres_data volume"
            fi
        else
            print_info "Keeping taolie_postgres_data volume"
        fi
    else
        print_info "Volume taolie_postgres_data does not exist"
    fi

    # Remove agent logs volume
    if docker volume ls -q -f name=taolie_agent_logs | grep -q .; then
        print_info "Removing agent logs volume..."
        if docker volume rm taolie_agent_logs &> /dev/null; then
            print_success "Volume removed: taolie_agent_logs"
            ((VOLUMES_REMOVED++))
        else
            print_error "Failed to remove taolie_agent_logs volume"
        fi
    else
        print_info "Volume taolie_agent_logs does not exist"
    fi
else
    print_warning "Keeping data volumes (--keep-data flag set)"
    print_info "To remove volumes later, run:"
    echo "  docker volume rm taolie_postgres_data taolie_agent_logs"
fi

print_header "Step 5: Removing Docker Network"

if docker network ls -q -f name=taolie-network | grep -q .; then
    print_info "Removing Docker network..."
    if docker network rm taolie-network &> /dev/null; then
        print_success "Network removed: taolie-network"
        ((NETWORKS_REMOVED++))
    else
        print_warning "Failed to remove taolie-network (may be in use)"
    fi
else
    print_info "Network taolie-network does not exist"
fi

print_header "Step 6: Removing Configuration Files"

if [ "$KEEP_CONFIG" = false ]; then
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Removing installation directory: $INSTALL_DIR"
        if confirm "Remove configuration directory and all files?"; then
            if rm -rf "$INSTALL_DIR"; then
                print_success "Directory removed: $INSTALL_DIR"
                ((FILES_REMOVED++))
            else
                print_error "Failed to remove $INSTALL_DIR"
            fi
        else
            print_info "Keeping configuration directory"
        fi
    else
        print_info "Installation directory does not exist: $INSTALL_DIR"
    fi
else
    print_warning "Keeping configuration directory (--keep-config flag set)"
    print_info "Configuration directory: $INSTALL_DIR"
fi

print_header "Step 7: Cleaning Up Firewall Rules"

if command -v ufw &> /dev/null; then
    if confirm "Remove firewall rules for Taolie ports (2222, 7777, 8888, 9999)?"; then
        print_info "Removing firewall rules..."
        sudo ufw delete allow 2222/tcp &> /dev/null || true
        sudo ufw delete allow 7777/tcp &> /dev/null || true
        sudo ufw delete allow 8888/tcp &> /dev/null || true
        sudo ufw delete allow 9999/tcp &> /dev/null || true
        print_success "Firewall rules removed"
    else
        print_info "Keeping firewall rules"
        print_warning "To remove manually later, run:"
        echo "  sudo ufw delete allow 2222/tcp"
        echo "  sudo ufw delete allow 7777/tcp"
        echo "  sudo ufw delete allow 8888/tcp"
        echo "  sudo ufw delete allow 9999/tcp"
    fi
else
    print_info "UFW not found, skipping firewall cleanup"
fi

# Final summary
print_header "Uninstallation Complete!"

cat << EOF
${GREEN}✓ Taolie Host Agent has been successfully uninstalled!${NC}

${BLUE}Removal Summary:${NC}
  Containers removed:  $CONTAINERS_REMOVED
  Images removed:      $IMAGES_REMOVED
  Volumes removed:     $VOLUMES_REMOVED
  Networks removed:    $NETWORKS_REMOVED
  Directories removed: $FILES_REMOVED

EOF

if [ "$KEEP_DATA" = true ]; then
    cat << EOF
${YELLOW}⚠ Data Volumes Preserved:${NC}
  The following volumes were kept and still exist:
  • taolie_postgres_data (database data)
  • taolie_agent_logs (agent logs)

  To remove them manually:
    docker volume rm taolie_postgres_data taolie_agent_logs

EOF
fi

if [ "$KEEP_CONFIG" = true ]; then
    cat << EOF
${YELLOW}⚠ Configuration Directory Preserved:${NC}
  Configuration files are still at: $INSTALL_DIR

  To remove manually:
    rm -rf $INSTALL_DIR

EOF
fi

# Check for any remaining components
print_info "Checking for any remaining Taolie components..."
REMAINING=0

if docker ps -a | grep -q taolie; then
    print_warning "Some Taolie containers still exist:"
    docker ps -a | grep taolie
    ((REMAINING++))
fi

if docker images | grep -q "banadda/host-agent\|taolie"; then
    print_warning "Some Taolie images still exist:"
    docker images | grep -E "banadda/host-agent|taolie"
    ((REMAINING++))
fi

if docker volume ls | grep -q taolie; then
    print_warning "Some Taolie volumes still exist:"
    docker volume ls | grep taolie
    ((REMAINING++))
fi

if [ $REMAINING -eq 0 ]; then
    print_success "No remaining Taolie components found"
fi

cat << EOF

${BLUE}What's Next?${NC}
  • Your machine is no longer providing compute to the Taolie network
  • To reinstall, visit: https://taolie-ai.vercel.app/my-gpu
  • Or run the installer again:
    curl -fsSL https://[...]/install.sh | bash -s -- --api-key YOUR_API_KEY

${BLUE}Need Help?${NC}
  Documentation: https://taolie-ai.vercel.app/my-gpu
  Support: https://help.manus.im

EOF

print_success "Uninstallation completed successfully!"

exit 0
