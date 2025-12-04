# Hiddify Agent Traffic Manager

ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها در HiddifyPanel

## ویژگی‌ها

- ✅ **محدودیت ترافیک برای ایجنت‌ها**: امکان تعیین حد مجاز ترافیک برای هر ایجنت در داشبورد ادمین
- ✅ **بررسی خودکار قبل از ایجاد کاربر**: سیستم به صورت خودکار قبل از ایجاد کاربر جدید، ترافیک ایجنت را بررسی می‌کند
- ✅ **غیرفعال‌سازی خودکار**: در صورت تجاوز از حد مجاز، تمام کاربران ایجنت به صورت خودکار غیرفعال می‌شوند
- ✅ **بررسی دوره‌ای**: یک Background Task به صورت دوره‌ای (هر 5 دقیقه) ترافیک ایجنت‌ها را بررسی می‌کند
- ✅ **API Endpoints**: API کامل برای مدیریت و بررسی ترافیک ایجنت‌ها
- ✅ **Admin Interface**: رابط کاربری در داشبورد ادمین برای مدیریت ترافیک

## نصب

### نصب یک خطی (ساده‌ترین روش) ⭐⭐⭐

برای نصب HiddifyPanel با قابلیت‌های مدیریت ترافیک ایجنت از repository شما:

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
```

یا اگر repository دیگری دارید:

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh) YOUR_USERNAME YOUR_REPO_NAME
```

این دستور:
- ✅ Hiddify-Manager را نصب می‌کند (اگر نصب نباشد)
- ✅ Repository سفارشی شما را کلون می‌کند
- ✅ اگر repository وجود نداشت، آن را می‌سازد و patches را اعمال می‌کند
- ✅ HiddifyPanel را از repository شما نصب می‌کند
- ✅ Database migration انجام می‌دهد
- ✅ سرویس‌ها را restart می‌کند

**نکته**: اگر repository شما وجود نداشته باشد، اسکریپت به صورت خودکار آن را می‌سازد و patches را اعمال می‌کند.

### روش 2: ایجاد Repository سفارشی خودتان ⭐⭐

این روش یک repository سفارشی از HiddifyPanel با تغییرات اعمال شده برای شما می‌سازد:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x setup_custom_repo.sh
bash setup_custom_repo.sh
```

این اسکریپت:
- ✅ HiddifyPanel را کلون می‌کند
- ✅ Remote را به repository شما تغییر می‌دهد
- ✅ تمام تغییرات را اعمال می‌کند
- ✅ به repository شما commit و push می‌کند

**بعد از این، می‌توانید از repository خودتان استفاده کنید!**

### روش 2: اعمال در سورس محلی

اگر می‌خواهید تغییرات را در سورس محلی اعمال کنید:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x apply_to_source.sh
bash apply_to_source.sh
systemctl restart hiddify-panel
```

این اسکریپت به صورت خودکار:
- ✅ سورس HiddifyPanel را پیدا می‌کند (یا کلون می‌کند)
- ✅ Backup می‌گیرد
- ✅ تغییرات را در `models/admin.py` اعمال می‌کند
- ✅ تغییرات را در `panel/admin/AdminstratorAdmin.py` اعمال می‌کند
- ✅ User creation hook اضافه می‌کند
- ✅ Database migration انجام می‌دهد

**برای جزئیات بیشتر، فایل [PATCH_INSTRUCTIONS.md](PATCH_INSTRUCTIONS.md) را مطالعه کنید.**

### روش 2: نصب به عنوان Extension (قدیمی)

برای نصب خودکار که شامل کلون کردن و نصب کامل می‌شود، فقط یک دستور کافی است:

```bash
cd /opt/hiddify-manager && bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/auto_install.sh)
```

یا اگر `curl` ندارید:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash auto_install.sh
```

این اسکریپت به صورت خودکار:
- ✅ Repository را کلون می‌کند (یا به‌روز می‌کند)
- ✅ ماژول را نصب می‌کند
- ✅ با HiddifyPanel یکپارچه می‌کند
- ✅ سرویس را restart می‌کند

### نصب دستی در Ubuntu (HiddifyPanel)

اگر می‌خواهید به صورت دستی نصب کنید:

```bash
# 1. رفتن به مسیر HiddifyPanel
cd /opt/hiddify-manager

# 2. کلون کردن ماژول
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git

# 3. نصب ماژول
cd hiddify-agent-traffic-manager
bash install_complete.sh
```

این اسکریپت (`install_complete.sh`) همه مراحل را خودکار انجام می‌دهد.

### Integration با HiddifyPanel

بعد از نصب، باید ماژول را به HiddifyPanel اضافه کنید. فایل `wsgi_app.py` را ویرایش کنید:

```python
# در تابع create_app() یا wsgi_app.py
from hiddify_agent_traffic_manager import init_app

