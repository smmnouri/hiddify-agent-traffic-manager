#!/bin/bash
# Simple installation script - uses python -m pip directly

set -e

echo "=========================================="
echo "Hiddify Agent Traffic Manager"
echo "Simple Installation Script"
echo "=========================================="
echo ""

HIDDIFY_DIR="/opt/hiddify-manager"
VENV_DIR="$HIDDIFY_DIR/.venv313"
MODULE_DIR="$HIDDIFY_DIR/hiddify-agent-traffic-manager"

# Find python
if [ -f "$VENV_DIR/bin/python" ]; then
    PYTHON_CMD="$VENV_DIR/bin/python"
elif [ -f "$VENV_DIR/bin/python3" ]; then
    PYTHON_CMD="$VENV_DIR/bin/python3"
else
    PYTHON_CMD=$(which python3 2>/dev/null || which python 2>/dev/null)
    if [ -z "$PYTHON_CMD" ]; then
        echo "Error: Python not found"
        exit 1
    fi
fi

echo "Using Python: $PYTHON_CMD"
echo "Python version: $($PYTHON_CMD --version 2>&1)"
echo ""

# Go to module directory
cd "$MODULE_DIR"

# Install using python -m pip
echo "Installing module..."
$PYTHON_CMD -m pip install -e .

echo ""
echo "✓ Installation completed!"
echo ""
echo "Next: Run auto_install.sh for full integration, or manually edit base.py"

