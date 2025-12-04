#!/bin/bash
# Script to temporarily disable the module by removing it from base.py

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"
VENV_DIR="$HIDDIFY_DIR/.venv313"

echo -e "${BLUE}Disabling module...${NC}"

# Find base.py
BASE_PY_PATHS=(
    "$VENV_DIR/lib/python3.13/site-packages/hiddifypanel/base.py"
    "$VENV_DIR/lib/python3.12/site-packages/hiddifypanel/base.py"
    "$VENV_DIR/lib/python3.11/site-packages/hiddifypanel/base.py"
)

BASE_PY_FILE=""
for path in "${BASE_PY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        BASE_PY_FILE="$path"
        break
    fi
done

if [ -z "$BASE_PY_FILE" ]; then
    BASE_PY_FILE=$(find "$VENV_DIR" -name "base.py" -path "*/hiddifypanel/base.py" -type f 2>/dev/null | head -n1)
fi

if [ -z "$BASE_PY_FILE" ] || [ ! -f "$BASE_PY_FILE" ]; then
    echo -e "${RED}✗ Could not find base.py${NC}"
    exit 1
fi

echo -e "${GREEN}Found base.py at: $BASE_PY_FILE${NC}"

# Backup
BACKUP_FILE="${BASE_PY_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$BASE_PY_FILE" "$BACKUP_FILE"
echo -e "${GREEN}✓ Backup created: $BACKUP_FILE${NC}"

# Remove module from extensions list
PYTHON_CMD="$VENV_DIR/bin/python"
if [ ! -f "$PYTHON_CMD" ]; then
    PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | head -n1)
fi

$PYTHON_CMD << 'PYTHON_SCRIPT'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Remove from extensions list
if '"hiddify_agent_traffic_manager:init_app"' in content:
    # Remove from extensions.extend([
    lines = content.split('\n')
    new_lines = []
    skip_next = False
    for i, line in enumerate(lines):
        if skip_next:
            skip_next = False
            continue
        if 'hiddify_agent_traffic_manager' in line:
            continue
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    print("Removed from extensions list")

# Remove import
if 'from hiddify_agent_traffic_manager import init_app' in content:
    content = content.replace('from hiddify_agent_traffic_manager import init_app\n', '')
    content = content.replace('\nfrom hiddify_agent_traffic_manager import init_app', '')
    print("Removed import")

# Remove init_app call
if 'app = init_app(app)' in content:
    lines = content.split('\n')
    new_lines = []
    for line in lines:
        if 'init_app(app)' in line and 'hiddify_agent_traffic_manager' in content:
            continue
        new_lines.append(line)
    content = '\n'.join(new_lines)
    print("Removed init_app call")

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("File updated successfully")
PYTHON_SCRIPT
"$BASE_PY_FILE"

echo -e "${GREEN}✓ Module disabled${NC}"
echo -e "${YELLOW}Please restart hiddify-panel: systemctl restart hiddify-panel${NC}"