def create_app():
    app = create_app_base()  # یا هر تابعی که app اصلی را می‌سازد
    
    # Initialize agent traffic manager
    app = init_app(app)
    
    return app
```

**مسیر فایل‌های HiddifyPanel:**
- اگر از package نصب شده: `/opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/apps/wsgi_app.py`
- اگر از source: `/opt/hiddify-manager/hiddify-panel/src/hiddifypanel/apps/wsgi_app.py`

### نصب از PyPI (اگر منتشر شود)

```bash
pip install hiddify-agent-traffic-manager
```

### نصب دستی

1. فایل‌های ماژول را در مسیر مناسب کپی کنید
2. در فایل `app.py` یا فایل اصلی HiddifyPanel، ماژول را import کنید:

```python
from hiddify_agent_traffic_manager import init_app

# در تابع create_app
app = create_app()
app = init_app(app)
```

### راهنمای کامل Integration

برای راهنمای کامل Integration با HiddifyPanel، فایل [INTEGRATION.md](INTEGRATION.md) را مطالعه کنید.

### رفع مشکلات (Troubleshooting)

اگر بعد از نصب با مشکل مواجه شدید:

#### 1. بررسی و رفع مشکلات Integration

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
bash fix_integration.sh
```

این اسکریپت:
- ✓ base.py را از backup restore می‌کند (اگر syntax error داشته باشد)
- ✓ بررسی می‌کند که integration درست انجام شده یا نه
- ✓ خطاهای syntax را نشان می‌دهد

#### 2. Restore دستی base.py

اگر `base.py` syntax error دارد:

```bash
# پیدا کردن آخرین backup
ls -lt /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py.backup.* | head -1

# Restore (مثال)
cp /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py.backup.20251204_221727 \
   /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py

# سپس دوباره نصب کنید
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
bash install_complete.sh
```

#### 3. بررسی لاگ‌ها

```bash
# بررسی لاگ پنل
tail -f /opt/hiddify-manager/log/system/panel.log

# بررسی سرویس
systemctl status hiddify-panel
journalctl -u hiddify-panel -n 50
```

#### 4. نصب مجدد

اگر همه چیز fail شد:

```bash
cd /opt/hiddify-manager
rm -rf hiddify-agent-traffic-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash install_complete.sh
```

## استفاده

### تنظیم محدودیت ترافیک برای ایجنت

#### از طریق Admin Panel:
1. به بخش "Administrators" بروید
2. ایجنت مورد نظر را انتخاب کنید
3. در فیلد "Traffic Limit (GB)" مقدار مورد نظر را وارد کنید
4. ذخیره کنید

#### از طریق API:
```bash
curl -X PUT http://your-panel/api/v1/agent-traffic/agents/2/traffic-limit \
  -H "Content-Type: application/json" \
  -d '{"traffic_limit_GB": 1000}'
```

### بررسی ترافیک یک ایجنت

```bash
curl http://your-panel/api/v1/agent-traffic/agents/2/traffic
```

### بررسی اینکه آیا می‌توان کاربر جدید ایجاد کرد

```bash
curl -X POST http://your-panel/api/v1/agent-traffic/agents/2/can-create-user \
  -H "Content-Type: application/json" \
  -d '{"user_traffic_limit_GB": 50}'
```

## API Endpoints

### `GET /api/v1/agent-traffic/agents/<agent_id>/traffic`
دریافت آمار ترافیک یک ایجنت

### `PUT /api/v1/agent-traffic/agents/<agent_id>/traffic-limit`
تنظیم محدودیت ترافیک برای یک ایجنت

**Body:**
```json
{
  "traffic_limit_GB": 1000
}
```

### `GET /api/v1/agent-traffic/agents/traffic`
دریافت ترافیک تمام ایجنت‌ها

### `POST /api/v1/agent-traffic/agents/<agent_id>/check`
بررسی ترافیک یک ایجنت و غیرفعال‌سازی در صورت تجاوز

### `POST /api/v1/agent-traffic/agents/check-all`
بررسی ترافیک تمام ایجنت‌ها

### `POST /api/v1/agent-traffic/agents/<agent_id>/can-create-user`
بررسی اینکه آیا ایجنت می‌تواند کاربر جدید ایجاد کند

**Body:**
```json
{
  "user_traffic_limit_GB": 50
}
```

## نحوه کار

