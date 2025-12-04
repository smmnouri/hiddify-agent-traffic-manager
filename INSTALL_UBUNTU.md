# راهنمای نصب در Ubuntu

این راهنما برای نصب ماژول Agent Traffic Manager در سرور Ubuntu با HiddifyPanel است.

## پیش‌نیازها

- Ubuntu 22.04 (یا بالاتر)
- HiddifyPanel نصب شده
- دسترسی root یا sudo
- Python 3.8+ و pip

## مراحل نصب

### مرحله 1: نصب ماژول

```bash
# رفتن به مسیر HiddifyPanel
cd /opt/hiddify-manager

# فعال‌سازی virtual environment
source .venv313/bin/activate

# کلون کردن repository
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git

# نصب ماژول
cd hiddify-agent-traffic-manager
pip install -e .
```

### مرحله 2: Integration با HiddifyPanel

بعد از نصب، باید ماژول را به HiddifyPanel اضافه کنید.

#### پیدا کردن فایل wsgi_app.py

```bash
# اگر از package نصب شده استفاده می‌کنید:
find /opt/hiddify-manager -name "wsgi_app.py" -type f

# یا اگر از source استفاده می‌کنید:
ls /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/apps/wsgi_app.py
```

#### ویرایش فایل wsgi_app.py

```bash
# باز کردن فایل با ویرایشگر (مثلاً nano)
nano /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/apps/wsgi_app.py
# یا
nano /opt/hiddify-manager/hiddify-panel/src/hiddifypanel/apps/wsgi_app.py
```

در ابتدای فایل، import را اضافه کنید:

```python
from hiddify_agent_traffic_manager import init_app
```

در تابع `create_app()`، قبل از return، این خط را اضافه کنید:

```python
def create_app():
    # ... کدهای موجود ...
    
    # Initialize agent traffic manager
    app = init_app(app)
    
    return app
```

#### مثال کامل:

```python
from hiddify_agent_traffic_manager import init_app

def create_app():
    app = create_app_base()  # یا هر تابعی که app اصلی را می‌سازد
    
    # ... سایر تنظیمات ...
    
    # Initialize agent traffic manager
    app = init_app(app)
    
    return app
```

### مرحله 3: Restart سرویس

```bash
# Restart HiddifyPanel
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks

# بررسی وضعیت
systemctl status hiddify-panel
```

### مرحله 4: بررسی نصب

```bash
# بررسی اینکه ماژول نصب شده است
python3 -c "import hiddify_agent_traffic_manager; print('Module installed successfully!')"

# بررسی لاگ‌ها
tail -f /opt/hiddify-manager/log/system/panel.log
```

## نصب خودکار (اسکریپت)

می‌توانید از اسکریپت زیر برای نصب خودکار استفاده کنید:

```bash
#!/bin/bash
set -e

echo "Installing Hiddify Agent Traffic Manager..."

# رفتن به مسیر HiddifyPanel
cd /opt/hiddify-manager

# فعال‌سازی virtual environment
source .venv313/bin/activate

# کلون کردن repository
if [ ! -d "hiddify-agent-traffic-manager" ]; then
    git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
fi

# نصب ماژول
cd hiddify-agent-traffic-manager
pip install -e .

echo "Installation completed!"
echo "Please edit wsgi_app.py to integrate the module (see INTEGRATION.md)"
```

## حذف نصب

```bash
cd /opt/hiddify-manager
source .venv313/bin/activate
pip uninstall hiddify-agent-traffic-manager -y
rm -rf hiddify-agent-traffic-manager
```

## مشکلات رایج

### مشکل: externally-managed-environment
**خطا**: `error: externally-managed-environment`

**راه‌حل**: در Ubuntu 22.04+ باید از pip از virtual environment استفاده کنید:

```bash
# به جای pip install، از pip از venv استفاده کنید:
/opt/hiddify-manager/.venv313/bin/pip install -e .

# یا venv را فعال کنید:
source /opt/hiddify-manager/.venv313/bin/activate
pip install -e .
```

**نکته**: هرگز از `--break-system-packages` استفاده نکنید!

### مشکل: ModuleNotFoundError
**راه‌حل**: مطمئن شوید که virtual environment فعال است و ماژول نصب شده است.

### مشکل: Permission denied
**راه‌حل**: از sudo استفاده کنید یا دسترسی‌های لازم را بررسی کنید.

### مشکل: Integration کار نمی‌کند
**راه‌حل**: 
1. مطمئن شوید که `init_app(app)` در `create_app()` فراخوانی شده است
2. سرویس را restart کنید
3. لاگ‌ها را بررسی کنید

## بررسی نصب موفق

بعد از نصب و Integration، می‌توانید با دستور زیر بررسی کنید:

```bash
# بررسی API endpoint
curl http://localhost:9000/api/v1/agent-traffic/agents/traffic
```

اگر پاسخ دریافت کردید، نصب موفق بوده است!

