#!/bin/bash
# Complete script to apply agent traffic management to HiddifyPanel source

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"
SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel/src"
VENV_DIR="$HIDDIFY_DIR/.venv313"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Apply Agent Traffic Management${NC}"
echo -e "${BLUE}to HiddifyPanel Source${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Step 1: Find source
echo -e "${BLUE}Step 1: Finding HiddifyPanel source...${NC}"
if [ ! -d "$SOURCE_DIR" ]; then
    SOURCE_DIR=$(find "$HIDDIFY_DIR" -type d -name "hiddifypanel" -path "*/src/hiddifypanel" 2>/dev/null | head -n1 | sed 's|/hiddifypanel$||')
fi

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${YELLOW}Source not found. Cloning...${NC}"
    cd "$HIDDIFY_DIR"
    if [ -d "hiddify-panel" ]; then
        echo -e "${YELLOW}Directory exists, updating...${NC}"
        cd hiddify-panel
        git pull || echo "Could not pull"
    else
        git clone https://github.com/hiddify/HiddifyPanel.git hiddify-panel
    fi
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel/src"
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}✗ Could not find or create source directory${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Source found at: $SOURCE_DIR${NC}"

# Backup
BACKUP_DIR="${SOURCE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${BLUE}Creating backup...${NC}"
cp -r "$SOURCE_DIR" "$BACKUP_DIR"
echo -e "${GREEN}✓ Backup created: $BACKUP_DIR${NC}"
echo ""

# Step 2: Patch models/admin.py
echo -e "${BLUE}Step 2: Patching models/admin.py...${NC}"
ADMIN_PY="$SOURCE_DIR/hiddifypanel/models/admin.py"

if [ ! -f "$ADMIN_PY" ]; then
    echo -e "${RED}✗ admin.py not found${NC}"
    exit 1
fi

# Create Python script to patch
python3 << 'PYTHON_SCRIPT'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already patched
if 'traffic_limit = Column(BigInteger' in content:
    print("Already patched (traffic_limit column exists)")
    sys.exit(0)

# Add BigInteger to imports
if 'from sqlalchemy import' in content and 'BigInteger' not in content:
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if 'from sqlalchemy import' in line and 'BigInteger' not in line:
            # Add BigInteger
            if ', ' in line:
                lines[i] = line.replace('from sqlalchemy import', 'from sqlalchemy import BigInteger,')
            else:
                lines[i] = line + ', BigInteger'
            content = '\n'.join(lines)
            print("Added BigInteger to imports")
            break

# Add traffic_limit column
if 'max_active_users = Column(Integer, default=100, nullable=False)' in content:
    content = content.replace(
        'max_active_users = Column(Integer, default=100, nullable=False)',
        'max_active_users = Column(Integer, default=100, nullable=False)\n    traffic_limit = Column(BigInteger, default=None, nullable=True)'
    )
    print("Added traffic_limit column")
else:
    print("Could not find insertion point for traffic_limit column")
    sys.exit(1)

# Add methods after recursive_sub_admins_ids
if 'def recursive_sub_admins_ids(self' in content:
    # Find insertion point (after recursive_sub_admins_ids method)
    lines = content.split('\n')
    insert_pos = -1
    brace_count = 0
    in_method = False
    
    for i, line in enumerate(lines):
        if 'def recursive_sub_admins_ids(self' in line:
            in_method = True
            brace_count = line.count('(') - line.count(')')
            continue
        
        if in_method:
            brace_count += line.count('(') - line.count(')')
            if brace_count == 0 and line.strip() and not line.strip().startswith('#'):
                # Found end of method
                insert_pos = i
                break
    
    if insert_pos > 0:
        methods = '''
    @property
    def traffic_limit_GB(self):
        """Get traffic limit in GB"""
        if self.traffic_limit is None:
            return None
        return self.traffic_limit / (1024 * 1024 * 1024)
    
    @traffic_limit_GB.setter
    def traffic_limit_GB(self, value):
        """Set traffic limit in GB"""
        if value is None:
            self.traffic_limit = None
        else:
            self.traffic_limit = int(value * (1024 * 1024 * 1024))
    
    def get_total_traffic(self):
        """محاسبه مجموع ترافیک مصرفی تمام کاربران ایجاد شده توسط این ایجنت"""
        from hiddifypanel.models.user import User
        from sqlalchemy import func
        
        admin_ids = self.recursive_sub_admins_ids()
        
        total_traffic = db.session.query(
            func.coalesce(func.sum(User.current_usage), 0)
        ).filter(
            User.added_by.in_(admin_ids)
        ).scalar()
        
        return total_traffic or 0
    
    def get_total_traffic_GB(self):
        """Get total traffic in GB"""
        return self.get_total_traffic() / (1024 * 1024 * 1024)
    
    def get_remaining_traffic(self):
        """محاسبه ترافیک باقیمانده"""
        if self.traffic_limit_GB is None:
            return None
        total = self.get_total_traffic()
        limit = int(self.traffic_limit_GB * (1024 * 1024 * 1024))
        remaining = limit - total
        return max(0, remaining)
    
    def get_remaining_traffic_GB(self):
        """Get remaining traffic in GB"""
        remaining = self.get_remaining_traffic()
        if remaining is None:
            return None
        return remaining / (1024 * 1024 * 1024)
    
    def can_create_user_with_traffic(self, user_traffic_limit_GB=None):
        """بررسی اینکه آیا می‌تواند کاربر جدید با ترافیک مشخص ایجاد کند"""
        if self.traffic_limit_GB is None:
            return True, None
        current_total = self.get_total_traffic()
        agent_limit = int(self.traffic_limit_GB * (1024 * 1024 * 1024))
        if user_traffic_limit_GB is not None:
            user_limit = int(user_traffic_limit_GB * (1024 * 1024 * 1024))
            if current_total + user_limit > agent_limit:
                return False, f"مجموع ترافیک کاربران ({current_total/(1024**3):.2f} GB) به علاوه ترافیک کاربر جدید ({user_traffic_limit_GB} GB) از حد مجاز ایجنت ({self.traffic_limit_GB} GB) بیشتر است"
        if current_total >= agent_limit:
            return False, f"ترافیک مصرفی کاربران ({current_total/(1024**3):.2f} GB) از حد مجاز ایجنت ({self.traffic_limit_GB} GB) تجاوز کرده است"
        return True, None
    
    def is_traffic_limit_exceeded(self):
        """بررسی اینکه آیا ترافیک از حد مجاز تجاوز کرده است"""
        if self.traffic_limit_GB is None:
            return False
        total = self.get_total_traffic()
        limit = int(self.traffic_limit_GB * (1024 * 1024 * 1024))
        return total >= limit
    
    def disable_all_users(self):
        """غیرفعال‌سازی تمام کاربران ایجاد شده توسط این ایجنت"""
        from hiddifypanel.models.user import User
        admin_ids = self.recursive_sub_admins_ids()
        affected = db.session.query(User).filter(
            User.added_by.in_(admin_ids)
        ).update(
            {User.enable: False},
            synchronize_session=False
        )
        db.session.commit()
        return affected
'''
        lines.insert(insert_pos, methods)
        content = '\n'.join(lines)
        print("Added traffic management methods")
    else:
        print("Could not find insertion point for methods")
        sys.exit(1)

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ admin.py patched successfully")
PYTHON_SCRIPT
"$ADMIN_PY"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ models/admin.py patched${NC}"
else
    echo -e "${RED}✗ Failed to patch admin.py${NC}"
    exit 1
fi

echo ""

# Step 3: Patch AdminstratorAdmin.py
echo -e "${BLUE}Step 3: Patching panel/admin/AdminstratorAdmin.py...${NC}"
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"

python3 << 'PYTHON_SCRIPT'
import sys
import re

file_path = sys.argv[1]

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already patched
if "'traffic_limit_GB'" in content and 'column_list' in content:
    print("Already patched (traffic columns in column_list)")
    sys.exit(0)

# Add to column_list
if "column_list = [" in content and "'traffic_limit_GB'" not in content:
    # Find column_list line
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if "column_list = [" in line:
            # Find the closing bracket
            for j in range(i, min(i+5, len(lines))):
                if ']' in lines[j]:
                    # Insert before closing bracket
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    traffic_cols = " 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',"
                    lines[j] = ' ' * (indent + 4) + traffic_cols + '\n' + lines[j]
                    content = '\n'.join(lines)
                    print("Added traffic columns to column_list")
                    break
            break

# Add to form_columns
if "form_columns = [" in content and "'traffic_limit_GB'" not in content:
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if "form_columns = [" in line:
            for j in range(i, min(i+10, len(lines))):
                if ']' in lines[j]:
                    indent = len(lines[j]) - len(lines[j].lstrip())
                    lines[j] = ' ' * (indent + 4) + "'traffic_limit_GB'," + '\n' + lines[j]
                    content = '\n'.join(lines)
                    print("Added traffic_limit_GB to form_columns")
                    break
            break

# Add column_formatters
if "column_formatters" not in content or "'traffic_limit_GB'" not in content:
    # Find where to add (after column_labels)
    if "column_labels = {" in content:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if "column_labels = {" in line:
                # Find closing brace
                brace_count = 0
                for j in range(i, len(lines)):
                    brace_count += lines[j].count('{') - lines[j].count('}')
                    if brace_count == 0 and '}' in lines[j]:
                        # Add column_formatters after this
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        formatters = '''
    column_formatters = {
        'traffic_limit_GB': lambda view, context, model, name: (
            '-' if model.mode != AdminMode.agent else (
                'Unlimited' if model.traffic_limit_GB is None else f"{model.traffic_limit_GB:.2f} GB"
            )
        ),
        'total_traffic': lambda view, context, model, name: (
            '-' if model.mode != AdminMode.agent else f"{model.get_total_traffic_GB():.2f} GB"
        ),
        'remaining_traffic': lambda view, context, model, name: (
            '-' if model.mode != AdminMode.agent or model.get_remaining_traffic_GB() is None else f"{model.get_remaining_traffic_GB():.2f} GB"
        ),
        'traffic_status': lambda view, context, model, name: (
            '-' if model.mode != AdminMode.agent else (
                '<span class="badge badge-info">No Limit</span>' if model.traffic_limit_GB is None else (
                    f'<span class="badge badge-danger">Exceeded ({(model.get_total_traffic_GB() / model.traffic_limit_GB * 100):.1f}%)</span>' if model.is_traffic_limit_exceeded() else (
                        f'<span class="badge badge-warning">Warning ({(model.get_total_traffic_GB() / model.traffic_limit_GB * 100):.1f}%)</span>' if (model.get_total_traffic_GB() / model.traffic_limit_GB * 100) > 90 else f'<span class="badge badge-success">OK ({(model.get_total_traffic_GB() / model.traffic_limit_GB * 100):.1f}%)</span>'
                    )
                )
            )
        )
    }
'''
                        lines.insert(j + 1, formatters)
                        content = '\n'.join(lines)
                        print("Added column_formatters")
                        break
                break

# Write back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("✓ AdminstratorAdmin.py patched successfully")
PYTHON_SCRIPT
"$ADMINSTRATOR_ADMIN_PY"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ AdminstratorAdmin.py patched${NC}"
else
    echo -e "${RED}✗ Failed to patch AdminstratorAdmin.py${NC}"
    exit 1
fi

echo ""

# Step 4: Add user creation hook
echo -e "${BLUE}Step 4: Adding user creation hook...${NC}"
HOOK_FILE="$SOURCE_DIR/hiddifypanel/panel/admin/user_creation_hook.py"

cat > "$HOOK_FILE" << 'HOOK_EOF'
from sqlalchemy import event
from hiddifypanel.models.user import User
from hiddifypanel.models.admin import AdminUser, AdminMode
from loguru import logger

@event.listens_for(User, 'before_insert', propagate=True)
def check_traffic_before_user_insert(mapper, connection, target):
    """بررسی ترافیک قبل از insert کردن کاربر"""
    agent_id = target.added_by
    if not agent_id:
        from flask import g
        if hasattr(g, 'account') and isinstance(g.account, AdminUser):
            agent_id = g.account.id
        else:
            agent_id = 1
    
    agent = AdminUser.query.get(agent_id)
    if not agent or agent.mode != AdminMode.agent:
        return
    
    if agent.traffic_limit_GB is None:
        return
    
    user_traffic_limit_GB = target.usage_limit_GB if hasattr(target, 'usage_limit') and target.usage_limit else None
    can_create, error_msg = agent.can_create_user_with_traffic(user_traffic_limit_GB)
    
    if not can_create:
        logger.error(f"User creation blocked for agent {agent.name}: {error_msg}")
        raise ValueError(error_msg)
HOOK_EOF

echo -e "${GREEN}✓ User creation hook created${NC}"

# Import hook in __init__.py
ADMIN_INIT="$SOURCE_DIR/hiddifypanel/panel/admin/__init__.py"
if [ -f "$ADMIN_INIT" ]; then
    if ! grep -q "from .user_creation_hook import" "$ADMIN_INIT"; then
        # Add import
        sed -i '/^from \./a from .user_creation_hook import *  # Agent traffic management hooks' "$ADMIN_INIT"
        echo -e "${GREEN}✓ Hook imported in admin/__init__.py${NC}"
    fi
fi

echo ""

# Step 5: Database migration
echo -e "${BLUE}Step 5: Running database migration...${NC}"
PYTHON_CMD="$VENV_DIR/bin/python"
if [ ! -f "$PYTHON_CMD" ]; then
    PYTHON_CMD=$(find "$VENV_DIR" -name "python*" -type f -executable 2>/dev/null | head -n1)
fi

$PYTHON_CMD << 'PYTHON_SCRIPT'
import sys
sys.path.insert(0, '/opt/hiddify-manager/hiddify-panel/src')

from hiddifypanel.database import db
from sqlalchemy import inspect

try:
    inspector = inspect(db.engine)
    columns = [col['name'] for col in inspector.get_columns('admin_user')]
    
    if 'traffic_limit' not in columns:
        print("Adding traffic_limit column...")
        db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
        db.session.commit()
        print("✓ Column added successfully")
    else:
        print("✓ Column already exists")
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
PYTHON_SCRIPT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database migration completed${NC}"
else
    echo -e "${YELLOW}⚠ Database migration had issues (column might already exist)${NC}"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}All patches applied successfully!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review changes in: $SOURCE_DIR"
echo "2. Restart hiddify-panel: systemctl restart hiddify-panel"
echo "3. Check logs: tail -f /opt/hiddify-manager/log/system/panel.log"
echo ""
echo -e "${YELLOW}Backup location: $BACKUP_DIR${NC}"

