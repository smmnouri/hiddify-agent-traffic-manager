#!/bin/bash
# Complete installation script for Hiddify Agent Traffic Manager
# This script does everything: clone, install, integrate, and restart

set -e

echo "=========================================="
echo "Hiddify Agent Traffic Manager"
echo "Complete Installation Script"
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
REPO_URL="https://github.com/smmnouri/hiddify-agent-traffic-manager.git"

# Step 1: Check prerequisites
echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

if [ ! -d "$HIDDIFY_DIR" ]; then
    echo -e "${RED}Error: HiddifyPanel not found at $HIDDIFY_DIR${NC}"
    echo "Please install HiddifyPanel first."
    exit 1
fi

if [ ! -d "$VENV_DIR" ]; then
    echo -e "${RED}Error: Virtual environment not found at $VENV_DIR${NC}"
    exit 1
fi

# Find Python
PYTHON_CMD=""
if [ -f "$VENV_DIR/bin/python" ]; then
    PYTHON_CMD="$VENV_DIR/bin/python"
elif [ -f "$VENV_DIR/bin/python3" ]; then
    PYTHON_CMD="$VENV_DIR/bin/python3"
else
    PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | head -n1)
    if [ -z "$PYTHON_CMD" ]; then
        PYTHON_CMD=$(which python3 2>/dev/null || which python 2>/dev/null)
    fi
fi

if [ -z "$PYTHON_CMD" ] || [ ! -f "$PYTHON_CMD" ]; then
    echo -e "${RED}Error: Python not found${NC}"
    exit 1
fi

echo -e "${GREEN}Python found: $($PYTHON_CMD --version 2>&1)${NC}"
echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Step 2: Clone or update repository
echo -e "${BLUE}Step 2: Getting repository...${NC}"

cd "$HIDDIFY_DIR"

if [ -d "$MODULE_DIR" ]; then
    echo -e "${YELLOW}Directory exists. Updating...${NC}"
    cd "$MODULE_DIR"
    git pull || echo -e "${YELLOW}Warning: git pull failed, continuing with existing files...${NC}"
else
    echo -e "${GREEN}Cloning repository...${NC}"
    git clone "$REPO_URL" "$MODULE_DIR" || {
        echo -e "${RED}Failed to clone repository${NC}"
        exit 1
    }
    cd "$MODULE_DIR"
fi

echo -e "${GREEN}✓ Repository ready${NC}"
echo ""

# Step 3: Install pip if needed
echo -e "${BLUE}Step 3: Checking pip...${NC}"

if ! $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
    echo -e "${YELLOW}pip not found, installing pip...${NC}"
    
    # Try ensurepip first
    if $PYTHON_CMD -m ensurepip --upgrade --default-pip 2>&1; then
        echo -e "${GREEN}✓ pip installed via ensurepip${NC}"
    else
        echo -e "${YELLOW}ensurepip failed, trying get-pip.py...${NC}"
        curl -sSL https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
        if $PYTHON_CMD /tmp/get-pip.py 2>&1; then
            echo -e "${GREEN}✓ pip installed via get-pip.py${NC}"
            rm -f /tmp/get-pip.py
        else
            echo -e "${RED}✗ Failed to install pip${NC}"
            echo -e "${YELLOW}Will try manual installation method...${NC}"
            USE_MANUAL_INSTALL=true
        fi
    fi
else
    echo -e "${GREEN}✓ pip is available${NC}"
fi

echo ""

# Step 4: Install module
echo -e "${BLUE}Step 4: Installing module...${NC}"

if [ "$USE_MANUAL_INSTALL" != "true" ]; then
    echo -e "${YELLOW}Using: $PYTHON_CMD -m pip install -e .${NC}"
    
    if $PYTHON_CMD -m pip install -e . 2>&1; then
        echo -e "${GREEN}✓ Module installed successfully${NC}"
    else
        echo -e "${YELLOW}pip install failed, trying manual copy method...${NC}"
        USE_MANUAL_INSTALL=true
    fi
fi

