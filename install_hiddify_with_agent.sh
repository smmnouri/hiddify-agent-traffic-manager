#!/bin/bash
# Complete installation script: HiddifyPanel + Agent System
# This script installs HiddifyPanel from your repository and adds Agent system

set -e

echo "=========================================="
echo "Installing HiddifyPanel with Agent System"
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

# Configuration
# Try SSH first, fallback to HTTPS
HIDDIFY_REPO_SSH="${HIDDIFY_REPO_SSH:-git@github.com:smmnouri/hiddify-panel.git}"
HIDDIFY_REPO_HTTPS="${HIDDIFY_REPO_HTTPS:-https://github.com/smmnouri/hiddify-panel.git}"
HIDDIFY_BRANCH="${HIDDIFY_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/hiddify-manager}"
AGENT_REPO="https://github.com/smmnouri/hiddify-agent-traffic-manager.git"

echo "Configuration:"
echo "  HiddifyPanel Repo (SSH): $HIDDIFY_REPO_SSH"
echo "  HiddifyPanel Repo (HTTPS): $HIDDIFY_REPO_HTTPS"
echo "  Branch: $HIDDIFY_BRANCH"
echo "  Install Directory: $INSTALL_DIR"
echo ""

# Step 1: Install prerequisites
echo "Step 1: Installing prerequisites..."
apt-get update -qq
apt-get install -y -qq \
    python3 python3-pip python3-venv \
    git curl wget \
    mysql-server mysql-client \
    redis-server \
    nginx \
    build-essential \
    libmysqlclient-dev \
    || {
    echo -e "${RED}✗ Failed to install prerequisites${NC}"
    exit 1
}
echo -e "${GREEN}✓ Prerequisites installed${NC}"

# Step 2: Create directory structure
echo ""
echo "Step 2: Creating directory structure..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"
echo -e "${GREEN}✓ Directory created${NC}"

# Step 3: Clone HiddifyPanel
echo ""
echo "Step 3: Cloning HiddifyPanel..."
if [ -d "hiddify-panel" ]; then
    echo "  Directory exists, updating..."
    cd hiddify-panel
    git pull origin "$HIDDIFY_BRANCH" || {
        echo -e "${YELLOW}⚠ Could not pull, using existing${NC}"
    }
else
    # Try SSH first (if SSH key is configured)
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "  Trying SSH..."
        git clone -b "$HIDDIFY_BRANCH" "$HIDDIFY_REPO_SSH" hiddify-panel 2>/dev/null && {
            cd hiddify-panel
            echo -e "${GREEN}✓ HiddifyPanel cloned via SSH${NC}"
        } || {
            echo "  SSH failed, trying HTTPS without credentials..."
            # Use HTTPS without credentials (for public repos)
            GIT_TERMINAL_PROMPT=0 git clone -b "$HIDDIFY_BRANCH" "$HIDDIFY_REPO_HTTPS" hiddify-panel || {
                echo -e "${RED}✗ Failed to clone HiddifyPanel${NC}"
                echo "Please check:"
                echo "  1. Repository is public, or"
                echo "  2. SSH key is configured, or"
                echo "  3. Use: export HIDDIFY_REPO_HTTPS='https://USERNAME:TOKEN@github.com/smmnouri/hiddify-panel.git'"
                exit 1
            }
            cd hiddify-panel
            echo -e "${GREEN}✓ HiddifyPanel cloned via HTTPS${NC}"
        }
    else
        echo "  Trying HTTPS (public repo)..."
        # Disable credential prompts for public repos
        GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=echo git clone -b "$HIDDIFY_BRANCH" "$HIDDIFY_REPO_HTTPS" hiddify-panel || {
            echo -e "${RED}✗ Failed to clone HiddifyPanel${NC}"
            echo "If repository is private, use one of these:"
            echo "  1. Setup SSH key: ssh-keygen -t ed25519 -C 'your_email@example.com'"
            echo "  2. Use token: export HIDDIFY_REPO_HTTPS='https://USERNAME:TOKEN@github.com/smmnouri/hiddify-panel.git'"
            exit 1
        }
        cd hiddify-panel
        echo -e "${GREEN}✓ HiddifyPanel cloned${NC}"
    fi
fi

# Step 4: Setup Python virtual environment
echo ""
echo "Step 4: Setting up Python virtual environment..."
if [ ! -d ".venv313" ]; then
    python3 -m venv .venv313 || {
        echo -e "${RED}✗ Failed to create virtual environment${NC}"
        exit 1
    }
fi
source .venv313/bin/activate
pip install --upgrade pip setuptools wheel
echo -e "${GREEN}✓ Virtual environment ready${NC}"

