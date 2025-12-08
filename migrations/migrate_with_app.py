#!/usr/bin/env python3
"""
Migration script using HiddifyPanel app context
"""
import sys
import os

# Set config path if needed
if not os.getenv('HIDDIFY_CONFIG_PATH'):
    possible_paths = [
        '/opt/hiddify-manager/config',
        '/opt/hiddify/config',
        os.path.expanduser('~/.config/hiddify'),
    ]
    for path in possible_paths:
        if os.path.exists(path):
            os.environ['HIDDIFY_CONFIG_PATH'] = path
            break

try:
    from hiddifypanel import create_app
    from hiddifypanel.database import db
    from sqlalchemy import inspect
    
    app = create_app()
    with app.app_context():
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('admin_user')]
        
        if 'traffic_limit' not in columns:
            print("Adding traffic_limit column...")
            db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
            db.session.commit()
            print("✓ Column added successfully")
        else:
            print("✓ Column already exists")
        
        sys.exit(0)
except Exception as e:
    print(f"Error: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

