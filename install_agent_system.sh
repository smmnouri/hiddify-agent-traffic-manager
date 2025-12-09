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
HIDDIFY_DIR=""

# Try to find from systemd service
if [ -f "/etc/systemd/system/hiddify-panel.service" ]; then
    WORKING_DIR=$(grep "^WorkingDirectory=" /etc/systemd/system/hiddify-panel.service | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$WORKING_DIR" ] && [ -d "$WORKING_DIR" ]; then
        HIDDIFY_DIR="$WORKING_DIR"
    fi
fi

# Try common paths
if [ -z "$HIDDIFY_DIR" ]; then
    for path in "/opt/hiddify-manager/hiddify-panel" "/opt/hiddify/hiddify-panel" "/usr/local/hiddify-panel"; do
        if [ -d "$path" ] && [ -f "$path/app.py" ]; then
            HIDDIFY_DIR="$path"
            break
        fi
    done
fi

# Try to find from Python package location
if [ -z "$HIDDIFY_DIR" ]; then
    PYTHON_PATH=$(python3 -c "import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))" 2>/dev/null || echo "")
    if [ -n "$PYTHON_PATH" ] && [ -d "$PYTHON_PATH" ] && [ -f "$PYTHON_PATH/app.py" ]; then
        HIDDIFY_DIR="$PYTHON_PATH"
    fi
fi

if [ -z "$HIDDIFY_DIR" ] || [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${RED}HiddifyPanel directory not found${NC}"
    echo "Please specify the HiddifyPanel directory:"
    echo "  export HIDDIFY_DIR=/path/to/hiddify-panel"
    echo "  or edit this script and set HIDDIFY_DIR manually"
    exit 1
fi

echo -e "${GREEN}✓ Found HiddifyPanel at $HIDDIFY_DIR${NC}"

# Check if virtual environment exists
VENV_DIR=""

# Try to find venv from systemd service
if [ -f "/etc/systemd/system/hiddify-panel.service" ]; then
    EXEC_START=$(grep "^ExecStart=" /etc/systemd/system/hiddify-panel.service | cut -d'=' -f2 | cut -d' ' -f1)
    if [ -n "$EXEC_START" ] && [ -f "$EXEC_START" ]; then
        VENV_DIR=$(dirname $(dirname "$EXEC_START"))
        if [ ! -d "$VENV_DIR" ]; then
            VENV_DIR=""
        fi
    fi
fi

# Try common venv paths
if [ -z "$VENV_DIR" ]; then
    for venv_path in "$HIDDIFY_DIR/.venv313" "$HIDDIFY_DIR/.venv" "/opt/hiddify-manager/.venv313" "/opt/hiddify-manager/.venv"; do
        if [ -d "$venv_path" ] && [ -f "$venv_path/bin/activate" ]; then
            VENV_DIR="$venv_path"
            break
        fi
    done
fi

if [ -z "$VENV_DIR" ] || [ ! -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}⚠ Virtual environment not found, trying system Python${NC}"
    VENV_DIR=""
else
    echo -e "${GREEN}✓ Found virtual environment at $VENV_DIR${NC}"
fi

echo -e "${GREEN}✓ Found virtual environment at $VENV_DIR${NC}"

# Activate virtual environment if found
if [ -n "$VENV_DIR" ]; then
    source "$VENV_DIR/bin/activate"
    PYTHON_CMD="python3"
    PIP_CMD="pip"
else
    PYTHON_CMD="python3"
    PIP_CMD="pip3"
fi

# Check Python version
PYTHON_VERSION=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)
echo -e "${GREEN}✓ Python version: $PYTHON_VERSION${NC}"

# Install from source (if source directory exists)
echo ""
echo "Step 1: Checking HiddifyPanel installation..."
cd "$HIDDIFY_DIR"

# Check if this is a source directory
if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -d "hiddifypanel" ]; then
    echo "Installing from source..."
    $PIP_CMD install -e . || {
        echo -e "${YELLOW}⚠ Failed to install from source, trying pip install${NC}"
        $PIP_CMD install . || {
            echo -e "${RED}✗ Failed to install${NC}"
            exit 1
        }
    }
    echo -e "${GREEN}✓ Installed from source${NC}"
else
    echo -e "${YELLOW}⚠ Not a source directory, skipping source installation${NC}"
    echo "HiddifyPanel seems to be installed via pip"
fi

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

