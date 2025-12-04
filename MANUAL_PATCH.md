# راهنمای اعمال دستی تغییرات

اگر اسکریپت‌های خودکار کار نکردند، می‌توانید تغییرات را به صورت دستی اعمال کنید.

## مرحله 1: پیدا کردن مسیر سورس

```bash
# پیدا کردن مسیر سورس
find /opt/hiddify-manager -name "AdminstratorAdmin.py" -type f 2>/dev/null
```

معمولاً مسیر یکی از این‌هاست:
- `/opt/hiddify-manager/hiddify-panel-custom/src/hiddifypanel/panel/admin/AdminstratorAdmin.py`
- `/opt/hiddify-manager/hiddify-panel/src/hiddifypanel/panel/admin/AdminstratorAdmin.py`

## مرحله 2: اعمال تغییرات به AdminstratorAdmin.py

```bash
# پیدا کردن فایل
ADMIN_FILE="/opt/hiddify-manager/hiddify-panel-custom/src/hiddifypanel/panel/admin/AdminstratorAdmin.py"
# یا
ADMIN_FILE="/opt/hiddify-manager/hiddify-panel/src/hiddifypanel/panel/admin/AdminstratorAdmin.py"

# Backup
cp "$ADMIN_FILE" "${ADMIN_FILE}.backup"

# ویرایش فایل
nano "$ADMIN_FILE"
```

### تغییر 1: اضافه کردن به column_list

پیدا کنید:
```python
column_list = ["name", 'UserLinks', 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'online_users', 'comment',]
```

تغییر دهید به:
```python
column_list = ["name", 'UserLinks', 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'online_users', 'comment', 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',]
```

### تغییر 2: اضافه کردن به form_columns

پیدا کنید:
```python
form_columns = ["name", 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'comment', "uuid", "password"]
```

تغییر دهید به:
```python
form_columns = ["name", 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'traffic_limit_GB', 'comment', "uuid", "password"]
```

## مرحله 3: اعمال تغییرات به models/admin.py

```bash
# پیدا کردن فایل
MODELS_FILE="/opt/hiddify-manager/hiddify-panel-custom/src/hiddifypanel/models/admin.py"
# یا
MODELS_FILE="/opt/hiddify-manager/hiddify-panel/src/hiddifypanel/models/admin.py"

# Backup
cp "$MODELS_FILE" "${MODELS_FILE}.backup"

# ویرایش فایل
nano "$MODELS_FILE"
```

### تغییر 1: اضافه کردن BigInteger به imports

پیدا کنید:
```python
from sqlalchemy import Column, Integer, Boolean, ForeignKey, Enum
```

تغییر دهید به:
```python
from sqlalchemy import Column, Integer, Boolean, ForeignKey, Enum, BigInteger
```

### تغییر 2: اضافه کردن traffic_limit column

پیدا کنید:
```python
max_active_users = Column(Integer, default=100, nullable=False)
users = db.relationship('User', backref='admin')
```

تغییر دهید به:
```python
max_active_users = Column(Integer, default=100, nullable=False)
traffic_limit = Column(BigInteger, default=None, nullable=True)
users = db.relationship('User', backref='admin')
```

## مرحله 4: نصب از سورس

```bash
# پیدا کردن مسیر src
cd /opt/hiddify-manager/hiddify-panel-custom/src
# یا
cd /opt/hiddify-manager/hiddify-panel/src

# نصب
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

## مرحله 5: Database Migration

```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
if 'traffic_limit' not in columns:
    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
    db.session.commit()
    print("Column added")
else:
    print("Column already exists")
EOF
```

## مرحله 6: Restart

```bash
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

## استفاده از اسکریپت ساده

یا می‌توانید از اسکریپت ساده استفاده کنید:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x apply_patches_direct.sh
bash apply_patches_direct.sh
```

بعد از این:
```bash
cd /opt/hiddify-manager/hiddify-panel-custom/src
/opt/hiddify-manager/.venv313/bin/pip install -e .
systemctl restart hiddify-panel
```

