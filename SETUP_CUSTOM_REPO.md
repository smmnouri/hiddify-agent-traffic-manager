# راهنمای ایجاد Repository سفارشی HiddifyPanel

این راهنما نحوه ایجاد یک repository سفارشی از HiddifyPanel با قابلیت‌های مدیریت ترافیک ایجنت را توضیح می‌دهد.

## مراحل

### 1. ایجاد Repository در GitHub

1. به https://github.com/new بروید
2. Repository name: `hiddify-panel-custom` (یا نام دلخواه)
3. Public یا Private (انتخاب شما)
4. **نکته مهم**: Don't initialize with README, .gitignore, or license
5. Create repository

### 2. اجرای اسکریپت

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x setup_custom_repo.sh
bash setup_custom_repo.sh
```

اسکریپت از شما می‌پرسد:
- GitHub username شما
- نام repository

### 3. استفاده از Repository سفارشی

بعد از اینکه repository شما آماده شد، می‌توانید از آن استفاده کنید:

#### گزینه 1: استفاده در Hiddify-Manager

اگر از Hiddify-Manager استفاده می‌کنید، می‌توانید repository را تغییر دهید:

```bash
cd /opt/hiddify-manager
# Backup current
mv hiddify-panel hiddify-panel-backup

# Clone your custom repo
git clone https://github.com/YOUR_USERNAME/hiddify-panel-custom.git hiddify-panel
cd hiddify-panel

# Install
make install  # یا دستورات نصب HiddifyPanel
```

#### گزینه 2: استفاده مستقیم

```bash
cd /opt/hiddify-manager
git clone https://github.com/YOUR_USERNAME/hiddify-panel-custom.git
cd hiddify-panel-custom
source ../.venv313/bin/activate
pip install -e .
```

### 4. Database Migration

```bash
cd /opt/hiddify-manager/hiddify-panel-custom
source ../.venv313/bin/activate
python -c "
from hiddifypanel.database import db
from sqlalchemy import inspect

inspector = inspect(db.engine)
columns = [col['name'] for col in inspector.get_columns('admin_user')]

if 'traffic_limit' not in columns:
    print('Adding traffic_limit column...')
    db.session.execute(db.text('ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL'))
    db.session.commit()
    print('✓ Column added')
else:
    print('✓ Column already exists')
"
```

### 5. Restart

```bash
systemctl restart hiddify-panel
```

## مزایای این روش

- ✅ Repository کاملاً در اختیار شما
- ✅ می‌توانید تغییرات بیشتری اضافه کنید
- ✅ می‌توانید با دیگران share کنید
- ✅ کنترل کامل بر کد
- ✅ بدون نیاز به extension system

## به‌روزرسانی

وقتی HiddifyPanel آپدیت می‌شود:

```bash
cd /opt/hiddify-manager/hiddify-panel-custom
git remote add upstream https://github.com/hiddify/HiddifyPanel.git 2>/dev/null || true
git fetch upstream
git merge upstream/main  # یا master
# حل conflict ها اگر وجود داشت
# دوباره تغییرات agent traffic را اعمال کنید
bash /opt/hiddify-manager/hiddify-agent-traffic-manager/setup_custom_repo.sh
git push origin main
```

## ساختار Repository

بعد از اجرای اسکریپت، repository شما شامل:
- تمام کدهای HiddifyPanel
- تغییرات در `models/admin.py` (traffic_limit column و methods)
- تغییرات در `panel/admin/AdminstratorAdmin.py` (columns و formatters)
- User creation hook در `panel/admin/user_creation_hook.py`

