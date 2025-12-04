# راهنمای Integration با HiddifyPanel

## روش 1: Integration مستقیم

### مرحله 1: کپی ماژول
ماژول را در کنار HiddifyPanel کپی کنید:

```bash
cp -r hiddify-agent-traffic-manager /opt/hiddify-manager/
```

### مرحله 2: Import در HiddifyPanel

در فایل `hiddifypanel/apps/wsgi_app.py` یا فایل اصلی که `create_app()` را فراخوانی می‌کند:

```python
def create_app():
    app = Flask(__name__)
    # ... سایر تنظیمات ...
    
    # Import و initialize agent traffic manager
    try:
        import sys
        sys.path.insert(0, '/opt/hiddify-manager/hiddify-agent-traffic-manager')
        from hiddify_agent_traffic_manager import init_app
        app = init_app(app)
    except Exception as e:
        print(f"Warning: Could not load agent traffic manager: {e}")
    
    return app
```

## روش 2: نصب به عنوان Package

### مرحله 1: نصب ماژول

```bash
cd hiddify-agent-traffic-manager
pip install -e .
```

### مرحله 2: Import در HiddifyPanel

```python
from hiddify_agent_traffic_manager import init_app

def create_app():
    app = Flask(__name__)
    # ... سایر تنظیمات ...
    
    # Initialize agent traffic manager
    app = init_app(app)
    
    return app
```

## روش 3: Integration با HiddifyPanel Source

اگر HiddifyPanel را از source اجرا می‌کنید:

### مرحله 1: اضافه کردن به requirements

در `pyproject.toml` یا `requirements.txt`:

```
hiddify-agent-traffic-manager @ file:///path/to/hiddify-agent-traffic-manager
```

### مرحله 2: Import در `hiddifypanel/apps/wsgi_app.py`

```python
from hiddify_agent_traffic_manager import init_app

def create_app():
    app = create_app_base()  # یا هر تابعی که app اصلی را می‌سازد
    
    # Initialize extensions
    app = init_app(app)  # Agent traffic manager
    
    return app
```

## بررسی نصب

پس از نصب، می‌توانید با دستور زیر بررسی کنید:

```python
from hiddifypanel.models.admin import AdminUser
from hiddifypanel.models.admin import AdminMode

# بررسی اینکه آیا متدهای جدید اضافه شده‌اند
agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
if agent:
    print(f"Traffic limit: {agent.traffic_limit_GB}")
    print(f"Total traffic: {agent.get_total_traffic_GB()} GB")
```

## تست API

```bash
# دریافت ترافیک یک ایجنت
curl http://localhost:9000/api/v1/agent-traffic/agents/2/traffic

# تنظیم محدودیت ترافیک
curl -X PUT http://localhost:9000/api/v1/agent-traffic/agents/2/traffic-limit \
  -H "Content-Type: application/json" \
  -d '{"traffic_limit_GB": 1000}'
```

## مشکلات رایج

### مشکل: ModuleNotFoundError
**راه‌حل**: مطمئن شوید که مسیر ماژول در `sys.path` است یا به صورت package نصب شده است.

### مشکل: Column 'traffic_limit' doesn't exist
**راه‌حل**: ماژول باید بتواند به دیتابیس دسترسی داشته باشد. بررسی کنید که:
- دسترسی به MySQL/MariaDB وجود دارد
- کاربر دیتابیس مجوز ALTER TABLE دارد

### مشکل: Hook کار نمی‌کند
**راه‌حل**: مطمئن شوید که `init_user_creation_hook()` فراخوانی شده است.

