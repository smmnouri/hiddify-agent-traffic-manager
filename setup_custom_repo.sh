#!/bin/bash
# Script to setup custom HiddifyPanel repository with agent traffic management

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HIDDIFY_DIR="/opt/hiddify-manager"
CUSTOM_REPO_DIR="$HIDDIFY_DIR/hiddify-panel-custom"
GITHUB_USER="smmnouri"  # تغییر دهید به username خودتان
REPO_NAME="hiddify-panel-custom"  # یا نام دلخواه

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}Setup Custom HiddifyPanel Repository${NC}"
echo -e "${BLUE}with Agent Traffic Management${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Step 1: Clone or create custom repo
echo -e "${BLUE}Step 1: Setting up custom repository...${NC}"

if [ -d "$CUSTOM_REPO_DIR" ]; then
    echo -e "${YELLOW}Custom repo exists, updating...${NC}"
    cd "$CUSTOM_REPO_DIR"
    git pull origin main || git pull origin master || echo "Could not pull"
else
    echo -e "${GREEN}Cloning HiddifyPanel...${NC}"
    cd "$HIDDIFY_DIR"
    git clone https://github.com/hiddify/HiddifyPanel.git hiddify-panel-custom
    cd "$CUSTOM_REPO_DIR"
    
    # Change remote to user's repo
    echo -e "${BLUE}Setting up remote...${NC}"
    git remote remove origin 2>/dev/null || true
    git remote add origin "https://github.com/$GITHUB_USER/$REPO_NAME.git" || true
    echo -e "${GREEN}✓ Remote set to: https://github.com/$GITHUB_USER/$REPO_NAME.git${NC}"
fi

echo ""

# Step 2: Apply patches
echo -e "${BLUE}Step 2: Applying agent traffic management patches...${NC}"

SOURCE_DIR="$CUSTOM_REPO_DIR/src"
ADMIN_PY="$SOURCE_DIR/hiddifypanel/models/admin.py"
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"

# Check if source exists
if [ ! -f "$ADMIN_PY" ]; then
    echo -e "${RED}✗ Source files not found${NC}"
    exit 1
fi

# Backup
BACKUP_DIR="${SOURCE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
cp -r "$SOURCE_DIR" "$BACKUP_DIR"
echo -e "${GREEN}✓ Backup created: $BACKUP_DIR${NC}"

# Apply patches using Python
python3 << 'PYTHON_SCRIPT'
import sys
import re
import os

admin_py = sys.argv[1]
adminstrator_admin_py = sys.argv[2]

