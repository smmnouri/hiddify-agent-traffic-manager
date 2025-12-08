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

# Check multiple locations
if [ -d "$HIDDIFY_DIR/hiddify-panel-source/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-source/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"
    echo "✓ Found source in hiddify-panel-source"
elif [ -d "$HIDDIFY_DIR/hiddify-panel-custom/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel-custom/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-custom/src"
    echo "✓ Found source in hiddify-panel-custom"
elif [ -d "$HIDDIFY_DIR/hiddify-panel/src" ] && [ "$(ls -A $HIDDIFY_DIR/hiddify-panel/src 2>/dev/null)" ]; then
    SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel/src"
    echo "✓ Found source in hiddify-panel"
else
    # Try to find hiddifypanel directory anywhere
    echo "Searching for hiddifypanel directory..."
    FOUND=$(find "$HIDDIFY_DIR" -type d -name "hiddifypanel" -path "*/src/hiddifypanel" 2>/dev/null | head -n1)
    if [ -n "$FOUND" ]; then
        SOURCE_DIR="$(dirname "$FOUND")"
        echo "✓ Found source via search: $SOURCE_DIR"
    else
        # Check if installed via pip
        echo "Checking pip installation..."
        VENV_PYTHON=""
        if [ -f "$HIDDIFY_DIR/.venv313/bin/python" ]; then
            VENV_PYTHON="$HIDDIFY_DIR/.venv313/bin/python"
        elif [ -f "$HIDDIFY_DIR/.venv/bin/python" ]; then
            VENV_PYTHON="$HIDDIFY_DIR/.venv/bin/python"
        else
            VENV_PYTHON="python3"
        fi
        
        if [ -n "$VENV_PYTHON" ]; then
            SITE_PACKAGES=$("$VENV_PYTHON" -c "import site; print(site.getsitepackages()[0])" 2>/dev/null || echo "")
            if [ -n "$SITE_PACKAGES" ] && [ -d "$SITE_PACKAGES/hiddifypanel" ]; then
                SOURCE_DIR="$SITE_PACKAGES"
                echo "✓ Found pip installation in: $SOURCE_DIR"
            fi
        fi
        
        if [ -z "$SOURCE_DIR" ]; then
            echo "✗ Source directory not found"
            echo ""
            echo "Attempting to clone HiddifyPanel..."
            
            # Check if git is available
            if ! command -v git &> /dev/null; then
                echo "✗ git is not installed. Please install git first."
                exit 1
            fi
            
            # Clone HiddifyPanel
            cd "$HIDDIFY_DIR"
            if [ -d "hiddify-panel-source" ]; then
                echo "⚠ hiddify-panel-source directory exists but is empty or invalid"
                echo "Removing and re-cloning..."
                rm -rf hiddify-panel-source
            fi
            
            echo "Cloning HiddifyPanel from GitHub..."
            git clone https://github.com/hiddify/hiddify-panel.git hiddify-panel-source
            
            if [ $? -eq 0 ] && [ -d "hiddify-panel-source/src" ] && [ "$(ls -A hiddify-panel-source/src 2>/dev/null)" ]; then
                SOURCE_DIR="$HIDDIFY_DIR/hiddify-panel-source/src"
                echo "✓ Successfully cloned and found source: $SOURCE_DIR"
            else
                echo "✗ Failed to clone or source directory is empty"
                echo ""
                echo "Please clone manually:"
                echo "  cd $HIDDIFY_DIR"
                echo "  git clone https://github.com/hiddify/hiddify-panel.git hiddify-panel-source"
                exit 1
            fi
        fi
    fi
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

# Step 4: Install from source (only if not pip-installed)
if [[ "$SOURCE_DIR" != *"site-packages"* ]]; then
    echo "Installing from source..."
    SOURCE_PARENT="$(dirname "$SOURCE_DIR")"
    
    # Check if it's a git repository
    if [ -d "$SOURCE_PARENT/.git" ] || [ -f "$SOURCE_PARENT/setup.py" ] || [ -f "$SOURCE_PARENT/pyproject.toml" ]; then
        cd "$SOURCE_PARENT"
        
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
    else
        echo "⚠ Not a git repository or source package, skipping installation"
        echo "  (If patching pip-installed package, this is normal)"
    fi
else
    echo "⚠ Patching pip-installed package (changes will be lost on upgrade)"
    echo "  Consider installing from source for permanent changes"
fi

echo ""

# Step 5: Restart services
echo "Restarting services..."
systemctl restart hiddify-panel hiddify-panel-background-tasks
echo "✓ Services restarted"

echo ""
echo "=========================================="
echo "✓ All done! Patches applied successfully"
echo "=========================================="

