"""
Hiddify Agent Traffic Manager
ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها
"""

__version__ = "1.0.0"
__author__ = "Hiddify Agent Traffic Manager"

from .models.agent_traffic import init_agent_traffic
from .utils.traffic_calculator import AgentTrafficCalculator
from .utils.traffic_checker import AgentTrafficChecker
from .tasks.periodic_checker import setup_periodic_checker
from .utils.user_creation_hook import init_user_creation_hook

def init_app(app):
    """Initialize the agent traffic manager extension"""
    # Initialize database extensions
    init_agent_traffic(app)
    
    # Setup user creation hooks
    init_user_creation_hook()
    
    # Setup periodic checker
    setup_periodic_checker(app)
    
    # Register blueprints
    from .api.agent_traffic_api import agent_traffic_bp
    app.register_blueprint(agent_traffic_bp, url_prefix='/api/v1/agent-traffic')
    
    # Extend admin interface (optional)
    try:
        from .admin.agent_traffic_admin import extend_admin_user_view, add_traffic_management_view
        from flask_admin import Admin
        
        # Try to get admin instance
        admin = getattr(app, 'admin', None)
        if admin:
            add_traffic_management_view(admin, app)
    except Exception as e:
        from loguru import logger
        logger.warning(f"Could not extend admin interface: {e}")
    
    return app

__all__ = [
    'init_app',
    'AgentTrafficCalculator',
    'AgentTrafficChecker',
    'setup_periodic_checker'
]

