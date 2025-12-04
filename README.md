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

### روش 1: نصب به عنوان ماژول

```bash
# کلون کردن ماژول
git clone <repository-url> hiddify-agent-traffic-manager

# نصب
cd hiddify-agent-traffic-manager
pip install -e .
```

### روش 2: نصب دستی

1. فایل‌های ماژول را در مسیر مناسب کپی کنید
2. در فایل `app.py` یا فایل اصلی HiddifyPanel، ماژول را import کنید:

```python
from hiddify_agent_traffic_manager import init_app

# در تابع create_app
app = create_app()
app = init_app(app)
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

## پشتیبانی

برای گزارش مشکل یا درخواست قابلیت جدید، لطفاً Issue ایجاد کنید.