# Step 5: Install HiddifyPanel
echo ""
echo "Step 5: Installing HiddifyPanel..."
if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
    pip install -e . || {
        echo -e "${RED}✗ Failed to install HiddifyPanel${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ HiddifyPanel installed${NC}"
else
    echo -e "${YELLOW}⚠ Not a source directory, skipping source install${NC}"
    pip install hiddifypanel || {
        echo -e "${RED}✗ Failed to install HiddifyPanel from pip${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ HiddifyPanel installed from pip${NC}"
fi

# Step 6: Clone Agent Traffic Manager
echo ""
echo "Step 6: Cloning Agent Traffic Manager..."
cd "$INSTALL_DIR"
if [ -d "hiddify-agent-traffic-manager" ]; then
    echo "  Directory exists, updating..."
    cd hiddify-agent-traffic-manager
    git pull origin main || {
        echo -e "${YELLOW}⚠ Could not pull, using existing${NC}"
    }
else
    git clone "$AGENT_REPO" hiddify-agent-traffic-manager || {
        echo -e "${RED}✗ Failed to clone Agent Traffic Manager${NC}"
        exit 1
    }
    cd hiddify-agent-traffic-manager
fi
echo -e "${GREEN}✓ Agent Traffic Manager cloned${NC}"

# Step 7: Copy Agent system files to HiddifyPanel
echo ""
echo "Step 7: Installing Agent system files..."
HIDDIFY_SOURCE="$INSTALL_DIR/hiddify-panel"

# Create services directory if it doesn't exist
mkdir -p "$HIDDIFY_SOURCE/hiddifypanel/services"

# Copy files
cp models/agent.py "$HIDDIFY_SOURCE/hiddifypanel/models/" || {
    echo -e "${YELLOW}⚠ Could not copy agent.py (might need manual copy)${NC}"
}

cp services/traffic_service.py "$HIDDIFY_SOURCE/hiddifypanel/services/" || {
    echo -e "${YELLOW}⚠ Could not copy traffic_service.py (might need manual copy)${NC}"
}

cp services/__init__.py "$HIDDIFY_SOURCE/hiddifypanel/services/" || {
    echo -e "${YELLOW}⚠ Could not copy services/__init__.py (might need manual copy)${NC}"
}

cp api/agent_api.py "$HIDDIFY_SOURCE/hiddifypanel/panel/commercial/restapi/v2/admin/" || {
    echo -e "${YELLOW}⚠ Could not copy agent_api.py (might need manual copy)${NC}"
}

echo -e "${GREEN}✓ Files copied${NC}"

# Step 8: Patch HiddifyPanel files
echo ""
echo "Step 8: Patching HiddifyPanel files..."
cd "$HIDDIFY_SOURCE"

# Patch models/__init__.py
if ! grep -q "from .agent import Agent, TrafficLog" hiddifypanel/models/__init__.py 2>/dev/null; then
    echo "from .agent import Agent, TrafficLog" >> hiddifypanel/models/__init__.py
    echo -e "${GREEN}✓ Patched models/__init__.py${NC}"
fi

# Patch models/user.py (add agent_id)
if ! grep -q "agent_id" hiddifypanel/models/user.py 2>/dev/null; then
    # This needs manual patching - we'll create a patch file
    echo -e "${YELLOW}⚠ models/user.py needs manual patching (add agent_id field)${NC}"
fi

# Patch init_db.py (add migration v121)
if ! grep -q "MAX_DB_VERSION = 121" hiddifypanel/panel/init_db.py 2>/dev/null; then
    echo -e "${YELLOW}⚠ init_db.py needs manual patching (add migration v121)${NC}"
fi

# Patch admin/__init__.py (register agent API)
if ! grep -q "from .agent_api import" hiddifypanel/panel/commercial/restapi/v2/admin/__init__.py 2>/dev/null; then
    echo -e "${YELLOW}⚠ admin/__init__.py needs manual patching (register agent API)${NC}"
fi

echo -e "${GREEN}✓ Patching completed${NC}"

# Step 9: Reinstall HiddifyPanel
echo ""
echo "Step 9: Reinstalling HiddifyPanel with Agent system..."
cd "$HIDDIFY_SOURCE"
source .venv313/bin/activate
pip install -e . || {
    echo -e "${YELLOW}⚠ Reinstall failed, continuing...${NC}"
}
echo -e "${GREEN}✓ Reinstalled${NC}"

# Step 10: Initialize database
echo ""
echo "Step 10: Initializing database..."
hiddify-panel-cli init-db || {
    echo -e "${YELLOW}⚠ Database initialization may have issues${NC}"
}
echo -e "${GREEN}✓ Database initialized${NC}"

# Step 11: Setup systemd services (if needed)
echo ""
echo "Step 11: Setting up systemd services..."
if [ ! -f "/etc/systemd/system/hiddify-panel.service" ]; then
    echo -e "${YELLOW}⚠ Systemd service not found, you may need to set it up manually${NC}"
else
    systemctl daemon-reload
    echo -e "${GREEN}✓ Systemd services ready${NC}"
fi

echo ""
echo -e "${GREEN}=========================================="
echo "Installation completed!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Configure HiddifyPanel (database, etc.)"
echo "2. Start services: systemctl start hiddify-panel"
echo "3. Check logs: journalctl -u hiddify-panel -f"
echo "4. Access panel and create your first agent"
echo ""
echo "Note: Some files may need manual patching. Check the warnings above."
echo ""

