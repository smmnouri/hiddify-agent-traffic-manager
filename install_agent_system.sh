#!/bin/bash
# Script to install Agent/Reseller system in HiddifyPanel

set -e

echo "=========================================="
echo "Installing Agent/Reseller System"
echo "=========================================="

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

# Find HiddifyPanel directory
HIDDIFY_DIR="/opt/hiddify-manager/hiddify-panel"
if [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${RED}HiddifyPanel directory not found at $HIDDIFY_DIR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found HiddifyPanel at $HIDDIFY_DIR${NC}"

# Check if virtual environment exists
VENV_DIR="$HIDDIFY_DIR/.venv313"
if [ ! -d "$VENV_DIR" ]; then
    VENV_DIR="$HIDDIFY_DIR/.venv"
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${RED}Virtual environment not found${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Found virtual environment at $VENV_DIR${NC}"

# Activate virtual environment
source "$VENV_DIR/bin/activate"

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "${GREEN}✓ Python version: $PYTHON_VERSION${NC}"

# Install from source
echo ""
echo "Step 1: Installing from source..."
cd "$HIDDIFY_DIR"
pip install -e . || {
    echo -e "${RED}✗ Failed to install from source${NC}"
    exit 1
}
echo -e "${GREEN}✓ Installed from source${NC}"

# Run database migration
echo ""
echo "Step 2: Running database migration..."
hiddify-panel-cli init-db || {
    echo -e "${YELLOW}⚠ Migration may have already run${NC}"
}

# Check database version
echo ""
echo "Step 3: Checking database version..."
DB_VERSION=$(hiddify-panel-cli get-config db_version 2>/dev/null || echo "unknown")
echo "Database version: $DB_VERSION"

if [ "$DB_VERSION" != "unknown" ] && [ "$DB_VERSION" -ge 121 ]; then
    echo -e "${GREEN}✓ Database version is up to date${NC}"
else
    echo -e "${YELLOW}⚠ Database version may need update${NC}"
fi

# Restart services
echo ""
echo "Step 4: Restarting services..."
systemctl restart hiddify-panel || {
    echo -e "${YELLOW}⚠ Failed to restart hiddify-panel service${NC}"
}

systemctl restart hiddify-panel-background-tasks || {
    echo -e "${YELLOW}⚠ Failed to restart hiddify-panel-background-tasks service${NC}"
}

# Check service status
echo ""
echo "Step 5: Checking service status..."
sleep 2
if systemctl is-active --quiet hiddify-panel; then
    echo -e "${GREEN}✓ hiddify-panel service is running${NC}"
else
    echo -e "${RED}✗ hiddify-panel service is not running${NC}"
    echo "Check logs with: journalctl -u hiddify-panel -n 50"
fi

# Verify installation
echo ""
echo "Step 6: Verifying installation..."
python3 -c "from hiddifypanel.models import Agent; print('✓ Agent model imported successfully')" || {
    echo -e "${RED}✗ Failed to import Agent model${NC}"
    exit 1
}

python3 -c "from hiddifypanel.services.traffic_service import update_agent_traffic; print('✓ Traffic service imported successfully')" || {
    echo -e "${RED}✗ Failed to import traffic service${NC}"
    exit 1
}

echo ""
echo -e "${GREEN}=========================================="
echo "Installation completed successfully!"
echo "==========================================${NC}"
echo ""
echo "Next steps:"
echo "1. Read AGENT_SYSTEM_README.md for usage instructions"
echo "2. Create your first agent using the API or Python"
echo "3. Check API endpoints at /api/v2/admin/agent/"
echo ""

