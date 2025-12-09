#!/bin/bash
# Commands to find HiddifyPanel path - run these one by one

echo "=========================================="
echo "Finding HiddifyPanel Installation Path"
echo "=========================================="
echo ""

echo "1. Checking systemd service..."
if [ -f "/etc/systemd/system/hiddify-panel.service" ]; then
    echo "Service file found!"
    grep WorkingDirectory /etc/systemd/system/hiddify-panel.service
    WORKING_DIR=$(grep "^WorkingDirectory=" /etc/systemd/system/hiddify-panel.service | cut -d'=' -f2 | tr -d ' ')
    if [ -n "$WORKING_DIR" ] && [ -d "$WORKING_DIR" ]; then
        echo ""
        echo "✓ Found! Use this:"
        echo "export HIDDIFY_DIR=\"$WORKING_DIR\""
        exit 0
    fi
else
    echo "✗ Service file not found"
fi

echo ""
echo "2. Checking Python package location..."
PYTHON_PATH=$(python3 -c "import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))" 2>/dev/null || echo "NOT_FOUND")
if [ "$PYTHON_PATH" != "NOT_FOUND" ] && [ -n "$PYTHON_PATH" ]; then
    echo "Python package location: $PYTHON_PATH"
    if [ -f "$PYTHON_PATH/app.py" ]; then
        echo ""
        echo "✓ Found! Use this:"
        echo "export HIDDIFY_DIR=\"$PYTHON_PATH\""
        exit 0
    else
        echo "⚠ app.py not found in this directory"
        echo "Looking for source directory..."
        # Try to find source directory
        POSSIBLE_DIRS=$(find /opt /usr -type d -name "*hiddify*panel*" 2>/dev/null | head -5)
        if [ -n "$POSSIBLE_DIRS" ]; then
            echo "Possible directories:"
            echo "$POSSIBLE_DIRS"
        fi
    fi
else
    echo "✗ Could not import hiddifypanel"
fi

echo ""
echo "3. Searching for app.py..."
FOUND_APP=$(find /opt /usr -name "app.py" 2>/dev/null | grep -i hiddify | head -3)
if [ -n "$FOUND_APP" ]; then
    echo "Found app.py files:"
    echo "$FOUND_APP"
    for app_file in $FOUND_APP; do
        DIR_PATH=$(dirname "$app_file")
        if [ -f "$DIR_PATH/app.py" ] && [ -d "$DIR_PATH/hiddifypanel" ]; then
            echo ""
            echo "✓ Found! Use this:"
            echo "export HIDDIFY_DIR=\"$DIR_PATH\""
            exit 0
        fi
    done
else
    echo "✗ No app.py found"
fi

echo ""
echo "4. Searching for hiddifypanel directories..."
FOUND_DIRS=$(find /opt /usr -type d -name "hiddifypanel" 2>/dev/null | head -5)
if [ -n "$FOUND_DIRS" ]; then
    echo "Found hiddifypanel directories:"
    for dir in $FOUND_DIRS; do
        PARENT_DIR=$(dirname "$dir")
        if [ -f "$PARENT_DIR/app.py" ]; then
            echo ""
            echo "✓ Found! Use this:"
            echo "export HIDDIFY_DIR=\"$PARENT_DIR\""
            exit 0
        else
            echo "  $dir (parent: $PARENT_DIR - no app.py)"
        fi
    done
else
    echo "✗ No hiddifypanel directory found"
fi

echo ""
echo "=========================================="
echo "Could not find HiddifyPanel automatically"
echo "=========================================="
echo ""
echo "Please run these commands manually and share the output:"
echo ""
echo "grep WorkingDirectory /etc/systemd/system/hiddify-panel.service"
echo "python3 -c \"import hiddifypanel; import os; print(os.path.dirname(os.path.dirname(hiddifypanel.__file__)))\""
echo "find /opt /usr -name app.py 2>/dev/null | head -5"
echo "find /opt /usr -type d -name '*hiddify*' 2>/dev/null | head -10"

