#!/bin/bash
# Migration script to add traffic_limit column to admin_user table

set -e

HIDDIFY_DIR="${HIDDIFY_DIR:-/opt/hiddify-manager}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find Python virtual environment
VENV_PYTHON=""
if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
    VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
    VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
else
    echo "Error: Python virtual environment not found in $HIDDIFY_DIR"
    echo "Please set HIDDIFY_DIR environment variable or ensure virtualenv is installed"
    exit 1
fi

echo "Using Python: $VENV_PYTHON"
echo "Running migration..."

cd "$SCRIPT_DIR"
"$VENV_PYTHON" add_traffic_limit_column.py

if [ $? -eq 0 ]; then
    echo "✓ Migration completed successfully"
    exit 0
else
    echo "✗ Migration failed"
    exit 1
fi

