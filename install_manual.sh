#!/bin/bash
# Manual installation script - bypasses all checks
# Use this if install.sh doesn't work

set -e

echo "Manual Installation Script"
echo "=========================="
echo ""

cd /opt/hiddify-manager/hiddify-agent-traffic-manager

# Direct installation using venv pip
echo "Installing using venv pip..."
/opt/hiddify-manager/.venv313/bin/pip install -e .

echo ""
echo "Installation completed!"
echo ""
echo "Next steps:"
echo "1. Edit wsgi_app.py to integrate the module"
echo "2. Restart services: sudo systemctl restart hiddify-panel"

