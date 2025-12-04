#!/bin/bash
# Automatic installation script for Hiddify Agent Traffic Manager
# This script installs the module and integrates it with HiddifyPanel automatically

set -e

echo "=========================================="
echo "Hiddify Agent Traffic Manager"
echo "Automatic Installation Script"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
HIDDIFY_DIR="/opt/hiddify-manager"
VENV_DIR="$HIDDIFY_DIR/.venv313"
MODULE_DIR="$HIDDIFY_DIR/hiddify-agent-traffic-manager"
PIP_CMD="$VENV_DIR/bin/pip"
PYTHON_CMD="$VENV_DIR/bin/python"

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

if [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${RED}Error: HiddifyPanel not found at $HIDDIFY_DIR${NC}"
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}Error: Virtual environment not found at $VENV_DIR${NC}"
    exit 1
fi

if [ ! -f "$PIP_CMD" ]; then
    echo -e "${RED}Error: pip not found in virtual environment${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Step 2: Clone or update repository
echo -e "${BLUE}Step 2: Cloning/updating repository...${NC}"

cd "$HIDDIFY_DIR"

if [ -d "$MODULE_DIR" ]; then
    echo -e "${YELLOW}Directory exists. Updating...${NC}"
    cd "$MODULE_DIR"
    git pull || echo -e "${YELLOW}Warning: git pull failed, continuing...${NC}"
else
    echo -e "${GREEN}Cloning repository...${NC}"
    git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
    cd "$MODULE_DIR"
fi

echo -e "${GREEN}✓ Repository ready${NC}"
echo ""

# Step 3: Install module
echo -e "${BLUE}Step 3: Installing module...${NC}"

if $PIP_CMD install -e .; then
    echo -e "${GREEN}✓ Module installed successfully${NC}"
else
    echo -e "${YELLOW}Trying alternative method...${NC}"
    if $PYTHON_CMD -m pip install -e .; then
        echo -e "${GREEN}✓ Module installed successfully (alternative method)${NC}"
    else
        echo -e "${RED}✗ Installation failed!${NC}"
        echo -e "${YELLOW}Trying manual copy method...${NC}"
        
        # Manual copy as last resort
        MODULE_NAME="hiddify_agent_traffic_manager"
        SITE_PACKAGES="$VENV_DIR/lib/python3.13/site-packages"
        
        if [ -d "$SITE_PACKAGES" ]; then
            cp -r "$MODULE_NAME" "$SITE_PACKAGES/" 2>/dev/null || {
                echo -e "${RED}Manual copy also failed${NC}"
                exit 1
            }
            echo -e "${GREEN}✓ Module copied manually${NC}"
        else
            echo -e "${RED}Could not find site-packages directory${NC}"
            exit 1
        fi
    fi
fi

echo ""

# Step 4: Verify installation
echo -e "${BLUE}Step 4: Verifying installation...${NC}"

if $PYTHON_CMD -c "import hiddify_agent_traffic_manager; print('OK')" 2>/dev/null; then
    echo -e "${GREEN}✓ Module verification successful${NC}"
else
    echo -e "${RED}✗ Module verification failed!${NC}"
    echo -e "${YELLOW}Module may not be properly installed${NC}"
    exit 1
fi

echo ""

# Step 5: Find and edit wsgi_app.py
echo -e "${BLUE}Step 5: Integrating with HiddifyPanel...${NC}"

# Find wsgi_app.py
WSGI_APP_PATHS=(
    "$VENV_DIR/lib/python3.13/site-packages/hiddifypanel/apps/wsgi_app.py"
    "$VENV_DIR/lib/python3.12/site-packages/hiddifypanel/apps/wsgi_app.py"
    "$VENV_DIR/lib/python3.11/site-packages/hiddifypanel/apps/wsgi_app.py"
    "$HIDDIFY_DIR/hiddify-panel/src/hiddifypanel/apps/wsgi_app.py"
)

WSGI_APP_FILE=""

for path in "${WSGI_APP_PATHS[@]}"; do
    if [ -f "$path" ]; then
        WSGI_APP_FILE="$path"
        echo -e "${GREEN}Found wsgi_app.py at: $path${NC}"
        break
    fi
done

if [ -z "$WSGI_APP_FILE" ]; then
    echo -e "${YELLOW}wsgi_app.py not found in common locations. Searching...${NC}"
    WSGI_APP_FILE=$(find "$VENV_DIR" -name "wsgi_app.py" -type f 2>/dev/null | head -n1)
    
    if [ -z "$WSGI_APP_FILE" ]; then
        WSGI_APP_FILE=$(find "$HIDDIFY_DIR" -name "wsgi_app.py" -type f 2>/dev/null | head -n1)
    fi
fi

if [ -z "$WSGI_APP_FILE" ] || [ ! -f "$WSGI_APP_FILE" ]; then
    echo -e "${RED}✗ Could not find wsgi_app.py${NC}"
    echo -e "${YELLOW}Please manually edit wsgi_app.py and add:${NC}"
    echo "  from hiddify_agent_traffic_manager import init_app"
    echo "  app = init_app(app)  # in create_app()"
    exit 1
fi

