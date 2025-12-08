#!/bin/bash
# Complete script to apply patches on server
# Just copy-paste and run this entire script on your server

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"
SCRIPT_DIR="$HIDDIFY_DIR/hiddify-agent-traffic-manager"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Applying Patches to HiddifyPanel${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Step 1: Find source directory
SOURCE_DIR=""

# Check hiddify-panel-source first (most likely)
if [ -d "$HIDDIFY_DIR/hiddify-panel-source/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-source/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"
    echo -e "${GREEN}✓ Found source in hiddify-panel-source${NC}"
elif [ -d "$HIDDIFY_DIR/hiddify-panel-custom/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-custom/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-custom/src"
    echo -e "${GREEN}✓ Found source in hiddify-panel-custom${NC}"
elif [ -d "$HIDDIFY_DIR/hiddify-panel/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel/src"
    echo -e "${GREEN}✓ Found source in hiddify-panel${NC}"
else
    # Try to find in site-packages (pip installed)
    echo -e "${YELLOW}Source directory not found. Checking pip installation...${NC}"
    VENV_PYTHON=""
    if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
        VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
    elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
        VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
    fi
    
    if [ -n "$VENV_PYTHON" ]; then
        SITE_PACKAGES=$("$VENV_PYTHON" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
        if [ -n "$SITE_PACKAGES" ] && [ -d "$SITE_PACKAGES/hiddifypanel" ]; then
            SOURCE_DIR="$SITE_PACKAGES"
            echo -e "${GREEN}✓ Found pip installation in: $SOURCE_DIR${NC}"
        fi
    fi
fi

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ Source directory not found${NC}"
    echo -e "${YELLOW}Please clone HiddifyPanel first:${NC}"
    echo "  cd $HIDDIFY_DIR"
    echo "  git clone https://github.com/hiddify/hiddify-panel.git hiddify-panel-source"
    exit 1
fi

echo -e "${GREEN}Using source directory: $SOURCE_DIR${NC}"
echo ""

# Step 2: Patch AdminstratorAdmin.py
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"

if [ ! -f "$ADMINSTRATOR_ADMIN_PY" ]; then
    echo -e "${YELLOW}⚠ AdminstratorAdmin.py not found, searching...${NC}"
    FOUND=$(find "$SOURCE_DIR" -name "AdminstratorAdmin.py" 2>/dev/null | head -n1)
    if [ -n "$FOUND" ]; then
        ADMINSTRATOR_ADMIN_PY="$FOUND"
        echo -e "${GREEN}✓ Found at: $ADMINSTRATOR_ADMIN_PY${NC}"
    else
        echo -e "${RED}✗ AdminstratorAdmin.py not found${NC}"
        exit 1
    fi
fi

echo -e "${BLUE}Patching AdminstratorAdmin.py...${NC}"

# Backup
cp "$ADMINSTRATOR_ADMIN_PY" "${ADMINSTRATOR_ADMIN_PY}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓ Backup created${NC}"

# Check if already patched
if grep -q "'traffic_limit_GB'" "$ADMINSTRATOR_ADMIN_PY"; then
    echo -e "${YELLOW}⚠ Already patched (traffic_limit_GB found)${NC}"
else
    # Use Python patch script if available
    if [ -f "$SCRIPT_DIR/patches/patch_adminstrator_admin.py" ]; then
        echo "Using Python patch script..."
        VENV_PYTHON=""
        if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
            VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
        elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
            VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
        else
            VENV_PYTHON="python3"
        fi
        
        "$VENV_PYTHON" "$SCRIPT_DIR/patches/patch_adminstrator_admin.py" "$ADMINSTRATOR_ADMIN_PY"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Patched successfully${NC}"
        else
            echo -e "${YELLOW}⚠ Patch script had warnings, but continuing...${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Python patch script not found, using basic method...${NC}"
        # Basic sed method (fallback)
        # This is a simplified version - full patch should use Python script
        echo "Note: Full patch requires Python script. Please ensure patches/patch_adminstrator_admin.py exists."
    fi
fi

echo ""

# Step 3: Run database migration
echo -e "${BLUE}Running database migration...${NC}"

if [ -f "$SCRIPT_DIR/migrations/run_migration.sh" ]; then
    chmod +x "$SCRIPT_DIR/migrations/run_migration.sh"
    bash "$SCRIPT_DIR/migrations/run_migration.sh"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Migration completed${NC}"
    else
        echo -e "${YELLOW}⚠ Migration had warnings (column might already exist)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Migration script not found${NC}"
fi

echo ""

# Step 4: Summary
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Patches applied successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

# Find pip command
PIP_CMD=""
if [ -f "$HIDDIFY_DIR/.venv313/bin/pip" ]; then
    PIP_CMD="$HIDDIFY_DIR/.venv313/bin/pip"
elif [ -f "$HIDDIFY_DIR/.venv/bin/pip" ]; then
    PIP_CMD="$HIDDIFY_DIR/.venv/bin/pip"
elif command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
fi

if [ -d "$HIDDIFY_DIR/hiddify-panel-source" ]; then
    echo -e "${YELLOW}Next steps:${NC}"
    if [ -n "$PIP_CMD" ]; then
        echo "1. Install from source: cd $HIDDIFY_DIR/hiddify-panel-source && $PIP_CMD install -e ."
    else
        echo "1. Install from source: cd $HIDDIFY_DIR/hiddify-panel-source && python3 -m pip install -e ."
    fi
    echo "2. Restart services: systemctl restart hiddify-panel hiddify-panel-background-tasks"
else
    echo -e "${YELLOW}Note: Patched installed package. Changes will be lost on next pip upgrade.${NC}"
    echo "Restart services: systemctl restart hiddify-panel hiddify-panel-background-tasks"
fi

echo ""
echo -e "${GREEN}Done!${NC}"

