# لیست تغییرات مورد نیاز برای فرم AdminUser و Database

## 📋 خلاصه تغییرات

### 1. تغییرات در فرم AdminstratorAdmin (AdminstratorAdmin.py)

#### 1.1 افزودن فیلد به فرم (form_columns)
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن `'traffic_limit_GB'` به لیست `form_columns`
- **موقعیت**: بعد از `'max_active_users'` یا `'max_users'`
- **کد فعلی**:
  ```python
  form_columns = ["name", 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'comment', "uuid", "password"]
  ```
- **کد جدید**:
  ```python
  form_columns = ["name", 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'traffic_limit_GB', 'comment', "uuid", "password"]
  ```

#### 1.2 افزودن ستون‌ها به لیست نمایش (column_list)
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن ستون‌های ترافیک به `column_list`
- **ستون‌های جدید**:
  - `'traffic_limit_GB'`: حد ترافیک ایجنت (GB)
  - `'total_traffic'`: مجموع ترافیک مصرفی (GB)
  - `'remaining_traffic'`: ترافیک باقیمانده (GB)
  - `'traffic_status'`: وضعیت ترافیک (با progress bar)
- **کد فعلی**:
  ```python
  column_list = ["name", 'UserLinks', 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'online_users', 'comment',]
  ```
- **کد جدید**:
  ```python
  column_list = ["name", 'UserLinks', 'mode', 'can_add_admin', 'max_active_users', 'max_users', 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status', 'online_users', 'comment',]
  ```

#### 1.3 افزودن Custom Widget برای فیلد فرم
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن `TrafficLimitField` به `form_overrides`
- **کد فعلی**:
  ```python
  form_overrides = {
      'mode': AdminModeField,
      'parent_admin': SubAdminsField
  }
  ```
- **کد جدید**:
  ```python
  from hiddify_agent_traffic_manager.admin.agent_traffic_admin import TrafficLimitField
  
  form_overrides = {
      'mode': AdminModeField,
      'parent_admin': SubAdminsField,
      'traffic_limit_GB': TrafficLimitField
  }
  ```

#### 1.4 افزودن Label ها
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن label های فارسی/انگلیسی برای ستون‌های جدید
- **کد جدید**:
  ```python
  column_labels = {
      # ... existing labels ...
      'traffic_limit_GB': _('Traffic Limit (GB)'),
      'total_traffic': _('Total Traffic (GB)'),
      'remaining_traffic': _('Remaining Traffic (GB)'),
      'traffic_status': _('Traffic Status')
  }
  ```

#### 1.5 افزودن Formatters برای نمایش ستون‌ها
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن formatter های سفارشی برای نمایش ترافیک
- **کد جدید**:
  ```python
  from hiddify_agent_traffic_manager.admin.agent_traffic_admin import (
      _format_traffic_limit,
      _format_total_traffic,
      _format_remaining_traffic,
      _format_traffic_status
  )
  
  column_formatters = {
      # ... existing formatters ...
      'traffic_limit_GB': _format_traffic_limit,
      'total_traffic': _format_total_traffic,
      'remaining_traffic': _format_remaining_traffic,
      'traffic_status': _format_traffic_status
  }
  ```

#### 1.6 افزودن Form Args
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن تنظیمات فرم برای `traffic_limit_GB`
- **کد جدید**:
  ```python
  form_args = {
      'uuid': {
          'validators': [Regexp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', message=__("Should be a valid uuid"))]
      },
      'traffic_limit_GB': {
          'validators': [],
          'label': _('Traffic Limit (GB)'),
          'description': _('Maximum total traffic allowed for this agent and all its users (in GB). Leave empty for unlimited.')
      }
  }
  ```

#### 1.7 تغییر on_model_change برای ذخیره traffic_limit
- **فایل**: `hiddifypanel/panel/admin/AdminstratorAdmin.py`
- **تغییر**: افزودن منطق ذخیره `traffic_limit_GB` در `on_model_change`
- **کد جدید**:
  ```python
  def on_model_change(self, form, model, is_created):
      # ... existing code ...
      
      # Handle traffic_limit_GB
      if hasattr(form, 'traffic_limit_GB') and form.traffic_limit_GB.data is not None:
          from hiddifypanel.database import db
          traffic_limit_bytes = form.traffic_limit_GB.data
          db.session.execute(
              db.text("UPDATE admin_user SET traffic_limit = :limit WHERE id = :id"),
              {"limit": traffic_limit_bytes, "id": model.id}
          )
  ```

