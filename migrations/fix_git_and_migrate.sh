#!/bin/bash
# Fix git issues and run migration

set -e

cd /opt/hiddify-manager/hiddify-agent-traffic-manager

echo "Fixing git issues..."
# Stash local changes
git stash

# Remove untracked files that might conflict
rm -f migrations/fix_git_and_migrate.sh

# Pull latest changes
git pull

echo "Running migration..."
cd /opt/hiddify-manager
source .venv313/bin/activate
python3 hiddify-agent-traffic-manager/migrations/migrate_with_app.py

