#!/bin/bash
# Installation script for Hiddify Agent Traffic Manager
# Usage: bash install.sh

set -e

echo "=========================================="
echo "Hiddify Agent Traffic Manager Installer"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root - Allow but warn
if [ "$EUID" -eq 0 ]; then 
   echo -e "${YELLOW}Warning: Running as root. It's recommended to run as hiddify-panel user.${NC}"
   echo -e "${YELLOW}Continuing anyway...${NC}"
   echo ""
fi

# Check if HiddifyPanel is installed
if [ ! -d "/opt/hiddify-manager" ]; then
    echo -e "${RED}Error: HiddifyPanel not found at /opt/hiddify-manager${NC}"
    echo "Please install HiddifyPanel first."
    exit 1
fi

# Check if virtual environment exists
if [ ! -d "/opt/hiddify-manager/.venv313" ]; then
    echo -e "${RED}Error: Virtual environment not found at /opt/hiddify-manager/.venv313${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Going to HiddifyPanel directory...${NC}"
cd /opt/hiddify-manager

# Check if venv exists
if [ ! -d ".venv313" ]; then
    echo -e "${RED}Error: Virtual environment not found at /opt/hiddify-manager/.venv313${NC}"
    exit 1
fi

# Check if pip exists in venv
if [ ! -f ".venv313/bin/pip" ]; then
    echo -e "${RED}Error: pip not found in virtual environment${NC}"
    exit 1
fi

echo -e "${GREEN}Using pip from virtual environment...${NC}"
# We'll use the full path to pip from venv to avoid externally-managed-environment error
PIP_CMD="/opt/hiddify-manager/.venv313/bin/pip"

echo -e "${GREEN}Step 2: Cloning repository...${NC}"
if [ -d "hiddify-agent-traffic-manager" ]; then
    echo -e "${YELLOW}Directory exists. Updating...${NC}"
    cd hiddify-agent-traffic-manager
    git pull
else
    git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
    cd hiddify-agent-traffic-manager
fi

echo -e "${GREEN}Step 3: Installing module...${NC}"
# Use pip from venv explicitly to avoid externally-managed-environment error
echo -e "${YELLOW}Using: $PIP_CMD install -e .${NC}"
$PIP_CMD install -e .

echo -e "${GREEN}Step 4: Installation completed!${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT: Manual Integration Required${NC}"
echo ""
echo "You need to manually integrate the module with HiddifyPanel:"
echo ""
echo "1. Edit the wsgi_app.py file:"
echo "   - Package install: /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/apps/wsgi_app.py"
echo "   - Source install: /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/apps/wsgi_app.py"
echo ""
echo "2. Add these lines:"
echo "   At the top: from hiddify_agent_traffic_manager import init_app"
echo "   In create_app(): app = init_app(app)"
echo ""
echo "3. Restart services:"
echo "   sudo systemctl restart hiddify-panel"
echo "   sudo systemctl restart hiddify-panel-background-tasks"
echo ""
echo "For detailed instructions, see: INSTALL_UBUNTU.md"
echo ""
echo -e "${GREEN}Installation script completed!${NC}"

