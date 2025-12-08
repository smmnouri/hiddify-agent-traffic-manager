#!/usr/bin/env python3
"""
Migration script using HiddifyPanel app context
"""
import sys
import os

# Try to find and set config path
HIDDIFY_DIR = os.getenv('HIDDIFY_DIR', '/opt/hiddify-manager')

# Find app.cfg file
app_cfg_paths = [
    f'{HIDDIFY_DIR}/hiddify-panel/app.cfg',
    f'{HIDDIFY_DIR}/hiddify-panel-custom/app.cfg',
    f'{HIDDIFY_DIR}/hiddify-panel-source/app.cfg',
]

app_cfg = None
for path in app_cfg_paths:
    if os.path.exists(path):
        app_cfg = path
        os.environ['HIDDIFY_CFG_PATH'] = path
        print(f"Found app.cfg: {path}")
        break

# Also set config path
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
    
    # If app.cfg found, make sure we're in the right directory
    if app_cfg:
        os.chdir(os.path.dirname(app_cfg))
        print(f"Changed to directory: {os.getcwd()}")
    
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
        print("⚠ App initialization failed (config issue). Trying to read database URI from app.cfg...")
        # Try to read SQLALCHEMY_DATABASE_URI from app.cfg
        db_uri = None
        if app_cfg:
            try:
                print(f"Reading app.cfg: {app_cfg}")
                with open(app_cfg, 'r') as f:
                    content = f.read()
                    # Look for SQLALCHEMY_DATABASE_URI
                    for line in content.split('\n'):
                        line = line.strip()
                        if line.startswith('SQLALCHEMY_DATABASE_URI'):
                            # Handle different formats: SQLALCHEMY_DATABASE_URI ='...' or SQLALCHEMY_DATABASE_URI='...'
                            if '=' in line:
                                db_uri = line.split('=', 1)[1].strip().strip("'\"")
                                print(f"✓ Found database URI in app.cfg")
                                break
            except Exception as e2:
                print(f"⚠ Could not read app.cfg: {e2}")
        
        # If not found in app.cfg, try to read from environment or construct from MySQL password
        if not db_uri:
            db_uri = os.getenv('SQLALCHEMY_DATABASE_URI')
            if not db_uri:
                # Try to read MySQL password and construct URI
                mysql_pass_file = f'{HIDDIFY_DIR}/other/mysql/mysql_pass'
                if os.path.exists(mysql_pass_file):
                    try:
                        with open(mysql_pass_file, 'r') as f:
                            mysql_pass = f.read().strip()
                        db_uri = f"mysql+mysqldb://hiddifypanel:{mysql_pass}@localhost/hiddifypanel?charset=utf8mb4"
                        print(f"✓ Constructed database URI from MySQL password file")
                    except Exception as e3:
                        print(f"⚠ Could not read MySQL password: {e3}")
        
        if db_uri:
            try:
                print("Connecting to database directly...")
                from sqlalchemy import create_engine, inspect, text
                engine = create_engine(db_uri)
                
                # Check if table exists first
                inspector = inspect(engine)
                tables = inspector.get_table_names()
                
                if 'admin_user' not in tables:
                    print("⚠ admin_user table does not exist. Database might not be initialized.")
                    print(f"   Available tables: {', '.join(tables[:5])}")
                    print("   Skipping migration - will be done when database is initialized")
                    sys.exit(0)
                
                columns = [col['name'] for col in inspector.get_columns('admin_user')]
                if 'traffic_limit' not in columns:
                    print("Adding traffic_limit column...")
                    with engine.connect() as conn:
                        conn.execute(text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                        conn.commit()
                    print("✓ Column added successfully (direct connection)")
                else:
                    print("✓ Column already exists")
                sys.exit(0)
            except Exception as e4:
                print(f"⚠ Direct connection failed: {e4}")
                # Don't print full traceback for common errors
                if "no such table" not in str(e4).lower():
                    import traceback
                    traceback.print_exc()
        
        print("Trying direct database access...")
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

