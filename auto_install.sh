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

# Check for pip - try different locations
if [ ! -f "$PIP_CMD" ]; then
    echo -e "${YELLOW}pip not found at $PIP_CMD, trying alternative locations...${NC}"
    
    # Try to find pip in venv
    FOUND_PIP=$(find "$VENV_DIR" -name "pip" -type f 2>/dev/null | head -n1)
    
    if [ -n "$FOUND_PIP" ] && [ -f "$FOUND_PIP" ]; then
        PIP_CMD="$FOUND_PIP"
        echo -e "${GREEN}Found pip at: $PIP_CMD${NC}"
    else
        # Check if python exists and can run -m pip
        if [ -f "$PYTHON_CMD" ] && $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
            echo -e "${GREEN}Using: $PYTHON_CMD -m pip${NC}"
            PIP_CMD="$PYTHON_CMD -m pip"
        else
            echo -e "${YELLOW}pip executable not found, will use python -m pip${NC}"
            PIP_CMD="$PYTHON_CMD -m pip"
        fi
    fi
fi

# Verify pip works
echo -e "${GREEN}Verifying pip...${NC}"

# First check if python exists
if [ ! -f "$PYTHON_CMD" ]; then
    echo -e "${YELLOW}Python not found at $PYTHON_CMD, searching...${NC}"
    PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | grep -E "python3?$" | head -n1)
    
    if [ -z "$PYTHON_CMD" ] || [ ! -f "$PYTHON_CMD" ]; then
        # Try system python
        if command -v python3 >/dev/null 2>&1; then
            PYTHON_CMD="python3"
            echo -e "${YELLOW}Using system python3${NC}"
        else
            echo -e "${RED}Python not found!${NC}"
            exit 1
        fi
    fi
fi

# Verify python works
if ! $PYTHON_CMD --version >/dev/null 2>&1; then
    echo -e "${RED}Python verification failed!${NC}"
    exit 1
fi

echo -e "${GREEN}Python found: $($PYTHON_CMD --version 2>&1)${NC}"

# Now verify pip
if [[ "$PIP_CMD" == *"-m pip"* ]]; then
    if $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Pip is working (python -m pip)${NC}"
        PIP_CMD="$PYTHON_CMD -m pip"
    else
        echo -e "${YELLOW}Pip module not available, trying to bootstrap...${NC}"
        # Try to bootstrap pip
        $PYTHON_CMD -m ensurepip --upgrade --default-pip 2>&1 || {
            echo -e "${YELLOW}ensurepip failed, trying get-pip.py...${NC}"
            curl -sSL https://bootstrap.pypa.io/get-pip.py | $PYTHON_CMD 2>&1 || {
                echo -e "${RED}Pip bootstrap failed. Please install pip manually.${NC}"
                exit 1
            }
        }
        # Try again
        if $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Pip is now working${NC}"
            PIP_CMD="$PYTHON_CMD -m pip"
        else
            echo -e "${RED}Pip verification failed after bootstrap${NC}"
            exit 1
        fi
    fi
else
    if $PIP_CMD --version >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Pip is working${NC}"
    else
        echo -e "${RED}Pip verification failed${NC}"
        exit 1
    fi
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

# Check if PIP_CMD is a file or a command
if [[ "$PIP_CMD" == *"-m pip"* ]]; then
    # It's python -m pip
    INSTALL_CMD="$PIP_CMD install -e ."
else
    # It's pip executable
    INSTALL_CMD="$PIP_CMD install -e ."
fi

echo -e "${YELLOW}Using: $INSTALL_CMD${NC}"

if eval "$INSTALL_CMD"; then
    echo -e "${GREEN}✓ Module installed successfully${NC}"
else
    echo -e "${YELLOW}Trying alternative method (python -m pip)...${NC}"
    if $PYTHON_CMD -m pip install -e . 2>&1; then
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

# Step 5: Find and edit base.py for integration
echo -e "${BLUE}Step 5: Integrating with HiddifyPanel...${NC}"

