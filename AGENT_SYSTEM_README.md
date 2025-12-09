# سیستم Agent/Reseller برای HiddifyPanel

این سیستم یک سیستم کامل مدیریت Agent/Reseller برای HiddifyPanel است که شامل:

## 🎯 ویژگی‌ها

1. **مدیریت Agent**: ایجاد، ویرایش، حذف و لیست Agent ها
2. **مدیریت ترافیک**: سقف ترافیک برای هر Agent و محاسبه خودکار مصرف
3. **محدودیت‌ها**: جلوگیری از ایجاد کاربر جدید یا افزایش ترافیک در صورت اتمام سقف
4. **لاگ ترافیک**: ثبت تمام مصرف ترافیک در جدول `traffic_log`
5. **API کامل**: API endpoints برای تمام عملیات‌ها

## 📁 ساختار فایل‌ها

### مدل‌های دیتابیس
- `hiddifypanel/models/agent.py`: مدل‌های `Agent` و `TrafficLog`
- `hiddifypanel/models/user.py`: فیلد `agent_id` به `User` اضافه شده

### API Endpoints
- `hiddifypanel/panel/commercial/restapi/v2/admin/agent_api.py`: API endpoints برای Agent
  - `GET /api/v2/admin/agent/`: لیست تمام Agent ها
  - `POST /api/v2/admin/agent/`: ایجاد Agent جدید
  - `GET /api/v2/admin/agent/<uuid>/`: دریافت اطلاعات Agent
  - `PATCH /api/v2/admin/agent/<uuid>/`: به‌روزرسانی Agent
  - `DELETE /api/v2/admin/agent/<uuid>/`: حذف Agent
  - `GET /api/v2/admin/agent/<uuid>/traffic/`: آمار ترافیک Agent

### سرویس‌ها
- `hiddifypanel/services/traffic_service.py`: سرویس مدیریت ترافیک
  - `update_agent_traffic()`: به‌روزرسانی ترافیک Agent
  - `log_user_traffic()`: ثبت لاگ ترافیک کاربر
  - `check_agent_can_create_user()`: بررسی امکان ایجاد کاربر
  - `check_agent_can_update_user_traffic()`: بررسی امکان به‌روزرسانی ترافیک

### Migration
- `hiddifypanel/panel/init_db.py`: Migration v121 برای ایجاد جداول و فیلدها

## 🗄️ ساختار دیتابیس

### جدول `agent`
```sql
CREATE TABLE agent (
    id INTEGER PRIMARY KEY,
    uuid VARCHAR(36) UNIQUE NOT NULL,
    name VARCHAR(512) NOT NULL,
    username VARCHAR(100),
    password VARCHAR(100),
    comment VARCHAR(512),
    telegram_id BIGINT,
    lang VARCHAR(10),
    traffic_limit BIGINT,  -- NULL = unlimited
    traffic_used BIGINT NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL,
    updated_at DATETIME NOT NULL
);
```

### جدول `traffic_log`
```sql
CREATE TABLE traffic_log (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    agent_id INTEGER,
    used_traffic BIGINT NOT NULL,
    timestamp DATETIME NOT NULL,
    description VARCHAR(512),
    FOREIGN KEY (user_id) REFERENCES user (id),
    FOREIGN KEY (agent_id) REFERENCES agent (id)
);
```

### فیلد جدید در `user`
```sql
ALTER TABLE user ADD COLUMN agent_id INTEGER;
```

## 🔧 نصب و راه‌اندازی

1. **Migration**: سیستم به صورت خودکار migration v121 را اجرا می‌کند
2. **Import مدل‌ها**: مدل‌ها در `hiddifypanel/models/__init__.py` import شده‌اند
3. **ثبت API**: API endpoints در `hiddifypanel/panel/commercial/restapi/v2/admin/__init__.py` ثبت شده‌اند

## 📝 استفاده

### ایجاد Agent
```python
from hiddifypanel.models import Agent

agent = Agent(
    name="Agent 1",
    username="agent1",
    password="password123",
    traffic_limit_GB=1000  # 1000 GB limit
)
db.session.add(agent)
db.session.commit()
```

### اختصاص Agent به کاربر
```python
from hiddifypanel.models import User, Agent

user = User.by_uuid("user-uuid")
agent = Agent.by_uuid("agent-uuid")

user.agent_id = agent.id
db.session.commit()
```

### بررسی امکان ایجاد کاربر
```python
from hiddifypanel.services.traffic_service import check_agent_can_create_user

can_create, error_msg = check_agent_can_create_user(
    agent_id=1,
    user_traffic_limit_GB=100
)

if not can_create:
    print(f"Error: {error_msg}")
```

## 🚀 API Examples

### ایجاد Agent
```bash
POST /api/v2/admin/agent/
{
    "name": "Agent 1",
    "username": "agent1",
    "password": "password123",
    "traffic_limit_GB": 1000
}
```

### دریافت آمار ترافیک
```bash
GET /api/v2/admin/agent/{uuid}/traffic/
```

### ایجاد کاربر با Agent
```bash
POST /api/v2/admin/user/
{
    "name": "User 1",
    "agent_id": 1,
    "usage_limit_GB": 100
}
```

## ⚠️ محدودیت‌ها

1. **Agent نمی‌تواند بیشتر از سقف ترافیک مصرف کند**
2. **اگر ترافیک Agent تمام شود**:
   - امکان ایجاد کاربر جدید وجود ندارد
   - امکان افزایش ترافیک کاربران وجود ندارد
3. **Admin همیشه بدون محدودیت است**
4. **traffic_used Agent = مجموع traffic_used تمام کاربران زیرمجموعه**

## 🔄 به‌روزرسانی خودکار ترافیک

سیستم به صورت خودکار ترافیک Agent را به‌روزرسانی می‌کند:
- هنگام ایجاد کاربر جدید
- هنگام به‌روزرسانی `current_usage` کاربر
- هنگام حذف کاربر

این کار از طریق SQLAlchemy event listeners انجام می‌شود.

## 📊 UI Components

UI components باید در frontend ایجاد شوند:
- `AgentList.jsx`: لیست Agent ها
- `AgentEdit.jsx`: ویرایش Agent
- `AgentTraffic.jsx`: نمایش آمار ترافیک
- `AgentDashboard.jsx`: داشبورد Agent

## 🐛 Troubleshooting

### مشکل: Migration اجرا نمی‌شود
- بررسی کنید که `MAX_DB_VERSION` در `init_db.py` به 121 به‌روزرسانی شده باشد
- بررسی کنید که `_v121()` function تعریف شده باشد

### مشکل: Agent traffic به‌روز نمی‌شود
- بررسی کنید که `traffic_service.py` import شده باشد
- بررسی کنید که event listeners فعال هستند

### مشکل: API endpoints کار نمی‌کنند
- بررسی کنید که `agent_api.py` در `__init__.py` import شده باشد
- بررسی کنید که blueprint ثبت شده باشد

