#!/usr/bin/env python3
"""
Migration script using HiddifyPanel app context
"""
import sys
import os

# Try to find and set config path
HIDDIFY_DIR = os.getenv('HIDDIFY_DIR', '/opt/hiddify-manager')
config_paths = [
    f'{HIDDIFY_DIR}/config',
    '/opt/hiddify/config',
    os.path.expanduser('~/.config/hiddify'),
]

if not os.getenv('HIDDIFY_CONFIG_PATH'):
    for path in config_paths:
        if os.path.exists(path):
            os.environ['HIDDIFY_CONFIG_PATH'] = path
            print(f"Using config path: {path}")
            break

# Try method 1: Using HiddifyPanel app
try:
    from hiddifypanel import create_app
    from hiddifypanel.database import db
    from sqlalchemy import inspect
    
    print("Initializing HiddifyPanel app...")
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
except RuntimeError as e:
    if "SQLALCHEMY_DATABASE_URI" in str(e):
        print("⚠ App initialization failed (config issue). Trying direct database access...")
    else:
        raise
except Exception as e:
    print(f"⚠ App method failed: {e}")
    print("Trying direct database access...")

# Method 2: Direct database access using hiddifypanel.database
try:
    # Try to import and use database module directly
    import sys
    sys.path.insert(0, f'{HIDDIFY_DIR}/hiddify-panel-source')
    sys.path.insert(0, f'{HIDDIFY_DIR}/hiddify-panel-custom')
    
    from hiddifypanel.database import db
    from sqlalchemy import inspect, create_engine
    from sqlalchemy.orm import sessionmaker
    
    # Try to get engine from db if available
    if hasattr(db, 'engine') and db.engine:
        inspector = inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('admin_user')]
        
        if 'traffic_limit' not in columns:
            print("Adding traffic_limit column (direct method)...")
            with db.engine.connect() as conn:
                conn.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                conn.commit()
            print("✓ Column added successfully")
        else:
            print("✓ Column already exists")
        sys.exit(0)
except Exception as e:
    print(f"⚠ Direct database method failed: {e}")

# Method 3: Find database file and use sqlite3
print("Trying to find database file and use sqlite3...")
import subprocess

# Search for database files
db_files = []
for config_dir in config_paths:
    if os.path.exists(config_dir):
        for file in os.listdir(config_dir):
            if file.endswith('.db'):
                db_files.append(os.path.join(config_dir, file))

# Also search recursively
import glob
for pattern in [f'{HIDDIFY_DIR}/**/*.db', '/opt/hiddify/**/*.db']:
    db_files.extend(glob.glob(pattern, recursive=True))

# Filter out cache and packages databases
db_files = [f for f in db_files if 'cache' not in f.lower() and 'packages' not in f.lower()]

if db_files:
    db_file = db_files[0]
    print(f"Found database: {db_file}")
    
    # Check if sqlite3 is available
    try:
        result = subprocess.run(
            ['sqlite3', db_file, "PRAGMA table_info(admin_user);"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if 'traffic_limit' in result.stdout:
            print("✓ Column already exists")
            sys.exit(0)
        
        # Add column
        result = subprocess.run(
            ['sqlite3', db_file, "ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL;"],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode == 0:
            print("✓ Column added successfully using sqlite3")
            sys.exit(0)
        else:
            print(f"✗ sqlite3 failed: {result.stderr}")
    except FileNotFoundError:
        print("✗ sqlite3 not found. Install with: apt install sqlite3")
    except Exception as e:
        print(f"✗ Error: {e}")

print("✗ All methods failed. Please run migration manually.")
sys.exit(1)

