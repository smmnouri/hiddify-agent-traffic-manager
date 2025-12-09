# راهنمای نصب سیستم Agent/Reseller

این راهنما برای نصب سیستم Agent/Reseller در HiddifyPanel است.

## 📋 پیش‌نیازها

- HiddifyPanel نصب شده
- دسترسی به دیتابیس
- دسترسی root یا sudo

## 🚀 روش نصب

### روش 1: نصب از Source (توصیه می‌شود)

```bash
# 1. رفتن به دایرکتوری HiddifyPanel
cd /opt/hiddify-manager/hiddify-panel

# 2. دریافت آخرین تغییرات (اگر از git استفاده می‌کنید)
git pull origin main

# 3. نصب از source
source .venv313/bin/activate  # یا .venv/bin/activate
pip install -e .

# 4. اجرای migration (به صورت خودکار اجرا می‌شود)
# یا دستی:
hiddify-panel-cli init-db

# 5. راه‌اندازی مجدد سرویس
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

### روش 2: نصب با Patch

اگر می‌خواهید فقط فایل‌های جدید را اضافه کنید:

```bash
# 1. کپی فایل‌های جدید
cp hiddifypanel/models/agent.py /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/models/
cp hiddifypanel/services/traffic_service.py /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/services/
cp hiddifypanel/services/__init__.py /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/services/
cp hiddifypanel/panel/commercial/restapi/v2/admin/agent_api.py /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/panel/commercial/restapi/v2/admin/

# 2. Patch کردن فایل‌های موجود
# (باید فایل‌های __init__.py, user.py, init_db.py, users_api.py, user_api.py را patch کنید)

# 3. راه‌اندازی مجدد
systemctl restart hiddify-panel
```

## ✅ بررسی نصب

### 1. بررسی Migration

```bash
# بررسی version دیتابیس
hiddify-panel-cli get-config db_version

# باید 121 یا بالاتر باشد
```

### 2. بررسی جداول

```bash
# اتصال به دیتابیس
mysql -u hiddifypanel -p hiddifypanel

# بررسی جداول
SHOW TABLES LIKE 'agent';
SHOW TABLES LIKE 'traffic_log';
DESCRIBE user;  # باید agent_id را ببینید
```

### 3. بررسی API

```bash
# تست API endpoint
curl -X GET "http://localhost:9000/api/v2/admin/agent/" \
  -H "Authorization: Bearer YOUR_TOKEN"

# باید لیست خالی یا لیست Agent ها را برگرداند
```

## 🔧 تنظیمات

### ایجاد Agent اول

```python
from hiddifypanel.models import Agent
from hiddifypanel.database import db

agent = Agent(
    name="Agent 1",
    username="agent1",
    password="password123",
    traffic_limit_GB=1000  # 1000 GB
)
db.session.add(agent)
db.session.commit()
```

یا از API:

```bash
curl -X POST "http://localhost:9000/api/v2/admin/agent/" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Agent 1",
    "username": "agent1",
    "password": "password123",
    "traffic_limit_GB": 1000
  }'
```

## 🐛 عیب‌یابی

### مشکل: Migration اجرا نمی‌شود

```bash
# بررسی فایل init_db.py
grep "MAX_DB_VERSION" /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/panel/init_db.py
# باید 121 باشد

# بررسی function _v121
grep "_v121" /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/panel/init_db.py
```

### مشکل: جداول ایجاد نشده

```bash
# اجرای دستی migration
cd /opt/hiddify-manager/hiddify-panel
source .venv313/bin/activate
python -c "from hiddifypanel.panel.init_db import init_db; init_db()"
```

### مشکل: API کار نمی‌کند

```bash
# بررسی لاگ
journalctl -u hiddify-panel -n 100 --no-pager

# بررسی import
python -c "from hiddifypanel.models import Agent; print('OK')"
python -c "from hiddifypanel.services.traffic_service import update_agent_traffic; print('OK')"
```

## 📚 مستندات بیشتر

برای اطلاعات بیشتر، فایل `AGENT_SYSTEM_README.md` را مطالعه کنید.

## 🔄 به‌روزرسانی

برای به‌روزرسانی سیستم:

```bash
cd /opt/hiddify-manager/hiddify-panel
git pull
pip install -e .
systemctl restart hiddify-panel
```

## ⚠️ نکات مهم

1. **Backup**: قبل از نصب، از دیتابیس backup بگیرید
2. **Migration**: Migration به صورت خودکار اجرا می‌شود
3. **Compatibility**: این سیستم با HiddifyPanel v2.2.0+ سازگار است
4. **Performance**: Event listeners ممکن است کمی performance را کاهش دهند

## 📞 پشتیبانی

در صورت بروز مشکل، لاگ‌ها را بررسی کنید:

```bash
journalctl -u hiddify-panel -f
```

