#!/bin/bash
# Direct patch application script - simpler and more reliable

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Direct Patch Application${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Find source directory - check multiple locations
SOURCE_DIR=""

# First, check if we're already in a source directory
if [ -d "src/hiddifypanel" ] || [ -d "hiddifypanel" ]; then
    if [ -d "src" ]; then
        SOURCE_DIR="$(pwd)/src"
        echo -e "${GREEN}Found source in current directory: $SOURCE_DIR${NC}"
    elif [ -d "hiddifypanel" ]; then
        SOURCE_DIR="$(pwd)"
        echo -e "${GREEN}Found source in current directory: $SOURCE_DIR${NC}"
    fi
fi

# If not found, check standard locations
if [ -z "$SOURCE_DIR" ]; then
    if [ -d "$HIDDIFY_DIR/hiddify-panel-custom/src" ]; then
        SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-custom/src"
        echo -e "${GREEN}Found in hiddify-panel-custom${NC}"
    elif [ -d "$HIDDIFY_DIR/hiddify-panel/src" ]; then
        SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel/src"
        echo -e "${GREEN}Found in hiddify-panel${NC}"
    fi
fi

# If still not found, search
if [ -z "$SOURCE_DIR" ]; then
    FOUND=$(find "$HIDDIFY_DIR" -type d -name "hiddifypanel" -path "*/src/hiddifypanel" 2>/dev/null | head -n1 | sed 's|/hiddifypanel$||')
    if [ -n "$FOUND" ] && [ -d "$FOUND" ]; then
        SOURCE_DIR="$FOUND"
        echo -e "${GREEN}Found via search: $SOURCE_DIR${NC}"
    fi
fi

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ Source directory not found${NC}"
    echo -e "${YELLOW}Searched in:${NC}"
    echo "  - Current directory: $(pwd)"
    echo "  - $HIDDIFY_DIR/hiddify-panel-custom/src"
    echo "  - $HIDDIFY_DIR/hiddify-panel/src"
    echo ""
    echo -e "${YELLOW}Please make sure HiddifyPanel is cloned or run from the correct directory${NC}"
    exit 1
fi

echo -e "${GREEN}Using source directory: $SOURCE_DIR${NC}"
echo ""

# Patch 1: models/admin.py
ADMIN_PY="$SOURCE_DIR/hiddifypanel/models/admin.py"
if [ ! -f "$ADMIN_PY" ]; then
    echo -e "${RED}✗ $ADMIN_PY not found${NC}"
    exit 1
fi

echo -e "${BLUE}Patching models/admin.py...${NC}"

# Backup
cp "$ADMIN_PY" "${ADMIN_PY}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if already patched
if grep -q "traffic_limit = Column(BigInteger" "$ADMIN_PY"; then
    echo -e "${YELLOW}Already patched (traffic_limit column exists)${NC}"
else
    # Add BigInteger import if needed
    if ! grep -q "from sqlalchemy import.*BigInteger" "$ADMIN_PY"; then
        sed -i 's/from sqlalchemy import/from sqlalchemy import BigInteger,/' "$ADMIN_PY"
        echo "Added BigInteger to imports"
    fi
    
    # Add traffic_limit column after max_active_users
    if grep -q "max_active_users = Column(Integer, default=100, nullable=False)" "$ADMIN_PY"; then
        sed -i '/max_active_users = Column(Integer, default=100, nullable=False)/a\    traffic_limit = Column(BigInteger, default=None, nullable=True)' "$ADMIN_PY"
        echo "Added traffic_limit column"
    else
        echo -e "${YELLOW}Could not find insertion point for traffic_limit${NC}"
    fi
fi

echo -e "${GREEN}✓ models/admin.py patched${NC}"
echo ""

# Patch 2: panel/admin/AdminstratorAdmin.py
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"
if [ ! -f "$ADMINSTRATOR_ADMIN_PY" ]; then
    echo -e "${RED}✗ $ADMINSTRATOR_ADMIN_PY not found${NC}"
    exit 1
fi

echo -e "${BLUE}Patching panel/admin/AdminstratorAdmin.py...${NC}"

# Backup
cp "$ADMINSTRATOR_ADMIN_PY" "${ADMINSTRATOR_ADMIN_PY}.backup.$(date +%Y%m%d_%H%M%S)"

# Check if already patched
if grep -q "'traffic_limit_GB'" "$ADMINSTRATOR_ADMIN_PY"; then
    echo -e "${YELLOW}Already patched (traffic_limit_GB in column_list)${NC}"
else
    # Add to column_list
    if grep -q "column_list = \[" "$ADMINSTRATOR_ADMIN_PY"; then
        # Find the line with column_list and add traffic columns before the closing bracket
        sed -i "/column_list = \[/,/\]/ {
            /'comment',/a\        'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',
        }" "$ADMINSTRATOR_ADMIN_PY"
        echo "Added traffic columns to column_list"
    fi
    
    # Add to form_columns
    if grep -q "form_columns = \[" "$ADMINSTRATOR_ADMIN_PY"; then
        sed -i "/form_columns = \[/,/\]/ {
            /'max_users',/a\        'traffic_limit_GB',
        }" "$ADMINSTRATOR_ADMIN_PY"
        echo "Added traffic_limit_GB to form_columns"
    fi
fi

echo -e "${GREEN}✓ AdminstratorAdmin.py patched${NC}"
echo ""

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}All patches applied successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Install from source: cd $SOURCE_DIR && /opt/hiddify-manager/.venv313/bin/pip install -e ."
echo "2. Restart services: systemctl restart hiddify-panel"

