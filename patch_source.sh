#!/bin/bash
# Script to apply agent traffic management changes directly to HiddifyPanel source

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
echo -e "${BLUE}Hiddify Agent Traffic Manager${NC}"
echo -e "${BLUE}Source Code Patcher${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

# Check if source exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${YELLOW}Source directory not found at: $SOURCE_DIR${NC}"
    echo -e "${YELLOW}Trying to find source...${NC}"
    
    # Try alternative locations
    SOURCE_DIR=$(find "$HIDDIFY_DIR" -type d -name "hiddifypanel" -path "*/src/hiddifypanel" 2>/dev/null | head -n1 | sed 's|/hiddifypanel$||')
    
    if [ -z "$SOURCE_DIR" ]; then
        echo -e "${RED}✗ Could not find HiddifyPanel source directory${NC}"
        echo -e "${YELLOW}Please clone the source first:${NC}"
        echo "  cd $HIDDIFY_DIR"
        echo "  git clone https://github.com/hiddify/HiddifyPanel.git hiddify-panel"
        exit 1
    fi
fi

echo -e "${GREEN}Found source at: $SOURCE_DIR${NC}"

# Check if it's a git repository
if [ -d "$SOURCE_DIR/.git" ]; then
    echo -e "${GREEN}✓ Git repository detected${NC}"
    echo -e "${YELLOW}Creating backup branch...${NC}"
    cd "$SOURCE_DIR"
    git checkout -b backup-before-agent-traffic-patch 2>/dev/null || echo "Backup branch may already exist"
    git checkout main 2>/dev/null || git checkout master 2>/dev/null || echo "Already on main branch"
else
    echo -e "${YELLOW}⚠ Not a git repository, creating backup...${NC}"
    BACKUP_DIR="${SOURCE_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    cp -r "$SOURCE_DIR" "$BACKUP_DIR"
    echo -e "${GREEN}✓ Backup created at: $BACKUP_DIR${NC}"
fi

echo ""
echo -e "${BLUE}Applying patches...${NC}"

# Get the patch files from this repository
PATCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PATCH_DIR"

# Apply patches
echo -e "${BLUE}Step 1: Patching models/admin.py...${NC}"
python3 << 'PYTHON_SCRIPT'
import sys
import os

source_file = sys.argv[1]
patch_file = sys.argv[2]

# Read source file
with open(source_file, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already patched
if 'traffic_limit' in content and 'Column(BigInteger' in content:
    print("Already patched")
    sys.exit(0)

# Add traffic_limit column after max_active_users
if 'max_active_users = Column' in content:
    content = content.replace(
        'max_active_users = Column(Integer, default=100, nullable=False)',
        'max_active_users = Column(Integer, default=100, nullable=False)\n    traffic_limit = Column(BigInteger, default=None, nullable=True)'
    )
    print("Added traffic_limit column")
else:
    print("Could not find insertion point")
    sys.exit(1)

# Add import if needed
if 'from sqlalchemy import' in content and 'BigInteger' not in content:
    import_line = [line for line in content.split('\n') if 'from sqlalchemy import' in line][0]
    if 'BigInteger' not in import_line:
        content = content.replace(
            import_line,
            import_line.replace('from sqlalchemy import', 'from sqlalchemy import BigInteger,') if ', ' in import_line else import_line + ', BigInteger'
        )
        print("Added BigInteger import")

# Add methods after recursive_sub_admins_ids
if 'def recursive_sub_admins_ids(self' in content:
    # Find the end of recursive_sub_admins_ids method
    lines = content.split('\n')
    insert_pos = -1
    for i, line in enumerate(lines):
        if 'def recursive_sub_admins_ids(self' in line:
            # Find the end of this method (next def or class)
            for j in range(i+1, len(lines)):
                if lines[j].strip().startswith('def ') and lines[j].strip() != line.strip():
                    insert_pos = j
                    break
                if lines[j].strip().startswith('class '):
                    insert_pos = j
                    break
            break
    
    if insert_pos > 0:
        # Add traffic management methods
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
with open(source_file, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied successfully")
PYTHON_SCRIPT
"$SOURCE_DIR/hiddifypanel/models/admin.py" "$PATCH_DIR/patches/admin.py.patch"

echo -e "${GREEN}✓ models/admin.py patched${NC}"

echo ""
echo -e "${BLUE}Step 2: Patching panel/admin/AdminstratorAdmin.py...${NC}"

# This will be done in a separate step
echo -e "${YELLOW}Manual patching required for AdminstratorAdmin.py${NC}"
echo -e "${YELLOW}Please see PATCH_INSTRUCTIONS.md for details${NC}"

echo ""
echo -e "${GREEN}==========================================${NC}"
echo -e "${GREEN}Patch completed!${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Review the changes in $SOURCE_DIR"
echo "2. Run database migration if needed"
echo "3. Restart hiddify-panel service"

