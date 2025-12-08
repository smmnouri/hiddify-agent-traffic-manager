#!/bin/bash
# Fix systemd service to set correct HIDDIFY_CFG_PATH

set -e

SERVICE_FILE="/etc/systemd/system/hiddify-panel.service"
BACKUP_FILE="${SERVICE_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

echo "=========================================="
echo "Fixing HiddifyPanel Systemd Service"
echo "=========================================="
echo ""

# Backup service file
if [ -f "$SERVICE_FILE" ]; then
    cp "$SERVICE_FILE" "$BACKUP_FILE"
    echo "✓ Backup created: $BACKUP_FILE"
else
    echo "✗ Service file not found: $SERVICE_FILE"
    exit 1
fi

# Check if HIDDIFY_CFG_PATH needs to be set
CURRENT_WORKDIR=$(grep "^WorkingDirectory=" "$SERVICE_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
if [ -z "$CURRENT_WORKDIR" ]; then
    CURRENT_WORKDIR="/opt/hiddify-manager/hiddify-panel"
fi

APP_CFG_PATH="${CURRENT_WORKDIR}/app.cfg"

# Check if app.cfg exists
if [ ! -f "$APP_CFG_PATH" ]; then
    echo "⚠ Warning: app.cfg not found at $APP_CFG_PATH"
    echo "   Looking for app.cfg..."
    FOUND_CFG=$(find /opt/hiddify-manager -name "app.cfg" -type f 2>/dev/null | head -1)
    if [ -n "$FOUND_CFG" ]; then
        APP_CFG_PATH="$FOUND_CFG"
        CURRENT_WORKDIR=$(dirname "$FOUND_CFG")
        echo "   ✓ Found at: $APP_CFG_PATH"
    else
        echo "   ✗ app.cfg not found anywhere"
        exit 1
    fi
fi

echo "Using app.cfg: $APP_CFG_PATH"
echo "WorkingDirectory: $CURRENT_WORKDIR"
echo ""

# Create temporary service file
TEMP_FILE=$(mktemp)

# Read current service file and modify
{
    while IFS= read -r line; do
        # Skip old HIDDIFY_CFG_PATH if exists
        if [[ "$line" =~ ^Environment=.*HIDDIFY_CFG_PATH ]]; then
            continue
        fi
        
        # Add HIDDIFY_CFG_PATH to existing Environment line or create new one
        if [[ "$line" =~ ^Environment= ]]; then
            # Check if it already has HIDDIFY_CFG_PATH
            if [[ ! "$line" =~ HIDDIFY_CFG_PATH ]]; then
                # Add HIDDIFY_CFG_PATH to existing Environment
                echo "${line} HIDDIFY_CFG_PATH=${APP_CFG_PATH}"
            else
                echo "$line"
            fi
        elif [[ "$line" =~ ^\[Service\] ]]; then
            echo "$line"
            # Add Environment line after [Service] if it doesn't exist
            if ! grep -q "^Environment=" "$SERVICE_FILE"; then
                echo "Environment=\"HIDDIFY_CFG_PATH=${APP_CFG_PATH}\""
            fi
        else
            echo "$line"
        fi
    done < "$SERVICE_FILE"
    
    # If no Environment line was found, add it before ExecStart
    if ! grep -q "^Environment=" "$SERVICE_FILE"; then
        # We need to insert it, but we already processed the file
        # So we'll add it in a second pass
        :
    fi
} > "$TEMP_FILE"

# Second pass: if no Environment line exists, add it
if ! grep -q "^Environment=" "$TEMP_FILE"; then
    # Find [Service] section and add Environment after it
    sed -i "/^\[Service\]/a Environment=\"HIDDIFY_CFG_PATH=${APP_CFG_PATH}\"" "$TEMP_FILE"
fi

# Also ensure WorkingDirectory is set correctly
if ! grep -q "^WorkingDirectory=" "$TEMP_FILE"; then
    sed -i "/^\[Service\]/a WorkingDirectory=${CURRENT_WORKDIR}" "$TEMP_FILE"
else
    sed -i "s|^WorkingDirectory=.*|WorkingDirectory=${CURRENT_WORKDIR}|" "$TEMP_FILE"
fi

# Replace service file
mv "$TEMP_FILE" "$SERVICE_FILE"
chmod 644 "$SERVICE_FILE"

echo "✓ Service file updated"
echo ""
echo "Changes made:"
echo "  - HIDDIFY_CFG_PATH=${APP_CFG_PATH}"
echo "  - WorkingDirectory=${CURRENT_WORKDIR}"
echo ""

# Reload systemd
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"
echo ""

# Show the updated service file
echo "Updated service file:"
echo "----------------------------------------"
grep -E "^Environment=|^WorkingDirectory=|^ExecStart=" "$SERVICE_FILE"
echo "----------------------------------------"
echo ""

echo "You can now restart the service with:"
echo "  systemctl restart hiddify-panel"

