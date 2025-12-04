# خلاصه ماژول Agent Traffic Manager

## ✅ قابلیت‌های پیاده‌سازی شده

### 1. محدودیت ترافیک برای ایجنت‌ها ✅
- فیلد `traffic_limit` به جدول `admin_user` اضافه می‌شود
- امکان تنظیم محدودیت ترافیک از طریق Admin Panel
- امکان تنظیم محدودیت ترافیک از طریق API

### 2. بررسی خودکار قبل از ایجاد کاربر ✅
- Hook در `User.before_insert` برای بررسی ترافیک
- بررسی اینکه مجموع ترافیک + ترافیک کاربر جدید از حد مجاز تجاوز نکند
- جلوگیری از ایجاد کاربر در صورت تجاوز

### 3. بررسی دوره‌ای و غیرفعال‌سازی خودکار ✅
- Background Task (Celery) هر 5 دقیقه یکبار اجرا می‌شود
- بررسی ترافیک تمام ایجنت‌ها
- غیرفعال‌سازی خودکار تمام کاربران ایجنت در صورت تجاوز از حد

### 4. API Endpoints ✅
- `GET /api/v1/agent-traffic/agents/<id>/traffic` - دریافت آمار ترافیک
- `PUT /api/v1/agent-traffic/agents/<id>/traffic-limit` - تنظیم محدودیت
- `GET /api/v1/agent-traffic/agents/traffic` - لیست تمام ایجنت‌ها
- `POST /api/v1/agent-traffic/agents/<id>/check` - بررسی یک ایجنت
- `POST /api/v1/agent-traffic/agents/check-all` - بررسی تمام ایجنت‌ها
- `POST /api/v1/agent-traffic/agents/<id>/can-create-user` - بررسی امکان ایجاد کاربر

### 5. Admin Interface ✅
- Extension برای AdminUser view
- فیلد `traffic_limit_GB` در فرم AdminUser
- ستون‌های نمایش ترافیک در لیست ایجنت‌ها
- Action برای بررسی ترافیک

### 6. Utility Functions ✅
- `AgentTrafficCalculator`: محاسبه ترافیک ایجنت‌ها
- `AgentTrafficChecker`: بررسی محدودیت‌ها
- متدهای اضافه شده به `AdminUser`:
  - `traffic_limit_GB` (property)
  - `get_total_traffic()` / `get_total_traffic_GB()`
  - `get_remaining_traffic()` / `get_remaining_traffic_GB()`
  - `can_create_user_with_traffic()`
  - `is_traffic_limit_exceeded()`
  - `disable_all_users()`

## 📁 ساختار فایل‌ها

```
hiddify-agent-traffic-manager/
├── __init__.py                    # نقطه ورود و init_app()
├── models/
│   └── agent_traffic.py          # Extension برای AdminUser + Migration
├── utils/
│   ├── traffic_calculator.py     # محاسبه ترافیک
│   ├── traffic_checker.py       # بررسی محدودیت‌ها
│   └── user_creation_hook.py     # Hook برای User creation
├── tasks/
│   └── periodic_checker.py      # Background task (Celery)
├── admin/
│   └── agent_traffic_admin.py   # Admin interface extension
├── api/
│   └── agent_traffic_api.py     # API endpoints
├── setup.py                      # Package setup
├── README.md                     # مستندات اصلی
├── INTEGRATION.md                # راهنمای Integration
├── example_usage.py              # مثال‌های استفاده
└── .gitignore                    # Git ignore file
```

## 🔧 نحوه استفاده

### نصب
```python
from hiddify_agent_traffic_manager import init_app

app = create_app()
app = init_app(app)
```

### تنظیم محدودیت ترافیک
```python
agent = AdminUser.query.get(agent_id)
agent.traffic_limit_GB = 1000  # 1000 GB
```

### بررسی ترافیک
```python
total = agent.get_total_traffic_GB()
remaining = agent.get_remaining_traffic_GB()
is_exceeded = agent.is_traffic_limit_exceeded()
```

## ⚙️ تنظیمات

- **فاصله زمانی بررسی دوره‌ای**: هر 5 دقیقه (قابل تغییر در `tasks/periodic_checker.py`)
- **Migration**: به صورت خودکار اجرا می‌شود

## 📝 نکات مهم

1. ماژول به صورت خودکار فیلد `traffic_limit` را به دیتابیس اضافه می‌کند
2. Hook ها به صورت خودکار در `init_app()` تنظیم می‌شوند
3. Background Task نیاز به Celery دارد
4. تمام متدها به `AdminUser` اضافه می‌شوند و فقط برای ایجنت‌ها کار می‌کنند

## 🚀 آماده استفاده

ماژول آماده استفاده است و تمام قابلیت‌های درخواستی پیاده‌سازی شده‌اند.

