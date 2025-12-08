# راهنمای Patch و Migration

این فایل راهنمای استفاده از اسکریپت‌های patch و migration برای افزودن قابلیت مدیریت ترافیک به HiddifyPanel است.

## 📋 فایل‌های ایجاد شده

### 1. Patch Scripts
- **`patches/patch_adminstrator_admin.py`**: اسکریپت Python برای patch کردن `AdminstratorAdmin.py`
  - افزودن فیلد `traffic_limit_GB` به فرم
  - افزودن ستون‌های ترافیک به لیست نمایش
  - افزودن formatter ها و label ها

### 2. Migration Scripts
- **`migrations/add_traffic_limit_column.sql`**: اسکریپت SQL برای افزودن ستون `traffic_limit`
- **`migrations/add_traffic_limit_column.py`**: اسکریپت Python برای اجرای migration با بررسی وجود ستون
- **`migrations/run_migration.sh`**: اسکریپت Bash برای اجرای آسان migration

### 3. Main Script
- **`apply_patches_direct.sh`**: اسکریپت اصلی که همه patch ها و migration را اعمال می‌کند

## 🚀 نحوه استفاده

### روش 1: استفاده از اسکریپت اصلی (توصیه می‌شود)

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash apply_patches_direct.sh
```

این اسکریپت به صورت خودکار:
1. دایرکتوری source را پیدا می‌کند
2. فایل‌های مورد نیاز را patch می‌کند
3. migration را اجرا می‌کند

### روش 2: اجرای دستی

#### Step 1: Patch کردن AdminstratorAdmin.py

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
python3 patches/patch_adminstrator_admin.py /path/to/hiddifypanel/panel/admin/AdminstratorAdmin.py
```

#### Step 2: اجرای Migration

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
bash migrations/run_migration.sh
```

یا مستقیماً با Python:

```bash
cd /opt/hiddify-manager
source .venv313/bin/activate  # یا .venv/bin/activate
cd hiddify-agent-traffic-manager
python migrations/add_traffic_limit_column.py
```

## 📝 تغییرات اعمال شده

### 1. AdminstratorAdmin.py

#### افزودن Import
```python
from hiddify_agent_traffic_manager.admin.agent_traffic_admin import TrafficLimitField
```

#### تغییر form_columns
```python
form_columns = [..., 'max_active_users', 'max_users', 'traffic_limit_GB', ...]
```

#### تغییر column_list
```python
column_list = [..., 'max_users', 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status', ...]
```

#### افزودن form_overrides
```python
form_overrides = {
    ...,
    'traffic_limit_GB': TrafficLimitField
}
```

#### افزودن column_labels
```python
column_labels = {
    ...,
    'traffic_limit_GB': _('Traffic Limit (GB)'),
    'total_traffic': _('Total Traffic (GB)'),
    'remaining_traffic': _('Remaining Traffic (GB)'),
    'traffic_status': _('Traffic Status')
}
```

#### افزودن column_formatters
```python
column_formatters = {
    ...,
    'traffic_limit_GB': _format_traffic_limit,
    'total_traffic': _format_total_traffic,
    'remaining_traffic': _format_remaining_traffic,
    'traffic_status': _format_traffic_status
}
```

#### تغییر on_model_change
افزودن منطق ذخیره `traffic_limit_GB` در دیتابیس

### 2. Database Migration

افزودن ستون `traffic_limit` به جدول `admin_user`:
```sql
ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL
```

## ✅ بررسی صحت اعمال تغییرات

### بررسی Patch

```bash
# بررسی وجود فیلد در form_columns
grep -q "traffic_limit_GB" /path/to/AdminstratorAdmin.py && echo "✓ Form field added" || echo "✗ Form field missing"

# بررسی وجود ستون‌ها در column_list
grep -q "'traffic_limit_GB', 'total_traffic'" /path/to/AdminstratorAdmin.py && echo "✓ Columns added" || echo "✗ Columns missing"
```

### بررسی Migration

```bash
# برای SQLite
sqlite3 /opt/hiddify-manager/config/hiddify-panel.db "PRAGMA table_info(admin_user);" | grep traffic_limit

# برای MySQL/MariaDB
mysql -u root -p -e "DESCRIBE admin_user;" | grep traffic_limit
```

## 🔄 بازگردانی تغییرات

### بازگردانی Patch

```bash
# پیدا کردن backup
ls -la /path/to/AdminstratorAdmin.py.backup.*

# بازگردانی
cp /path/to/AdminstratorAdmin.py.backup.YYYYMMDD_HHMMSS /path/to/AdminstratorAdmin.py
```

### بازگردانی Migration

```sql
-- حذف ستون (مراقب باشید!)
ALTER TABLE admin_user DROP COLUMN traffic_limit;
```

## ⚠️ نکات مهم

1. **Backup**: همیشه قبل از patch کردن backup بگیرید
2. **Test**: بعد از patch کردن، حتماً تست کنید
3. **Restart**: بعد از تغییرات، سرویس‌ها را restart کنید:
   ```bash
   systemctl restart hiddify-panel hiddify-panel-background-tasks
   ```
4. **Compatibility**: این patch ها برای HiddifyPanel نسخه‌های جدید طراحی شده‌اند

## 🐛 عیب‌یابی

### مشکل: Patch اعمال نشد

```bash
# بررسی وجود فایل
ls -la patches/patch_adminstrator_admin.py

# اجرای دستی با verbose
python3 -u patches/patch_adminstrator_admin.py /path/to/AdminstratorAdmin.py
```

### مشکل: Migration اجرا نشد

```bash
# بررسی دسترسی به دیتابیس
python3 migrations/add_traffic_limit_column.py

# بررسی لاگ‌ها
journalctl -u hiddify-panel -n 50
```

### مشکل: ستون قبلاً وجود دارد

این مشکل نیست! اسکریپت migration به صورت خودکار بررسی می‌کند و اگر ستون وجود داشته باشد، کاری انجام نمی‌دهد.

## 📞 پشتیبانی

اگر مشکلی پیش آمد، لاگ‌ها را بررسی کنید و در صورت نیاز issue ایجاد کنید.

