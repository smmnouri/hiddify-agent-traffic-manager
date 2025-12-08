#!/bin/bash
# Check crash logs and identify the error

echo "=========================================="
echo "Checking HiddifyPanel Crash Logs"
echo "=========================================="
echo ""

# Get the actual error from logs
echo "Recent error logs:"
journalctl -u hiddify-panel -n 200 --no-pager 2>/dev/null | grep -A 20 -i "error\|traceback\|exception\|failed" | tail -50

echo ""
echo "=========================================="
echo "Trying to run app.py directly to see error:"
echo "=========================================="

HIDDIFY_DIR="/opt/hiddify-manager"
if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
    PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
else
    PYTHON="python3"
fi

cd "$HIDDIFY_DIR"
$PYTHON hiddify-panel/app.py 2>&1 | head -50

