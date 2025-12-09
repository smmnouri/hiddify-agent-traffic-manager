"""
Agent/Reseller Model for HiddifyPanel
مدل Agent برای سیستم Reseller
"""
import datetime
from sqlalchemy import Column, Integer, BigInteger, DateTime, ForeignKey, Index
from sqlalchemy.orm import relationship
from hiddifypanel.database import db
from hiddifypanel.models.base_account import BaseAccount
from hiddifypanel.models.user import ONE_GIG


class Agent(BaseAccount):
    """
    Agent/Reseller Model
    هر Agent دارای سقف ترافیک مشخص است و می‌تواند کاربران ایجاد کند
    """
    __tablename__ = 'agent'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Traffic limits (in bytes)
    traffic_limit = Column(BigInteger, nullable=True, default=None, comment='Traffic limit in bytes, NULL = unlimited')
    traffic_used = Column(BigInteger, default=0, nullable=False, comment='Total traffic used by all users under this agent')
    
    # Timestamps
    created_at = Column(DateTime, default=datetime.datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow, nullable=False)
    
    # Relationships
    users = relationship('User', backref='agent', lazy='dynamic', foreign_keys='[User.agent_id]')
    
    # Indexes
    __table_args__ = (
        Index('idx_agent_traffic_limit', 'traffic_limit'),
        Index('idx_agent_traffic_used', 'traffic_used'),
    )
    
    @property
    def traffic_limit_GB(self) -> float | None:
        """Get traffic limit in GB"""
        if self.traffic_limit is None:
            return None
        return self.traffic_limit / ONE_GIG
    
    @traffic_limit_GB.setter
    def traffic_limit_GB(self, value: float | None):
        """Set traffic limit in GB"""
        if value is None:
            self.traffic_limit = None
        else:
            self.traffic_limit = int(value * ONE_GIG)
    
    @property
    def traffic_used_GB(self) -> float:
        """Get traffic used in GB"""
        return self.traffic_used / ONE_GIG
    
    @property
    def traffic_remaining_GB(self) -> float | None:
        """Get remaining traffic in GB"""
        if self.traffic_limit is None:
            return None
        remaining = self.traffic_limit - self.traffic_used
        return max(0, remaining / ONE_GIG)
    
    @property
    def traffic_usage_percentage(self) -> float | None:
        """Get traffic usage percentage"""
        if self.traffic_limit is None or self.traffic_limit == 0:
            return None
        return min(100.0, (self.traffic_used / self.traffic_limit) * 100)
    
    @property
    def is_traffic_limit_exceeded(self) -> bool:
        """Check if traffic limit is exceeded"""
        if self.traffic_limit is None:
            return False
        return self.traffic_used >= self.traffic_limit
    
    @property
    def is_traffic_warning(self) -> bool:
        """Check if traffic usage is above 90% (warning threshold)"""
        if self.traffic_limit is None:
            return False
        return self.traffic_usage_percentage and self.traffic_usage_percentage > 90
    
    def can_create_user(self, user_traffic_limit_GB: float = None) -> tuple[bool, str | None]:
        """
        Check if agent can create a new user with specified traffic limit
        
        Args:
            user_traffic_limit_GB: Traffic limit for the new user in GB
            
        Returns:
            tuple: (can_create: bool, error_message: str | None)
        """
        if self.traffic_limit is None:
            return True, None
        
        if self.is_traffic_limit_exceeded:
            return False, "Agent traffic limit exceeded"
        
        if user_traffic_limit_GB is not None:
            user_traffic_limit_bytes = int(user_traffic_limit_GB * ONE_GIG)
            new_total = self.traffic_used + user_traffic_limit_bytes
            
            if new_total > self.traffic_limit:
                remaining_GB = self.traffic_remaining_GB or 0
                return False, f"Creating user would exceed agent traffic limit. Remaining: {remaining_GB:.2f} GB"
        
        return True, None
    
    def update_traffic_used(self, commit: bool = True):
        """
        Update traffic_used by calculating sum of all users' current_usage
        """
        from hiddifypanel.models.user import User
        from sqlalchemy import func
        
        total_usage = db.session.query(
            func.coalesce(func.sum(User.current_usage), 0)
        ).filter(
            User.agent_id == self.id
        ).scalar() or 0
        
        self.traffic_used = total_usage
        self.updated_at = datetime.datetime.utcnow()
        
        if commit:
            db.session.commit()
    
    def to_dict(self, convert_date=True, dump_id=False) -> dict:
        """Convert to dictionary"""
        base = super().to_dict(convert_date=convert_date, dump_id=dump_id)
        if dump_id:
            base['id'] = self.id
        
        return {
            **base,
            'traffic_limit_GB': self.traffic_limit_GB,
            'traffic_used_GB': self.traffic_used_GB,
            'traffic_remaining_GB': self.traffic_remaining_GB,
            'traffic_usage_percentage': self.traffic_usage_percentage,
            'is_traffic_limit_exceeded': self.is_traffic_limit_exceeded,
            'is_traffic_warning': self.is_traffic_warning,
            'users_count': self.users.count() if hasattr(self, 'users') else 0,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None,
        }
    
    @classmethod
    def by_id(cls, id: int):
        """Get agent by ID"""
        return db.session.query(cls).filter(cls.id == id).first()
    
    @classmethod
    def by_uuid(cls, uuid: str):
        """Get agent by UUID"""
        return db.session.query(cls).filter(cls.uuid == uuid).first()
    
    @classmethod
    def get_all(cls):
        """Get all agents"""
        return db.session.query(cls).all()


