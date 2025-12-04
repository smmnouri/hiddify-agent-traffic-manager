# نصب سریع - حل مشکل externally-managed-environment

## مشکل

در Ubuntu 22.04+، حتی با فعال کردن venv، ممکن است خطای `externally-managed-environment` دریافت کنید.

## راه‌حل: استفاده مستقیم از pip از venv

### روش 1: استفاده از مسیر کامل pip

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager

# استفاده مستقیم از pip از venv (بدون فعال کردن venv)
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

### روش 2: استفاده از اسکریپت نصب

```bash
cd /opt/hiddify-manager
git clone https://github.com/smmnouri/hiddify-agent-traffic-manager.git
cd hiddify-agent-traffic-manager
bash install.sh
```

### روش 3: اگر venv فعال است اما هنوز خطا می‌دهد

```bash
# بررسی اینکه کدام pip استفاده می‌شود
which pip

# اگر system pip است، از مسیر کامل استفاده کنید:
/opt/hiddify-manager/.venv313/bin/pip install -e .

# یا venv را دوباره فعال کنید:
deactivate
source /opt/hiddify-manager/.venv313/bin/activate
which pip  # باید /opt/hiddify-manager/.venv313/bin/pip باشد
pip install -e .
```

## بررسی نصب

```bash
# بررسی اینکه ماژول نصب شده است
/opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')"
```

## نکته مهم

**هرگز از `--break-system-packages` استفاده نکنید!** این می‌تواند سیستم شما را خراب کند.

همیشه از pip از virtual environment استفاده کنید:
- `/opt/hiddify-manager/.venv313/bin/pip` ✅
- نه `pip` یا `/usr/bin/pip` ❌

