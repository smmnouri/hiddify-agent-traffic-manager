"""
مثال استفاده از ماژول Agent Traffic Manager
"""

# مثال 1: تنظیم محدودیت ترافیک برای یک ایجنت
def example_set_traffic_limit():
    from hiddifypanel.models.admin import AdminUser, AdminMode
    from hiddifypanel.database import db
    
    # پیدا کردن یک ایجنت
    agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
    
    if agent:
        # تنظیم محدودیت ترافیک به 1000 GB
        agent.traffic_limit_GB = 1000
        db.session.commit()
        print(f"Traffic limit set to 1000 GB for agent {agent.name}")


# مثال 2: بررسی ترافیک یک ایجنت
def example_check_agent_traffic():
    from hiddifypanel.models.admin import AdminUser, AdminMode
    from hiddify_agent_traffic_manager.utils.traffic_calculator import AgentTrafficCalculator
    
    agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
    
    if agent:
        stats = AgentTrafficCalculator.get_agent_traffic_stats(agent.id)
        print(f"Agent: {stats['agent_name']}")
        print(f"Total Traffic: {stats['total_traffic_GB']} GB")
        print(f"Traffic Limit: {stats['traffic_limit_GB']} GB")
        print(f"Remaining: {stats['remaining_traffic_GB']} GB")
        print(f"Is Exceeded: {stats['is_limit_exceeded']}")


# مثال 3: بررسی اینکه آیا می‌توان کاربر جدید ایجاد کرد
def example_check_can_create_user():
    from hiddifypanel.models.admin import AdminUser, AdminMode
    from hiddify_agent_traffic_manager.utils.traffic_checker import AgentTrafficChecker
    
    agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
    
    if agent:
        # بررسی با ترافیک 50 GB برای کاربر جدید
        can_create, error_msg = AgentTrafficChecker.check_before_user_creation(
            agent.id, 
            user_traffic_limit_GB=50
        )
        
        if can_create:
            print("Agent can create user with 50 GB limit")
        else:
            print(f"Cannot create user: {error_msg}")


# مثال 4: بررسی و غیرفعال‌سازی کاربران در صورت تجاوز
def example_check_and_disable():
    from hiddifypanel.models.admin import AdminUser, AdminMode
    from hiddify_agent_traffic_manager.utils.traffic_checker import AgentTrafficChecker
    
    agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
    
    if agent:
        was_exceeded = AgentTrafficChecker.check_and_disable_if_exceeded(agent.id)
        
        if was_exceeded:
            print(f"Agent {agent.name} exceeded traffic limit. Users disabled.")
        else:
            print(f"Agent {agent.name} is within traffic limit.")


# مثال 5: استفاده از متدهای اضافه شده به AdminUser
def example_use_agent_methods():
    from hiddifypanel.models.admin import AdminUser, AdminMode
    
    agent = AdminUser.query.filter(AdminUser.mode == AdminMode.agent).first()
    
    if agent:
        # دریافت محدودیت ترافیک
        limit = agent.traffic_limit_GB
        print(f"Traffic Limit: {limit} GB" if limit else "No limit set")
        
        # دریافت مجموع ترافیک
        total = agent.get_total_traffic_GB()
        print(f"Total Traffic: {total:.2f} GB")
        
        # دریافت ترافیک باقیمانده
        remaining = agent.get_remaining_traffic_GB()
        print(f"Remaining: {remaining:.2f} GB" if remaining else "Unlimited")
        
        # بررسی اینکه آیا از حد تجاوز کرده است
        is_exceeded = agent.is_traffic_limit_exceeded()
        print(f"Is Exceeded: {is_exceeded}")
        
        # بررسی امکان ایجاد کاربر
        can_create, error = agent.can_create_user_with_traffic(50)
        print(f"Can create user with 50 GB: {can_create}")


if __name__ == "__main__":
    # این مثال‌ها نیاز به Flask app context دارند
    from flask import Flask
    from hiddifypanel.database import db
    
    app = Flask(__name__)
    # تنظیمات app...
    
    with app.app_context():
        # مثال 1
        # example_set_traffic_limit()
        
        # مثال 2
        # example_check_agent_traffic()
        
        # مثال 3
        # example_check_can_create_user()
        
        # مثال 4
        # example_check_and_disable()
        
        # مثال 5
        # example_use_agent_methods()
        
        pass

