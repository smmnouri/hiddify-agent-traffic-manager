#!/bin/bash
# Check hiddify-panel service status and logs

echo "=========================================="
echo "Checking HiddifyPanel Service"
echo "=========================================="
echo ""

# Check service status
echo "1. Service status:"
systemctl status hiddify-panel --no-pager -l | head -30

echo ""
echo "2. Is service active?"
if systemctl is-active --quiet hiddify-panel; then
    echo "   ✓ Service is running"
else
    echo "   ✗ Service is NOT running"
fi

echo ""
echo "3. Recent logs (last 50 lines):"
journalctl -u hiddify-panel -n 50 --no-pager | tail -30

echo ""
echo "4. Errors in logs:"
journalctl -u hiddify-panel -n 100 --no-pager | grep -i "error\|traceback\|exception\|failed" | tail -10

echo ""
echo "5. Trying to start service manually:"
systemctl start hiddify-panel
sleep 2
systemctl status hiddify-panel --no-pager -l | head -20

