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
        from loguru import logger
        logger.error(f"Error adding traffic_limit column: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        return False

if __name__ == '__main__':
    # Try to get app context
    try:
        from hiddifypanel import create_app
        app = create_app()
        with app.app_context():
            success = migrate()
            sys.exit(0 if success else 1)
    except ImportError:
        # If we can't import, try direct database connection
        print("Warning: Could not import HiddifyPanel. Trying direct database connection...")
        try:
            import os
            from sqlalchemy import create_engine, text
            
            # Try to get database URL from environment or config
            db_url = os.getenv('DATABASE_URL')
            if not db_url:
                # Try common HiddifyPanel database paths
                config_path = os.getenv('HIDDIFY_CONFIG_PATH', '/opt/hiddify-manager/config/hiddify-panel.db')
                if Path(config_path).exists():
                    db_url = f'sqlite:///{config_path}'
                else:
                    print("Error: Could not find database. Please set DATABASE_URL environment variable.")
                    sys.exit(1)
            
            engine = create_engine(db_url)
            with engine.connect() as conn:
                # Check if column exists
                result = conn.execute(text("PRAGMA table_info(admin_user)"))
                columns = [row[1] for row in result]
                
                if 'traffic_limit' not in columns:
                    print("Adding traffic_limit column...")
                    conn.execute(text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    conn.commit()
                    print("Success: traffic_limit column added")
                else:
                    print("Info: traffic_limit column already exists")
            
            sys.exit(0)
        except Exception as e:
            print(f"Error: {e}")
            import traceback
            traceback.print_exc()
            sys.exit(1)

