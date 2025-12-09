# نصب HiddifyPanel + سیستم Agent از ابتدا

این راهنما برای نصب کامل HiddifyPanel همراه با سیستم Agent/Reseller است.

## روش 1: نصب خودکار (توصیه می‌شود) ⭐

```bash
# دریافت و اجرای اسکریپت نصب
cd /root
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
chmod +x install_hiddify_with_agent.sh
sudo ./install_hiddify_with_agent.sh
```

## روش 2: نصب دستی مرحله به مرحله

### مرحله 1: نصب پیش‌نیازها

```bash
apt-get update
apt-get install -y python3 python3-pip python3-venv git curl wget \
    mysql-server mysql-client redis-server nginx \
    build-essential libmysqlclient-dev
```

### مرحله 2: کلون کردن HiddifyPanel

```bash
mkdir -p /opt/hiddify-manager
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-panel.git hiddify-panel
cd hiddify-panel
```

### مرحله 3: نصب HiddifyPanel

```bash
# ایجاد virtual environment
python3 -m venv .venv313
source .venv313/bin/activate

# نصب
pip install --upgrade pip setuptools wheel
pip install -e .
```

### مرحله 4: اضافه کردن سیستم Agent

```bash
# کلون کردن Agent Traffic Manager
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager

# کپی فایل‌های Agent system
cp models/agent.py ../hiddify-panel/hiddifypanel/models/
mkdir -p ../hiddify-panel/hiddifypanel/services
cp services/traffic_service.py ../hiddify-panel/hiddifypanel/services/
cp services/__init__.py ../hiddify-panel/hiddifypanel/services/
cp api/agent_api.py ../hiddify-panel/hiddifypanel/panel/commercial/restapi/v2/admin/
```

### مرحله 5: Patch کردن فایل‌های HiddifyPanel

باید این فایل‌ها را patch کنید:

1. **`hiddifypanel/models/__init__.py`**: اضافه کردن
   ```python
   from .agent import Agent, TrafficLog
   ```

2. **`hiddifypanel/models/user.py`**: اضافه کردن فیلد `agent_id`
   ```python
   agent_id = db.Column(db.Integer, db.ForeignKey('agent.id'), nullable=True)
   ```

3. **`hiddifypanel/panel/init_db.py`**: 
   - تغییر `MAX_DB_VERSION = 121`
   - اضافه کردن function `_v121(child_id)`

4. **`hiddifypanel/panel/commercial/restapi/v2/admin/__init__.py`**: 
   - اضافه کردن import و register کردن agent API

### مرحله 6: نصب مجدد و راه‌اندازی

```bash
cd /opt/hiddify-manager/hiddify-panel
source .venv313/bin/activate
pip install -e .

# Initialize database
hiddify-panel-cli init-db

# Start services
systemctl start hiddify-panel
systemctl start hiddify-panel-background-tasks
```

## تنظیمات

### تنظیم Database

```bash
# اگر از MySQL استفاده می‌کنید
mysql -u root -p
CREATE DATABASE hiddifypanel;
CREATE USER 'hiddifypanel'@'localhost' IDENTIFIED BY 'your_password';
GRANT ALL PRIVILEGES ON hiddifypanel.* TO 'hiddifypanel'@'localhost';
FLUSH PRIVILEGES;
```

### تنظیم app.cfg

```bash
cd /opt/hiddify-manager/hiddify-panel
cat > app.cfg << EOF
SQLALCHEMY_DATABASE_URI = 'mysql+mysqldb://hiddifypanel:your_password@localhost/hiddifypanel'
REDIS_URI_MAIN = 'redis://localhost:6379/0'
EOF
```

## بررسی نصب

```bash
# بررسی import
python3 -c "from hiddifypanel.models import Agent; print('OK')"

# بررسی API
curl http://localhost:9000/api/v2/admin/agent/

# بررسی logs
journalctl -u hiddify-panel -f
```

## مشکلات احتمالی

### مشکل: Migration اجرا نمی‌شود
- بررسی کنید که `MAX_DB_VERSION = 121` در `init_db.py` باشد
- بررسی کنید که function `_v121()` تعریف شده باشد

### مشکل: Import errors
- مطمئن شوید که فایل‌ها در مسیر صحیح کپی شده‌اند
- `pip install -e .` را دوباره اجرا کنید

### مشکل: API کار نمی‌کند
- بررسی کنید که agent_api.py در `__init__.py` import شده باشد
- بررسی logs: `journalctl -u hiddify-panel -n 50`

## پشتیبانی

برای مشکلات بیشتر، لاگ‌ها را بررسی کنید:
```bash
journalctl -u hiddify-panel -n 100
tail -f /opt/hiddify-manager/log/system/panel.log
```