# Manual installation if needed
if [ "$USE_MANUAL_INSTALL" = "true" ]; then
    echo -e "${BLUE}Installing module (manual copy method)...${NC}"
    
    # Find site-packages
    SITE_PACKAGES_DIRS=(
        "$VENV_DIR/lib/python3.13/site-packages"
        "$VENV_DIR/lib/python3.12/site-packages"
        "$VENV_DIR/lib/python3.11/site-packages"
    )
    
    SITE_PACKAGES=""
    for dir in "${SITE_PACKAGES_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            SITE_PACKAGES="$dir"
            break
        fi
    done
    
    if [ -z "$SITE_PACKAGES" ]; then
        SITE_PACKAGES=$(find "$VENV_DIR/lib" -type d -name "site-packages" 2>/dev/null | head -n1)
    fi
    
    if [ -z "$SITE_PACKAGES" ] || [ ! -d "$SITE_PACKAGES" ]; then
        echo -e "${RED}Could not find site-packages directory${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Found site-packages at: $SITE_PACKAGES${NC}"
    
    # Create package directory
    PACKAGE_DIR="$SITE_PACKAGES/hiddify_agent_traffic_manager"
    mkdir -p "$PACKAGE_DIR"
    
    echo -e "${GREEN}Copying files...${NC}"
    
    # Copy __init__.py
    if [ -f "$MODULE_DIR/__init__.py" ]; then
        cp "$MODULE_DIR/__init__.py" "$PACKAGE_DIR/" || {
            echo -e "${RED}Failed to copy __init__.py${NC}"
            exit 1
        }
    fi
    
    # Copy subdirectories
    for dir in models utils tasks admin api; do
        if [ -d "$MODULE_DIR/$dir" ]; then
            cp -r "$MODULE_DIR/$dir" "$PACKAGE_DIR/" || {
                echo -e "${YELLOW}Warning: Could not copy $dir${NC}"
            }
        fi
    done
    
    if [ -f "$PACKAGE_DIR/__init__.py" ]; then
        echo -e "${GREEN}✓ Module copied successfully${NC}"
    else
        echo -e "${RED}✗ Module copy verification failed${NC}"
        exit 1
    fi
fi

echo ""

# Step 5: Verify installation
echo -e "${BLUE}Step 5: Verifying installation...${NC}"

if $PYTHON_CMD -c "import hiddify_agent_traffic_manager; print('OK')" 2>/dev/null; then
    echo -e "${GREEN}✓ Module verification successful${NC}"
else
    echo -e "${RED}✗ Module verification failed!${NC}"
    echo -e "${YELLOW}Module may not be properly installed${NC}"
    exit 1
fi

echo ""

# Step 6: Find and edit base.py for integration
echo -e "${BLUE}Step 6: Integrating with HiddifyPanel...${NC}"

# Find base.py
BASE_PY_PATHS=(
    "$VENV_DIR/lib/python3.13/site-packages/hiddifypanel/base.py"
    "$VENV_DIR/lib/python3.12/site-packages/hiddifypanel/base.py"
    "$VENV_DIR/lib/python3.11/site-packages/hiddifypanel/base.py"
    "$HIDDIFY_DIR/hiddify-panel/src/hiddifypanel/base.py"
)

BASE_PY_FILE=""

for path in "${BASE_PY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        BASE_PY_FILE="$path"
        echo -e "${GREEN}Found base.py at: $path${NC}"
        break
    fi
done

if [ -z "$BASE_PY_FILE" ]; then
    echo -e "${YELLOW}base.py not found in common locations. Searching...${NC}"
    BASE_PY_FILE=$(find "$VENV_DIR" -name "base.py" -path "*/hiddifypanel/base.py" -type f 2>/dev/null | head -n1)
    
    if [ -z "$BASE_PY_FILE" ]; then
        BASE_PY_FILE=$(find "$HIDDIFY_DIR" -name "base.py" -path "*/hiddifypanel/base.py" -type f 2>/dev/null | head -n1)
    fi
fi

if [ -z "$BASE_PY_FILE" ] || [ ! -f "$BASE_PY_FILE" ]; then
    echo -e "${RED}✗ Could not find base.py${NC}"
    echo -e "${YELLOW}Please manually edit base.py and add:${NC}"
    echo "  from hiddify_agent_traffic_manager import init_app"
    echo "  app = init_app(app)  # in create_app function"
    echo ""
    echo "Skipping integration step..."
    SKIP_INTEGRATION=true
else
    # Backup
    BACKUP_FILE="${BASE_PY_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$BASE_PY_FILE" "$BACKUP_FILE"
    echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"
    
    # Check if already integrated
    if grep -q "hiddify_agent_traffic_manager" "$BASE_PY_FILE"; then
        echo -e "${YELLOW}Module already integrated in base.py${NC}"
        echo -e "${GREEN}✓ Integration check passed${NC}"
    else
        echo -e "${GREEN}Adding integration code...${NC}"
        
        # Use Python script for safe integration
        $PYTHON_CMD << PYTHON_SCRIPT
import sys
import re

file_path = "$BASE_PY_FILE"

try:
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
except Exception as e:
    print(f"Error reading file: {e}")
    sys.exit(1)

# Check if already integrated
if 'hiddify_agent_traffic_manager' in content and ('init_app(app)' in content or '"hiddify_agent_traffic_manager:init_app"' in content):
    print("Already integrated")
    sys.exit(0)

