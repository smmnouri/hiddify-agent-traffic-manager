"""
Extension برای افزودن قابلیت محدودیت ترافیک به AdminUser
"""
from sqlalchemy import Column, BigInteger, event
from sqlalchemy.orm import Session
from flask import Flask
from loguru import logger

ONE_GIG = 1024 * 1024 * 1024


def init_agent_traffic(app: Flask):
    """Initialize agent traffic extension"""
    from hiddifypanel.database import db
    from hiddifypanel.models.admin import AdminUser
    
    # Add traffic_limit column if it doesn't exist
    try:
        # Check if column exists
        inspector = db.inspect(db.engine)
        columns = [col['name'] for col in inspector.get_columns('admin_user')]
        
        if 'traffic_limit' not in columns:
            logger.info("Adding traffic_limit column to admin_user table...")
            try:
                with db.engine.connect() as conn:
                    conn.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    conn.commit()
                logger.success("traffic_limit column added successfully")
            except Exception as e:
                logger.warning(f"Could not add traffic_limit column (might already exist): {e}")
                # Try alternative method
                try:
                    db.session.execute(db.text("ALTER TABLE admin_user ADD COLUMN traffic_limit BIGINT DEFAULT NULL"))
                    db.session.commit()
                    logger.success("traffic_limit column added successfully (alternative method)")
                except Exception as e2:
                    logger.error(f"Failed to add traffic_limit column: {e2}")
                    # Continue anyway, column might already exist
        else:
            logger.debug("traffic_limit column already exists")
    except Exception as e:
        logger.error(f"Error adding traffic_limit column: {e}")
        # Column might already exist, continue
    
    # Add properties and methods to AdminUser
    _extend_admin_user(AdminUser)
    
    return app


def _extend_admin_user(AdminUser):
    """Extend AdminUser model with traffic management methods"""
    from hiddifypanel.models.user import User
    
    @property
    def traffic_limit_GB(self):
        """Get traffic limit in GB"""
        from hiddifypanel.database import db
        try:
            result = db.session.execute(
                db.text("SELECT traffic_limit FROM admin_user WHERE id = :id"),
                {"id": self.id}
            ).first()
            traffic_limit = result[0] if result and result[0] else None
        except Exception as e:
            logger.debug(f"Error getting traffic_limit: {e}")
            traffic_limit = None
        
        if traffic_limit is None:
            return None
        return traffic_limit / ONE_GIG
    
    @traffic_limit_GB.setter
    def traffic_limit_GB(self, value):
        """Set traffic limit in GB"""
        from hiddifypanel.database import db
        if value is None:
            traffic_limit = None
        else:
            traffic_limit = int(value * ONE_GIG)
        
        db.session.execute(
            db.text("UPDATE admin_user SET traffic_limit = :limit WHERE id = :id"),
            {"limit": traffic_limit, "id": self.id}
        )
        db.session.commit()
        self._traffic_limit = traffic_limit
    
    def get_total_traffic(self):
        """محاسبه مجموع ترافیک مصرفی تمام کاربران ایجاد شده توسط این ایجنت"""
        from hiddifypanel.database import db
        from sqlalchemy import func
        
        # Get all users created by this agent (including sub-admins)
        admin_ids = self.recursive_sub_admins_ids()
        
        total_traffic = db.session.query(
            func.coalesce(func.sum(User.current_usage), 0)
        ).filter(
            User.added_by.in_(admin_ids)
        ).scalar()
        
        return total_traffic or 0
    
    def get_total_traffic_GB(self):
        """Get total traffic in GB"""
        return self.get_total_traffic() / ONE_GIG
    
    def get_remaining_traffic(self):
        """محاسبه ترافیک باقیمانده"""
        if self.traffic_limit_GB is None:
            return None  # No limit set
        
        total = self.get_total_traffic()
        limit = int(self.traffic_limit_GB * ONE_GIG)
        remaining = limit - total
        return max(0, remaining)
    
    def get_remaining_traffic_GB(self):
        """Get remaining traffic in GB"""
        remaining = self.get_remaining_traffic()
        if remaining is None:
            return None
        return remaining / ONE_GIG
    
    def can_create_user_with_traffic(self, user_traffic_limit_GB=None):
        """بررسی اینکه آیا می‌تواند کاربر جدید با ترافیک مشخص ایجاد کند"""
        # If no traffic limit is set for agent, allow creation
        if self.traffic_limit_GB is None:
            return True, None
        
        current_total = self.get_total_traffic()
        agent_limit = int(self.traffic_limit_GB * ONE_GIG)
        
        # If user_traffic_limit is provided, check if adding it would exceed
        if user_traffic_limit_GB is not None:
            user_limit = int(user_traffic_limit_GB * ONE_GIG)
            if current_total + user_limit > agent_limit:
                return False, f"مجموع ترافیک کاربران ({current_total/ONE_GIG:.2f} GB) به علاوه ترافیک کاربر جدید ({user_traffic_limit_GB} GB) از حد مجاز ایجنت ({self.traffic_limit_GB} GB) بیشتر است"
        
        # Check if current usage is already over limit
        if current_total >= agent_limit:
            return False, f"ترافیک مصرفی کاربران ({current_total/ONE_GIG:.2f} GB) از حد مجاز ایجنت ({self.traffic_limit_GB} GB) تجاوز کرده است"
        
        return True, None
    
    def is_traffic_limit_exceeded(self):
        """بررسی اینکه آیا ترافیک از حد مجاز تجاوز کرده است"""
        if self.traffic_limit_GB is None:
            return False
        
        total = self.get_total_traffic()
        limit = int(self.traffic_limit_GB * ONE_GIG)
        return total >= limit
    
    def disable_all_users(self):
        """غیرفعال‌سازی تمام کاربران ایجاد شده توسط این ایجنت"""
        from hiddifypanel.database import db
        from hiddifypanel.models.user import User
        
        admin_ids = self.recursive_sub_admins_ids()
        
        affected = db.session.query(User).filter(
            User.added_by.in_(admin_ids)
        ).update(
            {User.enable: False},
            synchronize_session=False
        )
        
        db.session.commit()
        logger.warning(f"Disabled {affected} users for agent {self.name} (ID: {self.id}) due to traffic limit exceeded")
        return affected
    
    # Attach methods to AdminUser class
    AdminUser.traffic_limit_GB = traffic_limit_GB
    AdminUser.get_total_traffic = get_total_traffic
    AdminUser.get_total_traffic_GB = get_total_traffic_GB
    AdminUser.get_remaining_traffic = get_remaining_traffic
    AdminUser.get_remaining_traffic_GB = get_remaining_traffic_GB
    AdminUser.can_create_user_with_traffic = can_create_user_with_traffic
    AdminUser.is_traffic_limit_exceeded = is_traffic_limit_exceeded
    AdminUser.disable_all_users = disable_all_users


class AgentTrafficExtension:
    """Extension class for agent traffic management"""
    pass

