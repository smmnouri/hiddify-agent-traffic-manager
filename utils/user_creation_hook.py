"""
Hook برای بررسی ترافیک قبل از ایجاد کاربر
"""
from sqlalchemy import event
from hiddifypanel.models.user import User
from hiddifypanel.models.admin import AdminUser
from loguru import logger
from flask_babel import gettext as _


def setup_user_creation_hook():
    """Setup hook to check traffic before user creation"""
    
    @event.listens_for(User, 'before_insert', propagate=True)
    def check_traffic_before_user_insert(mapper, connection, target):
        """بررسی ترافیک قبل از insert کردن کاربر"""
        # Get the agent who is creating this user
        agent_id = target.added_by
        
        if not agent_id:
            # If no agent specified, use current admin
            from flask import g
            if hasattr(g, 'account') and isinstance(g.account, AdminUser):
                agent_id = g.account.id
            else:
                agent_id = 1  # Owner
        
        agent = AdminUser.query.get(agent_id)
        if not agent:
            logger.warning(f"Agent with ID {agent_id} not found, skipping traffic check")
            return
        
        # Only check for agents
        from hiddifypanel.models.admin import AdminMode
        if agent.mode != AdminMode.agent:
            return  # Not an agent, skip check
        
        # Check if agent has traffic limit
        if agent.traffic_limit_GB is None:
            return  # No limit set, allow creation
        
        # Get user traffic limit
        user_traffic_limit_GB = target.usage_limit_GB if hasattr(target, 'usage_limit') and target.usage_limit else None
        
        # Check if agent can create this user
        can_create, error_msg = agent.can_create_user_with_traffic(user_traffic_limit_GB)
        
        if not can_create:
            logger.error(
                f"User creation blocked for agent {agent.name} (ID: {agent_id}). "
                f"Reason: {error_msg}"
            )
            from sqlalchemy.exc import IntegrityError
            raise IntegrityError(
                statement=None,
                params=None,
                orig=ValueError(error_msg or _("Cannot create user due to traffic limit"))
            )
    
    @event.listens_for(User, 'before_update', propagate=True)
    def check_traffic_before_user_update(mapper, connection, target):
        """بررسی ترافیک قبل از update کردن کاربر (اگر usage_limit تغییر کند)"""
        from sqlalchemy.orm import inspect
        
        # Check if usage_limit is being updated using SQLAlchemy inspect
        insp = inspect(target)
        if not insp.has_identity:
            return  # New object, not an update
        
        # Get changed attributes
        attrs = insp.attrs
        usage_limit_changed = 'usage_limit' in attrs and attrs['usage_limit'].history.has_changes()
        
        if not usage_limit_changed:
            return  # usage_limit not changed, skip check
        
        agent_id = target.added_by
        if not agent_id:
            return
        
        agent = AdminUser.query.get(agent_id)
        if not agent:
            return
        
        from hiddifypanel.models.admin import AdminMode
        if agent.mode != AdminMode.agent:
            return
        
        if agent.traffic_limit_GB is None:
            return
        
        # Get old and new usage_limit values
        old_value = attrs['usage_limit'].history.deleted[0] if attrs['usage_limit'].history.deleted else 0
        new_value = target.usage_limit or 0
        
        # Get current total traffic (excluding this user's old limit, including new limit)
        # We need to get total from database excluding this user, then add new limit
        from hiddifypanel.database import db
        from hiddifypanel.models.user import User
        from sqlalchemy import func
        
        admin_ids = agent.recursive_sub_admins_ids()
        # Get total traffic excluding this user
        total_excluding_user = db.session.query(
            func.coalesce(func.sum(User.current_usage), 0)
        ).filter(
            User.added_by.in_(admin_ids),
            User.id != target.id
        ).scalar() or 0
        
        # Calculate new total with new user limit
        new_total = total_excluding_user + new_value
        agent_limit = int(agent.traffic_limit_GB * (1024**3))
        
        if new_total > agent_limit:
            logger.error(
                f"User update blocked for agent {agent.name} (ID: {agent_id}). "
                f"New total would exceed limit: {new_total/(1024**3):.2f} GB > {agent.traffic_limit_GB} GB"
            )
            from sqlalchemy.exc import IntegrityError
            raise IntegrityError(
                statement=None,
                params=None,
                orig=ValueError(_("Updating user traffic limit would exceed agent's traffic limit"))
            )


def init_user_creation_hook():
    """Initialize user creation hooks"""
    setup_user_creation_hook()
    logger.success("User creation traffic check hooks initialized")

