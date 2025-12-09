#!/bin/bash
# Extended search for HiddifyPanel

echo "=========================================="
echo "Extended HiddifyPanel Search"
echo "=========================================="
echo ""

echo "1. Checking all systemd services..."
find /etc/systemd/system /lib/systemd/system -name "*hiddify*" -o -name "*panel*" 2>/dev/null | head -10

echo ""
echo "2. Checking running processes..."
ps aux | grep -E "(hiddify|panel|python.*app)" | grep -v grep | head -5

echo ""
echo "3. Checking all Python packages..."
python3 -c "import sys; print('\n'.join(sys.path))" 2>/dev/null

echo ""
echo "4. Searching for hiddifypanel in site-packages..."
find /usr -name "hiddifypanel" -type d 2>/dev/null | head -5
find /opt -name "hiddifypanel" -type d 2>/dev/null | head -5
find /home -name "hiddifypanel" -type d 2>/dev/null | head -5
find /root -name "hiddifypanel" -type d 2>/dev/null | head -5

echo ""
echo "5. Searching for app.py in all locations..."
find /opt /usr /home /root -name "app.py" 2>/dev/null | grep -v ".pyc" | head -10

echo ""
echo "6. Checking for virtual environments..."
find /opt /usr /home /root -name ".venv*" -type d 2>/dev/null | head -10
find /opt /usr /home /root -name "venv" -type d 2>/dev/null | head -10

echo ""
echo "7. Checking for hiddify in PATH..."
which hiddify-panel-cli 2>/dev/null || echo "hiddify-panel-cli not found"
which hiddifypanel 2>/dev/null || echo "hiddifypanel not found"

echo ""
echo "8. Checking for config files..."
find /opt /usr /home /root -name "app.cfg" 2>/dev/null | head -5
find /opt /usr /home /root -name "*hiddify*.cfg" 2>/dev/null | head -5

echo ""
echo "9. Checking for log files..."
find /opt /usr /var/log -name "*hiddify*" -o -name "*panel*" 2>/dev/null | head -5

echo ""
echo "10. Checking for installation scripts..."
find /opt /usr /home /root -name "*install*.sh" -path "*hiddify*" 2>/dev/null | head -5

