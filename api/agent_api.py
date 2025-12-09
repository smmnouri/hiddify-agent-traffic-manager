"""
Agent API endpoints for managing agents/resellers
"""
from flask import current_app as app, g
from flask.views import MethodView
from apiflask import abort
from hiddifypanel.auth import login_required
from hiddifypanel.models import Role, Agent, User, TrafficLog
from hiddifypanel.database import db
from marshmallow import Schema, fields, validate
from datetime import datetime, timedelta
from typing import Optional

from . import has_permission


class AgentSchema(Schema):
    """Schema for Agent"""
    id = fields.Integer(dump_only=True)
    uuid = fields.String(required=True)
    name = fields.String(required=True, validate=validate.Length(min=1, max=512))
    username = fields.String(allow_none=True, validate=validate.Length(max=100))
    password = fields.String(allow_none=True, validate=validate.Length(max=100))
    comment = fields.String(allow_none=True, validate=validate.Length(max=512))
    telegram_id = fields.Integer(allow_none=True)
    traffic_limit_GB = fields.Float(allow_none=True, validate=validate.Range(min=0))
    traffic_used_GB = fields.Float(dump_only=True)
    traffic_remaining_GB = fields.Float(dump_only=True, allow_none=True)
    traffic_usage_percentage = fields.Float(dump_only=True, allow_none=True)
    is_traffic_limit_exceeded = fields.Boolean(dump_only=True)
    is_traffic_warning = fields.Boolean(dump_only=True)
    users_count = fields.Integer(dump_only=True)
    created_at = fields.DateTime(dump_only=True)
    updated_at = fields.DateTime(dump_only=True)


class PostAgentSchema(Schema):
    """Schema for creating Agent"""
    name = fields.String(required=True, validate=validate.Length(min=1, max=512))
    username = fields.String(allow_none=True, validate=validate.Length(max=100))
    password = fields.String(allow_none=True, validate=validate.Length(max=100))
    comment = fields.String(allow_none=True, validate=validate.Length(max=512))
    telegram_id = fields.Integer(allow_none=True)
    traffic_limit_GB = fields.Float(allow_none=True, validate=validate.Range(min=0))


class PatchAgentSchema(Schema):
    """Schema for updating Agent"""
    name = fields.String(validate=validate.Length(min=1, max=512))
    username = fields.String(allow_none=True, validate=validate.Length(max=100))
    password = fields.String(allow_none=True, validate=validate.Length(max=100))
    comment = fields.String(allow_none=True, validate=validate.Length(max=512))
    telegram_id = fields.Integer(allow_none=True)
    traffic_limit_GB = fields.Float(allow_none=True, validate=validate.Range(min=0))


class AgentTrafficSchema(Schema):
    """Schema for Agent Traffic Statistics"""
    agent_id = fields.Integer(dump_only=True)
    traffic_limit_GB = fields.Float(allow_none=True)
    traffic_used_GB = fields.Float()
    traffic_remaining_GB = fields.Float(allow_none=True)
    traffic_usage_percentage = fields.Float(allow_none=True)
    is_traffic_limit_exceeded = fields.Boolean()
    is_traffic_warning = fields.Boolean()
    users_count = fields.Integer()
    active_users_count = fields.Integer()
    total_users_traffic_GB = fields.Float()


class SuccessfulSchema(Schema):
    """Schema for successful response"""
    status = fields.Integer()
    msg = fields.String()