---

### 2. Database Migration (اسکریپت ALTER TABLE)

#### 2.1 ایجاد اسکریپت Migration
- **فایل جدید**: `hiddify-agent-traffic-manager/migrations/add_traffic_limit_column.sql`
- **توضیحات**: اسکریپت SQL برای افزودن ستون `traffic_limit` به جدول `admin_user`
- **کد**:
  ```sql
  -- Add traffic_limit column to admin_user table
  -- This column stores the traffic limit in bytes (BIGINT)
  -- NULL means unlimited traffic
  
  ALTER TABLE admin_user 
  ADD COLUMN IF NOT EXISTS traffic_limit BIGINT DEFAULT NULL 
  COMMENT 'Maximum traffic limit for agent in bytes (NULL = unlimited)';
  ```

#### 2.2 ایجاد اسکریپت Python برای Migration
- **فایل جدید**: `hiddify-agent-traffic-manager/migrations/add_traffic_limit_column.py`
- **توضیحات**: اسکریپت Python برای اجرای migration با بررسی وجود ستون
- **کد**:
  ```python
  """
  Migration script to add traffic_limit column to admin_user table
  """
  from hiddifypanel.database import db
  from loguru import logger
  
  def migrate():
      """Add traffic_limit column if it doesn't exist"""
      try:
          # Check if column exists
          inspector = db.inspect(db.engine)
          columns = [col['name'] for col in inspector.get_columns('admin_user')]
          
          if 'traffic_limit' not in columns:
              logger.info("Adding traffic_limit column to admin_user table...")
              db.session.execute(
                  db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL")
              )
              db.session.commit()
              logger.success("traffic_limit column added successfully")
              return True
          else:
              logger.debug("traffic_limit column already exists")
              return False
      except Exception as e:
          logger.error(f"Error adding traffic_limit column: {e}")
          db.session.rollback()
          return False
  
  if __name__ == '__main__':
      from hiddifypanel import create_app
      app = create_app()
      with app.app_context():
          migrate()
  ```

#### 2.3 ایجاد اسکریپت Bash برای اجرای Migration
- **فایل جدید**: `hiddify-agent-traffic-manager/migrations/run_migration.sh`
- **توضیحات**: اسکریپت bash برای اجرای migration
- **کد**:
  ```bash
  #!/bin/bash
  # Migration script to add traffic_limit column
  
  HIDDIFY_DIR="/opt/hiddify-manager"
  VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
  
  if [ ! -f "$VENV_PYTHON" ]; then
      echo "Error: Python virtual environment not found"
      exit 1
  fi
  
  cd "$(dirname "$0")"
  "$VENV_PYTHON" add_traffic_limit_column.py
  ```

---

## 📝 فایل‌های مورد نیاز برای Patch

### فایل‌های موجود که باید تغییر کنند:
1. `hiddifypanel/panel/admin/AdminstratorAdmin.py` - افزودن فیلدها و ستون‌ها

### فایل‌های جدید که باید ایجاد شوند:
1. `migrations/add_traffic_limit_column.sql` - اسکریپت SQL
2. `migrations/add_traffic_limit_column.py` - اسکریپت Python
3. `migrations/run_migration.sh` - اسکریپت Bash

---

## ✅ چک‌لیست اجرا

- [ ] Patch کردن `AdminstratorAdmin.py` با تغییرات فرم
- [ ] ایجاد اسکریپت SQL migration
- [ ] ایجاد اسکریپت Python migration
- [ ] ایجاد اسکریپت Bash برای اجرای migration
- [ ] تست فرم در صفحه `/admin/adminuser/`
- [ ] تست migration script
- [ ] بررسی نمایش ستون‌های ترافیک در لیست
- [ ] بررسی ذخیره `traffic_limit_GB` در دیتابیس

---

## 🔍 نکات مهم

1. **Import ها**: باید import های لازم برای `TrafficLimitField` و formatter ها اضافه شوند
2. **Compatibility**: تغییرات باید با کد موجود سازگار باشند
3. **Error Handling**: باید error handling مناسب برای migration وجود داشته باشد
4. **Backup**: قبل از اجرای migration باید backup گرفته شود

