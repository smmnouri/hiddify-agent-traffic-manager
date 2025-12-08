#!/usr/bin/env python3
"""
Patch script for AdminstratorAdmin.py
Adds traffic management fields and columns to the admin interface
"""
import sys
import re
from pathlib import Path

def patch_adminstrator_admin(file_path):
    """Apply patches to AdminstratorAdmin.py"""
    
    if not Path(file_path).exists():
        print(f"Error: File not found: {file_path}")
        return False
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    
    # 1. Add import for TrafficLimitField at the top (after other imports)
    # Use try/except to handle import errors gracefully
    if 'TrafficLimitField' not in content or ('from hiddify_agent_traffic_manager' not in content and 'TrafficLimitField =' not in content):
        lines = content.split('\n')
        import_added = False
        
        # Find the last import line (after line with 'from hiddifypanel import hutils')
        for i, line in enumerate(lines):
            if 'from hiddifypanel import hutils' in line:
                # Add import after this line
                import_lines = [
                    '',
                    'try:',
                    '    from hiddify_agent_traffic_manager.admin.agent_traffic_admin import TrafficLimitField',
                    'except ImportError:',
                    '    # Fallback if module not available',
                    '    from wtforms import DecimalField',
                    '    TrafficLimitField = DecimalField',
                    ''
                ]
                for j, import_line in enumerate(import_lines):
                    lines.insert(i + 1 + j, import_line)
                import_added = True
                break
        
        if import_added:
            content = '\n'.join(lines)
        else:
            # If hutils import not found, add after last import
            for i in range(len(lines) - 1, -1, -1):
                if lines[i].strip().startswith('import ') or lines[i].strip().startswith('from '):
                    import_lines = [
                        '',
                        'try:',
                        '    from hiddify_agent_traffic_manager.admin.agent_traffic_admin import TrafficLimitField',
                        'except ImportError:',
                        '    from wtforms import DecimalField',
                        '    TrafficLimitField = DecimalField',
                        ''
                    ]
                    for j, import_line in enumerate(import_lines):
                        lines.insert(i + 1 + j, import_line)
                    content = '\n'.join(lines)
                    break
    
    # 2. Add traffic_limit_GB to form_columns (after max_active_users)
    form_columns_pattern = r"(form_columns = \[.*?'max_active_users', 'max_users',)(.*?\])"
    if re.search(form_columns_pattern, content, re.DOTALL):
        content = re.sub(
            form_columns_pattern,
            r"\1 'traffic_limit_GB',\2",
            content,
            flags=re.DOTALL
        )
    else:
        # Try alternative pattern
        form_columns_pattern2 = r"(form_columns = \[.*?'max_users',)(.*?\])"
        if re.search(form_columns_pattern2, content, re.DOTALL):
            content = re.sub(
                form_columns_pattern2,
                r"\1 'traffic_limit_GB',\2",
                content,
                flags=re.DOTALL
            )
    
    # 3. Add traffic columns to column_list (after max_users)
    column_list_pattern = r"(column_list = \[.*?'max_users',)(.*?'online_users'.*?\])"
    if re.search(column_list_pattern, content, re.DOTALL):
        content = re.sub(
            column_list_pattern,
            r"\1 'traffic_limit_GB', 'total_traffic', 'remaining_traffic', 'traffic_status',\2",
            content,
            flags=re.DOTALL
        )
    
    # 4. Add TrafficLimitField to form_overrides
    # Use line-by-line approach to ensure correct placement
    lines = content.split('\n')
    form_overrides_found = False
    form_overrides_end = -1
    
    for i, line in enumerate(lines):
        if 'form_overrides = {' in line:
            form_overrides_found = True
        elif form_overrides_found and line.strip() == '}':
            form_overrides_end = i
            # Check if traffic_limit_GB is already there
            form_overrides_section = '\n'.join(lines[lines.index([l for l in lines if 'form_overrides = {' in l][0]):i+1])
            if "'traffic_limit_GB': TrafficLimitField" not in form_overrides_section:
                # Insert before closing brace
                lines.insert(i, "        'traffic_limit_GB': TrafficLimitField,")
            break
    
    if form_overrides_end > 0:
        content = '\n'.join(lines)
    else:
        # Fallback to regex if line-by-line didn't work
        form_overrides_pattern = r"(form_overrides = \{[\s\S]*?'parent_admin': SubAdminsField\s*\n\s*\})"
        if re.search(form_overrides_pattern, content):
            content = re.sub(
                form_overrides_pattern,
                r"\1\n        'traffic_limit_GB': TrafficLimitField,",
                content
            )
    
    # 5. Add column labels
    column_labels_pattern = r"('can_add_admin': _\('Can add sub admin'\)\s*\n\s*\})"
    if re.search(column_labels_pattern, content):
        content = re.sub(
            column_labels_pattern,
            r"\1\n        'traffic_limit_GB': _('Traffic Limit (GB)'),\n        'total_traffic': _('Total Traffic (GB)'),\n        'remaining_traffic': _('Remaining Traffic (GB)'),\n        'traffic_status': _('Traffic Status'),",
            content
        )
    
    # 6. Add form_args for traffic_limit_GB
    form_args_pattern = r"(form_args = \{[^}]*'uuid': \{[^}]*\}\s*\}\s*)\}"
    if re.search(form_args_pattern, content, re.DOTALL):
        content = re.sub(
            form_args_pattern,
            r"\1,\n        'traffic_limit_GB': {\n            'validators': [],\n            'label': _('Traffic Limit (GB)'),\n            'description': _('Maximum total traffic allowed for this agent and all its users (in GB). Leave empty for unlimited.')\n        }\n    }",
            content,
            flags=re.DOTALL
        )
    
    # 7. Add formatters - we'll define them inline since they're nested functions
    # Check if formatters are already defined
    if '_format_traffic_limit' not in content or 'def _format_traffic_limit' not in content:
        # Add formatter functions before column_formatters dict
        formatter_functions = '''
    def _format_traffic_limit(view, context, model, name):
        """Format traffic limit column"""
        from hiddifypanel.models.admin import AdminMode
        from markupsafe import Markup
        from flask_babel import gettext as _
        if model.mode != AdminMode.agent:
            return '-'
        try:
            limit = model.traffic_limit_GB if hasattr(model, 'traffic_limit_GB') else None
            if limit is None:
                return Markup('<span class="badge badge-info">' + _('Unlimited') + '</span>')
            return f"{limit:.2f} GB"
        except Exception:
            return '-'
    
    def _format_total_traffic(view, context, model, name):
        """Format total traffic column"""
        from hiddifypanel.models.admin import AdminMode
        if model.mode != AdminMode.agent:
            return '-'
        try:
            total = model.get_total_traffic_GB() if hasattr(model, 'get_total_traffic_GB') else 0
            return f"{total:.2f} GB"
        except Exception:
            return '-'
    
    def _format_remaining_traffic(view, context, model, name):
        """Format remaining traffic column"""
        from hiddifypanel.models.admin import AdminMode
        from markupsafe import Markup
        from flask_babel import gettext as _
        if model.mode != AdminMode.agent:
            return '-'
        try:
            remaining = model.get_remaining_traffic_GB() if hasattr(model, 'get_remaining_traffic_GB') else None
            if remaining is None:
                return Markup('<span class="badge badge-info">' + _('Unlimited') + '</span>')
            return f"{remaining:.2f} GB"
        except Exception:
            return '-'
    
    def _format_traffic_status(view, context, model, name):
        """Format traffic status column with progress bar"""
        from hiddifypanel.models.admin import AdminMode
        from markupsafe import Markup
        from flask_babel import gettext as _
        if model.mode != AdminMode.agent:
            return '-'
        try:
            if not hasattr(model, 'traffic_limit_GB') or model.traffic_limit_GB is None:
                return Markup('<span class="badge badge-info">' + _('No Limit') + '</span>')
            total_gb = model.get_total_traffic_GB() if hasattr(model, 'get_total_traffic_GB') else 0
            limit_gb = model.traffic_limit_GB
            usage_percent = min((total_gb / limit_gb) * 100, 100) if limit_gb > 0 else 0
            is_exceeded = model.is_traffic_limit_exceeded() if hasattr(model, 'is_traffic_limit_exceeded') else False
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
        except Exception:
            return '-'
'''
        # Insert before column_formatters
        column_formatters_pattern = r'(column_formatters = \{)'
        if re.search(column_formatters_pattern, content):
            content = re.sub(
                column_formatters_pattern,
                formatter_functions + r'\n    \1',
                content
            )
    
    # 8. Add formatters to column_formatters dict
    column_formatters_pattern = r"('UserLinks': _ul_formatter\s*\n\s*\})"
    if re.search(column_formatters_pattern, content):
        content = re.sub(
            column_formatters_pattern,
            r"\1\n        'traffic_limit_GB': _format_traffic_limit,\n        'total_traffic': _format_total_traffic,\n        'remaining_traffic': _format_remaining_traffic,\n        'traffic_status': _format_traffic_status,",
            content
        )
    
    # 9. Modify on_model_change to handle traffic_limit_GB
    on_model_change_pattern = r"(if not model\.password and not is_created:\s*model\.password=AdminUser\.by_id\(model\.id\)\.password\s*)"
    if re.search(on_model_change_pattern, content):
        content = re.sub(
            on_model_change_pattern,
            r"\1\n\n        # Handle traffic_limit_GB from form\n        if hasattr(form, 'traffic_limit_GB') and form.traffic_limit_GB.data is not None:\n            from hiddifypanel.database import db\n            traffic_limit_bytes = form.traffic_limit_GB.data\n            db.session.execute(\n                db.text(\"UPDATE admin_user SET traffic_limit = :limit WHERE id = :id\"),\n                {\"limit\": traffic_limit_bytes, \"id\": model.id}\n            )",
            content
        )
    
    # Check if any changes were made
    if content == original_content:
        print("Warning: No changes were made. File might already be patched.")
        return False
    
    # Write the patched content
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"Successfully patched: {file_path}")
    return True

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python patch_adminstrator_admin.py <path_to_AdminstratorAdmin.py>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    success = patch_adminstrator_admin(file_path)
    sys.exit(0 if success else 1)