class AgentApi(MethodView):
    """API for single agent operations"""
    decorators = [login_required({Role.super_admin, Role.admin})]

    @app.output(AgentSchema)
    def get(self, uuid: str):
        """Get agent by UUID"""
        agent = Agent.by_uuid(uuid)
        if not agent:
            abort(404, "Agent not found")
        
        # Only super_admin can access all agents, others can only access their own
        if g.account.mode != Role.super_admin:
            # Check if agent belongs to current admin's hierarchy
            # For now, allow all admins to see all agents
            pass
        
        return agent.to_dict(dump_id=True)

    @app.input(PatchAgentSchema, arg_name='data')
    @app.output(AgentSchema)
    def patch(self, uuid: str, data: dict):
        """Update agent"""
        agent = Agent.by_uuid(uuid)
        if not agent:
            abort(404, "Agent not found")
        
        # Only super_admin can update agents
        if g.account.mode != Role.super_admin:
            abort(403, "Only super admin can update agents")
        
        # Update fields
        for key, value in data.items():
            if hasattr(agent, key):
                if key == 'traffic_limit_GB':
                    agent.traffic_limit_GB = value
                else:
                    setattr(agent, key, value)
        
        agent.updated_at = datetime.utcnow()
        db.session.commit()
        
        return agent.to_dict(dump_id=True)

    @app.output(SuccessfulSchema)
    def delete(self, uuid: str):
        """Delete agent"""
        agent = Agent.by_uuid(uuid)
        if not agent:
            abort(404, "Agent not found")
        
        # Only super_admin can delete agents
        if g.account.mode != Role.super_admin:
            abort(403, "Only super admin can delete agents")
        
        # Check if agent has users
        users_count = agent.users.count()
        if users_count > 0:
            abort(400, f"Cannot delete agent with {users_count} users. Please reassign or delete users first")
        
        db.session.delete(agent)
        db.session.commit()
        
        return {'status': 200, 'msg': 'Agent deleted successfully'}


class AgentsApi(MethodView):
    """API for listing and creating agents"""
    decorators = [login_required({Role.super_admin, Role.admin})]

    @app.output(AgentSchema(many=True))
    def get(self):
        """List all agents"""
        agents = Agent.get_all()
        return [agent.to_dict(dump_id=True) for agent in agents]

    @app.input(PostAgentSchema, arg_name='data')
    @app.output(AgentSchema)
    def post(self, data: dict):
        """Create new agent"""
        # Only super_admin can create agents
        if g.account.mode != Role.super_admin:
            abort(403, "Only super admin can create agents")
        
        # Check if username is unique
        if data.get('username'):
            existing = Agent.query.filter(Agent.username == data['username']).first()
            if existing:
                abort(400, "Username already exists")
        
        # Create agent
        agent = Agent(
            name=data['name'],
            username=data.get('username', ''),
            password=data.get('password', ''),
            comment=data.get('comment', ''),
            telegram_id=data.get('telegram_id'),
            traffic_limit_GB=data.get('traffic_limit_GB')
        )
        
        db.session.add(agent)
        db.session.commit()
        
        return agent.to_dict(dump_id=True)


class AgentTrafficApi(MethodView):
    """API for agent traffic statistics"""
    decorators = [login_required({Role.super_admin, Role.admin, Role.agent})]

    @app.output(AgentTrafficSchema)
    def get(self, uuid: str):
        """Get agent traffic statistics"""
        agent = Agent.by_uuid(uuid)
        if not agent:
            abort(404, "Agent not found")
        
        # Update traffic_used from users
        agent.update_traffic_used(commit=False)
        
        # Get active users count
        active_users_count = agent.users.filter(User.enable == True).count()
        
        # Get total users traffic
        from sqlalchemy import func
        total_users_traffic = db.session.query(
            func.coalesce(func.sum(User.current_usage), 0)
        ).filter(
            User.agent_id == agent.id
        ).scalar() or 0
        
        return {
            'agent_id': agent.id,
            'traffic_limit_GB': agent.traffic_limit_GB,
            'traffic_used_GB': agent.traffic_used_GB,
            'traffic_remaining_GB': agent.traffic_remaining_GB,
            'traffic_usage_percentage': agent.traffic_usage_percentage,
            'is_traffic_limit_exceeded': agent.is_traffic_limit_exceeded,
            'is_traffic_warning': agent.is_traffic_warning,
            'users_count': agent.users.count(),
            'active_users_count': active_users_count,
            'total_users_traffic_GB': total_users_traffic / (1024 ** 3)
        }

