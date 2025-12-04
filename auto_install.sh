#!/bin/bash
# Auto-install script for Hiddify Agent Traffic Manager
# This script clones the repository and installs the module automatically

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/smmnouri/hiddify-agent-traffic-manager.git"
INSTALL_DIR="/opt/hiddify-manager"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Hiddify Agent Traffic Manager${NC}"
echo -e "${BLUE}Auto Installation Script${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. It's recommended to run as hiddify-panel user.${NC}"
    echo ""
fi

# Step 1: Check if HiddifyPanel is installed
echo -e "${BLUE}Step 1: Checking HiddifyPanel installation...${NC}"
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}✗ HiddifyPanel not found at $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Please install HiddifyPanel first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ HiddifyPanel found${NC}"
echo ""

# Step 2: Clone or update repository
echo -e "${BLUE}Step 2: Getting repository...${NC}"
cd "$INSTALL_DIR"

if [ -d "hiddify-agent-traffic-manager" ]; then
    echo -e "${YELLOW}Directory exists. Updating...${NC}"
    cd hiddify-agent-traffic-manager
    git pull origin main || {
        echo -e "${YELLOW}Git pull failed, removing and re-cloning...${NC}"
        cd ..
        rm -rf hiddify-agent-traffic-manager
        git clone "$REPO_URL"
        cd hiddify-agent-traffic-manager
    }
else
    echo -e "${GREEN}Cloning repository...${NC}"
    git clone "$REPO_URL"
    cd hiddify-agent-traffic-manager
fi
echo -e "${GREEN}✓ Repository ready${NC}"
echo ""

# Step 3: Run install_complete.sh
echo -e "${BLUE}Step 3: Running installation...${NC}"
if [ ! -f "install_complete.sh" ]; then
    echo -e "${RED}✗ install_complete.sh not found${NC}"
    exit 1
fi

chmod +x install_complete.sh

# Check if running as root, warn but continue
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Running install_complete.sh as root...${NC}"
    bash install_complete.sh
else
    # Try to run as hiddify-panel user if exists
    if id "hiddify-panel" &>/dev/null; then
        echo -e "${GREEN}Running install_complete.sh as hiddify-panel user...${NC}"
        sudo -u hiddify-panel bash install_complete.sh || bash install_complete.sh
    else
        bash install_complete.sh
    fi
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Installation completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
