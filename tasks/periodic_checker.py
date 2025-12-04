"""
Background task for periodic checking of agent traffic limits
"""
from flask import Flask
from loguru import logger
from datetime import datetime
from hiddifypanel.models.admin import AdminUser, AdminMode
from ..utils.traffic_checker import AgentTrafficChecker


def setup_periodic_checker(app: Flask):
    """
    Setup periodic checker for agent traffic limits
    
    This function sets up a Celery task that runs periodically
    to check if any agents have exceeded their traffic limits
    and disable their users if necessary.
    """
    try:
        from hiddifypanel.apps.celery_app import celery_app
        
        @celery_app.task(name='agent_traffic.check_limits')
        def check_agent_traffic_limits_task():
            """Celery task for checking agent traffic limits"""
            with app.app_context():
                return check_agent_traffic_limits()
        
        # Schedule periodic task (every 5 minutes)
        from celery.schedules import crontab
        
        celery_app.conf.beat_schedule.update({
            'check-agent-traffic-limits': {
                'task': 'agent_traffic.check_limits',
                'schedule': crontab(minute='*/5'),  # Every 5 minutes
            },
        })
        
        logger.success("Periodic agent traffic checker setup completed")
        
    except ImportError:
        logger.warning("Celery not available, periodic checker will not run")
    except Exception as e:
        logger.error(f"Error setting up periodic checker: {e}")


def check_agent_traffic_limits():
    """
    Check all agents for traffic limit violations and disable users if needed
    
    Returns:
        dict: Statistics about the check
    """
    try:
        agents = AdminUser.query.filter(
            AdminUser.mode == AdminMode.agent
        ).all()
        
        total_agents = len(agents)
        checked_agents = 0
        exceeded_agents = 0
        disabled_users_count = 0
        
        for agent in agents:
            if agent.traffic_limit_GB is None:
                continue  # Skip agents without traffic limit
            
            checked_agents += 1
            
            if agent.is_traffic_limit_exceeded():
                exceeded_agents += 1
                logger.warning(
                    f"Agent {agent.name} (ID: {agent.id}) has exceeded traffic limit. "
                    f"Total: {agent.get_total_traffic_GB():.2f} GB / Limit: {agent.traffic_limit_GB} GB"
                )
                
                # Disable all users
                disabled_count = agent.disable_all_users()
                disabled_users_count += disabled_count
                
                logger.info(
                    f"Disabled {disabled_count} users for agent {agent.name} "
                    f"due to traffic limit exceeded"
                )
        
        result = {
            'timestamp': datetime.now().isoformat(),
            'total_agents': total_agents,
            'checked_agents': checked_agents,
            'exceeded_agents': exceeded_agents,
            'disabled_users_count': disabled_users_count
        }
        
        logger.info(f"Agent traffic check completed: {result}")
        return result
        
    except Exception as e:
        logger.error(f"Error checking agent traffic limits: {e}")
        return {
            'error': str(e),
            'timestamp': datetime.now().isoformat()
        }


def check_agent_traffic_limits_manual():
    """
    Manual function to check agent traffic limits (can be called from CLI)
    """
    from flask import current_app
    with current_app.app_context():
        return check_agent_traffic_limits()

