#!/bin/bash
# Quick migration script that finds database and adds column

set -e

HIDDIFY_DIR="${HIDDIFY_DIR:-/opt/hiddify-manager}"

echo "=========================================="
echo "Quick Migration: Add traffic_limit column"
echo "=========================================="
echo ""

# Find database file
DB_FILE=""

# Search in common locations
possible_paths=(
    "$HIDDIFY_DIR/config/hiddify-panel.db"
    "$HIDDIFY_DIR/hiddify-panel.db"
    "/opt/hiddify/config/hiddify-panel.db"
    "/opt/hiddify/hiddify-panel.db"
)

echo "Searching for database file..."
for path in "${possible_paths[@]}"; do
    if [ -f "$path" ]; then
        DB_FILE="$path"
        echo "✓ Found database: $DB_FILE"
        break
    fi
done

# If not found, search recursively
if [ -z "$DB_FILE" ]; then
    echo "Searching recursively..."
    DB_FILE=$(find "$HIDDIFY_DIR" -name "*.db" -type f 2>/dev/null | grep -v "cache.db" | grep -v "packages.db" | head -n1)
    if [ -n "$DB_FILE" ]; then
        echo "✓ Found database: $DB_FILE"
    fi
fi

if [ -z "$DB_FILE" ] || [ ! -f "$DB_FILE" ]; then
    echo "✗ Database file not found"
    echo ""
    echo "Please specify database file manually:"
    echo "  export DB_FILE=/path/to/hiddify-panel.db"
    echo "  bash $0"
    exit 1
fi

# Check if column exists
echo ""
echo "Checking if traffic_limit column exists..."
if command -v sqlite3 &> /dev/null; then
    COLUMN_EXISTS=$(sqlite3 "$DB_FILE" "PRAGMA table_info(admin_user);" | grep -c "traffic_limit" || echo "0")
    
    if [ "$COLUMN_EXISTS" -gt 0 ]; then
        echo "✓ Column 'traffic_limit' already exists"
        exit 0
    fi
    
    echo "Adding traffic_limit column..."
    sqlite3 "$DB_FILE" "ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL;"
    
    if [ $? -eq 0 ]; then
        echo "✓ Successfully added traffic_limit column"
        exit 0
    else
        echo "✗ Failed to add column"
        exit 1
    fi
else
    echo "✗ sqlite3 not found. Please install it: apt install sqlite3"
    exit 1
fi

