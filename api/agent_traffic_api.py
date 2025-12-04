"""
API endpoints for agent traffic management
"""
from flask import Blueprint, request, jsonify
from flask_babel import gettext as _
from apiflask import APIBlueprint, input, output
from pydantic import BaseModel
from typing import Optional
from loguru import logger

from hiddifypanel.models.admin import AdminUser, AdminMode
from hiddifypanel.database import db
from ..utils.traffic_calculator import AgentTrafficCalculator
from ..utils.traffic_checker import AgentTrafficChecker

agent_traffic_bp = APIBlueprint('agent_traffic', __name__)


# Schemas
class TrafficLimitSchema(BaseModel):
    traffic_limit_GB: Optional[float] = None


class AgentTrafficStatsSchema(BaseModel):
    agent_id: int
    agent_name: str
    agent_uuid: str
    total_traffic_bytes: int
    total_traffic_GB: float
    traffic_limit_GB: Optional[float]
    remaining_traffic_GB: Optional[float]
    is_limit_exceeded: bool
    users_count: int
    active_users_count: int
    usage_percentage: Optional[float]


@agent_traffic_bp.get('/agents/<int:agent_id>/traffic')
@output(AgentTrafficStatsSchema)
def get_agent_traffic(agent_id: int):
    """دریافت آمار ترافیک یک ایجنت"""
    agent = AdminUser.query.get(agent_id)
    if not agent:
        return {'error': 'Agent not found'}, 404
    
    if agent.mode != AdminMode.agent:
        return {'error': 'User is not an agent'}, 400
    
    stats = AgentTrafficCalculator.get_agent_traffic_stats(agent_id)
    return stats


@agent_traffic_bp.put('/agents/<int:agent_id>/traffic-limit')
@input(TrafficLimitSchema)
def set_agent_traffic_limit(agent_id: int, json_data: dict):
    """تنظیم محدودیت ترافیک برای یک ایجنت"""
    agent = AdminUser.query.get(agent_id)
    if not agent:
        return {'error': 'Agent not found'}, 404
    
    if agent.mode != AdminMode.agent:
        return {'error': 'User is not an agent'}, 400
    
    traffic_limit_GB = json_data.get('traffic_limit_GB')
    
    try:
        agent.traffic_limit_GB = traffic_limit_GB
        db.session.commit()
        
        logger.info(
            f"Traffic limit set for agent {agent.name} (ID: {agent_id}): "
            f"{traffic_limit_GB} GB" if traffic_limit_GB else "Unlimited"
        )
        
        return {
            'message': 'Traffic limit updated successfully',
            'agent_id': agent_id,
            'traffic_limit_GB': traffic_limit_GB
        }
    except Exception as e:
        logger.error(f"Error setting traffic limit: {e}")
        db.session.rollback()
        return {'error': str(e)}, 500


@agent_traffic_bp.get('/agents/traffic')
def get_all_agents_traffic():
    """دریافت ترافیک تمام ایجنت‌ها"""
    try:
        agents_traffic = AgentTrafficCalculator.get_all_agents_traffic()
        return {
            'agents': agents_traffic,
            'count': len(agents_traffic)
        }
    except Exception as e:
        logger.error(f"Error getting agents traffic: {e}")
        return {'error': str(e)}, 500


@agent_traffic_bp.post('/agents/<int:agent_id>/check')
def check_agent_traffic(agent_id: int):
    """بررسی ترافیک یک ایجنت و غیرفعال‌سازی در صورت تجاوز"""
    agent = AdminUser.query.get(agent_id)
    if not agent:
        return {'error': 'Agent not found'}, 404
    
    if agent.mode != AdminMode.agent:
        return {'error': 'User is not an agent'}, 400
    
    try:
        was_exceeded = AgentTrafficChecker.check_and_disable_if_exceeded(agent_id)
        
        stats = AgentTrafficCalculator.get_agent_traffic_stats(agent_id)
        
        return {
            'message': 'Check completed',
            'was_exceeded': was_exceeded,
            'stats': stats
        }
    except Exception as e:
        logger.error(f"Error checking agent traffic: {e}")
        return {'error': str(e)}, 500


@agent_traffic_bp.post('/agents/check-all')
def check_all_agents_traffic():
    """بررسی ترافیک تمام ایجنت‌ها"""
    try:
        exceeded_count = AgentTrafficChecker.check_all_agents()
        
        return {
            'message': 'All agents checked',
            'exceeded_agents_count': exceeded_count
        }
    except Exception as e:
        logger.error(f"Error checking all agents: {e}")
        return {'error': str(e)}, 500


@agent_traffic_bp.post('/agents/<int:agent_id>/can-create-user')
@input({'user_traffic_limit_GB': Optional[float]})
def can_create_user(agent_id: int, json_data: dict):
    """بررسی اینکه آیا ایجنت می‌تواند کاربر جدید ایجاد کند"""
    agent = AdminUser.query.get(agent_id)
    if not agent:
        return {'error': 'Agent not found'}, 404
    
    if agent.mode != AdminMode.agent:
        return {'error': 'User is not an agent'}, 400
    
    user_traffic_limit_GB = json_data.get('user_traffic_limit_GB')
    
    try:
        can_create, error_msg = AgentTrafficChecker.check_before_user_creation(
            agent_id, user_traffic_limit_GB
        )
        
        stats = AgentTrafficCalculator.get_agent_traffic_stats(agent_id)
        
        return {
            'can_create': can_create,
            'error_message': error_msg,
            'agent_stats': stats
        }
    except Exception as e:
        logger.error(f"Error checking if can create user: {e}")
        return {'error': str(e)}, 500

