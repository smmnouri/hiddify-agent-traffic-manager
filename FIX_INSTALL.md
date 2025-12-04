# حل مشکل نصب - راهنمای کامل

## اگر خطای externally-managed-environment دریافت می‌کنید

### راه‌حل 1: استفاده مستقیم از pip از venv (توصیه می‌شود)

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

### راه‌حل 2: استفاده از python -m pip

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
/opt/hiddify-manager/.venv313/bin/python -m pip install -e .
```

### راه‌حل 3: بررسی و استفاده از pip درست

```bash
# بررسی اینکه کدام pip استفاده می‌شود
which pip

# اگر system pip است، deactivate کنید
deactivate 2>/dev/null || true

# استفاده مستقیم از pip از venv
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
/opt/hiddify-manager/.venv313/bin/pip install -e .
```

### راه‌حل 4: نصب دستی بدون pip

```bash
cd /opt/hiddify-manager/hiddify-agent-traffic-manager

# اضافه کردن مسیر به PYTHONPATH
export PYTHONPATH="/opt/hiddify-manager/hiddify-agent-traffic-manager:$PYTHONPATH"

# یا استفاده از pip install با --target
/opt/hiddify-manager/.venv313/bin/pip install --target /opt/hiddify-manager/.venv313/lib/python3.13/site-packages -e .
```

## بررسی نصب

```bash
# بررسی اینکه ماژول نصب شده است
/opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('Module installed successfully!')"
```

## اگر هنوز مشکل دارید

لطفاً این اطلاعات را ارسال کنید:

```bash
# اطلاعات سیستم
python3 --version
/opt/hiddify-manager/.venv313/bin/python --version
which pip
/opt/hiddify-manager/.venv313/bin/pip --version
ls -la /opt/hiddify-manager/.venv313/bin/pip
```

## نصب بدون pip (کپی مستقیم)

اگر هیچکدام از روش‌های بالا کار نکرد:

```bash
# کپی ماژول به site-packages
cd /opt/hiddify-manager/hiddify-agent-traffic-manager
cp -r hiddify_agent_traffic_manager /opt/hiddify-manager/.venv313/lib/python3.13/site-packages/

# بررسی
/opt/hiddify-manager/.venv313/bin/python -c "import hiddify_agent_traffic_manager; print('OK')"
```

