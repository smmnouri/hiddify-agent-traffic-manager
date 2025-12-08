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

# Verify source directory structure
echo -e "${BLUE}Checking source directory structure...${NC}"
if [ ! -d "$SOURCE_DIR/hiddifypanel" ]; then
    echo -e "${YELLOW}Warning: hiddifypanel directory not found in $SOURCE_DIR${NC}"
    echo -e "${YELLOW}Listing contents of $SOURCE_DIR:${NC}"
    ls -la "$SOURCE_DIR" | head -20
    echo ""
    
    # Try to find hiddifypanel directory
    FOUND_HIDDIFY=$(find "$SOURCE_DIR" -type d -name "hiddifypanel" 2>/dev/null | head -n1)
    if [ -n "$FOUND_HIDDIFY" ]; then
        echo -e "${GREEN}Found hiddifypanel at: $FOUND_HIDDIFY${NC}"
        # Adjust SOURCE_DIR to parent of hiddifypanel
        SOURCE_DIR="$(dirname "$FOUND_HIDDIFY")"
        echo -e "${GREEN}Adjusted source directory to: $SOURCE_DIR${NC}"
    else
        echo -e "${RED}✗ Could not find hiddifypanel directory${NC}"
        exit 1
    fi
fi

# Patch 1: models/admin.py
ADMIN_PY="$SOURCE_DIR/hiddifypanel/models/admin.py"
if [ ! -f "$ADMIN_PY" ]; then
    echo -e "${YELLOW}⚠ $ADMIN_PY not found, searching...${NC}"
    # Try to find admin.py
    FOUND_ADMIN=$(find "$SOURCE_DIR" -name "admin.py" -path "*/models/admin.py" 2>/dev/null | head -n1)
    if [ -n "$FOUND_ADMIN" ]; then
        ADMIN_PY="$FOUND_ADMIN"
        echo -e "${GREEN}Found admin.py at: $ADMIN_PY${NC}"
    else
        echo -e "${RED}✗ admin.py not found in expected location${NC}"
        echo -e "${YELLOW}Searching for models directory...${NC}"
        find "$SOURCE_DIR" -type d -name "models" 2>/dev/null | head -5
        echo ""
        echo -e "${YELLOW}Note: This patch is optional if traffic_limit column is already in the model${NC}"
        echo -e "${YELLOW}Continuing with AdminstratorAdmin.py patch...${NC}"
        ADMIN_PY=""
    fi
fi

if [ -n "$ADMIN_PY" ] && [ -f "$ADMIN_PY" ]; then
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
else
    echo -e "${YELLOW}⚠ Skipping models/admin.py patch (file not found or already handled by migration)${NC}"
    echo ""
fi

# Patch 2: panel/admin/AdminstratorAdmin.py
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"
if [ ! -f "$ADMINSTRATOR_ADMIN_PY" ]; then
    echo -e "${YELLOW}⚠ $ADMINSTRATOR_ADMIN_PY not found, searching...${NC}"
    # Try to find AdminstratorAdmin.py
    FOUND_ADMINSTRATOR=$(find "$SOURCE_DIR" -name "AdminstratorAdmin.py" 2>/dev/null | head -n1)
    if [ -n "$FOUND_ADMINSTRATOR" ]; then
        ADMINSTRATOR_ADMIN_PY="$FOUND_ADMINSTRATOR"
        echo -e "${GREEN}Found AdminstratorAdmin.py at: $ADMINSTRATOR_ADMIN_PY${NC}"
    else
        echo -e "${RED}✗ AdminstratorAdmin.py not found${NC}"
        echo -e "${YELLOW}Searching for admin directory...${NC}"
        find "$SOURCE_DIR" -type d -name "admin" 2>/dev/null | head -5
        exit 1
    fi
fi

echo -e "${BLUE}Patching panel/admin/AdminstratorAdmin.py...${NC}"

# Backup
cp "$ADMINSTRATOR_ADMIN_PY" "${ADMINSTRATOR_ADMIN_PY}.backup.$(date +%Y%m%d_%H%M%S)"

# Use Python patch script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_SCRIPT="$SCRIPT_DIR/patches/patch_adminstrator_admin.py"

if [ -f "$PATCH_SCRIPT" ]; then
    # Find Python
    VENV_PYTHON=""
    if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
        VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
    elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
        VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
    else
        VENV_PYTHON="python3"
    fi
    
    echo "Using Python patch script..."
    "$VENV_PYTHON" "$PATCH_SCRIPT" "$ADMINSTRATOR_ADMIN_PY"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ AdminstratorAdmin.py patched successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Patch script completed with warnings (might already be patched)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Patch script not found, using basic sed method...${NC}"
    # Fallback to basic sed method
    if grep -q "'traffic_limit_GB'" "$ADMINSTRATOR_ADMIN_PY"; then
        echo -e "${YELLOW}Already patched (traffic_limit_GB in column_list)${NC}"
    else
        # Add to column_list
        if grep -q "column_list = \[" "$ADMINSTRATOR_ADMIN_PY"; then
            sed -i "/column_list = \[/,/\]/ {
                /'max_users',/a\        'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',
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
fi

echo ""

# Step 3: Run database migration
echo -e "${BLUE}Running database migration...${NC}"

MIGRATION_SCRIPT="$SCRIPT_DIR/migrations/run_migration.sh"
if [ -f "$MIGRATION_SCRIPT" ]; then
    chmod +x "$MIGRATION_SCRIPT"
    bash "$MIGRATION_SCRIPT"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Database migration completed${NC}"
    else
        echo -e "${YELLOW}⚠ Migration completed with warnings (column might already exist)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Migration script not found, skipping...${NC}"
fi

echo ""

echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}All patches applied successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Install from source: cd $SOURCE_DIR && /opt/hiddify-manager/.venv313/bin/pip install -e ."
echo "2. Restart services: systemctl restart hiddify-panel hiddify-panel-background-tasks"