# Find base.py (where create_app is defined)
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
    echo -e "${YELLOW}Please manually edit base.py and add in create_app function:${NC}"
    echo "  from hiddify_agent_traffic_manager import init_app"
    echo "  app = init_app(app)  # before return app"
    exit 1
fi

# Backup original file
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
    $PYTHON_CMD << 'PYTHON_SCRIPT'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already integrated
if 'hiddify_agent_traffic_manager' in content:
    print("Already integrated")
    sys.exit(0)

# Add import after other imports
import_added = False
if 'from hiddify_agent_traffic_manager import init_app' not in content:
    # Find a good place to add import (after dynaconf or dotenv)
    if 'from dynaconf import' in content:
        content = content.replace(
            'from dynaconf import FlaskDynaconf',
            'from dynaconf import FlaskDynaconf\nfrom hiddify_agent_traffic_manager import init_app'
        )
        import_added = True
    elif 'from dotenv import' in content:
        content = content.replace(
            'from dotenv import dotenv_values',
            'from dotenv import dotenv_values\nfrom hiddify_agent_traffic_manager import init_app'
        )
        import_added = True
    else:
        # Add after imports section
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if line.startswith('def create_app'):
                # Add import before function
                lines.insert(i, 'from hiddify_agent_traffic_manager import init_app')
                import_added = True
                break
        if import_added:
            content = '\n'.join(lines)

# Add to extensions list (HiddifyPanel uses extension system)
if 'hiddify_agent_traffic_manager' not in content:
    # Find extensions list and add our extension
    # Look for extensions.extend or extensions.append
    if 'extensions.extend([' in content:
        # Add to the extend list
        content = content.replace(
            'extensions.extend([',
            'extensions.extend([\n            "hiddify_agent_traffic_manager:init_app",'
        )
        print("Added to extensions.extend")
    elif 'extensions = [' in content:
        # Add to the list
        pattern = r'(extensions\s*=\s*\[[^\]]*)(\])'
        def add_extension(match):
            before = match.group(1)
            # Check if list is empty or has items
            if before.strip().endswith('['):
                return before + '\n        "hiddify_agent_traffic_manager:init_app",' + match.group(2)
            else:
                return before + ',\n        "hiddify_agent_traffic_manager:init_app"' + match.group(2)
        content = re.sub(pattern, add_extension, content)
        print("Added to extensions list")
    else:
        # Fallback: add init_app call before return
        if 'app = init_app(app)' not in content and 'def create_app' in content:
            # Find the return statement in create_app
            pattern = r'(def create_app\([^)]*\):.*?)(\n\s+app\.config\.load_extensions\("EXTENSIONS"\)\s*\n\s+return\s+app)'
            
            def replace_func(match):
                before = match.group(1)
                after = match.group(2)
                # Add init_app before return
                return before + '\n    # Initialize agent traffic manager\n    app = init_app(app)' + after
            
            new_content = re.sub(pattern, replace_func, content, flags=re.DOTALL)
            
            if new_content == content:
                # Fallback: add before return app
                lines = content.split('\n')
                for i in range(len(lines) - 1, -1, -1):
                    if 'return app' in lines[i] and i > 0:
                        # Check if we're in create_app function
                        func_start = -1
                        for j in range(i, -1, -1):
                            if 'def create_app' in lines[j]:
                                func_start = j
                                break
                        
                        if func_start >= 0:
                            indent = len(lines[i]) - len(lines[i].lstrip())
                            lines.insert(i, ' ' * indent + '# Initialize agent traffic manager')
                            lines.insert(i + 1, ' ' * indent + 'app = init_app(app)')
                            new_content = '\n'.join(lines)
                            break
                
                content = new_content
            else:
                content = new_content
                print("Added init_app call before return")

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

if import_added:
    print("Import added")
if 'app = init_app(app)' in content:
    print("Integration code added")
else:
    print("Warning: Could not add integration code automatically")
PYTHON_SCRIPT
    "$BASE_PY_FILE"
    
    echo -e "${GREEN}✓ Integration code added${NC}"
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

