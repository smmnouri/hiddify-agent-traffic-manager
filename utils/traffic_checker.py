"""
Utility functions for checking traffic limits before user creation
"""
from loguru import logger
from flask_babel import gettext as _


class AgentTrafficChecker:
    """کلاس برای بررسی محدودیت ترافیک قبل از ایجاد کاربر"""
    
    @staticmethod
    def check_before_user_creation(agent_id: int, user_traffic_limit_GB: float = None) -> tuple[bool, str | None]:
        """
        بررسی اینکه آیا ایجنت می‌تواند کاربر جدید ایجاد کند
        
        Args:
            agent_id: شناسه ایجنت
            user_traffic_limit_GB: محدودیت ترافیک کاربر جدید (اختیاری)
            
        Returns:
            tuple: (can_create: bool, error_message: str | None)
        """
        from hiddifypanel.models.admin import AdminUser
        agent = AdminUser.query.get(agent_id)
        if not agent:
            return False, "Agent not found"
        
        # Check if agent has traffic limit
        if agent.traffic_limit_GB is None:
            # No limit set, allow creation
            return True, None
        
        # Check traffic limit
        can_create, error_msg = agent.can_create_user_with_traffic(user_traffic_limit_GB)
        
        if not can_create:
            logger.warning(
                f"Agent {agent.name} (ID: {agent_id}) cannot create user. "
                f"Reason: {error_msg}"
            )
        
        return can_create, error_msg
    
    @staticmethod
    def validate_user_creation(agent_id: int, user_traffic_limit_GB: float = None):
        """
        Validate user creation and raise exception if not allowed
        
        Args:
            agent_id: شناسه ایجنت
            user_traffic_limit_GB: محدودیت ترافیک کاربر جدید
            
        Raises:
            HTTPException: اگر ایجاد کاربر مجاز نباشد
        """
        can_create, error_msg = AgentTrafficChecker.check_before_user_creation(
            agent_id, user_traffic_limit_GB
        )
        
        if not can_create:
            from apiflask import abort
            abort(400, error_msg or "Cannot create user due to traffic limit")
    
    @staticmethod
    def check_and_disable_if_exceeded(agent_id: int) -> bool:
        """
        بررسی ترافیک ایجنت و در صورت تجاوز، غیرفعال‌سازی کاربران
        
        Args:
            agent_id: شناسه ایجنت
            
        Returns:
            True if users were disabled, False otherwise
        """
        from hiddifypanel.models.admin import AdminUser
        agent = AdminUser.query.get(agent_id)
        if not agent:
            return False
        
        if agent.is_traffic_limit_exceeded():
            logger.warning(
                f"Agent {agent.name} (ID: {agent_id}) has exceeded traffic limit. "
                f"Disabling all users..."
            )
            disabled_count = agent.disable_all_users()
            logger.info(f"Disabled {disabled_count} users for agent {agent.name}")
            return True
        
        return False
    
    @staticmethod
    def check_all_agents():
        """
        بررسی تمام ایجنت‌ها و غیرفعال‌سازی کاربران در صورت تجاوز
        
        Returns:
            تعداد ایجنت‌هایی که از حد تجاوز کرده‌اند
        """
        from hiddifypanel.models.admin import AdminUser, AdminMode
        
        agents = AdminUser.query.filter(
            AdminUser.mode == AdminMode.agent
        ).all()
        
        exceeded_count = 0
        for agent in agents:
            if agent.traffic_limit_GB is None:
                continue  # Skip agents without traffic limit
            
            if AgentTrafficChecker.check_and_disable_if_exceeded(agent.id):
                exceeded_count += 1
        
        return exceeded_count