# Add import after dynaconf or dotenv
import_added = False
if 'from dynaconf import' in content and 'from hiddify_agent_traffic_manager import init_app' not in content:
    content = content.replace(
        'from dynaconf import FlaskDynaconf',
        'from dynaconf import FlaskDynaconf\\nfrom hiddify_agent_traffic_manager import init_app'
    )
    import_added = True
    print("Import added after dynaconf")
elif 'from dotenv import' in content and 'from hiddify_agent_traffic_manager import init_app' not in content:
    content = content.replace(
        'from dotenv import dotenv_values',
        'from dotenv import dotenv_values\\nfrom hiddify_agent_traffic_manager import init_app'
    )
    import_added = True
    print("Import added after dotenv")
elif 'from hiddify_agent_traffic_manager import init_app' not in content:
    # Add before create_app function
    lines = content.split('\\n')
    for i, line in enumerate(lines):
        if line.startswith('def create_app'):
            lines.insert(i, 'from hiddify_agent_traffic_manager import init_app')
            import_added = True
            content = '\\n'.join(lines)
            print("Import added before create_app")
            break

# Add to extensions list (preferred method for HiddifyPanel)
if 'extensions.extend([' in content and '"hiddify_agent_traffic_manager:init_app"' not in content:
    # Find the line with extensions.extend([
    lines = content.split('\\n')
    for i, line in enumerate(lines):
        if 'extensions.extend([' in line:
            # Add to the next line
            indent = len(line) - len(line.lstrip())
            lines.insert(i + 1, ' ' * indent + '"hiddify_agent_traffic_manager:init_app",')
            content = '\\n'.join(lines)
            print("Added to extensions.extend")
            break
elif 'app = init_app(app)' not in content and 'def create_app' in content:
    # Fallback: add init_app call before return
    # Find return app in create_app function
    lines = content.split('\\n')
    in_create_app = False
    for i in range(len(lines) - 1, -1, -1):
        if 'return app' in lines[i] and in_create_app:
            indent = len(lines[i]) - len(lines[i].lstrip())
            lines.insert(i, ' ' * indent + '# Initialize agent traffic manager')
            lines.insert(i + 1, ' ' * indent + 'app = init_app(app)')
            content = '\\n'.join(lines)
            print("Added init_app call before return")
            break
        elif 'def create_app' in lines[i]:
            in_create_app = True

# Write back
try:
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("File updated successfully")
except Exception as e:
    print(f"Error writing file: {e}")
    sys.exit(1)
PYTHON_SCRIPT
        
        echo -e "${GREEN}✓ Integration code added${NC}"
    fi
fi

echo ""

# Step 7: Restart services
if [ "$SKIP_INTEGRATION" != "true" ]; then
    echo -e "${BLUE}Step 7: Restarting services...${NC}"
    
    if systemctl is-active --quiet hiddify-panel 2>/dev/null || systemctl is-enabled --quiet hiddify-panel 2>/dev/null; then
        echo -e "${GREEN}Restarting hiddify-panel...${NC}"
        systemctl restart hiddify-panel 2>/dev/null || sudo systemctl restart hiddify-panel 2>/dev/null || {
            echo -e "${YELLOW}Could not restart hiddify-panel (may need sudo)${NC}"
        }
        echo -e "${GREEN}✓ hiddify-panel restarted${NC}"
    else
        echo -e "${YELLOW}hiddify-panel service not found or not active${NC}"
    fi
    
    if systemctl is-active --quiet hiddify-panel-background-tasks 2>/dev/null || systemctl is-enabled --quiet hiddify-panel-background-tasks 2>/dev/null; then
        echo -e "${GREEN}Restarting hiddify-panel-background-tasks...${NC}"
        systemctl restart hiddify-panel-background-tasks 2>/dev/null || sudo systemctl restart hiddify-panel-background-tasks 2>/dev/null || {
            echo -e "${YELLOW}Could not restart hiddify-panel-background-tasks (may need sudo)${NC}"
        }
        echo -e "${GREEN}✓ hiddify-panel-background-tasks restarted${NC}"
    else
        echo -e "${YELLOW}hiddify-panel-background-tasks service not found or not active${NC}"
    fi
    
    echo ""
fi

# Step 8: Final verification
echo -e "${BLUE}Step 8: Final verification...${NC}"

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
echo "1. Check the panel logs: tail -f $HIDDIFY_DIR/log/system/panel.log"
echo "2. Test the API: curl http://localhost:9000/api/v1/agent-traffic/agents/traffic"
echo "3. Access the admin panel and check if agent traffic management is available"
echo ""
if [ -n "$BACKUP_FILE" ]; then
    echo -e "${YELLOW}Note: Backup file created at:${NC}"
    echo "  $BACKUP_FILE"
    echo ""
fi
echo -e "${GREEN}Installation script completed successfully!${NC}"

