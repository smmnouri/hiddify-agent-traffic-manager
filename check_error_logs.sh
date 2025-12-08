#!/bin/bash
# Check error logs from hiddify-panel

echo "=========================================="
echo "Checking HiddifyPanel Error Logs"
echo "=========================================="
echo ""

# Check standard error log
ERROR_LOG="/opt/hiddify-manager/log/system/hiddify_panel.err.log"
if [ -f "$ERROR_LOG" ]; then
    echo "1. Error log (last 50 lines):"
    echo "----------------------------------------"
    tail -50 "$ERROR_LOG"
    echo "----------------------------------------"
else
    echo "1. Error log not found: $ERROR_LOG"
fi

echo ""
echo "2. Standard output log (last 50 lines):"
OUTPUT_LOG="/opt/hiddify-manager/log/system/hiddify_panel.out.log"
if [ -f "$OUTPUT_LOG" ]; then
    echo "----------------------------------------"
    tail -50 "$OUTPUT_LOG"
    echo "----------------------------------------"
else
    echo "   Output log not found: $OUTPUT_LOG"
fi

echo ""
echo "3. Trying to run app.py directly to see error:"
echo "----------------------------------------"
cd /opt/hiddify-manager/hiddify-panel
source /opt/hiddify-manager/.venv313/bin/activate
python app.py 2>&1 | head -50
echo "----------------------------------------"