# Patch admin.py
print("Patching models/admin.py...")
with open(admin_py, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already patched
if 'traffic_limit = Column(BigInteger' in content:
    print("Already patched")
else:
    # Add BigInteger import
    if 'from sqlalchemy import' in content and 'BigInteger' not in content:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if 'from sqlalchemy import' in line and 'BigInteger' not in line:
                if ', ' in line:
                    lines[i] = line.replace('from sqlalchemy import', 'from sqlalchemy import BigInteger,')
                else:
                    lines[i] = line + ', BigInteger'
                content = '\n'.join(lines)
                break
    
    # Add column
    if 'max_active_users = Column(Integer, default=100, nullable=False)' in content:
        content = content.replace(
            'max_active_users = Column(Integer, default=100, nullable=False)',
            'max_active_users = Column(Integer, default=100, nullable=False)\n    traffic_limit = Column(BigInteger, default=None, nullable=True)'
        )
    
    # Add methods after recursive_sub_admins_ids
    if 'def recursive_sub_admins_ids(self' in content:
        lines = content.split('\n')
        insert_pos = -1
        for i, line in enumerate(lines):
            if 'def recursive_sub_admins_ids(self' in line:
                # Find end of method
                for j in range(i+1, len(lines)):
                    if lines[j].strip().startswith('def ') or lines[j].strip().startswith('class '):
                        if lines[j].strip().startswith('def ') and 'recursive_sub_admins_ids' not in lines[j]:
                            insert_pos = j
                            break
                        elif lines[j].strip().startswith('class '):
                            insert_pos = j
                            break
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
    
    with open(admin_py, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ admin.py patched")

# Patch AdminstratorAdmin.py
print("Patching AdminstratorAdmin.py...")
with open(adminstrator_admin_py, 'r', encoding='utf-8') as f:
    content = f.read()

if "'traffic_limit_GB'" in content and 'column_list' in content:
    print("Already patched")
else:
    # Add to column_list
    if "column_list = [" in content:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if "column_list = [" in line:
                for j in range(i, min(i+10, len(lines))):
                    if ']' in lines[j] and "'traffic_limit_GB'" not in lines[j]:
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        traffic_cols = " 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',"
                        lines[j] = ' ' * (indent + 4) + traffic_cols + '\n' + lines[j]
                        content = '\n'.join(lines)
                        break
                break
    
    # Add to form_columns
    if "form_columns = [" in content:
        lines = content.split('\n')
        for i, line in enumerate(lines):
            if "form_columns = [" in line:
                for j in range(i, min(i+15, len(lines))):
                    if ']' in lines[j] and "'traffic_limit_GB'" not in lines[j]:
                        indent = len(lines[j]) - len(lines[j].lstrip())
                        lines[j] = ' ' * (indent + 4) + "'traffic_limit_GB'," + '\n' + lines[j]
                        content = '\n'.join(lines)
                        break
                break
    
    # Add column_formatters
    if "column_formatters" not in content or "'traffic_limit_GB'" not in content:
        if "column_labels = {" in content:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if "column_labels = {" in line:
                    brace_count = 0
                    for j in range(i, len(lines)):
                        brace_count += lines[j].count('{') - lines[j].count('}')
                        if brace_count == 0 and '}' in lines[j]:
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
                            break
                    break
    
    with open(adminstrator_admin_py, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✓ AdminstratorAdmin.py patched")

print("All patches applied successfully")
PYTHON_SCRIPT
"$ADMIN_PY" "$ADMINSTRATOR_ADMIN_PY"

echo -e "${GREEN}✓ Patches applied${NC}"
echo ""

# Step 3: Add user creation hook
echo -e "${BLUE}Step 3: Adding user creation hook...${NC}"
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

# Import in __init__.py
ADMIN_INIT="$SOURCE_DIR/hiddifypanel/panel/admin/__init__.py"
if [ -f "$ADMIN_INIT" ] && ! grep -q "from .user_creation_hook import" "$ADMIN_INIT"; then
    sed -i '/^from \./a from .user_creation_hook import *  # Agent traffic management hooks' "$ADMIN_INIT"
fi

echo -e "${GREEN}✓ User creation hook added${NC}"
echo ""

# Step 4: Commit and push
echo -e "${BLUE}Step 4: Committing changes...${NC}"
cd "$CUSTOM_REPO_DIR"

git add -A
git commit -m "Add agent traffic management features" || echo "No changes to commit or already committed"

echo -e "${GREEN}✓ Changes committed${NC}"
echo ""

# Step 5: Push to user's repo
echo -e "${BLUE}Step 5: Pushing to GitHub...${NC}"
echo -e "${YELLOW}Note: Make sure you have set up the remote and have push access${NC}"

read -p "Do you want to push to GitHub now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git push origin main || git push origin master || echo -e "${YELLOW}Could not push. Please push manually.${NC}"
    echo -e "${GREEN}✓ Pushed to GitHub${NC}"
else
    echo -e "${YELLOW}Skipped push. You can push later with:${NC}"
    echo "  cd $CUSTOM_REPO_DIR"
    echo "  git push origin main"
fi

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Setup completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review changes in: $CUSTOM_REPO_DIR"
echo "2. If not pushed, create repo on GitHub and push:"
echo "   - Create repo: https://github.com/new"
echo "   - Name: $REPO_NAME"
echo "   - Then: cd $CUSTOM_REPO_DIR && git push -u origin main"
echo "3. Use this custom repo in your HiddifyPanel installation"
echo "4. Run database migration if needed"
echo "5. Restart hiddify-panel: systemctl restart hiddify-panel"

