"""
Hiddify Agent Traffic Manager
ماژول مدیریت محدودیت ترافیک برای ایجنت‌ها
"""

__version__ = "1.0.0"
__author__ = "Hiddify Agent Traffic Manager"

# Lazy imports to avoid circular import issues
# These will be imported when actually needed, not at module level

def init_app(app):
    """Initialize the agent traffic manager extension
    
    This function is called by HiddifyPanel's extension system.
    It can also be called manually: app = init_app(app)
    """
    from loguru import logger
    
    try:
        # Lazy import to avoid circular import issues
        from .models.agent_traffic import init_agent_traffic
        # Initialize database extensions
        init_agent_traffic(app)
    except Exception as e:
        logger.error(f"Error initializing agent traffic database: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        # Continue anyway
    
    try:
        # Lazy import to avoid circular import issues
        from .utils.user_creation_hook import init_user_creation_hook
        # Setup user creation hooks
        init_user_creation_hook()
    except Exception as e:
        logger.error(f"Error setting up user creation hooks: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        # Continue anyway
    
    try:
        # Lazy import to avoid circular import issues
        from .tasks.periodic_checker import setup_periodic_checker
        # Setup periodic checker
        setup_periodic_checker(app)
    except Exception as e:
        logger.warning(f"Error setting up periodic checker: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        # Continue anyway
    
    try:
        # Register blueprints
        from .api.agent_traffic_api import agent_traffic_bp
        app.register_blueprint(agent_traffic_bp, url_prefix='/api/v1/agent-traffic')
    except Exception as e:
        logger.error(f"Error registering blueprints: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        # Continue anyway
    
    # Extend admin interface (with better error handling)
    try:
        from loguru import logger
        
        # Try to extend admin interface, but don't fail if it doesn't work
        try:
            from .admin.agent_traffic_admin import extend_admin_user_view, add_traffic_management_view
            
            # Extend AdminstratorAdmin class before it's used
            try:
                from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
                import hiddifypanel.panel.admin.AdminstratorAdmin as admin_module
                
                # Extend the class
                extended_class = extend_admin_user_view(AdminstratorAdmin)
                admin_module.AdminstratorAdmin = extended_class
                
                logger.success("Extended AdminstratorAdmin class with traffic management")
            except ImportError as e:
                logger.debug(f"AdminstratorAdmin not found yet (will extend later): {e}")
            except Exception as e:
                logger.warning(f"Could not extend AdminstratorAdmin class: {e}")
                import traceback
                logger.debug(traceback.format_exc())
            
            # Register with HiddifyPanel's event system
            try:
                from hiddifypanel import Events
                
                def extend_admin_views(flaskadmin=None, admin_bp=None):
                    """Extend admin views using HiddifyPanel's event system"""
                    try:
                        # Extend AdminstratorAdmin if not already extended
                        try:
                            from hiddifypanel.panel.admin.AdminstratorAdmin import AdminstratorAdmin
                            import hiddifypanel.panel.admin.AdminstratorAdmin as admin_module
                            
                            # Check if already extended
                            if not hasattr(AdminstratorAdmin, 'column_formatters') or 'traffic_limit_GB' not in getattr(AdminstratorAdmin, 'column_formatters', {}):
                                extended_class = extend_admin_user_view(AdminstratorAdmin)
                                admin_module.AdminstratorAdmin = extended_class
                                logger.success("Extended AdminstratorAdmin via event hook")
                        except Exception as e:
                            logger.debug(f"Could not extend AdminstratorAdmin in event hook: {e}")
                        
                        # Add traffic management view if admin instance is available
                        if flaskadmin:
                            try:
                                add_traffic_management_view(flaskadmin, app)
                                logger.success("Added traffic management view to admin")
                            except Exception as e:
                                logger.warning(f"Could not add traffic management view: {e}")
                                
                    except Exception as e:
                        logger.error(f"Error in extend_admin_views: {e}")
                        import traceback
                        logger.debug(traceback.format_exc())
                
                # Register with HiddifyPanel's event system
                Events.admin_prehook.subscribe(extend_admin_views)
                logger.success("Registered admin_prehook for traffic management")
                
            except ImportError:
                logger.debug("Events.admin_prehook not available, skipping admin extension")
            except Exception as e:
                logger.warning(f"Could not register admin_prehook: {e}")
                import traceback
                logger.debug(traceback.format_exc())
                
        except ImportError as e:
            logger.debug(f"Could not import admin extension modules: {e}")
        except Exception as e:
            logger.warning(f"Could not extend admin interface: {e}")
            import traceback
            logger.debug(traceback.format_exc())
            
    except Exception as e:
        from loguru import logger
        logger.error(f"Critical error in admin interface extension: {e}")
        import traceback
        logger.debug(traceback.format_exc())
        # Don't fail the entire app if admin extension fails
    
    return app

# Lazy getters for classes to avoid import errors
def get_AgentTrafficCalculator():
    """Lazy getter for AgentTrafficCalculator"""
    from .utils.traffic_calculator import AgentTrafficCalculator
    return AgentTrafficCalculator

def get_AgentTrafficChecker():
    """Lazy getter for AgentTrafficChecker"""
    from .utils.traffic_checker import AgentTrafficChecker
    return AgentTrafficChecker

def get_setup_periodic_checker():
    """Lazy getter for setup_periodic_checker"""
    from .tasks.periodic_checker import setup_periodic_checker
    return setup_periodic_checker

__all__ = [
    'init_app',
    'get_AgentTrafficCalculator',
    'get_AgentTrafficChecker',
    'get_setup_periodic_checker'
]

