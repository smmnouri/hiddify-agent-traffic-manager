# راه‌حل سریع: نصب از Repository شخصی شما

## مشکل
فیلدهای ترافیک در صفحه `/admin/adminuser/` نمایش داده نمی‌شوند.

## راه‌حل: نصب از Repository شخصی

### مرحله 1: بررسی وضعیت فعلی

```bash
# دانلود اسکریپت بررسی
curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/check_installation.sh -o /tmp/check_installation.sh
chmod +x /tmp/check_installation.sh
bash /tmp/check_installation.sh
```

### مرحله 2: نصب از Repository شخصی (توصیه می‌شود) ⭐

```bash
# نصب یک خطی از repository شما
bash <(curl -s https://raw.githubusercontent.com/smmnouri/hiddify-agent-traffic-manager/main/install.sh)
```

این اسکریپت:
1. ✅ Hiddify-Manager را بررسی می‌کند
2. ✅ Repository شخصی شما (`hiddify-panel-custom`) را کلون می‌کند
3. ✅ اگر repository وجود نداشت، آن را می‌سازد و patches را اعمال می‌کند
4. ✅ HiddifyPanel را از repository شما نصب می‌کند
5. ✅ Database migration انجام می‌دهد
6. ✅ سرویس‌ها را restart می‌کند

### مرحله 3: بررسی نصب

بعد از نصب، بررسی کنید:

```bash
# بررسی لاگ‌ها
journalctl -u hiddify-panel -n 50 --no-pager | grep -i traffic

# بررسی extension
grep -i "hiddify_agent_traffic_manager" /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/hiddifypanel/base.py

# بررسی database
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.database import db
from sqlalchemy import inspect
inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]
print('traffic_limit exists:', 'traffic_limit' in columns)
EOF
```

### اگر repository شخصی وجود ندارد:

```bash
# ساخت repository شخصی
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash setup_custom_repo.sh
```

این اسکریپت:
1. HiddifyPanel را کلون می‌کند
2. تغییرات را اعمال می‌کند
3. به repository شما (`https://github.com/smmnouri/hiddify-panel-custom`) push می‌کند

بعد از این، می‌توانید از `install.sh` استفاده کنید.

## نکات مهم

1. **از Repository شخصی نصب کنید**: تغییرات باید در سورس HiddifyPanel اعمال شوند، نه فقط به عنوان ماژول جداگانه
2. **Restart سرویس‌ها**: بعد از نصب، حتماً restart کنید
3. **بررسی لاگ‌ها**: اگر مشکلی بود، لاگ‌ها را بررسی کنید

## عیب‌یابی

### اگر فیلدها هنوز نمایش داده نمی‌شوند:

1. **بررسی کنید که از repository شخصی نصب شده:**
```bash
/opt/hiddify-manager/.venv313/bin/python -c "import hiddifypanel; print(hiddifypanel.__file__)"
```
اگر مسیر شامل `hiddify-panel-custom` نباشد، از repository شخصی نصب نشده.

2. **بررسی کنید که AdminstratorAdmin extend شده:**
```bash
/opt/hiddify-manager/.venv313/bin/python << 'EOF'
from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
print("column_list:", getattr(AdminstratorAdmin, 'column_list', 'NOT FOUND'))
print("form_columns:", getattr(AdminstratorAdmin, 'form_columns', 'NOT FOUND'))
print("formatters:", list(getattr(AdminstratorAdmin, 'column_formatters', {}).keys()))
EOF
```

3. **Clear cache و restart:**
```bash
systemctl restart hiddify-panel
systemctl restart hiddify-panel-background-tasks
```

4. **بررسی لاگ‌ها:**
```bash
journalctl -u hiddify-panel -f
```

