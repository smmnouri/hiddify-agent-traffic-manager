#!/bin/bash
# Script to find HiddifyPanel installation path

echo "Searching for HiddifyPanel installation..."
echo ""

# Method 1: From systemd service
if [ -f "/etc/systemd/system/hiddify-panel.service" ]; then
    WORKING_DIR=$(grep "^WorkingDirectory=" /etc/systemd/system/hiddify-panel.service | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$WORKING_DIR" ] && [ -d "$WORKING_DIR" ]; then
        echo "✓ Found from systemd service: $WORKING_DIR"
        echo "export HIDDIFY_DIR=\"$WORKING_DIR\""
        exit 0
    fi
fi

# Method 2: From Python package
PYTHON_PATH=$(python3 -c "import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))" 2>/dev/null || echo "")
if [ -n "$PYTHON_PATH" ] && [ -d "$PYTHON_PATH" ] && [ -f "$PYTHON_PATH/app.py" ]; then
    echo "✓ Found from Python package: $PYTHON_PATH"
    echo "export HIDDIFY_DIR=\"$PYTHON_PATH\""
    exit 0
fi

# Method 3: Common paths
for path in "/opt/hiddify-manager/hiddify-panel" "/opt/hiddify/hiddify-panel" "/usr/local/hiddify-panel" "/opt/hiddify-panel"; do
    if [ -d "$path" ] && [ -f "$path/app.py" ]; then
        echo "✓ Found in common path: $path"
        echo "export HIDDIFY_DIR=\"$path\""
        exit 0
    fi
done

# Method 4: Search for app.py
echo "Searching for app.py..."
FOUND_PATH=$(find /opt /usr -name "app.py" -path "*/hiddify-panel/*" 2>/dev/null | head -1)
if [ -n "$FOUND_PATH" ]; then
    DIR_PATH=$(dirname "$FOUND_PATH")
    echo "✓ Found app.py at: $DIR_PATH"
    echo "export HIDDIFY_DIR=\"$DIR_PATH\""
    exit 0
fi

# Method 5: Search for hiddifypanel package
echo "Searching for hiddifypanel package..."
PYTHON_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
if [ -n "$PYTHON_SITE" ] && [ -d "$PYTHON_SITE/hiddifypanel" ]; then
    # Try to find source directory
    SOURCE_DIR=$(find /opt /usr -type d -name "hiddify-panel*" -o -name "HiddifyPanel*" 2>/dev/null | grep -E "(source|src)" | head -1)
    if [ -n "$SOURCE_DIR" ] && [ -f "$SOURCE_DIR/app.py" ]; then
        echo "✓ Found source directory: $SOURCE_DIR"
        echo "export HIDDIFY_DIR=\"$SOURCE_DIR\""
        exit 0
    fi
fi

echo "✗ HiddifyPanel directory not found automatically"
echo ""
echo "Please find it manually:"
echo "1. Check systemd service: grep WorkingDirectory /etc/systemd/system/hiddify-panel.service"
echo "2. Check Python package: python3 -c \"import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))\""
echo "3. Search for app.py: find /opt /usr -name app.py 2>/dev/null"
echo ""
echo "Then set: export HIDDIFY_DIR=/path/to/hiddify-panel"

