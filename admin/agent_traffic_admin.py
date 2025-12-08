"""
Admin interface extension for agent traffic management
"""
from flask_admin import expose
from flask_babel import gettext as _
from loguru import logger
from wtforms import DecimalField
from markupsafe import Markup

from hiddifypanel.models.admin import AdminUser, AdminMode
from hiddifypanel.panel.admin.adminlte import AdminLTEMixin
from ..utils.traffic_calculator import AgentTrafficCalculator
from ..utils.traffic_checker import AgentTrafficChecker

ONE_GIG = 1024 * 1024 * 1024


class TrafficLimitField(DecimalField):
    """Custom field for traffic limit in GB"""
    def process_data(self, value):
        if value is not None:
            # value is in bytes, convert to GB
            self.data = value / ONE_GIG
        else:
            self.data = None

    def process_formdata(self, valuelist):
        if valuelist and valuelist[0]:
            # Convert GB to bytes
            self.data = int(float(valuelist[0]) * ONE_GIG)
        else:
            self.data = None


def extend_admin_user_view(admin_view):
    """Extend AdminUser admin view with traffic management"""
    
    try:
        # Add traffic limit field to form
        original_form_columns = list(admin_view.form_columns) if admin_view.form_columns else []
        
        if 'traffic_limit_GB' not in original_form_columns:
            # Add after max_active_users or max_users
            if 'max_active_users' in original_form_columns:
                idx = original_form_columns.index('max_active_users') + 1
                original_form_columns.insert(idx, 'traffic_limit_GB')
            elif 'max_users' in original_form_columns:
                idx = original_form_columns.index('max_users') + 1
                original_form_columns.insert(idx, 'traffic_limit_GB')
            else:
                original_form_columns.append('traffic_limit_GB')
            
            admin_view.form_columns = original_form_columns
            logger.debug("Added traffic_limit_GB to form_columns")
    except Exception as e:
        logger.warning(f"Could not add traffic_limit_GB to form_columns: {e}")
    
    try:
        # Add traffic limit and traffic info to column list
        original_column_list = list(admin_view.column_list) if admin_view.column_list else []
        
        # Add traffic columns if not already present
        traffic_columns = ['traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status']
        for col in traffic_columns:
            if col not in original_column_list:
                original_column_list.append(col)
        
        admin_view.column_list = original_column_list
        logger.debug("Added traffic columns to column_list")
    except Exception as e:
        logger.warning(f"Could not add traffic columns to column_list: {e}")
    
    # Add form override for traffic_limit_GB
    try:
        if not hasattr(admin_view, 'form_overrides'):
            admin_view.form_overrides = {}
        elif not isinstance(admin_view.form_overrides, dict):
            admin_view.form_overrides = {}
        
        # Preserve existing form_overrides
        existing_overrides = admin_view.form_overrides.copy()
        existing_overrides['traffic_limit_GB'] = TrafficLimitField
        admin_view.form_overrides = existing_overrides
        logger.debug("Added TrafficLimitField to form_overrides")
    except Exception as e:
        logger.warning(f"Could not add TrafficLimitField to form_overrides: {e}")
    
    # Override on_model_change to handle traffic_limit_GB
    original_on_model_change = admin_view.on_model_change
    def on_model_change_with_traffic(self, form, model, is_created):
        """Handle traffic_limit_GB field in form"""
        try:
            # Get traffic_limit_GB from form
            if hasattr(form, 'traffic_limit_GB') and form.traffic_limit_GB.data is not None:
                # The TrafficLimitField already converts GB to bytes
                # But we need to save it to the database
                from hiddifypanel.database import db
                traffic_limit_bytes = form.traffic_limit_GB.data
                
                # Update the model's traffic_limit directly
                db.session.execute(
                    db.text("UPDATE admin_user SET traffic_limit = :limit WHERE id = :id"),
                    {"limit": traffic_limit_bytes, "id": model.id}
                )
                logger.debug(f"Updated traffic_limit for admin {model.id}: {traffic_limit_bytes} bytes")
        except Exception as e:
            logger.warning(f"Error handling traffic_limit_GB in on_model_change: {e}")
        
        # Call original on_model_change
        if original_on_model_change:
            try:
                original_on_model_change(self, form, model, is_created)
            except Exception as e:
                logger.warning(f"Error in original on_model_change: {e}")
    
    admin_view.on_model_change = on_model_change_with_traffic
    logger.debug("Overrode on_model_change to handle traffic_limit_GB")
    
    # Add column labels
    try:
        if not hasattr(admin_view, 'column_labels'):
            admin_view.column_labels = {}
        admin_view.column_labels.update({
            'traffic_limit_GB': _('Traffic Limit (GB)'),
            'total_traffic': _('Total Traffic (GB)'),
            'remaining_traffic': _('Remaining Traffic (GB)'),
            'traffic_status': _('Traffic Status')
        })
        logger.debug("Added traffic column labels")
    except Exception as e:
        logger.warning(f"Could not add column labels: {e}")
    
    # Add custom column formatters
    # These functions are also exported for use in patched AdminstratorAdmin.py
    def _format_traffic_limit(view, context, model, name):
        """Format traffic limit column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        try:
            limit = model.traffic_limit_GB
            if limit is None:
                return Markup('<span class="badge badge-info">' + _('Unlimited') + '</span>')
            return f"{limit:.2f} GB"
        except Exception as e:
            logger.debug(f"Error formatting traffic_limit: {e}")
            return '-'
    
    def _format_total_traffic(view, context, model, name):
        """Format total traffic column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        try:
            total = model.get_total_traffic_GB()
            return f"{total:.2f} GB"
        except Exception as e:
            logger.debug(f"Error formatting total_traffic: {e}")
            return '-'
    
    def _format_remaining_traffic(view, context, model, name):
        """Format remaining traffic column"""
        if model.mode != AdminMode.agent:
            return '-'
        
        try:
            remaining = model.get_remaining_traffic_GB()
            if remaining is None:
                return Markup('<span class="badge badge-info">' + _('Unlimited') + '</span>')
            return f"{remaining:.2f} GB"
        except Exception as e:
            logger.debug(f"Error formatting remaining_traffic: {e}")
            return '-'
    
    def _format_traffic_status(view, context, model, name):
        """Format traffic status column with progress bar"""
        if model.mode != AdminMode.agent:
            return '-'
        
        try:
            if not hasattr(model, 'traffic_limit_GB') or model.traffic_limit_GB is None:
                return Markup('<span class="badge badge-info">' + _('No Limit') + '</span>')
            
            total_gb = model.get_total_traffic_GB()
            limit_gb = model.traffic_limit_GB
            usage_percent = min((total_gb / limit_gb) * 100, 100) if limit_gb > 0 else 0
            
            is_exceeded = model.is_traffic_limit_exceeded()
            
            if is_exceeded:
                color = "#ff7e7e"
                badge_class = "badge-danger"
                status_text = _('Exceeded')
            elif usage_percent > 90:
                color = "#ffc107"
                badge_class = "badge-warning"
                status_text = _('Warning')
            else:
                color = "#9ee150"
                badge_class = "badge-success"
                status_text = _('OK')
            
            return Markup(f"""
            <div class="progress progress-lg position-relative" style="min-width: 100px;">
              <div class="progress-bar progress-bar-striped" role="progressbar" style="width: {usage_percent:.1f}%;background-color: {color};" aria-valuenow="{usage_percent:.1f}" aria-valuemin="0" aria-valuemax="100"></div>
              <span class='badge position-absolute {badge_class}' style="left:auto;right:auto;width: 100%;font-size:1em">{status_text} ({usage_percent:.1f}%)</span>
            </div>
            """)
        except Exception as e:
            logger.debug(f"Error formatting traffic_status: {e}")
            return '-'
    
    # Add custom columns to formatters
    try:
        if not hasattr(admin_view, 'column_formatters'):
            admin_view.column_formatters = {}
        elif not isinstance(admin_view.column_formatters, dict):
            admin_view.column_formatters = {}
        
        # Preserve existing formatters
        existing_formatters = admin_view.column_formatters.copy()
        
        # Add our formatters
        existing_formatters.update({
            'traffic_limit_GB': _format_traffic_limit,
            'total_traffic': _format_total_traffic,
            'remaining_traffic': _format_remaining_traffic,
            'traffic_status': _format_traffic_status
        })
        
        admin_view.column_formatters = existing_formatters
        logger.debug("Added traffic column formatters")
    except Exception as e:
        logger.warning(f"Could not add column formatters: {e}")
    
    # Add form args for traffic_limit_GB
    try:
        if not hasattr(admin_view, 'form_args'):
            admin_view.form_args = {}
        admin_view.form_args['traffic_limit_GB'] = {
            'validators': [],
            'label': _('Traffic Limit (GB)'),
            'description': _('Maximum total traffic allowed for this agent and all its users (in GB). Leave empty for unlimited.')
        }
        logger.debug("Added form_args for traffic_limit_GB")
    except Exception as e:
        logger.warning(f"Could not add form_args: {e}")
    
    # Add custom action
    try:
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
                from flask import flash
                flash(_('Error checking traffic: {}').format(str(e)), 'error')
        
        logger.debug("Added check_traffic action")
    except Exception as e:
        logger.warning(f"Could not add check_traffic action: {e}")
    
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
    
    try:
        admin.add_view(AgentTrafficManagementView(
            name=_('Agent Traffic Management'),
            endpoint='agenttrafficmanagementview',
            category=_('Traffic Management')
        ))
        logger.success("Agent traffic management view added to admin")
    except Exception as e:
        logger.warning(f"Could not add traffic management view: {e}")
