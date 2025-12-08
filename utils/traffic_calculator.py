"""
Utility functions for calculating agent traffic
"""
from sqlalchemy import func
from loguru import logger

ONE_GIG = 1024 * 1024 * 1024


class AgentTrafficCalculator:
    """کلاس برای محاسبه ترافیک ایجنت‌ها"""
    
    @staticmethod
    def calculate_agent_traffic(agent_id: int) -> int:
        """
        محاسبه مجموع ترافیک مصرفی تمام کاربران یک ایجنت
        
        Args:
            agent_id: شناسه ایجنت (AdminUser)
            
        Returns:
            مجموع ترافیک به بایت
        """
        from hiddifypanel.models.admin import AdminUser
        agent = AdminUser.query.get(agent_id)
        if not agent:
            logger.error(f"Agent with ID {agent_id} not found")
            return 0
        
        return agent.get_total_traffic()
    
    @staticmethod
    def calculate_agent_traffic_GB(agent_id: int) -> float:
        """
        محاسبه مجموع ترافیک مصرفی تمام کاربران یک ایجنت به گیگابایت
        
        Args:
            agent_id: شناسه ایجنت
            
        Returns:
            مجموع ترافیک به گیگابایت
        """
        total_bytes = AgentTrafficCalculator.calculate_agent_traffic(agent_id)
        return total_bytes / ONE_GIG
    
    @staticmethod
    def get_all_agents_traffic():
        """
        دریافت ترافیک تمام ایجنت‌ها
        
        Returns:
            لیست دیکشنری شامل اطلاعات ترافیک هر ایجنت
        """
        from hiddifypanel.models.admin import AdminUser, AdminMode
        
        agents = AdminUser.query.filter(
            AdminUser.mode == AdminMode.agent
        ).all()
        
        result = []
        for agent in agents:
            total_traffic = agent.get_total_traffic()
            total_traffic_GB = total_traffic / ONE_GIG
            traffic_limit_GB = agent.traffic_limit_GB
            remaining_traffic_GB = agent.get_remaining_traffic_GB()
            is_exceeded = agent.is_traffic_limit_exceeded()
            
            result.append({
                'agent_id': agent.id,
                'agent_name': agent.name,
                'agent_uuid': agent.uuid,
                'total_traffic_bytes': total_traffic,
                'total_traffic_GB': total_traffic_GB,
                'traffic_limit_GB': traffic_limit_GB,
                'remaining_traffic_GB': remaining_traffic_GB,
                'is_limit_exceeded': is_exceeded,
                'users_count': agent.recursive_users_query().count()
            })
        
        return result
    
    @staticmethod
    def get_agent_traffic_stats(agent_id: int) -> dict:
        """
        دریافت آمار کامل ترافیک یک ایجنت
        
        Args:
            agent_id: شناسه ایجنت
            
        Returns:
            دیکشنری شامل آمار ترافیک
        """
        from hiddifypanel.models.admin import AdminUser
        from hiddifypanel.models.user import User
        
        agent = AdminUser.query.get(agent_id)
        if not agent:
            return None
        
        total_traffic = agent.get_total_traffic()
        total_traffic_GB = total_traffic / ONE_GIG
        traffic_limit_GB = agent.traffic_limit_GB
        remaining_traffic_GB = agent.get_remaining_traffic_GB()
        is_exceeded = agent.is_traffic_limit_exceeded()
        users_count = agent.recursive_users_query().count()
        active_users_count = agent.recursive_users_query().filter(User.enable == True).count()
        
        return {
            'agent_id': agent.id,
            'agent_name': agent.name,
            'agent_uuid': agent.uuid,
            'total_traffic_bytes': total_traffic,
            'total_traffic_GB': round(total_traffic_GB, 2),
            'traffic_limit_GB': traffic_limit_GB,
            'remaining_traffic_GB': round(remaining_traffic_GB, 2) if remaining_traffic_GB is not None else None,
            'is_limit_exceeded': is_exceeded,
            'users_count': users_count,
            'active_users_count': active_users_count,
            'usage_percentage': round((total_traffic_GB / traffic_limit_GB * 100), 2) if traffic_limit_GB else None
        }