class TrafficLog(db.Model):
    """
    Traffic Log Model
    برای لاگ کردن مصرف ترافیک هر کاربر و Agent
    """
    __tablename__ = 'traffic_log'
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Foreign keys
    user_id = Column(Integer, ForeignKey('user.id'), nullable=True, comment='User who consumed traffic')
    agent_id = Column(Integer, ForeignKey('agent.id'), nullable=True, comment='Agent who owns the user')
    
    # Traffic data
    used_traffic = Column(BigInteger, nullable=False, comment='Traffic used in bytes')
    
    # Metadata
    timestamp = Column(DateTime, default=datetime.datetime.utcnow, nullable=False, index=True)
    description = Column(db.String(512), nullable=True, comment='Description of traffic usage')
    
    # Relationships
    user = relationship('User', backref='traffic_logs', lazy='select')
    agent = relationship('Agent', backref='traffic_logs', lazy='select')
    
    # Indexes
    __table_args__ = (
        Index('idx_traffic_log_user_id', 'user_id'),
        Index('idx_traffic_log_agent_id', 'agent_id'),
        Index('idx_traffic_log_timestamp', 'timestamp'),
        Index('idx_traffic_log_user_agent', 'user_id', 'agent_id'),
    )
    
    @property
    def used_traffic_GB(self) -> float:
        """Get used traffic in GB"""
        return self.used_traffic / ONE_GIG
    
    def to_dict(self) -> dict:
        """Convert to dictionary"""
        return {
            'id': self.id,
            'user_id': self.user_id,
            'agent_id': self.agent_id,
            'used_traffic': self.used_traffic,
            'used_traffic_GB': self.used_traffic_GB,
            'timestamp': self.timestamp.isoformat() if self.timestamp else None,
            'description': self.description,
        }
    
    @classmethod
    def create_log(cls, user_id: int = None, agent_id: int = None, used_traffic: int = 0, 
                   description: str = None, commit: bool = True):
        """Create a new traffic log entry"""
        log = cls(
            user_id=user_id,
            agent_id=agent_id,
            used_traffic=used_traffic,
            description=description
        )
        db.session.add(log)
        if commit:
            db.session.commit()
        return log
    
    @classmethod
    def get_agent_traffic_logs(cls, agent_id: int, start_date: datetime.datetime = None, 
                               end_date: datetime.datetime = None, limit: int = 100):
        """Get traffic logs for an agent"""
        query = db.session.query(cls).filter(cls.agent_id == agent_id)
        
        if start_date:
            query = query.filter(cls.timestamp >= start_date)
        if end_date:
            query = query.filter(cls.timestamp <= end_date)
        
        return query.order_by(cls.timestamp.desc()).limit(limit).all()
    
    @classmethod
    def get_user_traffic_logs(cls, user_id: int, start_date: datetime.datetime = None,
                               end_date: datetime.datetime = None, limit: int = 100):
        """Get traffic logs for a user"""
        query = db.session.query(cls).filter(cls.user_id == user_id)
        
        if start_date:
            query = query.filter(cls.timestamp >= start_date)
        if end_date:
            query = query.filter(cls.timestamp <= end_date)
        
        return query.order_by(cls.timestamp.desc()).limit(limit).all()

