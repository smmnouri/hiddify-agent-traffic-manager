# راهنمای به‌روزرسانی ماژول Agent Traffic Manager

## روش 1: به‌روزرسانی ماژول (اگر قبلاً نصب کرده‌اید) ⭐

اگر قبلاً ماژول را نصب کرده‌اید، فقط آن را به‌روزرسانی کنید:

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
git pull origin main
```

سپس سرویس را restart کنید:

```bash
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

## روش 2: نصب مجدد از Repository شما (توصیه می‌شود) ⭐⭐

اگر می‌خواهید از repository سفارشی خودتان استفاده کنید:

```bash
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
```

این اسکریپت:
- ✅ Hiddify-Manager را بررسی می‌کند (اگر نصب نباشد، نصب می‌کند)
- ✅ Repository سفارشی شما را کلون می‌کند
- ✅ HiddifyPanel را از repository شما نصب می‌کند
- ✅ Database migration انجام می‌دهد
- ✅ سرویس‌ها را restart می‌کند

## روش 3: به‌روزرسانی Repository سفارشی

اگر قبلاً repository سفارشی را ساخته‌اید:

```bash
cd /opt/hiddify-manager/hiddify-panel-custom
git pull origin main
cd src
/opt/hiddify-manager/.venv313/bin/pip install -e .
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

## بررسی نصب

بعد از نصب/به‌روزرسانی، بررسی کنید:

1. **بررسی لاگ‌ها:**
```bash
journalctl -u hiddify-panel -n 50 --no-pager
```

2. **بررسی ماژول:**
```bash
/opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')"
```

3. **بررسی Database:**
```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
print('traffic_limit column exists:', 'traffic_limit' in columns)
EOF
```

## مشکلات احتمالی

### اگر ماژول قبلاً نصب نشده:
از روش 2 استفاده کنید (اسکریپت نصب یک خطی)

### اگر خطای import دارید:
```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

### اگر Database migration انجام نشده:
```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
if 'traffic_limit' not in columns:
    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
    db.session.commit()
    print("Column added")
else:
    print("Column already exists")
EOF
```

