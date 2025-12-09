#!/bin/bash
# Update repository and install

set -e

echo "=========================================="
echo "Updating and Installing"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run as root${NC}"
    exit 1
fi

# Go to existing directory or clone
if [ -d "/root/hiddify-agent-traffic-manager" ]; then
    echo "Updating existing repository..."
    cd /root/hiddify-agent-traffic-manager
    git pull origin main || {
        echo -e "${YELLOW}⚠ Could not pull, using existing files${NC}"
    }
else
    echo "Cloning repository..."
    cd /root
    git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
    cd hiddify-agent-traffic-manager
fi

echo -e "${GREEN}✓ Repository ready${NC}"

# Check which script to run
echo ""
echo "Available installation scripts:"
echo "1. install_hiddify_with_agent.sh - Full installation (HiddifyPanel + Agent)"
echo "2. install_agent_system.sh - Agent system only (if HiddifyPanel exists)"

if [ -f "install_hiddify_with_agent.sh" ]; then
    echo ""
    echo "Running full installation..."
    chmod +x install_hiddify_with_agent.sh
    ./install_hiddify_with_agent.sh
else
    echo -e "${RED}✗ install_hiddify_with_agent.sh not found${NC}"
    echo "Please run: git pull origin main"
    exit 1
fi