### 1. بررسی قبل از ایجاد کاربر
هنگامی که یک ایجنت می‌خواهد کاربر جدید ایجاد کند:
- سیستم به صورت خودکار مجموع ترافیک مصرفی کاربران موجود را محاسبه می‌کند
- اگر مجموع ترافیک + ترافیک کاربر جدید از حد مجاز تجاوز کند، ایجاد کاربر مسدود می‌شود

### 2. بررسی دوره‌ای
یک Background Task (Celery) هر 5 دقیقه یکبار:
- ترافیک تمام ایجنت‌ها را بررسی می‌کند
- اگر ترافیک از حد مجاز تجاوز کرده باشد، تمام کاربران آن ایجنت را غیرفعال می‌کند

### 3. محاسبه ترافیک
ترافیک محاسبه شده شامل:
- مجموع `current_usage` تمام کاربران ایجاد شده توسط ایجنت
- شامل کاربران ایجاد شده توسط sub-admins نیز می‌شود

## ساختار فایل‌ها

```
hiddify-agent-traffic-manager/
├── __init__.py                 # نقطه ورود ماژول
├── models/
│   └── agent_traffic.py        # Extension برای AdminUser
├── utils/
│   ├── traffic_calculator.py  # محاسبه ترافیک
│   ├── traffic_checker.py     # بررسی ترافیک
│   └── user_creation_hook.py   # Hook برای User creation
├── tasks/
│   └── periodic_checker.py     # Background task
├── admin/
│   └── agent_traffic_admin.py  # Admin interface
└── api/
    └── agent_traffic_api.py    # API endpoints
```

## Migration

ماژول به صورت خودکار فیلد `traffic_limit` را به جدول `admin_user` اضافه می‌کند. نیازی به اجرای migration دستی نیست.

## تنظیمات

### تغییر فاصله زمانی بررسی دوره‌ای

در فایل `tasks/periodic_checker.py`:

```python
'schedule': crontab(minute='*/5'),  # هر 5 دقیقه
```

را به مقدار مورد نظر تغییر دهید.

## مشکلات و راه‌حل

### مشکل: فیلد traffic_limit اضافه نمی‌شود
**راه‌حل**: دسترسی به دیتابیس را بررسی کنید. ماژول باید بتواند ALTER TABLE را اجرا کند.

### مشکل: Hook کار نمی‌کند
**راه‌حل**: مطمئن شوید که `init_user_creation_hook()` در `init_app()` فراخوانی شده است.

### مشکل: Background Task اجرا نمی‌شود
**راه‌حل**: مطمئن شوید که Celery نصب و اجرا شده است.

## توسعه

برای توسعه ماژول:

```bash
# نصب در حالت development
pip install -e ".[dev]"

# اجرای تست‌ها
pytest
```

## مجوز

این ماژول تحت مجوز GPL-3.0 منتشر شده است.

## نصب سریع (یک خطی)

### روش 1: نصب کامل خودکار (توصیه می‌شود) ⭐⭐⭐

این اسکریپت **همه چیز** را از ابتدا تا انتها خودکار انجام می‌دهد:
- کلون کردن repository
- نصب pip (اگر نباشد)
- نصب ماژول
- Integration با HiddifyPanel
- Restart سرویس‌ها

```bash
cd /opt/hiddify-manager && bash -c "$(curl -sSL https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install_complete.sh)" || (git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git && cd hiddify-agent-traffic-manager && bash install_complete.sh)
```

یا به صورت ساده:

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash install_complete.sh
```

### روش 2: نصب خودکار (auto_install.sh)

```bash
cd /opt/hiddify-manager && git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git && cd hiddify-agent-traffic-manager && bash auto_install.sh
```

### روش 2: استفاده از اسکریپت نصب ساده

```bash
cd /opt/hiddify-manager && git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git && cd hiddify-agent-traffic-manager && bash install.sh
```

### روش 2: دستورات دستی

```bash
cd /opt/hiddify-manager
source .venv313/bin/activate
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
pip install -e .
```

**توجه**: اگر خطای `externally-managed-environment` دریافت کردید، از pip از venv استفاده کنید:
```bash
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

**توجه**: بعد از نصب، باید ماژول را به HiddifyPanel اضافه کنید (بخش Integration را ببینید).

برای راهنمای کامل نصب در Ubuntu، فایل [INSTALL_UBUNTU.md](INSTALL_UBUNTU.md) را مطالعه کنید.

## پشتیبانی

برای گزارش مشکل یا درخواست قابلیت جدید، لطفاً Issue ایجاد کنید:

**Repository**: https://github.com/smmnouri/hiddify-agent-traffic-manager

