#!/bin/bash
# Complete script to run on server
# Copy-paste this entire script and run it on your server

set -e

echo "=========================================="
echo "Applying Patches to HiddifyPanel"
echo "=========================================="
echo ""

HIDDIFY_DIR="/opt/hiddify-manager"
SCRIPT_DIR="$HIDDIFY_DIR/hiddify-agent-traffic-manager"

# Step 1: Find source directory
SOURCE_DIR=""

if [ -d "$HIDDIFY_DIR/hiddify-panel-source/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-source/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"
    echo "✓ Found source in hiddify-panel-source"
elif [ -d "$HIDDIFY_DIR/hiddify-panel-custom/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-custom/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-custom/src"
    echo "✓ Found source in hiddify-panel-custom"
else
    echo "✗ Source directory not found"
    echo "Please make sure hiddify-panel-source is cloned"
    exit 1
fi

echo "Using source directory: $SOURCE_DIR"
echo ""

# Step 2: Patch AdminstratorAdmin.py
ADMINSTRATOR_ADMIN_PY="$SOURCE_DIR/hiddifypanel/panel/admin/AdminstratorAdmin.py"

if [ ! -f "$ADMINSTRATOR_ADMIN_PY" ]; then
    echo "✗ AdminstratorAdmin.py not found at: $ADMINSTRATOR_ADMIN_PY"
    echo "Searching..."
    FOUND=$(find "$SOURCE_DIR" -name "AdminstratorAdmin.py" 2>/dev/null | head -n1)
    if [ -n "$FOUND" ]; then
        ADMINSTRATOR_ADMIN_PY="$FOUND"
        echo "✓ Found at: $ADMINSTRATOR_ADMIN_PY"
    else
        echo "✗ AdminstratorAdmin.py not found"
        exit 1
    fi
fi

echo "Patching AdminstratorAdmin.py..."
cp "$ADMINSTRATOR_ADMIN_PY" "${ADMINSTRATOR_ADMIN_PY}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✓ Backup created"

# Find Python
VENV_PYTHON=""
if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
    VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
    VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
else
    VENV_PYTHON="python3"
fi

# Run patch script
if [ -f "$SCRIPT_DIR/patches/patch_adminstrator_admin.py" ]; then
    "$VENV_PYTHON" "$SCRIPT_DIR/patches/patch_adminstrator_admin.py" "$ADMINSTRATOR_ADMIN_PY"
    echo "✓ AdminstratorAdmin.py patched"
else
    echo "✗ Patch script not found: $SCRIPT_DIR/patches/patch_adminstrator_admin.py"
    exit 1
fi

echo ""

# Step 3: Run database migration
echo "Running database migration..."
if [ -f "$SCRIPT_DIR/migrations/run_migration.sh" ]; then
    chmod +x "$SCRIPT_DIR/migrations/run_migration.sh"
    bash "$SCRIPT_DIR/migrations/run_migration.sh"
    echo "✓ Migration completed"
else
    echo "⚠ Migration script not found, skipping..."
fi

echo ""

# Step 4: Install from source
echo "Installing from source..."
cd "$(dirname "$SOURCE_DIR")"

# Find pip
PIP_CMD=""
if [ -f "$HIDDIFY_DIR/.venv313/bin/pip" ]; then
    PIP_CMD="$HIDDIFY_DIR/.venv313/bin/pip"
elif [ -f "$HIDDIFY_DIR/.venv/bin/pip" ]; then
    PIP_CMD="$HIDDIFY_DIR/.venv/bin/pip"
elif command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
else
    PIP_CMD="python3 -m pip"
fi

"$PIP_CMD" install -e .
echo "✓ Installed from source"

echo ""

# Step 5: Restart services
echo "Restarting services..."
systemctl restart hiddify-panel hiddify-panel-background-tasks
echo "✓ Services restarted"

echo ""
echo "=========================================="
echo "✓ All done! Patches applied successfully"
echo "=========================================="

