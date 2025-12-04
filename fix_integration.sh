#!/bin/bash
# Fix integration script - restores base.py and integrates correctly

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"
VENV_DIR="$HIDDIFY_DIR/.venv313"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Fix Integration Script${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

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

# Find latest backup
BACKUP_FILES=$(ls -t "${BASE_PY_FILE}.backup."* 2>/dev/null | head -1)
if [ -n "$BACKUP_FILES" ]; then
    LATEST_BACKUP="$BACKUP_FILES"
    echo -e "${GREEN}Found backup: $LATEST_BACKUP${NC}"
    
    # Check current file syntax
    PYTHON_CMD="$VENV_DIR/bin/python"
    if [ ! -f "$PYTHON_CMD" ]; then
        PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | head -n1)
    fi
    
    SYNTAX_CHECK=$($PYTHON_CMD -m py_compile "$BASE_PY_FILE" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Current base.py has syntax errors!${NC}"
        echo -e "${YELLOW}Restoring from backup...${NC}"
        cp "$LATEST_BACKUP" "$BASE_PY_FILE"
        echo -e "${GREEN}✓ Restored from backup${NC}"
    else
        echo -e "${GREEN}✓ Current base.py syntax is valid${NC}"
    fi
fi

# Check if already integrated
if grep -q "hiddify_agent_traffic_manager" "$BASE_PY_FILE"; then
    echo -e "${YELLOW}Module already integrated${NC}"
    
    # Verify integration is correct
    if grep -q '"hiddify_agent_traffic_manager:init_app"' "$BASE_PY_FILE"; then
        echo -e "${GREEN}✓ Integration found in extensions list${NC}"
    elif grep -q "from hiddify_agent_traffic_manager import init_app" "$BASE_PY_FILE"; then
        echo -e "${GREEN}✓ Integration found as import${NC}"
    else
        echo -e "${YELLOW}⚠ Integration found but format unclear${NC}"
    fi
    
    # Final syntax check
    SYNTAX_CHECK=$($PYTHON_CMD -m py_compile "$BASE_PY_FILE" 2>&1)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ base.py syntax is valid${NC}"
        echo -e "${GREEN}✓ Integration is correct${NC}"
    else
        echo -e "${RED}✗ base.py has syntax errors!${NC}"
        echo -e "${YELLOW}Error: $SYNTAX_CHECK${NC}"
        if [ -n "$LATEST_BACKUP" ]; then
            echo -e "${YELLOW}Restoring from backup...${NC}"
            cp "$LATEST_BACKUP" "$BASE_PY_FILE"
            echo -e "${GREEN}✓ Restored from backup${NC}"
            echo -e "${YELLOW}Please run install_complete.sh again${NC}"
        fi
    fi
else
    echo -e "${YELLOW}Module not integrated yet${NC}"
    echo -e "${YELLOW}Please run install_complete.sh to integrate${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"

