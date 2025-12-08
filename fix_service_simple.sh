#!/bin/bash
# Simple fix for systemd service - remove incorrect HIDDIFY_CFG_PATH

set -e

SERVICE_FILE="/etc/systemd/system/hiddify-panel.service"

echo "=========================================="
echo "Fixing HiddifyPanel Systemd Service (Simple)"
echo "=========================================="
echo ""

if [ ! -f "$SERVICE_FILE" ]; then
    echo "✗ Service file not found: $SERVICE_FILE"
    exit 1
fi

# Backup
BACKUP="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$SERVICE_FILE" "$BACKUP"
echo "✓ Backup created: $BACKUP"
echo ""

# Remove any HIDDIFY_CFG_PATH from Environment lines
sed -i '/HIDDIFY_CFG_PATH/d' "$SERVICE_FILE"

# Ensure WorkingDirectory is set correctly
if ! grep -q "^WorkingDirectory=" "$SERVICE_FILE"; then
    sed -i '/^\[Service\]/a WorkingDirectory=/opt/hiddify-manager/hiddify-panel/' "$SERVICE_FILE"
else
    sed -i 's|^WorkingDirectory=.*|WorkingDirectory=/opt/hiddify-manager/hiddify-panel/|' "$SERVICE_FILE"
fi

echo "✓ Service file updated"
echo ""

# Show changes
echo "Current configuration:"
echo "----------------------------------------"
grep -E "^WorkingDirectory=|^Environment=|^ExecStart=" "$SERVICE_FILE" || true
echo "----------------------------------------"
echo ""

# Reload and restart
echo "Reloading systemd..."
systemctl daemon-reload
echo "✓ Systemd reloaded"
echo ""

echo "Restarting service..."
systemctl restart hiddify-panel
sleep 3

echo ""
echo "Service status:"
systemctl status hiddify-panel --no-pager -l | head -20