# Backup original file
BACKUP_FILE="${WSGI_APP_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$WSGI_APP_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Check if already integrated
if grep -q "hiddify_agent_traffic_manager" "$WSGI_APP_FILE"; then
    echo -e "${YELLOW}Module already integrated in wsgi_app.py${NC}"
    echo -e "${GREEN}✓ Integration check passed${NC}"
else
    echo -e "${GREEN}Adding integration code...${NC}"
    
    # Add import at the top (after other imports)
    if ! grep -q "from hiddify_agent_traffic_manager import init_app" "$WSGI_APP_FILE"; then
        # Find a good place to add import (after flask or hiddifypanel imports)
        if grep -q "^from flask" "$WSGI_APP_FILE" || grep -q "^import flask" "$WSGI_APP_FILE"; then
            # Add after flask imports
            sed -i '/^from flask\|^import flask/a from hiddify_agent_traffic_manager import init_app' "$WSGI_APP_FILE"
        elif grep -q "^import hiddifypanel" "$WSGI_APP_FILE" || grep -q "^from hiddifypanel" "$WSGI_APP_FILE"; then
            # Add after hiddifypanel imports
            sed -i '/^import hiddifypanel\|^from hiddifypanel/a from hiddify_agent_traffic_manager import init_app' "$WSGI_APP_FILE"
        else
            # Add at the beginning of imports section
            sed -i '1a from hiddify_agent_traffic_manager import init_app' "$WSGI_APP_FILE"
        fi
        echo -e "${GREEN}✓ Import added${NC}"
    fi
    
    # Add init_app call in create_app function
    if grep -q "def create_app" "$WSGI_APP_FILE"; then
        # Check if init_app is already called
        if ! grep -q "init_app(app)" "$WSGI_APP_FILE"; then
            # Find the return statement in create_app and add init_app before it
            # This is a bit tricky, so we'll use a Python script for safety
            $PYTHON_CMD << 'PYTHON_SCRIPT'
import re
import sys

file_path = sys.argv[1]

with open(file_path, 'r') as f:
    content = f.read()

# Check if already integrated
if 'init_app(app)' in content:
    print("Already integrated")
    sys.exit(0)

# Find create_app function and add init_app before return
pattern = r'(def create_app\([^)]*\):.*?)(\n\s+return\s+app)'
replacement = r'\1\n    # Initialize agent traffic manager\n    app = init_app(app)\2'

new_content = re.sub(pattern, replacement, content, flags=re.DOTALL)

if new_content != content:
    with open(file_path, 'w') as f:
        f.write(new_content)
    print("Integration added successfully")
else:
    # Fallback: add before last return
    lines = content.split('\n')
    for i in range(len(lines) - 1, -1, -1):
        if 'return app' in lines[i] and 'def create_app' in '\n'.join(lines[:i]):
            indent = len(lines[i]) - len(lines[i].lstrip())
            lines.insert(i, ' ' * indent + '# Initialize agent traffic manager')
            lines.insert(i + 1, ' ' * indent + 'app = init_app(app)')
            break
    
    with open(file_path, 'w') as f:
        f.write('\n'.join(lines))
    print("Integration added (fallback method)")
PYTHON_SCRIPT
            "$WSGI_APP_FILE"
            
            echo -e "${GREEN}✓ Integration code added${NC}"
        else
            echo -e "${GREEN}✓ Integration already present${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: create_app function not found. Manual integration required.${NC}"
    fi
fi

echo ""

# Step 6: Restart services
echo -e "${BLUE}Step 6: Restarting services...${NC}"

if systemctl is-active --quiet hiddify-panel 2>/dev/null; then
    echo -e "${GREEN}Restarting hiddify-panel...${NC}"
    systemctl restart hiddify-panel || sudo systemctl restart hiddify-panel
    echo -e "${GREEN}✓ hiddify-panel restarted${NC}"
else
    echo -e "${YELLOW}hiddify-panel service not found or not active${NC}"
fi

if systemctl is-active --quiet hiddify-panel-background-tasks 2>/dev/null; then
    echo -e "${GREEN}Restarting hiddify-panel-background-tasks...${NC}"
    systemctl restart hiddify-panel-background-tasks || sudo systemctl restart hiddify-panel-background-tasks
    echo -e "${GREEN}✓ hiddify-panel-background-tasks restarted${NC}"
else
    echo -e "${YELLOW}hiddify-panel-background-tasks service not found or not active${NC}"
fi

echo ""

# Step 7: Final verification
echo -e "${BLUE}Step 7: Final verification...${NC}"

sleep 2

if $PYTHON_CMD -c "import hiddify_agent_traffic_manager; print('OK')" 2>/dev/null; then
    echo -e "${GREEN}✓ Module is accessible${NC}"
else
    echo -e "${RED}✗ Module verification failed${NC}"
fi

echo ""
echo "=========================================="
echo -e "${GREEN}Installation completed!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Check the panel logs: tail -f /opt/hiddify-manager/log/system/panel.log"
echo "2. Test the API: curl http://localhost:9000/api/v1/agent-traffic/agents/traffic"
echo "3. Access the admin panel and check if agent traffic management is available"
echo ""
echo -e "${YELLOW}Note: If you encounter any issues, check the backup file:${NC}"
echo "  $BACKUP_FILE"
echo ""

