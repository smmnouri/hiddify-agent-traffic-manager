"""
Admin interface extension for agent traffic management
"""
from flask_admin import expose
from flask_babel import gettext as _
from loguru import logger

from hiddifypanel.models.admin import AdminUser, AdminMode
from hiddifypanel.panel.admin.adminlte import AdminLTEMixin
from ..utils.traffic_calculator import AgentTrafficCalculator
from ..utils.traffic_checker import AgentTrafficChecker


def extend_admin_user_view(admin_view):
    """Extend AdminUser admin view with traffic management"""
    
    try:
        # Add traffic limit field to form
        original_form_columns = admin_view.form_columns
        
        if original_form_columns:
            if 'traffic_limit_GB' not in original_form_columns:
                admin_view.form_columns = list(original_form_columns) + ['traffic_limit_GB']
        else:
            admin_view.form_columns = ['traffic_limit_GB']
    except Exception as e:
        from loguru import logger
        logger.warning(f"Could not add traffic_limit_GB to form_columns: {e}")
    
    try:
        # Add traffic limit and traffic info to column list
        original_column_list = admin_view.column_list
        
        if original_column_list:
            # Add traffic columns if not already present
            traffic_columns = ['traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status']
            for col in traffic_columns:
                if col not in original_column_list:
                    admin_view.column_list = list(original_column_list) + [col]
        else:
            admin_view.column_list = ['traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status']
    except Exception as e:
        from loguru import logger
        logger.warning(f"Could not add traffic columns to column_list: {e}")
    
    # Add custom column formatters
    def _format_traffic_limit(view, context, model, name):
        """Format traffic limit column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        limit = model.traffic_limit_GB
        if limit is None:
            return _('Unlimited')
        return f"{limit:.2f} GB"
    
    def _format_total_traffic(view, context, model, name):
        """Format total traffic column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        total = model.get_total_traffic_GB()
        return f"{total:.2f} GB"
    
    def _format_remaining_traffic(view, context, model, name):
        """Format remaining traffic column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        remaining = model.get_remaining_traffic_GB()
        if remaining is None:
            return '-'
        return f"{remaining:.2f} GB"
    
    def _format_traffic_status(view, context, model, name):
        """Format traffic status column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        if model.traffic_limit_GB is None:
            return '<span class="badge badge-info">No Limit</span>'
        
        is_exceeded = model.is_traffic_limit_exceeded()
        usage_percent = (model.get_total_traffic_GB() / model.traffic_limit_GB) * 100
        
        if is_exceeded:
            return f'<span class="badge badge-danger">Exceeded ({usage_percent:.1f}%)</span>'
        elif usage_percent > 90:
            return f'<span class="badge badge-warning">Warning ({usage_percent:.1f}%)</span>'
        else:
            return f'<span class="badge badge-success">OK ({usage_percent:.1f}%)</span>'
    
    # Add custom columns
    try:
        admin_view.column_formatters = getattr(admin_view, 'column_formatters', {})
        if not isinstance(admin_view.column_formatters, dict):
            admin_view.column_formatters = {}
        admin_view.column_formatters['traffic_limit_GB'] = _format_traffic_limit
        admin_view.column_formatters['total_traffic'] = _format_total_traffic
        admin_view.column_formatters['remaining_traffic'] = _format_remaining_traffic
        admin_view.column_formatters['traffic_status'] = _format_traffic_status
    except Exception as e:
        from loguru import logger
        logger.warning(f"Could not add column formatters: {e}")
    
    # Add custom action
    @admin_view.action('check_traffic', _('Check Traffic & Disable if Exceeded'))
    def action_check_traffic(self, ids):
        """Action to check traffic for selected agents"""
        try:
            from flask import flash
            from hiddifypanel.database import db
            
            count = 0
            for agent_id in ids:
                agent = AdminUser.query.get(agent_id)
                if agent and agent.mode == AdminMode.agent:
                    was_exceeded = AgentTrafficChecker.check_and_disable_if_exceeded(agent.id)
                    if was_exceeded:
                        count += 1
            
            if count > 0:
                flash(_(f'Traffic checked for {count} agent(s). Users disabled if exceeded.'), 'warning')
            else:
                flash(_('All agents are within their traffic limits.'), 'success')
            
            db.session.commit()
        except Exception as e:
            logger.error(f"Error in check_traffic action: {e}")
            flash(_('Error checking traffic: {}').format(str(e)), 'error')
    
    return admin_view


def add_traffic_management_view(admin, app):
    """Add traffic management view to admin"""
    
    class AgentTrafficManagementView(AdminLTEMixin):
        """View for managing agent traffic"""
        
        @expose('/')
        def index(self):
            """Show all agents traffic statistics"""
            from flask import render_template
            
            agents_traffic = AgentTrafficCalculator.get_all_agents_traffic()
            
            return render_template(
                'admin/agent_traffic_management.html',
                agents_traffic=agents_traffic
            )
        
        @expose('/check-all', methods=['POST'])
        def check_all(self):
            """Check all agents traffic"""
            from flask import flash, redirect, url_for
            
            try:
                exceeded_count = AgentTrafficChecker.check_all_agents()
                
                if exceeded_count > 0:
                    flash(
                        _('Traffic check completed. {} agent(s) exceeded their limits and users were disabled.').format(exceeded_count),
                        'warning'
                    )
                else:
                    flash(_('All agents are within their traffic limits.'), 'success')
                
                return redirect(url_for('agenttrafficmanagementview.index'))
            except Exception as e:
                logger.error(f"Error checking all agents: {e}")
                flash(_('Error checking agents: {}').format(str(e)), 'error')
                return redirect(url_for('agenttrafficmanagementview.index'))
    
    admin.add_view(AgentTrafficManagementView(
        name=_('Agent Traffic Management'),
        endpoint='agenttrafficmanagementview',
        category=_('Traffic Management')
    ))
    
    logger.success("Agent traffic management view added to admin")

