"""
Traffic Service for Agent/Reseller system
سرویس مدیریت ترافیک Agent
"""
from hiddifypanel.database import db
from hiddifypanel.models import Agent, User, TrafficLog
from hiddifypanel.models.user import ONE_GIG
from sqlalchemy import event, func
from sqlalchemy.orm import Session
from datetime import datetime
from loguru import logger


def update_agent_traffic(agent_id: int, commit: bool = True):
    """
    Update agent's traffic_used by calculating sum of all users' current_usage
    
    Args:
        agent_id: Agent ID
        commit: Whether to commit the transaction
    """
    agent = Agent.by_id(agent_id)
    if not agent:
        logger.warning(f"Agent {agent_id} not found")
        return
    
    # Calculate total usage from all users under this agent
    total_usage = db.session.query(
        func.coalesce(func.sum(User.current_usage), 0)
    ).filter(
        User.agent_id == agent_id
    ).scalar() or 0
    
    old_traffic_used = agent.traffic_used
    agent.traffic_used = total_usage
    agent.updated_at = datetime.utcnow()
    
    if commit:
        db.session.commit()
    
    logger.debug(f"Updated agent {agent_id} traffic: {old_traffic_used / ONE_GIG:.2f} GB -> {total_usage / ONE_GIG:.2f} GB")


def log_user_traffic(user_id: int, used_traffic: int, description: str = None, commit: bool = True):
    """
    Log user traffic usage
    
    Args:
        user_id: User ID
        used_traffic: Traffic used in bytes
        description: Optional description
        commit: Whether to commit the transaction
    """
    user = User.by_id(user_id)
    if not user:
        logger.warning(f"User {user_id} not found")
        return
    
    agent_id = user.agent_id if hasattr(user, 'agent_id') else None
    
    # Create traffic log
    log = TrafficLog.create_log(
        user_id=user_id,
        agent_id=agent_id,
        used_traffic=used_traffic,
        description=description or f"User {user_id} traffic usage",
        commit=False
    )
    
    # Update agent traffic if user has an agent
    if agent_id:
        update_agent_traffic(agent_id, commit=False)
    
    if commit:
        db.session.commit()
    
    return log


def check_agent_can_create_user(agent_id: int, user_traffic_limit_GB: float = None) -> tuple[bool, str | None]:
    """
    Check if agent can create a new user with specified traffic limit
    
    Args:
        agent_id: Agent ID
        user_traffic_limit_GB: Traffic limit for the new user in GB
        
    Returns:
        tuple: (can_create: bool, error_message: str | None)
    """
    agent = Agent.by_id(agent_id)
    if not agent:
        return False, "Agent not found"
    
    return agent.can_create_user(user_traffic_limit_GB)


def check_agent_can_update_user_traffic(agent_id: int, user_id: int, new_traffic_limit_GB: float) -> tuple[bool, str | None]:
    """
    Check if agent can update user's traffic limit
    
    Args:
        agent_id: Agent ID
        user_id: User ID
        new_traffic_limit_GB: New traffic limit in GB
        
    Returns:
        tuple: (can_update: bool, error_message: str | None)
    """
    agent = Agent.by_id(agent_id)
    if not agent:
        return False, "Agent not found"
    
    if agent.traffic_limit is None:
        return True, None
    
    # Get current user's traffic limit
    user = User.by_id(user_id)
    if not user:
        return False, "User not found"
    
    old_traffic_limit = user.usage_limit or 0
    
    # Calculate new total
    from sqlalchemy import func
    total_excluding_user = db.session.query(
        func.coalesce(func.sum(User.current_usage), 0)
    ).filter(
        User.agent_id == agent_id,
        User.id != user_id
    ).scalar() or 0
    
    new_traffic_limit_bytes = int(new_traffic_limit_GB * ONE_GIG)
    new_total = total_excluding_user + new_traffic_limit_bytes
    
    if new_total > agent.traffic_limit:
        remaining_GB = agent.traffic_remaining_GB or 0
        return False, f"Updating user traffic limit would exceed agent traffic limit. Remaining: {remaining_GB:.2f} GB"
    
    return True, None


# SQLAlchemy event listeners for automatic traffic updates

@event.listens_for(User, 'after_insert')
def user_after_insert(mapper, connection, target: User):
    """Update agent traffic when a new user is created"""
    if hasattr(target, 'agent_id') and target.agent_id:
        update_agent_traffic(target.agent_id, commit=False)


@event.listens_for(User, 'after_update')
def user_after_update(mapper, connection, target: User):
    """Update agent traffic when user's current_usage changes"""
    if hasattr(target, 'agent_id') and target.agent_id:
        # Check if current_usage changed
        from sqlalchemy.orm import inspect
        insp = inspect(target)
        if 'current_usage' in insp.attrs and insp.attrs['current_usage'].history.has_changes():
            update_agent_traffic(target.agent_id, commit=False)


@event.listens_for(User, 'after_delete')
def user_after_delete(mapper, connection, target: User):
    """Update agent traffic when a user is deleted"""
    if hasattr(target, 'agent_id') and target.agent_id:
        update_agent_traffic(target.agent_id, commit=False)

