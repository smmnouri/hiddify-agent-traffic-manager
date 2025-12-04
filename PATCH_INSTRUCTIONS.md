# راهنمای اعمال تغییرات در سورس اصلی HiddifyPanel

این راهنما نحوه اعمال تغییرات مدیریت ترافیک ایجنت‌ها را در سورس اصلی HiddifyPanel توضیح می‌دهد.

## مراحل

### 1. کلون کردن سورس HiddifyPanel

```bash
cd /opt/hiddify-manager
git clone https://github.com/hiddify/HiddifyPanel.git hiddify-panel
cd hiddify-panel
```

### 2. اعمال تغییرات در `models/admin.py`

فایل `hiddifypanel/models/admin.py` را ویرایش کنید:

#### 2.1. اضافه کردن import

در ابتدای فایل، بعد از import های موجود:

```python
from sqlalchemy import Column, BigInteger  # اضافه کردن BigInteger
```

#### 2.2. اضافه کردن column

در کلاس `AdminUser`، بعد از `max_active_users`:

```python
traffic_limit = Column(BigInteger, default=None, nullable=True)
```

#### 2.3. اضافه کردن methods

بعد از متد `recursive_sub_admins_ids`، این methods را اضافه کنید:

```python
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
```

### 3. اعمال تغییرات در `panel/admin/AdminstratorAdmin.py`

فایل `hiddifypanel/panel/admin/AdminstratorAdmin.py` را ویرایش کنید:

#### 3.1. اضافه کردن به column_list

در `column_list`، بعد از `'comment'`:

```python
column_list = ["name", 'UserLinks', 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'online_users', 'comment', 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status']
```

#### 3.2. اضافه کردن به form_columns

در `form_columns`، بعد از `'comment'`:

```python
form_columns = ["name", 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'comment', 'traffic_limit_GB', "uuid", "password"]
```

#### 3.3. اضافه کردن column_formatters

بعد از `column_labels`، این را اضافه کنید:

```python
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
```

### 4. اضافه کردن Hook برای بررسی قبل از ایجاد کاربر

فایل جدید `hiddifypanel/panel/admin/user_creation_hook.py` ایجاد کنید:

```python
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
```

و در `hiddifypanel/panel/admin/__init__.py`، در تابع `init_app`، بعد از import ها:

```python
from .user_creation_hook import *  # Import hooks
```

### 5. اضافه کردن Periodic Checker

در `hiddifypanel/panel/cli.py` یا فایل مناسب، یک task برای بررسی دوره‌ای اضافه کنید.

### 6. Database Migration

بعد از اعمال تغییرات، migration را اجرا کنید:

```bash
cd /opt/hiddify-manager/hiddify-panel
source ../.venv313/bin/activate
python -c "from hiddifypanel.database import db; from hiddifypanel.models.admin import AdminUser; from sqlalchemy import inspect; inspector = inspect(db.engine); columns = [c['name'] for c in inspector.get_columns('admin_user')]; print('traffic_limit' in columns)"
```

اگر `False` بود، column را اضافه کنید:

```python
from hiddifypanel.database import db
db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
db.session.commit()
```

### 7. Restart

```bash
systemctl restart hiddify-panel
```

## مزایای این روش

- ✅ یکپارچگی کامل با سورس اصلی
- ✅ بدون نیاز به extension system
- ✅ کنترل کامل بر تغییرات
- ✅ کمتر احتمال crash

## معایب

- ⚠️ در صورت آپدیت HiddifyPanel، باید تغییرات را دوباره اعمال کنید
- ⚠️ نیاز به دسترسی به سورس

