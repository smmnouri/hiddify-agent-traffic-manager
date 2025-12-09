# راهنمای نصب سریع

## مرحله 1: پیدا کردن مسیر HiddifyPanel

```bash
# دریافت اسکریپت
cd /root
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager

# پیدا کردن مسیر
chmod +x find_hiddify_path.sh
./find_hiddify_path.sh
```

خروجی را کپی کنید (مثلاً `export HIDDIFY_DIR="/opt/hiddify-manager/hiddify-panel"`)

## مرحله 2: نصب

```bash
# تنظیم مسیر (از خروجی مرحله قبل)
export HIDDIFY_DIR="/path/to/hiddify-panel"

# اجرای نصب
chmod +x install_agent_system.sh
sudo ./install_agent_system.sh
```

## روش جایگزین: پیدا کردن دستی

اگر اسکریپت مسیر را پیدا نکرد:

```bash
# روش 1: از systemd
grep WorkingDirectory /etc/systemd/system/hiddify-panel.service

# روش 2: از Python
python3 -c "import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))"

# روش 3: جستجوی app.py
find /opt /usr -name "app.py" -path "*/hiddify-panel/*" 2>/dev/null

# سپس:
export HIDDIFY_DIR="/path/found/above"
sudo ./install_agent_system.sh
```

## نصب دستی (اگر اسکریپت کار نکرد)

```bash
# 1. پیدا کردن مسیر Python و pip
which python3
which pip3

# 2. پیدا کردن مسیر hiddifypanel
python3 -c "import hiddifypanel; print(hiddifypanel.__file__)"

# 3. کپی فایل‌ها
# اگر HiddifyPanel از source نصب شده:
cp models/agent.py $HIDDIFY_DIR/src/hiddifypanel/models/
cp services/traffic_service.py $HIDDIFY_DIR/src/hiddifypanel/services/
cp api/agent_api.py $HIDDIFY_DIR/src/hiddifypanel/panel/commercial/restapi/v2/admin/

# 4. Patch کردن فایل‌های موجود (باید دستی انجام شود)
# - models/__init__.py: اضافه کردن import Agent
# - models/user.py: اضافه کردن agent_id
# - panel/init_db.py: اضافه کردن migration v121
# - panel/commercial/restapi/v2/admin/__init__.py: ثبت API endpoints

# 5. نصب مجدد
cd $HIDDIFY_DIR
pip3 install -e .

# 6. اجرای migration
hiddify-panel-cli init-db

# 7. راه‌اندازی مجدد
systemctl restart hiddify-panel
```
