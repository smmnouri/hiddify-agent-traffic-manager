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

# Try Python migration first
"$VENV_PYTHON" add_traffic_limit_column.py

if [ $? -eq 0 ]; then
    echo "✓ Migration completed successfully"
    exit 0
else
    echo "⚠ Python migration failed, trying SQLite3 direct method..."
    
    # Try to find database file
    DB_FILE=""
    possible_paths=(
        "$HIDDIFY_DIR/config/hiddify-panel.db"
        "$HIDDIFY_DIR/hiddify-panel.db"
        "/opt/hiddify/config/hiddify-panel.db"
    )
    
    for path in "${possible_paths[@]}"; do
        if [ -f "$path" ]; then
            DB_FILE="$path"
            break
        fi
    done
    
    # If not found, search
    if [ -z "$DB_FILE" ]; then
        DB_FILE=$(find "$HIDDIFY_DIR" -name "*.db" -type f 2>/dev/null | grep -i hiddify | head -n1)
    fi
    
    if [ -n "$DB_FILE" ] && [ -f "$DB_FILE" ]; then
        echo "Found database: $DB_FILE"
        
        # Check if sqlite3 is available
        if command -v sqlite3 &> /dev/null; then
            echo "Using sqlite3 to add column..."
            sqlite3 "$DB_FILE" "ALTER TABLE admin_user ADD COLUMN IF NOT EXISTS traffic_limit BIGINT DEFAULT NULL;" 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "✓ Column added using sqlite3"
                exit 0
            else
                echo "✗ sqlite3 command failed"
            fi
        else
            echo "⚠ sqlite3 not found. Install it with: apt install sqlite3"
        fi
    else
        echo "✗ Could not find database file"
    fi
    
    echo "✗ Migration failed"
    exit 1
fi

