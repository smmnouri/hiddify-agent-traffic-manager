"""
Hook برای بررسی ترافیک قبل از ایجاد کاربر
"""
from sqlalchemy import event
from hiddifypanel.models.user import User
from hiddifypanel.models.admin import AdminUser
from loguru import logger
from apiflask import abort
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
        user_traffic_limit_GB = target.usage_limit_GB if target.usage_limit else None
        
        # Check if agent can create this user
        can_create, error_msg = agent.can_create_user_with_traffic(user_traffic_limit_GB)
        
        if not can_create:
            logger.error(
                f"User creation blocked for agent {agent.name} (ID: {agent_id}). "
                f"Reason: {error_msg}"
            )
            abort(400, error_msg or _("Cannot create user due to traffic limit"))
    
    @event.listens_for(User, 'before_update', propagate=True)
    def check_traffic_before_user_update(mapper, connection, target):
        """بررسی ترافیک قبل از update کردن کاربر (اگر usage_limit تغییر کند)"""
        # Only check if usage_limit is being updated
        if 'usage_limit' not in target.__dict__ and 'usage_limit_GB' not in target.__dict__:
            return
        
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
        
        # Get current total traffic (excluding this user's current limit)
        current_total = agent.get_total_traffic()
        current_user_limit = target.usage_limit or 0
        
        # Get new user limit
        new_user_limit = target.usage_limit if hasattr(target, 'usage_limit') else target.usage_limit_GB * (1024**3)
        
        # Calculate new total
        new_total = current_total - current_user_limit + new_user_limit
        agent_limit = int(agent.traffic_limit_GB * (1024**3))
        
        if new_total > agent_limit:
            logger.error(
                f"User update blocked for agent {agent.name} (ID: {agent_id}). "
                f"New total would exceed limit: {new_total/(1024**3):.2f} GB > {agent.traffic_limit_GB} GB"
            )
            abort(400, _("Updating user traffic limit would exceed agent's traffic limit"))


def init_user_creation_hook():
    """Initialize user creation hooks"""
    setup_user_creation_hook()
    logger.success("User creation traffic check hooks initialized")

