#!/bin/bash
# One-line installer for HiddifyPanel with Agent Traffic Management
# Usage: bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
# Or: bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh) YOUR_USERNAME YOUR_REPO_NAME

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - می‌تواند از command line هم دریافت شود
GITHUB_USER="${1:-smmnouri}"
CUSTOM_REPO="${2:-hiddify-panel-custom}"
HIDDIFY_DIR="/opt/hiddify-manager"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}HiddifyPanel with Agent Traffic Management${NC}"
echo -e "${BLUE}Installer${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Step 1: Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}✗ Please run as root${NC}"
    exit 1
fi

# Step 2: Check if Hiddify-Manager exists
# First, verify the directory actually exists
if [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${YELLOW}Hiddify-Manager not found. Installing Hiddify-Manager first...${NC}"
    echo -e "${YELLOW}This may take several minutes. Please wait...${NC}"
    
    # Try the official installation URL
    if ! bash <(curl -s https://i.hiddify.com/release); then
        echo -e "${YELLOW}First method failed, trying alternative...${NC}"
        if ! bash <(curl -s https://get.hiddify.com/install.sh); then
            echo -e "${RED}✗ Failed to install Hiddify-Manager${NC}"
            echo -e "${YELLOW}Please install Hiddify-Manager manually first:${NC}"
            echo -e "${YELLOW}  bash <(curl -s https://i.hiddify.com/release)${NC}"
            exit 1
        fi
    fi
    
    # Wait and verify installation - Hiddify installation can take 5-10 minutes
    echo -e "${YELLOW}Waiting for Hiddify-Manager installation to complete...${NC}"
    echo -e "${YELLOW}This may take 5-10 minutes. Please be patient...${NC}"
    for i in {1..60}; do
        sleep 5
        if [ -d "$HIDDIFY_DIR" ] && [ -n "$(ls -A "$HIDDIFY_DIR" 2>/dev/null)" ]; then
            break
        fi
        if [ $((i % 6)) -eq 0 ]; then
            echo -e "${YELLOW}Still waiting... ($((i*5)) seconds elapsed)${NC}"
        fi
    done
fi

# Final verification - check if directory exists and is accessible
if [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${RED}✗ Hiddify-Manager directory not found: $HIDDIFY_DIR${NC}"
    echo -e "${YELLOW}The installation may still be in progress.${NC}"
    echo -e "${YELLOW}Please wait a few more minutes and check manually:${NC}"
    echo -e "${YELLOW}  ls -la /opt/hiddify-manager${NC}"
    echo -e "${YELLOW}Or install Hiddify-Manager manually:${NC}"
    echo -e "${YELLOW}  bash <(curl -s https://i.hiddify.com/release)${NC}"
    exit 1
fi

# Verify we can actually access the directory
if ! cd "$HIDDIFY_DIR" 2>/dev/null; then
    echo -e "${RED}✗ Cannot access Hiddify-Manager directory: $HIDDIFY_DIR${NC}"
    echo -e "${YELLOW}Please check permissions and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Hiddify-Manager found at $HIDDIFY_DIR${NC}"
echo ""

# Step 3: Setup custom repository
echo -e "${BLUE}Step 1: Setting up custom HiddifyPanel repository...${NC}"

CUSTOM_REPO_DIR="$HIDDIFY_DIR/hiddify-panel-custom"
REPO_URL="https://github.com/$GITHUB_USER/$CUSTOM_REPO.git"

if [ -d "$CUSTOM_REPO_DIR" ]; then
    echo -e "${YELLOW}Custom repo exists, updating...${NC}"
    cd "$CUSTOM_REPO_DIR"
    git pull origin main || git pull origin master || echo "Could not pull"
else
    echo -e "${GREEN}Cloning custom repository...${NC}"
    # Verify directory exists before cd
    if [ ! -d "$HIDDIFY_DIR" ]; then
        echo -e "${RED}✗ Hiddify-Manager directory not found: $HIDDIFY_DIR${NC}"
        echo -e "${YELLOW}Please install Hiddify-Manager first:${NC}"
        echo -e "${YELLOW}  bash <(curl -s https://i.hiddify.com/release)${NC}"
        exit 1
    fi
    
    # Change to directory with error handling
    if ! cd "$HIDDIFY_DIR"; then
        echo -e "${RED}✗ Cannot access $HIDDIFY_DIR${NC}"
        echo -e "${YELLOW}Please check permissions${NC}"
        exit 1
    fi
    if ! git clone "$REPO_URL" hiddify-panel-custom 2>/dev/null; then
        echo -e "${RED}✗ Failed to clone repository${NC}"
        echo -e "${YELLOW}Creating repository with patches...${NC}"
        
        # Clone original and apply patches
        git clone https://github.com/hiddify/HiddifyPanel.git hiddify-panel-custom
        cd hiddify-panel-custom
        
        # Download and apply patches
        echo -e "${BLUE}Applying agent traffic management patches...${NC}"
        if ! curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/apply_to_source.sh | bash; then
            echo -e "${YELLOW}Could not apply patches automatically${NC}"
            echo -e "${YELLOW}Please run setup_custom_repo.sh manually${NC}"
        fi
        
        # Set remote
        git remote set-url origin "$REPO_URL" 2>/dev/null || git remote add origin "$REPO_URL"
    fi
fi

echo -e "${GREEN}✓ Repository ready${NC}"
echo ""

# Step 4: Install from custom repo
echo -e "${BLUE}Step 2: Installing from custom repository...${NC}"

cd "$CUSTOM_REPO_DIR"

# Check if it's a proper HiddifyPanel structure
if [ ! -d "src" ] && [ -d "hiddifypanel" ]; then
    # It's the source structure
    SOURCE_DIR="$CUSTOM_REPO_DIR"
elif [ -d "src" ]; then
    SOURCE_DIR="$CUSTOM_REPO_DIR/src"
else
    echo -e "${RED}✗ Invalid repository structure${NC}"
    exit 1
fi

# Install using pip
VENV_DIR="$HIDDIFY_DIR/.venv313"
if [ -d "$VENV_DIR" ]; then
    PIP_CMD="$VENV_DIR/bin/pip"
    if [ ! -f "$PIP_CMD" ]; then
        PIP_CMD="$VENV_DIR/bin/python -m pip"
    fi
    
    echo -e "${BLUE}Installing from source...${NC}"
    cd "$SOURCE_DIR"
    $PIP_CMD install -e . || {
        echo -e "${YELLOW}pip install failed, trying alternative...${NC}"
        cd "$CUSTOM_REPO_DIR"
        if [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
            $PIP_CMD install -e .
        else
            echo -e "${YELLOW}Manual installation required${NC}"
        fi
    }
    
    echo -e "${GREEN}✓ Installed from custom repository${NC}"
else
    echo -e "${YELLOW}⚠ Virtual environment not found${NC}"
fi

echo ""

# Step 5: Database migration
echo -e "${BLUE}Step 3: Running database migration...${NC}"

PYTHON_CMD="$VENV_DIR/bin/python"
if [ ! -f "$PYTHON_CMD" ]; then
    PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | head -n1)
fi

if [ -f "$PYTHON_CMD" ]; then
    $PYTHON_CMD << 'PYTHON_SCRIPT'
import sys
sys.path.insert(0, '/opt/hiddify-manager/hiddify-panel-custom/src')

from hiddifypanel.database import db
from sqlalchemy import inspect

try:
    inspector = inspect(db.engine)
    columns = [col['name'] for col in inspector.get_columns('admin_user')]
    
    if 'traffic_limit' not in columns:
        print("Adding traffic_limit column...")
        db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
        db.session.commit()
        print("✓ Column added successfully")
    else:
        print("✓ Column already exists")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
PYTHON_SCRIPT

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database migration completed${NC}"
    else
        echo -e "${YELLOW}⚠ Database migration had issues${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Python not found, skipping migration${NC}"
fi

echo ""

# Step 6: Restart services
echo -e "${BLUE}Step 4: Restarting services...${NC}"

if systemctl is-active --quiet hiddify-panel; then
    systemctl restart hiddify-panel
    echo -e "${GREEN}✓ hiddify-panel restarted${NC}"
fi

if systemctl is-active --quiet hiddify-panel-background-tasks; then
    systemctl restart hiddify-panel-background-tasks
    echo -e "${GREEN}✓ hiddify-panel-background-tasks restarted${NC}"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Installation completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Repository: https://github.com/$GITHUB_USER/$CUSTOM_REPO${NC}"
echo -e "${YELLOW}Custom source: $CUSTOM_REPO_DIR${NC}"
echo ""
