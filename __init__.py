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
    """Initialize the agent traffic manager extension
    
    This function is called by HiddifyPanel's extension system.
    It can also be called manually: app = init_app(app)
    """
    # Initialize database extensions
    init_agent_traffic(app)
    
    # Setup user creation hooks
    init_user_creation_hook()
    
    # Setup periodic checker
    setup_periodic_checker(app)
    
    # Register blueprints
    from .api.agent_traffic_api import agent_traffic_bp
    app.register_blueprint(agent_traffic_bp, url_prefix='/api/v1/agent-traffic')
    
    # Extend admin interface
    try:
        from .admin.agent_traffic_admin import extend_admin_user_view, add_traffic_management_view
        from hiddifypanel import Events
        from loguru import logger
        
        def extend_admin_views(flaskadmin=None, admin_bp=None):
            """Extend admin views using HiddifyPanel's event system"""
            try:
                # Import AdminstratorAdmin
                from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
                
                # Extend the AdminstratorAdmin class
                extended_class = extend_admin_user_view(AdminstratorAdmin)
                
                # Replace the original class with extended one
                import hiddifypanel.panel.admin.AdminstratorAdmin as admin_module
                admin_module.AdminstratorAdmin = extended_class
                
                logger.success("Extended AdminstratorAdmin with traffic management")
                
                # Add traffic management view if admin instance is available
                if flaskadmin:
                    add_traffic_management_view(flaskadmin, app)
                    logger.success("Added traffic management view to admin")
                    
            except Exception as e:
                logger.error(f"Error extending admin views: {e}")
                import traceback
                logger.debug(traceback.format_exc())
        
        # Register with HiddifyPanel's event system
        Events.admin_prehook.subscribe(extend_admin_views)
        logger.success("Registered admin_prehook for traffic management")
        
        # Also try to extend immediately if admin is already initialized
        try:
            from hiddifypanel.panel.admin import flaskadmin
            if flaskadmin:
                extend_admin_views(flaskadmin=flaskadmin)
        except:
            pass  # Admin not initialized yet, will be called via event
            
    except Exception as e:
        from loguru import logger
        logger.warning(f"Could not extend admin interface: {e}")
        import traceback
        logger.debug(traceback.format_exc())
    
    return app

__all__ = [
    'init_app',
    'AgentTrafficCalculator',
    'AgentTrafficChecker',
    'setup_periodic_checker'
]

