#!/bin/bash
# Check HiddifyPanel configuration

echo "=========================================="
echo "Checking HiddifyPanel Configuration"
echo "=========================================="
echo ""

HIDDIFY_DIR="/opt/hiddify-manager"

# Check app.cfg location
echo "1. Checking app.cfg location:"
if [ -f "$HIDDIFY_DIR/app.cfg" ]; then
    echo "   ✓ Found: $HIDDIFY_DIR/app.cfg"
    echo "   SQLALCHEMY_DATABASE_URI:"
    grep -i "SQLALCHEMY_DATABASE_URI" "$HIDDIFY_DIR/app.cfg" || echo "   (not found in app.cfg)"
else
    echo "   ✗ Not found: $HIDDIFY_DIR/app.cfg"
fi

# Check environment variable
echo ""
echo "2. Checking HIDDIFY_CFG_PATH environment variable:"
if [ -n "$HIDDIFY_CFG_PATH" ]; then
    echo "   ✓ HIDDIFY_CFG_PATH=$HIDDIFY_CFG_PATH"
    if [ -f "$HIDDIFY_CFG_PATH" ]; then
        echo "   ✓ File exists"
    else
        echo "   ✗ File does not exist"
    fi
else
    echo "   (not set, will use default: app.cfg)"
fi

# Check systemd service environment
echo ""
echo "3. Checking systemd service environment:"
systemctl show hiddify-panel | grep -i "environment\|execstart" | head -5

# Check if database file exists
echo ""
echo "4. Looking for database files:"
find "$HIDDIFY_DIR" -name "*.db" -type f 2>/dev/null | head -5

# Check config directory
echo ""
echo "5. Checking config directory:"
if [ -d "$HIDDIFY_DIR/config" ]; then
    echo "   ✓ Config directory exists"
    ls -la "$HIDDIFY_DIR/config" | head -10
else
    echo "   ✗ Config directory not found"
fi

