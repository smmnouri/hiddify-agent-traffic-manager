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
    form_overrides_start = -1
    form_overrides_end = -1
    
    # Find form_overrides block - look for the exact pattern
    for i, line in enumerate(lines):
        if 'form_overrides = {' in line:
            form_overrides_start = i
        elif form_overrides_start >= 0:
            # Check if this is the closing brace of form_overrides
            stripped = line.strip()
            if stripped == '}' and i > form_overrides_start:
                # Verify this is form_overrides by checking previous lines
                # Should have 'parent_admin': SubAdminsField before this
                # and should NOT have 'column_labels' after form_overrides_start
                prev_section = '\n'.join(lines[form_overrides_start:i+1])
                next_section = '\n'.join(lines[i+1:min(i+5, len(lines))])
                if "'parent_admin': SubAdminsField" in prev_section and 'column_labels' not in prev_section:
                    # Double check: the next non-empty line should be column_labels or something else, not another }
                    form_overrides_end = i
                    break
    
    if form_overrides_start >= 0 and form_overrides_end > form_overrides_start:
        # Check if already added
        form_overrides_section = '\n'.join(lines[form_overrides_start:form_overrides_end+1])
        if "'traffic_limit_GB': TrafficLimitField" not in form_overrides_section:
            # Get indentation from 'parent_admin' line
            indent = ' ' * 8  # Default indentation
            parent_admin_line_idx = -1
            for j in range(form_overrides_start, form_overrides_end):
                if "'parent_admin': SubAdminsField" in lines[j]:
                    # Get indentation from this line
                    indent = ' ' * (len(lines[j]) - len(lines[j].lstrip()))
                    parent_admin_line_idx = j
                    break
            
            # Check if parent_admin line has a comma at the end
            if parent_admin_line_idx >= 0:
                parent_line = lines[parent_admin_line_idx].rstrip()
                if not parent_line.endswith(','):
                    # Add comma to parent_admin line
                    lines[parent_admin_line_idx] = parent_line + ','
            
            # Insert before closing brace with correct indentation
            lines.insert(form_overrides_end, f"{indent}'traffic_limit_GB': TrafficLimitField,")
            content = '\n'.join(lines)
            print("Added TrafficLimitField to form_overrides")
    else:
        # Fallback to regex - be more specific, must have parent_admin and end before column_labels
        # First ensure parent_admin has a comma
        content = re.sub(
            r"('parent_admin': SubAdminsField)(\s*\n\s*\})",
            r"\1,\2",
            content
        )
        form_overrides_pattern = r"(form_overrides = \{[\s\S]*?'parent_admin': SubAdminsField,\s*\n\s*\})(\s*column_labels)"
        if re.search(form_overrides_pattern, content):
            content = re.sub(
                form_overrides_pattern,
                r"\1\n        'traffic_limit_GB': TrafficLimitField,\n    }\2",
                content
            )
            print("Added TrafficLimitField to form_overrides (regex fallback)")
    
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
        # Find the correct indentation by looking at existing formatter functions
        lines = content.split('\n')
        formatter_indent = '    '  # Default: 4 spaces (class method level)
        for i, line in enumerate(lines):
            if 'def _' in line and ('formatter' in line.lower() or '_ul_formatter' in line or '_name_formatter' in line):
                # Get indentation from existing formatter
                formatter_indent = ' ' * (len(line) - len(line.lstrip()))
                break
        
        # Find where to insert (before column_formatters)
        insert_pos = -1
        for i, line in enumerate(lines):
            if 'column_formatters = {' in line:
                insert_pos = i
                break
        
        if insert_pos > 0:
            # Build formatter functions with correct indentation
            formatter_lines = [
                '',
                f'{formatter_indent}def _format_traffic_limit(view, context, model, name):',
                f'{formatter_indent}    """Format traffic limit column"""',
                f'{formatter_indent}    from hiddifypanel.models.admin import AdminMode',
                f'{formatter_indent}    from markupsafe import Markup',
                f'{formatter_indent}    from flask_babel import gettext as _',
                f'{formatter_indent}    if model.mode != AdminMode.agent:',
                f'{formatter_indent}        return \'-\'',
                f'{formatter_indent}    try:',
                f'{formatter_indent}        limit = model.traffic_limit_GB if hasattr(model, \'traffic_limit_GB\') else None',
                f'{formatter_indent}        if limit is None:',
                f'{formatter_indent}            return Markup(\'<span class="badge badge-info">\' + _(\'Unlimited\') + \'</span>\')',
                f'{formatter_indent}        return f"{{limit:.2f}} GB"',
                f'{formatter_indent}    except Exception:',
                f'{formatter_indent}        return \'-\'',
                '',
                f'{formatter_indent}def _format_total_traffic(view, context, model, name):',
                f'{formatter_indent}    """Format total traffic column"""',
                f'{formatter_indent}    from hiddifypanel.models.admin import AdminMode',
                f'{formatter_indent}    if model.mode != AdminMode.agent:',
                f'{formatter_indent}        return \'-\'',
                f'{formatter_indent}    try:',
                f'{formatter_indent}        total = model.get_total_traffic_GB() if hasattr(model, \'get_total_traffic_GB\') else 0',
                f'{formatter_indent}        return f"{{total:.2f}} GB"',
                f'{formatter_indent}    except Exception:',
                f'{formatter_indent}        return \'-\'',
                '',
                f'{formatter_indent}def _format_remaining_traffic(view, context, model, name):',
                f'{formatter_indent}    """Format remaining traffic column"""',
                f'{formatter_indent}    from hiddifypanel.models.admin import AdminMode',
                f'{formatter_indent}    from markupsafe import Markup',
                f'{formatter_indent}    from flask_babel import gettext as _',
                f'{formatter_indent}    if model.mode != AdminMode.agent:',
                f'{formatter_indent}        return \'-\'',
                f'{formatter_indent}    try:',
                f'{formatter_indent}        remaining = model.get_remaining_traffic_GB() if hasattr(model, \'get_remaining_traffic_GB\') else None',
                f'{formatter_indent}        if remaining is None:',
                f'{formatter_indent}            return Markup(\'<span class="badge badge-info">\' + _(\'Unlimited\') + \'</span>\')',
                f'{formatter_indent}        return f"{{remaining:.2f}} GB"',
                f'{formatter_indent}    except Exception:',
                f'{formatter_indent}        return \'-\'',
                '',
                f'{formatter_indent}def _format_traffic_status(view, context, model, name):',
                f'{formatter_indent}    """Format traffic status column with progress bar"""',
                f'{formatter_indent}    from hiddifypanel.models.admin import AdminMode',
                f'{formatter_indent}    from markupsafe import Markup',
                f'{formatter_indent}    from flask_babel import gettext as _',
                f'{formatter_indent}    if model.mode != AdminMode.agent:',
                f'{formatter_indent}        return \'-\'',
                f'{formatter_indent}    try:',
                f'{formatter_indent}        if not hasattr(model, \'traffic_limit_GB\') or model.traffic_limit_GB is None:',
                f'{formatter_indent}            return Markup(\'<span class="badge badge-info">\' + _(\'No Limit\') + \'</span>\')',
                f'{formatter_indent}        total_gb = model.get_total_traffic_GB() if hasattr(model, \'get_total_traffic_GB\') else 0',
                f'{formatter_indent}        limit_gb = model.traffic_limit_GB',
                f'{formatter_indent}        usage_percent = min((total_gb / limit_gb) * 100, 100) if limit_gb > 0 else 0',
                f'{formatter_indent}        is_exceeded = model.is_traffic_limit_exceeded() if hasattr(model, \'is_traffic_limit_exceeded\') else False',
                f'{formatter_indent}        if is_exceeded:',
                f'{formatter_indent}            color = "#ff7e7e"',
                f'{formatter_indent}            badge_class = "badge-danger"',
                f'{formatter_indent}            status_text = _(\'Exceeded\')',
                f'{formatter_indent}        elif usage_percent > 90:',
                f'{formatter_indent}            color = "#ffc107"',
                f'{formatter_indent}            badge_class = "badge-warning"',
                f'{formatter_indent}            status_text = _(\'Warning\')',
                f'{formatter_indent}        else:',
                f'{formatter_indent}            color = "#9ee150"',
                f'{formatter_indent}            badge_class = "badge-success"',
                f'{formatter_indent}            status_text = _(\'OK\')',
                f'{formatter_indent}        return Markup(f"""',
                f'{formatter_indent}            <div class="progress progress-lg position-relative" style="min-width: 100px;">',
                f'{formatter_indent}              <div class="progress-bar progress-bar-striped" role="progressbar" style="width: {{usage_percent:.1f}}%;background-color: {{color}};" aria-valuenow="{{usage_percent:.1f}}" aria-valuemin="0" aria-valuemax="100"></div>',
                f'{formatter_indent}              <span class=\'badge position-absolute {{badge_class}}\' style="left:auto;right:auto;width: 100%;font-size:1em">{{status_text}} ({{usage_percent:.1f}}%)</span>',
                f'{formatter_indent}            </div>',
                f'{formatter_indent}            """)',
                f'{formatter_indent}    except Exception:',
                f'{formatter_indent}        return \'-\'',
                ''
            ]
            
            # Insert the formatter functions before column_formatters
            for i, formatter_line in enumerate(formatter_lines):
                lines.insert(insert_pos + i, formatter_line)
            
            content = '\n'.join(lines)
            print("Added formatter functions before column_formatters")
    
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

