#!/usr/bin/env python3
"""
Migration script to add traffic_limit column to admin_user table
"""
import sys
from pathlib import Path

def migrate():
    """Add traffic_limit column if it doesn't exist"""
    try:
        from hiddifypanel.database import db
        from loguru import logger
        
        # Check if column exists
        inspector = db.inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('admin_user')]
        
        if 'traffic_limit' not in columns:
            logger.info("Adding traffic_limit column to admin_user table...")
            try:
                # Try with connection
                with db.engine.connect() as conn:
                    conn.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    conn.commit()
                logger.success("traffic_limit column added successfully")
                return True
            except Exception as e:
                logger.warning(f"First method failed: {e}")
                # Try alternative method
                try:
                    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    db.session.commit()
                    logger.success("traffic_limit column added successfully (alternative method)")
                    return True
                except Exception as e2:
                    logger.error(f"Failed to add traffic_limit column: {e2}")
                    db.session.rollback()
                    return False
        else:
            logger.debug("traffic_limit column already exists")
            return True
    except Exception as e:
        # Try without app context - direct database access
        try:
            from hiddifypanel.database import db
            # Try to get engine directly
            if hasattr(db, 'engine') and db.engine:
                from sqlalchemy import inspect
                inspector = inspect(db.engine)
                columns = [col['name'] for col in inspector.get_columns('admin_user')]
                
                if 'traffic_limit' not in columns:
                    print("Adding traffic_limit column (direct method)...")
                    with db.engine.connect() as conn:
                        conn.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                        conn.commit()
                    print("✓ Success: traffic_limit column added")
                    return True
                else:
                    print("✓ Info: traffic_limit column already exists")
                    return True
        except Exception as e2:
            from loguru import logger
            logger.error(f"Error adding traffic_limit column: {e}")
            import traceback
            logger.debug(traceback.format_exc())
            return False

if __name__ == '__main__':
    # Try to get app context
    try:
        import os
        # Set environment variables if needed
        if not os.getenv('HIDDIFY_CONFIG_PATH'):
            # Try to find config path
            possible_paths = [
                '/opt/hiddify-manager/config',
                '/opt/hiddify/config',
                os.path.expanduser('~/.config/hiddify'),
            ]
            for path in possible_paths:
                if os.path.exists(path):
                    os.environ['HIDDIFY_CONFIG_PATH'] = path
                    break
        
        from hiddifypanel import create_app
        app = create_app()
        with app.app_context():
            success = migrate()
            sys.exit(0 if success else 1)
    except (ImportError, RuntimeError) as e:
        # If we can't import or initialize app, try direct database connection
        print(f"Warning: Could not initialize HiddifyPanel app ({e}). Trying direct database connection...")
        try:
            import os
            from sqlalchemy import create_engine, text
            
            # Try to get database URL from environment or config
            db_url = os.getenv('DATABASE_URL')
            if not db_url:
                # Try to read from HiddifyPanel config
                try:
                    import json
                    config_paths = [
                        '/opt/hiddify-manager/config',
                        '/opt/hiddify/config',
                        os.path.expanduser('~/.config/hiddify'),
                    ]
                    
                    config_path = os.getenv('HIDDIFY_CONFIG_PATH')
                    if config_path:
                        config_paths.insert(0, config_path)
                    
                    for config_dir in config_paths:
                        config_file = os.path.join(config_dir, 'config.json')
                        if os.path.exists(config_file):
                            with open(config_file, 'r') as f:
                                config = json.load(f)
                                if 'database' in config:
                                    db_url = config['database']
                                    print(f"Found database URL in config: {config_file}")
                                    break
                except Exception as e:
                    print(f"Could not read config: {e}")
                
                if not db_url:
                    # Try to find database file
                    possible_db_paths = [
                        '/opt/hiddify-manager/config/hiddify-panel.db',
                        '/opt/hiddify-manager/hiddify-panel.db',
                        '/opt/hiddify/config/hiddify-panel.db',
                        '/opt/hiddify/hiddify-panel.db',
                        os.path.expanduser('~/.config/hiddify/hiddify-panel.db'),
                    ]
                    
                    # Search for any .db file in config directories
                    for config_dir in config_paths:
                        if os.path.isdir(config_dir):
                            for file in os.listdir(config_dir):
                                if file.endswith('.db'):
                                    possible_db_paths.append(os.path.join(config_dir, file))
                    
                    # Also search recursively
                    print("Searching for database files...")
                    for root, dirs, files in os.walk('/opt/hiddify-manager'):
                        for file in files:
                            if file.endswith('.db') and 'hiddify' in file.lower():
                                possible_db_paths.append(os.path.join(root, file))
                    
                    for db_path in possible_db_paths:
                        if os.path.exists(db_path):
                            db_url = f'sqlite:///{db_path}'
                            print(f"Found database at: {db_path}")
                            break
                    
                    if not db_url:
                        print("Error: Could not find database file.")
                        print("Searched in:")
                        for path in set(possible_db_paths[:10]):  # Show first 10 unique paths
                            print(f"  - {path}")
                        print("\nTrying to use HiddifyPanel's database connection directly...")
                        # Try one more time with hiddifypanel database module
                        raise Exception("Database file not found")
            
            print(f"Connecting to database: {db_url}")
            engine = create_engine(db_url)
            with engine.connect() as conn:
                # Check if column exists (for SQLite)
                try:
                    result = conn.execute(text("PRAGMA table_info(admin_user)"))
                    columns = [row[1] for row in result]
                except:
                    # For MySQL/MariaDB, use different query
                    result = conn.execute(text("SHOW COLUMNS FROM admin_user"))
                    columns = [row[0] for row in result]
                
                if 'traffic_limit' not in columns:
                    print("Adding traffic_limit column...")
                    conn.execute(text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    conn.commit()
                    print("✓ Success: traffic_limit column added")
                else:
                    print("✓ Info: traffic_limit column already exists")
            
            sys.exit(0)
        except Exception as e2:
            print(f"Error: {e2}")
            import traceback
            traceback.print_exc()
            print("\nTrying alternative method using hiddifypanel database module...")
            # Last resort: try to use hiddifypanel database directly
            try:
                from hiddifypanel.database import db
                from sqlalchemy import inspect
                
                inspector = inspect(db.engine)
                columns = [col['name'] for col in inspector.get_columns('admin_user')]
                
                if 'traffic_limit' not in columns:
                    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    db.session.commit()
                    print("✓ Success: traffic_limit column added (alternative method)")
                else:
                    print("✓ Info: traffic_limit column already exists")
                sys.exit(0)
            except Exception as e3:
                print(f"All methods failed. Last error: {e3}")
                sys.exit(1)

